#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched or baseline PHP source tree required}
version=${2:?PHP version required}
expected_progress=${3:?PROGRESS_PRESENT or PROGRESS_ABSENT required}
verify_final=${4:-}
[[ $expected_progress == PROGRESS_PRESENT || $expected_progress == PROGRESS_ABSENT ]]
[[ -z $verify_final || $verify_final == VERIFY_FINAL ]]

case $version in
    5.*) image=localhost/php-backport-build:5.6 ;;
    7.*) image=localhost/php-backport-build:7.4 ;;
    8.*) image=localhost/php-backport-build:8.1 ;;
    *) echo "unsupported PHP version: $version" >&2; exit 2 ;;
esac

set -- "$source_tree"/libs/libphp*.so
[[ $# -eq 1 && -f $1 ]] || { echo "one built Apache module is required" >&2; exit 2; }
module_name=$(basename "$1")
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/health.php:/var/www/html/health.php:ro" \
    -v "$script_dir/normal-multipart.php:/var/www/html/normal-multipart.php:ro" \
    -v "$script_dir/normal-progress-state.php:/var/www/html/normal-progress-state.php:ro" \
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

health=
for _ in $(seq 1 30); do
    if health=$(podman exec "$container_id" curl -fsS --max-time 2 \
        -c /tmp/php-cookies http://127.0.0.1/health.php 2>/dev/null); then
        break
    fi
    sleep 1
done
[[ $health == "$version"$'\n'apache2handler$'\n'SESSION_OK ]] || {
    echo "unexpected PHP version, SAPI, or session state: $health" >&2
    exit 1
}

result=$(podman exec "$container_id" bash -lc '
    set -e
    printf hello > /tmp/note.txt
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

if [[ $verify_final == VERIFY_FINAL ]]; then
    final=$(podman exec "$container_id" curl -fsS --max-time 5 \
        -b /tmp/php-cookies 'http://127.0.0.1/normal-progress-state.php?final=1')
    printf '%s\n' "$final"
    [[ $final == $'SESSION_OK\nPROGRESS_PRESENT\nPROGRESS_COMPLETE' ]]
fi
