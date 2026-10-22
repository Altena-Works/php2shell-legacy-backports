#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?source tree required}
version=${2:?version required}
case "$version" in
    5.6.40) image=localhost/php-backport-build:5.6 ;;
    7.3.33) image=localhost/php-backport-build:7.4 ;;
    *) exit 2 ;;
esac
script_dir=$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)

"$script_dir/check-multipart-progress.sh" "$source_tree" "$version" PROGRESS_PRESENT

set -- "$source_tree"/libs/libphp*.so
[[ $# -eq 1 && -f $1 ]] || exit 2
module_name=$(basename "$1")
container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/health.php:/var/www/html/health.php:ro" \
    -v "$script_dir/normal-multipart.php:/var/www/html/normal-multipart.php:ro" \
    -v "$script_dir/candidates/session-fixture.php:/var/www/html/session-fixture.php:ro" \
    -e PHP_MODULE_NAME="$module_name" \
    "$image" bash -lc '
        set -e
        install -m 644 "/src/libs/$PHP_MODULE_NAME" "/usr/lib/apache2/modules/$PHP_MODULE_NAME"
        printf "%s\n" "php_value session.upload_progress.enabled On" \
            "php_value session.upload_progress.cleanup Off" \
            > /etc/apache2/conf-enabled/upload-progress-test.conf
        exec apache2-foreground
    ')
trap 'podman stop --time 2 "$container_id" >/dev/null 2>&1 || true' EXIT

for _ in $(seq 1 30); do
    if podman exec "$container_id" curl -fsS --max-time 2 \
        -c /tmp/php-cookies http://127.0.0.1/health.php >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

result=$(podman exec "$container_id" bash -lc '
    set -e
    curl -fsS --max-time 5 -b /tmp/php-cookies -X POST \
        http://127.0.0.1/session-fixture.php
    printf hello > /tmp/note.txt
    curl -fsS --max-time 10 -b /tmp/php-cookies \
        -F PHP_SESSION_UPLOAD_PROGRESS=check \
        -F title=ordinary \
        -F "attachment=@/tmp/note.txt;filename=note.txt" \
        http://127.0.0.1/normal-multipart.php
    curl -fsS --max-time 5 -b /tmp/php-cookies \
        http://127.0.0.1/session-fixture.php
')
printf '%s\n' "$result"
[[ $result == $'SEEDED\nMULTIPART_OK\nPRESERVED' ]]

if [[ $version == 7.3.33 ]]; then
    "$script_dir/candidates/check-session-formats.sh" "$source_tree"
    "$script_dir/candidates/check-json-oom.sh" "$source_tree"
    "$script_dir/candidates/check-repeat-oom.sh" "$source_tree"
    "$script_dir/candidates/check-upload-decode-oom.sh" "$source_tree"
fi
