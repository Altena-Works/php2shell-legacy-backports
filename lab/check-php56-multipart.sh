#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched or baseline PHP 5.6.40 source tree required}
expected_progress=${2:?PROGRESS_PRESENT or PROGRESS_ABSENT required}
[[ $expected_progress == PROGRESS_PRESENT || $expected_progress == PROGRESS_ABSENT ]]
[[ -f $source_tree/libs/libphp5.so ]]
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/health.php:/var/www/html/health.php:ro" \
    -v "$script_dir/normal-multipart.php:/var/www/html/normal-multipart.php:ro" \
    -v "$script_dir/normal-progress-state.php:/var/www/html/normal-progress-state.php:ro" \
    localhost/php-backport-build:5.6 bash -lc '
        set -e
        install -m 644 /src/libs/libphp5.so /usr/lib/apache2/modules/libphp5.so
        printf "%s\n" "php_value session.upload_progress.enabled On" \
            "php_value session.upload_progress.cleanup Off" \
            > /etc/apache2/conf-enabled/upload-progress-test.conf
        exec apache2-foreground
    ')
trap 'podman stop --time 2 "$container_id" >/dev/null 2>&1 || true' EXIT

for _ in $(seq 1 30); do
    if podman exec "$container_id" curl -fsS --max-time 2 \
        http://127.0.0.1/health.php >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

result=$(podman exec "$container_id" bash -lc '
    set -e
    printf hello > /tmp/note.txt
    curl -fsS --max-time 5 -c /tmp/php-cookies \
        http://127.0.0.1/health.php >/dev/null
    curl -fsS --max-time 10 -b /tmp/php-cookies \
        -F PHP_SESSION_UPLOAD_PROGRESS=check \
        -F title=ordinary \
        -F "attachment=@/tmp/note.txt;filename=note.txt" \
        http://127.0.0.1/normal-multipart.php
    curl -fsS --max-time 5 -b /tmp/php-cookies \
        http://127.0.0.1/normal-progress-state.php
')
printf '%s\n' "$result"
[[ $result == $'MULTIPART_OK\nSESSION_OK\n'"$expected_progress" ]]
