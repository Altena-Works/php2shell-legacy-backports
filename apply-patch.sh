#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 VERSION [--archive php-VERSION.tar.gz] [--output DIRECTORY]" >&2
    exit 2
}

[[ $# -ge 1 ]] || usage
version=$1
shift
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || usage

archive_path=
output_root=$HOME/php-backport-apply
while [[ $# -gt 0 ]]; do
    case $1 in
        --archive) [[ $# -ge 2 ]] || usage; archive_path=$2; shift 2 ;;
        --output) [[ $# -ge 2 ]] || usage; output_root=$2; shift 2 ;;
        *) usage ;;
    esac
done

script_dir=$(cd "$(dirname "$0")" && pwd -P)
patch_file=$script_dir/patches/php-$version.patch
[[ -f $patch_file ]] || { echo "No patch for PHP $version" >&2; exit 2; }
for tool in awk patch tar; do
    command -v "$tool" >/dev/null 2>&1 || { echo "Missing command: $tool" >&2; exit 2; }
done

expected=$(awk -F '\t' -v v="$version" '$1 == v { print $2 }' "$script_dir/lab/source-hashes.tsv")
[[ $expected =~ ^[0-9a-f]{64}$ ]] || { echo "No unique source hash for PHP $version" >&2; exit 2; }

hash_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{ print $1 }'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{ print $1 }'
    else
        echo 'Missing SHA-256 command (sha256sum or shasum)' >&2
        return 2
    fi
}

mkdir -p "$output_root"
output_root=$(cd "$output_root" && pwd -P)
target_dir=$output_root/$version
[[ ! -e $target_dir && ! -L $target_dir ]] || {
    echo "Output already exists: $target_dir" >&2
    exit 2
}

temp_dir=$(mktemp -d "$output_root/.apply-$version.XXXXXXXX")
trap 'if [[ -n ${temp_dir:-} ]]; then rm -rf -- "$temp_dir"; fi' EXIT
archive_name=php-$version.tar.gz
if [[ -n $archive_path ]]; then
    [[ -f $archive_path ]] || { echo "Archive not found: $archive_path" >&2; exit 2; }
    cp -- "$archive_path" "$temp_dir/$archive_name"
else
    command -v curl >/dev/null 2>&1 || { echo 'Missing command: curl' >&2; exit 2; }
    major=${version%%.*}
    curl -fL --retry 3 "https://museum.php.net/php$major/$archive_name" \
        -o "$temp_dir/$archive_name"
fi

actual=$(hash_file "$temp_dir/$archive_name")
[[ $actual == "$expected" ]] || { echo "Source hash mismatch for PHP $version" >&2; exit 1; }
tar -xzf "$temp_dir/$archive_name" -C "$temp_dir"
source_tree=$temp_dir/php-$version
[[ -d $source_tree ]] || { echo "Source directory missing: php-$version" >&2; exit 1; }

(
    cd "$source_tree"
    if ! patch --dry-run --fuzz=0 --batch -p1 < "$patch_file" > "$temp_dir/patch-dry-run.log" 2>&1; then
        cat "$temp_dir/patch-dry-run.log" >&2
        exit 1
    fi
    if ! patch --fuzz=0 --batch -p1 < "$patch_file" > "$temp_dir/patch-apply.log" 2>&1; then
        cat "$temp_dir/patch-apply.log" >&2
        exit 1
    fi
)
mv -- "$temp_dir" "$target_dir"
temp_dir=
echo "Patched source: $target_dir/php-$version"
echo 'Verification candidate only: complete remediation of both CVEs has not been established.' >&2
