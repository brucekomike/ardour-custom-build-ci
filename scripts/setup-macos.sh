#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
case "$(uname -s):$(uname -m)" in
	Darwin:arm64) exec "$script_dir/setup-macos-arm64-brew.sh" "$@" ;;
	Darwin:x86_64) exec "$script_dir/setup-macos-x86_64-port.sh" "$@" ;;
	*) printf 'Unsupported host: %s/%s\n' "$(uname -s)" "$(uname -m)" >&2; exit 2 ;;
esac
