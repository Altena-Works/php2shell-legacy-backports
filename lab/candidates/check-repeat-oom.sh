#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched PHP 7.3.33 source tree required}
[[ -f "$source_tree/libs/libphp7.so" ]] || exit 2
script_dir=$(cd "$(dirname "$0")" && pwd)
container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:/src:ro" \
    -v "$script_dir/normal-repeat-limit.php:/var/www/html/normal-repeat-limit.php:ro" \
    -v "$script_dir/normal-pad-limit.php:/var/www/html/normal-pad-limit.php:ro" \
    -v "$script_dir/normal-implode-limit.php:/var/www/html/normal-implode-limit.php:ro" \
    -v "$script_dir/normal-chunk-limit.php:/var/www/html/normal-chunk-limit.php:ro" \
    -v "$script_dir/normal-wordwrap-limit.php:/var/www/html/normal-wordwrap-limit.php:ro" \
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
cleanup() {
    result=$?
    podman stop --time 2 "$container_id" >/dev/null 2>&1 || true
    exit "$result"
}
trap cleanup EXIT

pre=
for _ in $(seq 1 30); do
    if pre=$(podman exec "$container_id" curl -fsS --max-time 2 \
        http://127.0.0.1/normal-worker.php 2>/dev/null); then
        break
    fi
    sleep 1
done
[[ $pre == *$'\n'7.3.33$'\n'apache2handler ]] || exit 1

normal=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-repeat-limit.php)
[[ $normal == REPEAT_OK ]] || { printf 'normal str_repeat failed: %s\n' "$normal" >&2; exit 1; }
normal_pad=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-pad-limit.php)
[[ $normal_pad == PAD_OK ]] || { printf 'normal str_pad failed: %s\n' "$normal_pad" >&2; exit 1; }
normal_implode=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-implode-limit.php)
[[ $normal_implode == IMPLODE_OK ]] || { printf 'normal implode failed: %s\n' "$normal_implode" >&2; exit 1; }
normal_chunk=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-chunk-limit.php)
[[ $normal_chunk == CHUNK_OK ]] || { printf 'normal chunk_split failed: %s\n' "$normal_chunk" >&2; exit 1; }
normal_wordwrap=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-wordwrap-limit.php)
[[ $normal_wordwrap == WORDWRAP_OK ]] || { printf 'normal wordwrap failed: %s\n' "$normal_wordwrap" >&2; exit 1; }

podman exec "$container_id" curl -sS --max-time 20 \
    -o /tmp/repeat-limit.out 'http://127.0.0.1/normal-repeat-limit.php?limit=1' >/dev/null
limited=$(podman exec "$container_id" tail -c 500 /tmp/repeat-limit.out)
post=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $limited == *'Allowed memory size of 8388608 bytes exhausted'* ]] || {
    printf 'expected soft OOM missing: %s\n' "$limited" >&2; exit 1;
}
[[ $limited != *RETURNED* ]] || {
    printf 'request continued after soft OOM: %s\n' "$limited" >&2; exit 1;
}
[[ ${pre%%$'\n'*} == ${post%%$'\n'*} ]] || {
    printf 'Apache worker changed after soft OOM\n' >&2; exit 1;
}

podman exec "$container_id" curl -sS --max-time 20 \
    -o /tmp/repeat-aggregate.out 'http://127.0.0.1/normal-repeat-limit.php?limit=1&aggregate=1' >/dev/null
aggregate=$(podman exec "$container_id" tail -c 500 /tmp/repeat-aggregate.out)
after_aggregate=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $aggregate == *RETAINED* ]] || {
    printf 'first retained allocation did not complete: %s\n' "$aggregate" >&2; exit 1;
}
[[ $aggregate == *'Allowed memory size of 8388608 bytes exhausted'* ]] || {
    printf 'aggregate soft OOM missing: %s\n' "$aggregate" >&2; exit 1;
}
[[ $aggregate != *RETURNED* ]] || {
    printf 'request continued after aggregate soft OOM: %s\n' "$aggregate" >&2; exit 1;
}
[[ ${pre%%$'\n'*} == ${after_aggregate%%$'\n'*} ]] || {
    printf 'Apache worker changed after aggregate soft OOM\n' >&2; exit 1;
}

podman exec "$container_id" curl -sS --max-time 20 \
    -o /tmp/pad-limit.out 'http://127.0.0.1/normal-pad-limit.php?limit=1' >/dev/null
padded=$(podman exec "$container_id" tail -c 500 /tmp/pad-limit.out)
after_pad=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $padded == *'Allowed memory size of 8388608 bytes exhausted'* && $padded != *RETURNED* ]] || {
    printf 'expected pad soft OOM and request abort missing: %s\n' "$padded" >&2; exit 1;
}
[[ ${pre%%$'\n'*} == ${after_pad%%$'\n'*} ]] || {
    printf 'Apache worker changed after pad soft OOM\n' >&2; exit 1;
}

podman exec "$container_id" curl -sS --max-time 20 \
    -o /tmp/implode-limit.out 'http://127.0.0.1/normal-implode-limit.php?limit=1' >/dev/null
imploded=$(podman exec "$container_id" tail -c 500 /tmp/implode-limit.out)
after_implode=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $imploded == *'Allowed memory size of 8388608 bytes exhausted'* && $imploded != *RETURNED* ]] || {
    printf 'expected implode soft OOM and request abort missing: %s\n' "$imploded" >&2; exit 1;
}
[[ ${pre%%$'\n'*} == ${after_implode%%$'\n'*} ]] || {
    printf 'Apache worker changed after implode soft OOM\n' >&2; exit 1;
}

podman exec "$container_id" curl -sS --max-time 20 \
    -o /tmp/chunk-limit.out 'http://127.0.0.1/normal-chunk-limit.php?limit=1' >/dev/null
chunked=$(podman exec "$container_id" tail -c 500 /tmp/chunk-limit.out)
after_chunk=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $chunked == *'Allowed memory size of 8388608 bytes exhausted'* && $chunked != *RETURNED* ]] || {
    printf 'expected chunk_split soft OOM and request abort missing: %s\n' "$chunked" >&2; exit 1;
}
[[ ${pre%%$'\n'*} == ${after_chunk%%$'\n'*} ]] || {
    printf 'Apache worker changed after chunk_split soft OOM\n' >&2; exit 1;
}
podman exec "$container_id" curl -sS --max-time 20 \
    -o /tmp/wordwrap-limit.out 'http://127.0.0.1/normal-wordwrap-limit.php?limit=1' >/dev/null
wrapped=$(podman exec "$container_id" tail -c 500 /tmp/wordwrap-limit.out)
after_wordwrap=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $wrapped == *'Allowed memory size of 8388608 bytes exhausted'* && $wrapped != *RETURNED* ]] || {
    printf 'expected wordwrap soft OOM and request abort missing: %s\n' "$wrapped" >&2; exit 1;
}
[[ ${pre%%$'\n'*} == ${after_wordwrap%%$'\n'*} ]] || {
    printf 'Apache worker changed after wordwrap soft OOM\n' >&2; exit 1;
}
printf '%s\n' REPEAT_NORMAL_OK REPEAT_OOM_REPORTED AGGREGATE_OOM_REPORTED PAD_NORMAL_OK PAD_OOM_REPORTED IMPLODE_NORMAL_OK IMPLODE_OOM_REPORTED CHUNK_NORMAL_OK CHUNK_OOM_REPORTED WORDWRAP_NORMAL_OK WORDWRAP_OOM_REPORTED WORKER_REUSED
