#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 5.6.40 source tree required}
[[ -f "$source_tree/libs/libphp5.so" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/session-fixture.php:/var/www/html/session-fixture.php:ro" \
    -v "$script_dir/normal-no-file.php:/var/www/html/normal-no-file.php:ro" \
    localhost/php-backport-build:5.6 bash -lc '
        set -e
        install -m 644 /src/libs/libphp5.so /usr/lib/apache2/modules/libphp5.so
        printf "%s\n" "StartServers 1" "MinSpareServers 1" \
            "MaxSpareServers 1" "ServerLimit 1" "MaxRequestWorkers 1" \
            "php_value session.upload_progress.enabled On" \
            "php_value session.upload_progress.cleanup Off" \
            > /etc/apache2/conf-enabled/session-test.conf
        exec apache2-foreground
    ')
trap 'podman stop --time 2 "$container_id" >/dev/null 2>&1 || true' EXIT

for _ in $(seq 1 30); do
    if podman exec "$container_id" curl -fsS --max-time 2 \
        http://127.0.0.1/session-fixture.php >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

result=$(podman exec "$container_id" bash -lc '
    set -e
    curl -fsS --max-time 5 -c /tmp/cookie -X POST \
        http://127.0.0.1/session-fixture.php
    curl -fsS --max-time 15 -b /tmp/cookie \
        -F PHP_SESSION_UPLOAD_PROGRESS=check -F title=ordinary \
        http://127.0.0.1/normal-no-file.php
    curl -fsS --max-time 5 -b /tmp/cookie \
        http://127.0.0.1/session-fixture.php
')
[[ $result == $'SEEDED\nNO_FILE_OK\nPRESERVED' ]] || {
    printf '%s\n' "$result" >&2
    exit 1
}
printf '%s\n' 'NO_FILE_OK / SESSION_PRESERVED'
