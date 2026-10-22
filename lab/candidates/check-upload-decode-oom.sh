#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 7.3.33 source tree required}
[[ -f "$source_tree/libs/libphp7.so" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/session-large-seed.php:/var/www/html/session-large-seed.php:ro" \
    -v "$script_dir/ordinary-upload.php:/var/www/html/ordinary-upload.php:ro" \
    -v "$script_dir/../normal-worker.php:/var/www/html/normal-worker.php:ro" \
    localhost/php-backport-build:7.4 bash -lc '
        set -e
        install -m 644 /src/libs/libphp7.so /usr/lib/apache2/modules/libphp7.so
        printf "%s\n" "StartServers 1" "MinSpareServers 1" \
            "MaxSpareServers 1" "ServerLimit 1" "MaxRequestWorkers 1" \
            "php_value memory_limit 8M" \
            "php_value session.upload_progress.enabled On" \
            "php_value session.upload_progress.cleanup Off" \
            "php_flag display_errors On" "php_flag log_errors On" \
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

seed=$(podman exec "$container_id" curl -fsS --max-time 10 \
    -c /tmp/php-cookies http://127.0.0.1/session-large-seed.php)
[[ $seed == SEEDED ]] || exit 1
session_before=$(podman exec "$container_id" bash -lc '
    for dir in /tmp /var/lib/php/sessions; do
        if [[ -d "$dir" ]]; then
            find "$dir" -maxdepth 1 -type f -name "sess_*" -exec sha256sum {} +
        fi
    done | sort
')
[[ -n $session_before ]] || { printf 'seeded session file missing\n' >&2; exit 1; }

podman exec "$container_id" bash -lc '
    printf ordinary > /tmp/note.txt
    curl -sS --max-time 20 -b /tmp/php-cookies -o /tmp/upload.out \
        -F PHP_SESSION_UPLOAD_PROGRESS=check \
        -F "attachment=@/tmp/note.txt;filename=note.txt" \
        http://127.0.0.1/ordinary-upload.php || true
'
post=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
upload_output=$(podman exec "$container_id" cat /tmp/upload.out)
logs=$(podman logs "$container_id" 2>&1)
session_after=$(podman exec "$container_id" bash -lc '
    for dir in /tmp /var/lib/php/sessions; do
        if [[ -d "$dir" ]]; then
            find "$dir" -maxdepth 1 -type f -name "sess_*" -exec sha256sum {} +
        fi
    done | sort
')
[[ $logs == *'Allowed memory size of 8388608 bytes exhausted'* ]] || {
    printf 'upload session OOM was not observed\n' >&2; exit 1;
}
[[ ${pre%%$'\n'*} == ${post%%$'\n'*} ]] || {
    printf 'Apache worker changed after upload session OOM\n' >&2; exit 1;
}
[[ $upload_output != *UPLOAD_OK* ]] || {
    printf 'upload script ran despite request-startup OOM\n' >&2; exit 1;
}
[[ $session_before == "$session_after" ]] || {
    printf 'stored session changed after upload session OOM\n' >&2; exit 1;
}
printf '%s\n' UPLOAD_SESSION_OOM_REPORTED SCRIPT_NOT_RUN WORKER_REUSED SESSION_PRESERVED
