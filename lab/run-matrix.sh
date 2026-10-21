#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
mode=patch
jobs=2
versions=5.6.40,7.3.29,7.3.33
source_dir=/private/tmp/php-backport-sources
results_dir=/private/tmp/php-backport-results
patch_dir=
check_dir=
timeout_seconds=3600

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) mode=$2; shift 2 ;;
        --jobs) jobs=$2; shift 2 ;;
        --versions) versions=$2; shift 2 ;;
        --source-dir) source_dir=$2; shift 2 ;;
        --patch-dir) patch_dir=$2; shift 2 ;;
        --check-dir) check_dir=$2; shift 2 ;;
        --timeout-seconds) timeout_seconds=$2; shift 2 ;;
        --results-dir) results_dir=$2; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

[[ $mode == patch || $mode == baseline ]] || { echo 'mode must be patch or baseline' >&2; exit 2; }
[[ $jobs =~ ^[1-9][0-9]*$ ]] || { echo 'jobs must be positive' >&2; exit 2; }
[[ $timeout_seconds =~ ^[1-9][0-9]*$ ]] || { echo 'timeout must be positive' >&2; exit 2; }
if [[ $mode == patch && -z $patch_dir ]]; then
    echo '--patch-dir is required in patch mode' >&2
    exit 2
fi
if [[ $mode == patch && -z $check_dir ]]; then
    echo '--check-dir is required in patch mode' >&2
    exit 2
fi
mkdir -p "$results_dir"
export PHP_MATRIX_MODE=$mode PHP_SOURCE_DIR=$source_dir PHP_PATCH_DIR=$patch_dir
export PHP_CHECK_DIR=$check_dir PHP_RESULTS_DIR=$results_dir PHP_TIMEOUT_SECONDS=$timeout_seconds
printf '%s\n' "${versions//,/$'\n'}" | xargs -P "$jobs" -I '{}' "$script_dir/run-one.sh" '{}'
