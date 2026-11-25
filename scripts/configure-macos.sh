#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
	printf 'Usage: %s <ardour-source-dir> [additional-waf-configure-options...]\n' "$0" >&2
	exit 2
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
source_dir="$(cd "$1" && pwd)"
shift

if [[ -z "${ARDOUR_PYTHON:-}" || -z "${ARDOUR_EXTRA_INCLUDE:-}" ]]; then
	source "$script_dir/activate-macos-build-env.sh"
fi
"$script_dir/apply-custom-build-patches.sh" "$source_dir"

configure_args=(
	--noconfirm
	--no-phone-home
	--no-carbon
	--nls
	--optimize
	--ptformat
	--with-backends=jack,coreaudio,dummy
)

if [[ -n "${ARDOUR_EXTRA_INCLUDE:-}" ]]; then
	configure_args+=("--also-include=$ARDOUR_EXTRA_INCLUDE")
fi
if [[ -n "${ARDOUR_EXTRA_LIBDIR:-}" ]]; then
	configure_args+=("--also-libdir=$ARDOUR_EXTRA_LIBDIR")
fi
if [[ "$(uname -m)" == arm64 ]]; then
	configure_args+=(--arm64)
fi

cd "$source_dir"
"$ARDOUR_PYTHON" waf configure "${configure_args[@]}" "$@"
