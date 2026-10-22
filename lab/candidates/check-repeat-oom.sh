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
    -v "$script_dir/normal-nl2br-limit.php:/var/www/html/normal-nl2br-limit.php:ro" \
    -v "$script_dir/normal-unpack-limit.php:/var/www/html/normal-unpack-limit.php:ro" \
    -v "$script_dir/normal-wordwrap-limit.php:/var/www/html/normal-wordwrap-limit.php:ro" \
    -v "$script_dir/normal-explode-limit.php:/var/www/html/normal-explode-limit.php:ro" \
    -v "$script_dir/normal-array-fill-limit.php:/var/www/html/normal-array-fill-limit.php:ro" \
    -v "$script_dir/normal-range-limit.php:/var/www/html/normal-range-limit.php:ro" \
    -v "$script_dir/normal-array-chunk-limit.php:/var/www/html/normal-array-chunk-limit.php:ro" \
    -v "$script_dir/normal-array-map-limit.php:/var/www/html/normal-array-map-limit.php:ro" \
    -v "$script_dir/normal-array-pad-array-limit.php:/var/www/html/normal-array-pad-array-limit.php:ro" \
    -v "$script_dir/normal-memory-stream-limit.php:/var/www/html/normal-memory-stream-limit.php:ro" \
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
normal_nl2br=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-nl2br-limit.php)
[[ $normal_nl2br == NL2BR_OK ]] || { printf 'normal nl2br failed: %s\n' "$normal_nl2br" >&2; exit 1; }
normal_unpack=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-unpack-limit.php)
[[ $normal_unpack == UNPACK_OK ]] || { printf 'normal unpack failed: %s\n' "$normal_unpack" >&2; exit 1; }
normal_wordwrap=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-wordwrap-limit.php)
[[ $normal_wordwrap == WORDWRAP_OK ]] || { printf 'normal wordwrap failed: %s\n' "$normal_wordwrap" >&2; exit 1; }
normal_explode=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-explode-limit.php)
[[ $normal_explode == EXPLODE_OK ]] || { printf 'normal explode failed: %s\n' "$normal_explode" >&2; exit 1; }
normal_fill=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-array-fill-limit.php)
[[ $normal_fill == ARRAY_FILL_OK ]] || { printf 'normal array_fill failed: %s\n' "$normal_fill" >&2; exit 1; }
normal_range=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-range-limit.php)
[[ $normal_range == RANGE_OK ]] || { printf 'normal range failed: %s\n' "$normal_range" >&2; exit 1; }
normal_array_chunk=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-array-chunk-limit.php)
[[ $normal_array_chunk == ARRAY_CHUNK_OK ]] || { printf 'normal array_chunk failed: %s\n' "$normal_array_chunk" >&2; exit 1; }
normal_array_map=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-array-map-limit.php)
[[ $normal_array_map == ARRAY_MAP_OK ]] || { printf 'normal array_map failed: %s\n' "$normal_array_map" >&2; exit 1; }
normal_array_pad=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-array-pad-array-limit.php)
[[ $normal_array_pad == ARRAY_PAD_ARRAY_OK ]] || { printf 'normal array_pad failed: %s\n' "$normal_array_pad" >&2; exit 1; }
normal_memory_stream=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-memory-stream-limit.php)
[[ $normal_memory_stream == MEMORY_STREAM_OK ]] || { printf 'normal memory stream failed: %s\n' "$normal_memory_stream" >&2; exit 1; }

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
    -o /tmp/nl2br-limit.out 'http://127.0.0.1/normal-nl2br-limit.php?limit=1' >/dev/null
nl2br_result=$(podman exec "$container_id" tail -c 500 /tmp/nl2br-limit.out)
after_nl2br=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $nl2br_result == *'Allowed memory size of 8388608 bytes exhausted'* && $nl2br_result != *RETURNED* ]] || {
    printf 'expected nl2br soft OOM and request abort missing: %s\n' "$nl2br_result" >&2; exit 1;
}
[[ ${pre%%$'\n'*} == ${after_nl2br%%$'\n'*} ]] || {
    printf 'Apache worker changed after nl2br soft OOM\n' >&2; exit 1;
}
printf 'NL2BR_NORMAL_AND_OOM_REPORTED\n'
podman exec "$container_id" curl -sS --max-time 20 \
    -o /tmp/unpack-limit.out 'http://127.0.0.1/normal-unpack-limit.php?limit=1' >/dev/null
