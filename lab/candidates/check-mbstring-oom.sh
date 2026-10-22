#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 7.3.33 source tree required}
[[ -f "$source_tree/libs/libphp7.so" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/normal-mbstring-limit.php:/var/www/html/normal-mbstring-limit.php:ro" \
    -v "$script_dir/normal-mbregex-limit.php:/var/www/html/normal-mbregex-limit.php:ro" \
    -v "$script_dir/normal-mbfl-limit.php:/var/www/html/normal-mbfl-limit.php:ro" \
    -v "$script_dir/normal-kana-limit.php:/var/www/html/normal-kana-limit.php:ro" \
    -v "$script_dir/../normal-worker.php:/var/www/html/normal-worker.php:ro" \
    localhost/php-backport-build:7.4 bash -lc '
        set -e
        install -m 644 /src/libs/libphp7.so /usr/lib/apache2/modules/libphp7.so
        printf "%s\n" "StartServers 1" "MinSpareServers 1" \
            "MaxSpareServers 1" "ServerLimit 1" "MaxRequestWorkers 1" \
            "php_value display_errors On" \
            > /etc/apache2/conf-enabled/one-worker.conf
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
    -o /tmp/mbstring-oom.out http://127.0.0.1/normal-mbstring-limit.php >/dev/null
body=$(podman exec "$container_id" tail -c 700 /tmp/mbstring-oom.out)
post=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $body == *READY* && $body != *RETURNED* && \
    $body == *'Allowed memory size of 8388608 bytes exhausted'* ]] || {
    printf 'mbstring OOM was not reported at the expected boundary: %s\n' "$body" >&2
    exit 1
}
[[ ${post%%$'\n'*} == "$worker" ]] || {
    printf 'Apache worker changed after mbstring OOM\n' >&2
    exit 1
}
printf '%s\n' MBSTRING_INPUT_OOM_REPORTED WORKER_REUSED

podman exec "$container_id" curl -sS --max-time 30 \
    -o /tmp/mbregex-oom.out http://127.0.0.1/normal-mbregex-limit.php >/dev/null
body=$(podman exec "$container_id" tail -c 700 /tmp/mbregex-oom.out)
post=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $body == *READY* && $body != *RETURNED* && \
    $body == *'Allowed memory size of 8388608 bytes exhausted'* ]] || {
    printf 'mbregex OOM was not reported at the expected boundary: %s\n' "$body" >&2
    exit 1
}
[[ ${post%%$'\n'*} == "$worker" ]] || {
    printf 'Apache worker changed after mbregex OOM\n' >&2
    exit 1
}
printf '%s\n' MBREGEX_REPLACE_OOM_REPORTED WORKER_REUSED

podman exec "$container_id" curl -sS --max-time 30 \
    -o /tmp/mbfl-oom.out http://127.0.0.1/normal-mbfl-limit.php >/dev/null
body=$(podman exec "$container_id" tail -c 700 /tmp/mbfl-oom.out)
post=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $body == *READY* && $body != *RETURNED* && \
    $body == *'Allowed memory size of 8388608 bytes exhausted'* ]] || {
    printf 'mbfl OOM was not reported at the expected boundary: %s\n' "$body" >&2
    exit 1
}
[[ ${post%%$'\n'*} == "$worker" ]] || {
    printf 'Apache worker changed after mbfl OOM\n' >&2
    exit 1
}
printf '%s\n' MBFL_OUTPUT_OOM_REPORTED WORKER_REUSED

podman exec "$container_id" curl -sS --max-time 30 \
    -o /tmp/kana-oom.out http://127.0.0.1/normal-kana-limit.php >/dev/null
body=$(podman exec "$container_id" tail -c 700 /tmp/kana-oom.out)
post=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $body == *READY* && $body != *RETURNED* && \
    $body == *'Allowed memory size of 8388608 bytes exhausted'* ]] || {
    printf 'kana OOM was not reported at the expected boundary: %s\n' "$body" >&2
    exit 1
}
[[ ${post%%$'\n'*} == "$worker" ]] || {
    printf 'Apache worker changed after kana OOM\n' >&2
    exit 1
}
printf '%s\n' MBFL_KANA_OOM_REPORTED WORKER_REUSED
