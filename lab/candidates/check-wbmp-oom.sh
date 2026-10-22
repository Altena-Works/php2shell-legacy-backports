#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 7.3.33 source tree required}
[[ -f $source_tree/libs/libphp7.so ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)
container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/normal-wbmp.php:/var/www/html/normal-wbmp.php:ro" \
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
    pre=$(podman exec "$container_id" curl -fsS --max-time 2 \
        http://127.0.0.1/normal-worker.php 2>/dev/null) && break || true
    sleep 1
done
[[ $pre == *$'\n'7.3.33$'\n'apache2handler ]]
normal=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-wbmp.php)
[[ $normal == WBMP_OK ]]
seed=$(podman exec "$container_id" curl -fsS --max-time 30 \
    'http://127.0.0.1/normal-wbmp.php?mode=seed')
[[ $seed == WBMP_SEEDED ]]

podman exec "$container_id" curl -sS --max-time 30 \
    -o /tmp/wbmp-oom.out 'http://127.0.0.1/normal-wbmp.php?mode=read-limit' >/dev/null
body=$(podman exec "$container_id" tail -c 700 /tmp/wbmp-oom.out)
post=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $body == *READY* && $body != *RETURNED* && \
    $body == *'Allowed memory size of 8388608 bytes exhausted'* ]] || {
    printf 'WBMP OOM was not reported as expected: %s\n' "$body" >&2
    exit 1
}
[[ ${pre%%$'\n'*} == ${post%%$'\n'*} ]]
printf 'WBMP_NORMAL_AND_OOM_REPORTED\nWORKER_REUSED\n'
