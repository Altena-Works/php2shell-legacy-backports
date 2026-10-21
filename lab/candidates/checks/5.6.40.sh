#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$(realpath "$0")")" && pwd)
"$script_dir/7.3.33.sh" "$@"
"$script_dir/../check-session-init-failure.sh" "$1"
"$script_dir/../check-reference-progress.sh" "$1"
