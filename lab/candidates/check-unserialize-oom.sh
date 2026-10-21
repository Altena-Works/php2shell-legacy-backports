#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 7.3.33 source tree required}
[[ -f "$source_tree/libs/libphp7.so" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/normal-unserialize-limit.php:/var/www/html/normal-unserialize-limit.php:ro" \
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

seed=$(podman exec "$container_id" curl -fsS --max-time 20 \
    'http://127.0.0.1/normal-unserialize-limit.php?seed=1')
[[ $seed == SEEDED ]] || exit 1

limited=$(podman exec "$container_id" curl -sS --max-time 30 \
    http://127.0.0.1/normal-unserialize-limit.php)
post=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $limited == *'Allowed memory size of 8388608 bytes exhausted'* ]] || exit 1
[[ $limited == *'normal-unserialize-limit.php'* ]] || exit 1
[[ ${pre%%$'\n'*} == ${post%%$'\n'*} ]] || exit 1
printf '%s\n' UNSERIALIZE_OOM_REPORTED WORKER_REUSED
