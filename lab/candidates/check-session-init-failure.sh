#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 5.6.40 source tree required}
[[ -f "$source_tree/libs/libphp5.so" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/ordinary-upload.php:/var/www/html/ordinary-upload.php:ro" \
    -v "$script_dir/../normal-worker.php:/var/www/html/normal-worker.php:ro" \
    localhost/php-backport-build:5.6 bash -lc '
        set -e
        install -m 644 /src/libs/libphp5.so /usr/lib/apache2/modules/libphp5.so
        printf "%s\n" "StartServers 1" "MinSpareServers 1" \
            "MaxSpareServers 1" "ServerLimit 1" "MaxRequestWorkers 1" \
            "php_value session.upload_progress.enabled On" \
            "php_value session.save_path /no-such-dir" "php_flag log_errors On" \
            > /etc/apache2/conf-enabled/one-worker.conf
        test ! -e /no-such-dir
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
[[ $pre == *$'\n'5.6.40$'\n'apache2handler ]] || exit 1

result=$(podman exec "$container_id" bash -lc '
    printf ordinary > /tmp/note.txt
    curl -fsS --max-time 15 -F PHPSESSID=ordinary \
        -F PHP_SESSION_UPLOAD_PROGRESS=check \
        -F "attachment=@/tmp/note.txt;filename=note.txt" \
        http://127.0.0.1/ordinary-upload.php
')
post=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
logs=$(podman logs "$container_id" 2>&1)
[[ $result == UPLOAD_OK ]] || exit 1
[[ $logs == *'Failed to read session data: files (path: /no-such-dir)'* ]] || exit 1
[[ ${pre%%$'\n'*} == ${post%%$'\n'*} ]] || exit 1
printf '%s\n' SESSION_INIT_FAILURE_REPORTED UPLOAD_OK WORKER_REUSED
