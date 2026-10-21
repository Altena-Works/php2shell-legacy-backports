#!/usr/bin/env bash
set -euo pipefail

version=${1:?version required}
[[ $version =~ ^[57]\.[0-9]+\.[0-9]+$ ]] || { echo "invalid version: $version" >&2; exit 2; }
mode=${PHP_MATRIX_MODE:?mode required}
source_dir=${PHP_SOURCE_DIR:?source directory required}
results_root=${PHP_RESULTS_DIR:?results directory required}
patch_dir=${PHP_PATCH_DIR:-}
check_dir=${PHP_CHECK_DIR:-}
timeout_seconds=${PHP_TIMEOUT_SECONDS:-3600}
script_dir=$(cd "$(dirname "$0")" && pwd)
result_dir=$results_root/$mode/$version
mkdir -p "$result_dir"
work_dir=$results_root/work/$version
mkdir -p "$work_dir"
container_id=

finish() {
    result=$?
    if [[ -n $container_id ]]; then
        podman logs "$container_id" > "$result_dir/container.log" 2>&1 || true
        podman stop --time 2 "$container_id" >/dev/null 2>&1 || true
    fi
    for log in configure make install; do
        if [[ -f $work_dir/php-$version/$log.log ]]; then
            cp "$work_dir/php-$version/$log.log" "$result_dir/$log.log"
        fi
    done
    if [[ $result -eq 0 ]]; then printf 'pass\n' > "$result_dir/status";
    else printf 'fail (%s)\n' "$result" > "$result_dir/status"; fi
}
trap finish EXIT

case "$version" in
    5.*) image=localhost/php-backport-build:5.6 ;;
    7.*) image=localhost/php-backport-build:7.4 ;;
    *) echo "unsupported version: $version" >&2; exit 2 ;;
esac

archive=$source_dir/php-$version.tar.gz
[[ -f $archive ]] || { echo "missing source: $archive" >&2; exit 2; }
expected_hash=$(awk -F '\t' -v v="$version" '$1 == v { print $2 }' "$script_dir/source-hashes.tsv")
[[ -n $expected_hash ]] || { echo "missing source hash: $version" >&2; exit 2; }
actual_hash=$(shasum -a 256 "$archive" | awk '{ print $1 }')
[[ $actual_hash == "$expected_hash" ]] || { echo "source hash mismatch: $version" >&2; exit 2; }
printf '%s  %s\n' "$actual_hash" "$archive" > "$result_dir/source.sha256"
source_tree=$work_dir/php-$version
if [[ ! -d $source_tree ]]; then
    tar -xzf "$archive" -C "$work_dir"
    printf '%s\n' "$actual_hash" > "$work_dir/source.sha256"
    printf '/src\n' > "$work_dir/mount-path"
else
    [[ $(cat "$work_dir/source.sha256" 2>/dev/null) == "$actual_hash" ]] || {
        echo "existing worktree has a different source: $source_tree" >&2
        exit 2
    }
fi
[[ -f $source_tree/configure ]] || { echo "invalid source archive: $archive" >&2; exit 2; }
mount_path=$(cat "$work_dir/mount-path" 2>/dev/null)
case "$mount_path" in
    /src|/work/php-"$version") ;;
    *) echo "invalid mount path: $mount_path" >&2; exit 2 ;;
esac

if [[ $mode == patch ]]; then
    patch_file=$patch_dir/php-$version.patch
    [[ -f $patch_file ]] || { echo "missing patch: $patch_file" >&2; exit 2; }
    check_file=$check_dir/$version.sh
    [[ -x $check_file ]] || { echo "missing defense check: $check_file" >&2; exit 2; }
    shasum -a 256 "$patch_file" > "$result_dir/patch.sha256"
    patch_hash=$(awk '{ print $1 }' "$result_dir/patch.sha256")
    if [[ -f $work_dir/applied-patch.sha256 ]]; then
        [[ $(cat "$work_dir/applied-patch.sha256") == "$patch_hash" ]] || {
            echo "different patch already applied: $version" >&2
            exit 2
        }
    else
        podman run --rm --platform linux/amd64 --network none \
            -v "$source_tree:$mount_path" -v "$patch_file:/fix.patch:ro" -w "$mount_path" \
            "$image" patch --dry-run --fuzz=0 --batch --forward -p1 -i /fix.patch \
            > "$result_dir/patch-check.log" 2>&1
        podman run --rm --platform linux/amd64 --network none \
            -v "$source_tree:$mount_path" -v "$patch_file:/fix.patch:ro" -w "$mount_path" \
            "$image" patch --fuzz=0 --batch --forward -p1 -i /fix.patch \
            > "$result_dir/patch-apply.log" 2>&1
        printf '%s\n' "$patch_hash" > "$work_dir/applied-patch.sha256"
    fi
elif [[ $mode != baseline ]]; then
    echo "invalid mode: $mode" >&2
    exit 2
elif [[ -f $work_dir/applied-patch.sha256 ]]; then
    echo "baseline requested on patched worktree: $version" >&2
    exit 2
fi

container_id=$(podman run --rm -d --platform linux/amd64 --network none \
    -v "$source_tree:$mount_path" -v "$script_dir/health.php:/var/www/html/health.php:ro" \
    -e PHP_SRC_PATH="$mount_path" -w "$mount_path" "$image" bash -lc '
        set -e
        if [ ! -f Makefile ]; then
            ./configure --prefix=/opt/php-backport --with-apxs2=/usr/bin/apxs \
                --disable-all --enable-session --disable-cgi --without-pear \
                > "$PHP_SRC_PATH/configure.log" 2>&1
        fi
        make -j2 >> "$PHP_SRC_PATH/make.log" 2>&1
        set -- libs/libphp*.so
        [ "$#" -eq 1 ] && [ -f "$1" ]
        target=/usr/lib/apache2/modules/$(basename "$1")
        install -m 644 "$1" "$target" > "$PHP_SRC_PATH/install.log" 2>&1
        cmp "$1" "$target"
        exec apache2-foreground
    ')

deadline=$(( $(date +%s) + timeout_seconds ))
while (( $(date +%s) < deadline )); do
    if podman exec "$container_id" curl -fsS --max-time 3 \
        http://127.0.0.1/health.php > "$result_dir/runtime.txt" 2>/dev/null; then
        if [[ $(cat "$result_dir/runtime.txt") == "$version"$'\n'apache2handler$'\n'SESSION_OK ]]; then
            if [[ $mode == patch ]]; then
                "$check_file" "$source_tree" "$version" > "$result_dir/defense-check.log" 2>&1
            fi
            echo "$version: $mode pass"
            exit 0
        fi
        echo "$version: unexpected HTTP result" >&2
        exit 1
    fi
    state=$(podman inspect --format '{{.State.Running}}' "$container_id" 2>/dev/null || true)
    if [[ $state != true ]]; then
        echo "$version: build or Apache exited; see result logs" >&2
        exit 1
    fi
    sleep 5
done
echo "$version: timed out after $timeout_seconds seconds" >&2
exit 1
