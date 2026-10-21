#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$(realpath "$0")")" && pwd)
exec "$script_dir/7.3.33.sh" "$@"
