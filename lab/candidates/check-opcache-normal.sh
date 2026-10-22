#!/usr/bin/env bash
set -euo pipefail
source_tree=${1:?patched source tree required}
script_dir=$(cd "$(dirname "$0")/.." && pwd)
[[ -f $source_tree/modules/opcache.so ]] || { echo 'missing opcache.so' >&2; exit 2; }
set -- "$source_tree"/libs/libphp*.so
[[ $# -eq 1 && -f $1 ]] || exit 2
module_name=$(basename "$1")
container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/candidates/opcache-status.php:/var/www/html/opcache-status.php:ro" \
    -v "$script_dir/candidates/session-fixture.php:/var/www/html/session-fixture.php:ro" \
    -v "$script_dir/candidates/normal-repeat-limit.php:/var/www/html/normal-repeat-limit.php:ro" \
    -v "$script_dir/normal-multipart.php:/var/www/html/normal-multipart.php:ro" \
    -v "$script_dir/normal-worker.php:/var/www/html/normal-worker.php:ro" \
    -e PHP_MODULE_NAME="$module_name" -e PHP_INI_SCAN_DIR=/tmp/php-conf \
    localhost/php-backport-build:7.4 bash -lc '
        set -e
        mkdir -p /tmp/php-conf
        printf "%s\n" "zend_extension=/src/modules/opcache.so" "opcache.enable=1" \
            "opcache.file_update_protection=0" > /tmp/php-conf/opcache.ini
        install -m 644 "/src/libs/$PHP_MODULE_NAME" "/usr/lib/apache2/modules/$PHP_MODULE_NAME"
        printf "%s\n" "StartServers 1" "MinSpareServers 1" \
            "MaxSpareServers 1" "ServerLimit 1" "MaxRequestWorkers 1" \
            "php_value display_errors On" \
            > /etc/apache2/conf-enabled/one-worker.conf
        exec apache2-foreground
    ')
trap 'podman stop --time 2 "$container_id" >/dev/null 2>&1 || true' EXIT
for _ in $(seq 1 30); do
    status=$(podman exec "$container_id" curl -fsS --max-time 2 \
        http://127.0.0.1/opcache-status.php 2>/dev/null) && break || true
    sleep 1
done
[[ ${status:-} == OPCACHE_OK ]]
result=$(podman exec "$container_id" bash -lc '
    set -e
    curl -fsS --max-time 5 -c /tmp/php-cookies -X POST http://127.0.0.1/session-fixture.php
    printf hello >/tmp/note.txt
    curl -fsS --max-time 10 -b /tmp/php-cookies \
        -F PHP_SESSION_UPLOAD_PROGRESS=check -F title=ordinary \
        -F "attachment=@/tmp/note.txt;filename=note.txt" \
        http://127.0.0.1/normal-multipart.php
    curl -fsS --max-time 5 -b /tmp/php-cookies http://127.0.0.1/session-fixture.php
')
[[ $result == $'SEEDED\nMULTIPART_OK\nPRESERVED' ]]
before=$(podman exec "$container_id" curl -fsS --max-time 5 http://127.0.0.1/normal-worker.php)
podman exec "$container_id" curl -sS --max-time 30 \
    -o /tmp/opcache-oom.out 'http://127.0.0.1/normal-repeat-limit.php?limit=1' >/dev/null
oom_result=$(podman exec "$container_id" tail -c 500 /tmp/opcache-oom.out)
after=$(podman exec "$container_id" curl -fsS --max-time 5 http://127.0.0.1/normal-worker.php)
[[ $oom_result == *'Allowed memory size of 8388608 bytes exhausted'* && $oom_result != *RETURNED* ]]
[[ $before == "$after" ]]
printf 'OPCACHE_OK\n%s\nOPCACHE_WORKER_REUSED\n' "$result"
