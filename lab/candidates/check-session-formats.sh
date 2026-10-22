#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP source tree required}
case "$(basename "$source_tree")" in
    php-5.6.40) module=libphp5.so; image=localhost/php-backport-build:5.6 ;;
    php-7.3.33) module=libphp7.so; image=localhost/php-backport-build:7.4 ;;
    *) exit 2 ;;
esac
[[ -f "$source_tree/libs/$module" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)

for serializer in php php_binary php_serialize; do
    container_id=$(podman run --rm -d --platform linux/amd64 --network none \
        -v "$source_tree:/src:ro" \
        -v "$script_dir/session-fixture.php:/var/www/html/session-fixture.php:ro" \
        -v "$script_dir/normal-unserialize.php:/var/www/html/normal-unserialize.php:ro" \
        -v "$script_dir/../normal-multipart.php:/var/www/html/normal-multipart.php:ro" \
        -e SERIALIZER="$serializer" \
        -e PHP_MODULE_NAME="$module" \
        "$image" bash -lc '
            set -e
            install -m 644 "/src/libs/$PHP_MODULE_NAME" "/usr/lib/apache2/modules/$PHP_MODULE_NAME"
            printf "%s\n" "php_value session.serialize_handler $SERIALIZER" \
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
        printf hello > /tmp/note.txt
        curl -fsS --max-time 15 -b /tmp/cookie \
            -F PHP_SESSION_UPLOAD_PROGRESS=check -F title=ordinary \
            -F "attachment=@/tmp/note.txt;filename=note.txt" \
            http://127.0.0.1/normal-multipart.php
        curl -fsS --max-time 5 -b /tmp/cookie \
            "http://127.0.0.1/session-fixture.php?progress=1"
    ')
    [[ $result == $'SEEDED\nMULTIPART_OK\nPRESERVED\nPROGRESS_PRESENT' ]] || {
        printf '%s\n%s\n' "$serializer" "$result" >&2
        exit 1
    }
    printf '%s: %s\n' "$serializer" 'MULTIPART_OK / PRESERVED / PROGRESS_PRESENT'
    if [[ $module == libphp7.so ]]; then
        unserialize_result=$(podman exec "$container_id" curl -fsS --max-time 5 \
            http://127.0.0.1/normal-unserialize.php)
        [[ $unserialize_result == UNSERIALIZE_OK ]] || {
            printf 'unserialize normal path failed: %s\n' "$unserialize_result" >&2
            exit 1
        }
        printf 'UNSERIALIZE_NORMAL_REPORTED\n'
    fi
    podman stop --time 2 "$container_id" >/dev/null
    trap - EXIT
done