unpacked=$(podman exec "$container_id" tail -c 500 /tmp/unpack-limit.out)
after_unpack=$(podman exec "$container_id" curl -fsS --max-time 5 \
    http://127.0.0.1/normal-worker.php)
[[ $unpacked == *READY* && $unpacked == *'Allowed memory size of 8388608 bytes exhausted'* && $unpacked != *RETURNED* ]] || {
    printf 'expected unpack soft OOM and request abort missing: %s\n' "$unpacked" >&2; exit 1;
}
[[ ${pre%%$'\n'*} == ${after_unpack%%$'\n'*} ]] || {
    printf 'Apache worker changed after unpack soft OOM\n' >&2; exit 1;
}
printf 'UNPACK_NORMAL_AND_OOM_REPORTED\n'
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
for explode_case in positive negative terminal; do
    explode_url='http://127.0.0.1/normal-explode-limit.php?limit=1'
    if [[ $explode_case == negative ]]; then
        explode_url+='&negative=1'
    elif [[ $explode_case == terminal ]]; then
        explode_url+='&terminal=1'
    fi
    podman exec "$container_id" curl -sS --max-time 20 \
        -o /tmp/explode-limit.out "$explode_url" >/dev/null
    exploded=$(podman exec "$container_id" tail -c 500 /tmp/explode-limit.out)
    after_explode=$(podman exec "$container_id" curl -fsS --max-time 5 \
        http://127.0.0.1/normal-worker.php)
    [[ $exploded == *READY* && $exploded == *'Allowed memory size of 8388608 bytes exhausted'* && $exploded != *RETURNED* ]] || {
        printf 'expected %s explode soft OOM and request abort missing: %s\n' "$explode_case" "$exploded" >&2; exit 1;
    }
    [[ ${pre%%$'\n'*} == ${after_explode%%$'\n'*} ]] || {
        printf 'Apache worker changed after %s explode soft OOM\n' "$explode_case" >&2; exit 1;
    }
done
for fill_case in packed mixed; do
    fill_url='http://127.0.0.1/normal-array-fill-limit.php?limit=1'
    if [[ $fill_case == mixed ]]; then
        fill_url+='&mixed=1'
    fi
    podman exec "$container_id" curl -sS --max-time 20 \
        -o /tmp/array-fill-limit.out "$fill_url" >/dev/null
    filled=$(podman exec "$container_id" tail -c 500 /tmp/array-fill-limit.out)
    after_fill=$(podman exec "$container_id" curl -fsS --max-time 5 \
        http://127.0.0.1/normal-worker.php)
    [[ $filled == *READY* && $filled == *'Allowed memory size of 8388608 bytes exhausted'* && $filled != *RETURNED* ]] || {
        printf 'expected %s array_fill soft OOM and request abort missing: %s\n' "$fill_case" "$filled" >&2; exit 1;
    }
    [[ ${pre%%$'\n'*} == ${after_fill%%$'\n'*} ]] || {
        printf 'Apache worker changed after %s array_fill soft OOM\n' "$fill_case" >&2; exit 1;
    }
done
for range_case in long double; do
    range_url='http://127.0.0.1/normal-range-limit.php?limit=1'
    if [[ $range_case == double ]]; then
        range_url+='&double=1'
    fi
    podman exec "$container_id" curl -sS --max-time 20 \
        -o /tmp/range-limit.out "$range_url" >/dev/null
    ranged=$(podman exec "$container_id" tail -c 500 /tmp/range-limit.out)
    after_range=$(podman exec "$container_id" curl -fsS --max-time 5 \
        http://127.0.0.1/normal-worker.php)
    [[ $ranged == *READY* && $ranged == *'Allowed memory size of 8388608 bytes exhausted'* && $ranged != *RETURNED* ]] || {
        printf 'expected %s range soft OOM and request abort missing: %s\n' "$range_case" "$ranged" >&2; exit 1;
    }
    [[ ${pre%%$'\n'*} == ${after_range%%$'\n'*} ]] || {
        printf 'Apache worker changed after %s range soft OOM\n' "$range_case" >&2; exit 1;
    }
done
for chunk_case in outer inner; do
    chunk_url='http://127.0.0.1/normal-array-chunk-limit.php?limit=1'
    if [[ $chunk_case == inner ]]; then
        chunk_url+='&inner=1'
    fi
    podman exec "$container_id" curl -sS --max-time 20 \
        -o /tmp/array-chunk-limit.out "$chunk_url" >/dev/null
    chunk_result=$(podman exec "$container_id" tail -c 500 /tmp/array-chunk-limit.out)
    after_array_chunk=$(podman exec "$container_id" curl -fsS --max-time 5 \
        http://127.0.0.1/normal-worker.php)
    [[ $chunk_result == *READY* && $chunk_result == *'Allowed memory size of 8388608 bytes exhausted'* && $chunk_result != *RETURNED* ]] || {
        printf 'expected %s array_chunk soft OOM and request abort missing: %s\n' "$chunk_case" "$chunk_result" >&2; exit 1;
    }
    [[ ${pre%%$'\n'*} == ${after_array_chunk%%$'\n'*} ]] || {
        printf 'Apache worker changed after %s array_chunk soft OOM\n' "$chunk_case" >&2; exit 1;
    }
done
for map_case in outer inner; do
    map_url='http://127.0.0.1/normal-array-map-limit.php?limit=1'
    if [[ $map_case == inner ]]; then
        map_url+='&inner=1'
    fi
    podman exec "$container_id" curl -sS --max-time 20 \
        -o /tmp/array-map-limit.out "$map_url" >/dev/null
    map_result=$(podman exec "$container_id" tail -c 500 /tmp/array-map-limit.out)
    after_array_map=$(podman exec "$container_id" curl -fsS --max-time 5 \
        http://127.0.0.1/normal-worker.php)
    [[ $map_result == *READY* && $map_result == *'Allowed memory size of 8388608 bytes exhausted'* && $map_result != *RETURNED* ]] || {
        printf 'expected %s array_map soft OOM and request abort missing: %s\n' "$map_case" "$map_result" >&2; exit 1;
    }
    [[ ${pre%%$'\n'*} == ${after_array_map%%$'\n'*} ]] || {
        printf 'Apache worker changed after %s array_map soft OOM\n' "$map_case" >&2; exit 1;
    }
done
for pad_case in packed_positive packed_negative mixed_positive mixed_negative; do
    pad_url='http://127.0.0.1/normal-array-pad-array-limit.php?limit=1'
    if [[ $pad_case == mixed_* ]]; then
        pad_url+='&mixed=1'
    fi
    if [[ $pad_case == *_negative ]]; then
        pad_url+='&negative=1'
    fi
    podman exec "$container_id" curl -sS --max-time 20 \
        -o /tmp/array-pad-array-limit.out "$pad_url" >/dev/null
    pad_result=$(podman exec "$container_id" tail -c 500 /tmp/array-pad-array-limit.out)
    after_array_pad=$(podman exec "$container_id" curl -fsS --max-time 5 \
        http://127.0.0.1/normal-worker.php)
    [[ $pad_result == *READY* && $pad_result == *'Allowed memory size of 8388608 bytes exhausted'* && $pad_result != *RETURNED* ]] || {
        printf 'expected %s array_pad soft OOM and request abort missing: %s\n' "$pad_case" "$pad_result" >&2; exit 1;
    }
    [[ ${pre%%$'\n'*} == ${after_array_pad%%$'\n'*} ]] || {
        printf 'Apache worker changed after %s array_pad soft OOM\n' "$pad_case" >&2; exit 1;
    }
done
for memory_case in write truncate; do
    memory_url='http://127.0.0.1/normal-memory-stream-limit.php?limit=1'
    if [[ $memory_case == truncate ]]; then
        memory_url+='&truncate=1'
    fi
    podman exec "$container_id" curl -sS --max-time 20 \
        -o /tmp/memory-stream-limit.out "$memory_url" >/dev/null
    memory_result=$(podman exec "$container_id" tail -c 500 /tmp/memory-stream-limit.out)
    after_memory=$(podman exec "$container_id" curl -fsS --max-time 5 \
        http://127.0.0.1/normal-worker.php)
    [[ $memory_result == *READY* && $memory_result == *'Allowed memory size of 8388608 bytes exhausted'* && $memory_result != *RETURNED* ]] || {
        printf 'expected %s memory stream soft OOM and request abort missing: %s\n' "$memory_case" "$memory_result" >&2; exit 1;
    }
    [[ ${pre%%$'\n'*} == ${after_memory%%$'\n'*} ]] || {
        printf 'Apache worker changed after %s memory stream soft OOM\n' "$memory_case" >&2; exit 1;
    }
done
printf '%s\n' REPEAT_NORMAL_OK REPEAT_OOM_REPORTED AGGREGATE_OOM_REPORTED PAD_NORMAL_OK PAD_OOM_REPORTED IMPLODE_NORMAL_OK IMPLODE_OOM_REPORTED CHUNK_NORMAL_OK CHUNK_OOM_REPORTED WORDWRAP_NORMAL_OK WORDWRAP_OOM_REPORTED EXPLODE_NORMAL_OK EXPLODE_POSITIVE_OOM_REPORTED EXPLODE_NEGATIVE_OOM_REPORTED EXPLODE_TERMINAL_OOM_REPORTED ARRAY_FILL_NORMAL_OK ARRAY_FILL_PACKED_OOM_REPORTED ARRAY_FILL_MIXED_OOM_REPORTED RANGE_NORMAL_OK RANGE_LONG_OOM_REPORTED RANGE_DOUBLE_OOM_REPORTED ARRAY_CHUNK_NORMAL_OK ARRAY_CHUNK_OUTER_OOM_REPORTED ARRAY_CHUNK_INNER_OOM_REPORTED ARRAY_MAP_NORMAL_OK ARRAY_MAP_OUTER_OOM_REPORTED ARRAY_MAP_INNER_OOM_REPORTED ARRAY_PAD_ARRAY_NORMAL_OK ARRAY_PAD_ARRAY_PACKED_OOM_REPORTED ARRAY_PAD_ARRAY_MIXED_OOM_REPORTED MEMORY_STREAM_NORMAL_OK MEMORY_STREAM_WRITE_OOM_REPORTED MEMORY_STREAM_TRUNCATE_OOM_REPORTED WORKER_REUSED
