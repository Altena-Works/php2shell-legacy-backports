#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP source tree required}
version=${2:?PHP version required}
case $version in
    5.*) image=localhost/php-backport-build:5.6 ;;
    7.*) image=localhost/php-backport-build:7.4 ;;
    *) echo "unsupported version: $version" >&2; exit 2 ;;
esac

set -- "$source_tree"/libs/libphp*.so
[[ $# -eq 1 && -f $1 ]] || { echo 'one built Apache module is required' >&2; exit 2; }
module_name=$(basename "$1")
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/normal-limit.php:/var/www/html/normal-limit.php:ro" \
    -v "$script_dir/normal-worker.php:/var/www/html/normal-worker.php:ro" \
    -e PHP_MODULE_NAME="$module_name" "$image" bash -lc '
        set -e
        install -m 644 "/src/libs/$PHP_MODULE_NAME" "/usr/lib/apache2/modules/$PHP_MODULE_NAME"
        cat > /etc/apache2/conf-enabled/one-worker.conf <<EOF
StartServers 1
MinSpareServers 1
MaxSpareServers 1
ServerLimit 1
MaxRequestWorkers 1
EOF
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
[[ $pre == *$'\n'"$version"$'\n'apache2handler ]] || {
    echo "unexpected version or SAPI: $pre" >&2
    exit 1
}

curl_status=0
headers=$(podman exec "$container_id" curl -sS --max-time 15 \
    -D - -o /tmp/normal-limit-body http://127.0.0.1/normal-limit.php) || curl_status=$?
body=$(podman exec "$container_id" cat /tmp/normal-limit-body 2>/dev/null || true)
post=
for _ in $(seq 1 30); do
    if post=$(podman exec "$container_id" curl -fsS --max-time 2 \
        http://127.0.0.1/normal-worker.php 2>/dev/null); then
        break
    fi
    sleep 1
done
[[ $post == *$'\n'"$version"$'\n'apache2handler ]] || {
    echo "Apache did not serve the next request: $post" >&2
    exit 1
}

[[ $curl_status -eq 0 ]] || {
    echo "memory_limit request lost its HTTP connection (curl $curl_status); worker before=${pre%%$'\n'*}, after=${post%%$'\n'*}" >&2
    exit 1
}

[[ ${pre%%$'\n'*} == ${post%%$'\n'*} ]] || {
    echo 'Apache worker changed after a normal memory_limit error' >&2
    exit 1
}
[[ $headers == *'X-Test-Worker: '"${pre%%$'\n'*}"* ]] || {
    echo 'normal OOM request was not handled by the checked worker' >&2
    exit 1
}
[[ $body == *'Allowed memory size'* && $body != *'LIMIT_NOT_REACHED'* ]] || {
    echo "unexpected memory_limit response: $body" >&2
    exit 1
}
printf '%s\n' "NORMAL_OOM_REPORTED" "WORKER_REUSED" "$version apache2handler"
