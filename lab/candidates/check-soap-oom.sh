#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 7.3.33 source tree required}
[[ -f "$source_tree/libs/libphp7.so" && -x "$source_tree/sapi/cli/php" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/normal-soap-large-response.php:/var/www/html/normal-soap-large-response.php:ro" \
    -v "$script_dir/normal-soap-limit.php:/var/www/html/normal-soap-limit.php:ro" \
    -v "$script_dir/../normal-worker.php:/var/www/html/normal-worker.php:ro" \
    localhost/php-backport-build:7.4 bash -lc '
        set -e
        install -m 644 /src/libs/libphp7.so /usr/lib/apache2/modules/libphp7.so
        printf "%s\n" "StartServers 1" "MinSpareServers 1" \
            "MaxSpareServers 1" "ServerLimit 1" "MaxRequestWorkers 1" \
            "php_value display_errors On" \
            > /etc/apache2/conf-enabled/one-worker.conf
        /src/sapi/cli/php -S 127.0.0.1:8081 -t /var/www/html >/tmp/soap-http.log 2>&1 &
        exec apache2-foreground
    ')
trap 'podman stop --time 2 "$container_id" >/dev/null 2>&1 || true' EXIT

pre=
for _ in $(seq 1 30); do
    if pre=$(podman exec "$container_id" curl -fsS --max-time 2 \
        http://127.0.0.1/normal-worker.php 2>/dev/null); then
        break
    fi
    sleep 1
done
[[ $pre == *$'\n'7.3.33$'\n'apache2handler ]] || exit 1
worker=${pre%%$'\n'*}

podman exec "$container_id" curl -sS --max-time 30 \
    -o /tmp/soap-oom.out http://127.0.0.1/normal-soap-limit.php >/dev/null
body=$(podman exec "$container_id" tail -c 700 /tmp/soap-oom.out)
post=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $body == *READY* && $body != *RETURNED* && \
    $body == *'Allowed memory size of 8388608 bytes exhausted'* ]] || {
    printf 'SOAP OOM was not reported at the expected boundary: %s\n' "$body" >&2
    exit 1
}
[[ ${post%%$'\n'*} == "$worker" ]] || {
    printf 'Apache worker changed after SOAP OOM\n' >&2
    exit 1
}
printf '%s\n' SOAP_BODY_OOM_REPORTED WORKER_REUSED
