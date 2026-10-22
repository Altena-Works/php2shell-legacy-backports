#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 7.3.33 source tree required}
[[ -f "$source_tree/libs/libphp7.so" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)
container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/normal-iconv-limit.php:/var/www/html/normal-iconv-limit.php:ro" \
    -v "$script_dir/../normal-worker.php:/var/www/html/normal-worker.php:ro" \
    localhost/php-backport-build:7.4 bash -lc '
        set -e
        install -m 644 /src/libs/libphp7.so /usr/lib/apache2/modules/libphp7.so
        printf "%s\n" "StartServers 1" "MinSpareServers 1" \
            "MaxSpareServers 1" "ServerLimit 1" "MaxRequestWorkers 1" \
            "php_flag display_errors On" \
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
normal=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-iconv-limit.php)
[[ $normal == ICONV_OK ]] || {
    printf 'iconv normal path failed: %s\n' "$normal" >&2
    exit 1
}
podman exec "$container_id" bash -lc '
    head -c 4194304 /dev/zero | tr "\000" x > /tmp/iconv-large.txt
'
podman exec "$container_id" curl -sS --max-time 30 -o /tmp/iconv-limit.out \
    'http://127.0.0.1/normal-iconv-limit.php?limit=1' >/dev/null
limited=$(podman exec "$container_id" tail -c 500 /tmp/iconv-limit.out)
post=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $limited == *READY* && $limited == *'Allowed memory size of 8388608 bytes exhausted'* && $limited != *RETURNED* ]] || {
    printf 'iconv soft OOM was not observed: %s\n' "$limited" >&2
    exit 1
}
[[ ${pre%%$'\n'*} == ${post%%$'\n'*} ]] || {
    printf 'Apache worker changed after iconv OOM\n' >&2
    exit 1
}
printf '%s\n' ICONV_NORMAL_AND_OOM_REPORTED WORKER_REUSED
