#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 7.3.33 source tree required}
[[ -f "$source_tree/libs/libphp7.so" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/normal-tokenizer-limit.php:/var/www/html/normal-tokenizer-limit.php:ro" \
    -v "$script_dir/../normal-worker.php:/var/www/html/normal-worker.php:ro" \
    localhost/php-backport-build:7.4 bash -lc '
        set -e
        install -m 644 /src/libs/libphp7.so /usr/lib/apache2/modules/libphp7.so
        printf "%s\n" "StartServers 1" "MinSpareServers 1" \
            "MaxSpareServers 1" "ServerLimit 1" "MaxRequestWorkers 1" \
            "php_value display_errors On" \
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
worker=${pre%%$'\n'*}

normal=$(podman exec "$container_id" curl -fsS --max-time 15 \
    'http://127.0.0.1/normal-tokenizer-limit.php?n=1800000')
[[ $normal == *READY* && $normal == *RETURNED* ]] || {
    printf 'normal tokenization failed: %s\n' "$normal" >&2
    exit 1
}

for mode in normal parse; do
    query='n=2200000'
    [[ $mode == parse ]] && query='n=2200000&parse=1'
    podman exec "$container_id" curl -sS --max-time 15 \
        -o /tmp/tokenizer-oom-body \
        "http://127.0.0.1/normal-tokenizer-limit.php?$query" >/dev/null
    body=$(podman exec "$container_id" cat /tmp/tokenizer-oom-body)
    post=$(podman exec "$container_id" curl -fsS --max-time 2 \
        http://127.0.0.1/normal-worker.php)
    [[ $body == *READY* && $body != *RETURNED* ]] || {
        printf '%s did not stop at OOM: %s\n' "$mode" "$body" >&2
        exit 1
    }
    [[ $body == *'Allowed memory size of 8388608 bytes exhausted'* && \
        $body == *'tried to allocate 2200036 bytes'* ]] || {
        printf '%s missed token-string allocation failure: %s\n' "$mode" "$body" >&2
        exit 1
    }
    [[ ${post%%$'\n'*} == "$worker" ]] || {
        printf 'Apache worker changed after %s OOM\n' "$mode" >&2
        exit 1
    }
    printf 'TOKEN_%s_OOM_REPORTED WORKER_REUSED\n' "$mode"
done
