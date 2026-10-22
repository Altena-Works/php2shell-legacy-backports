#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 7.3.33 source tree required}
[[ -f "$source_tree/libs/libphp7.so" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/normal-soap-server.php:/var/www/html/normal-soap-server.php:ro" \
    -v "$script_dir/normal-soap-client.php:/var/www/html/normal-soap-client.php:ro" \
    localhost/php-backport-build:7.4 bash -lc '
        set -e
        install -m 644 /src/libs/libphp7.so /usr/lib/apache2/modules/libphp7.so
        exec apache2-foreground
    ')
trap 'podman stop --time 2 "$container_id" >/dev/null 2>&1 || true' EXIT

response=
for _ in $(seq 1 30); do
    if response=$(podman exec "$container_id" curl -fsS --max-time 5 \
        http://127.0.0.1/normal-soap-client.php 2>/dev/null); then
        break
    fi
    sleep 1
done
[[ $response == SOAP_OK ]] || {
    printf 'soap normal check failed: %s\n' "$response" >&2
    exit 1
}
printf '%s\n' "$response"
