#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 5.6.40 source tree required}
[[ -f "$source_tree/libs/libphp5.so" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/reference-session.php:/var/www/html/reference-session.php:ro" \
    -v "$script_dir/../normal-multipart.php:/var/www/html/normal-multipart.php:ro" \
    localhost/php-backport-build:5.6 bash -lc '
        set -e
        install -m 644 /src/libs/libphp5.so /usr/lib/apache2/modules/libphp5.so
        printf "%s\n" "php_value session.upload_progress.enabled On" \
            "php_value session.upload_progress.cleanup Off" \
            > /etc/apache2/conf-enabled/progress.conf
        exec apache2-foreground
    ')
trap 'podman stop --time 2 "$container_id" >/dev/null 2>&1 || true' EXIT

result=$(podman exec "$container_id" bash -lc '
    set -e
    for attempt in $(seq 1 30); do
        if curl -fsS --max-time 2 -c /tmp/cookies \
            "http://127.0.0.1/reference-session.php?seed=1" 2>/dev/null; then
            break
        fi
        sleep 1
    done
    printf hello > /tmp/note.txt
    curl -fsS --max-time 10 -b /tmp/cookies \
        -F PHP_SESSION_UPLOAD_PROGRESS=check -F title=ordinary \
        -F "attachment=@/tmp/note.txt;filename=note.txt" \
        http://127.0.0.1/normal-multipart.php
    curl -fsS --max-time 5 -b /tmp/cookies \
        http://127.0.0.1/reference-session.php
')
printf '%s\n' "$result"
[[ $result == $'SEEDED\nMULTIPART_OK\nALIAS_LINKED\nPROGRESS_OK' ]]
