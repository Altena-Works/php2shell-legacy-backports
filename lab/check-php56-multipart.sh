#!/usr/bin/env bash
set -euo pipefail

source_tree=${1:?patched or baseline PHP 5.6.40 source tree required}
expected_progress=${2:?PROGRESS_PRESENT or PROGRESS_ABSENT required}
script_dir=$(cd "$(dirname "$0")" && pwd)
exec "$script_dir/check-multipart-progress.sh" "$source_tree" 5.6.40 "$expected_progress"
