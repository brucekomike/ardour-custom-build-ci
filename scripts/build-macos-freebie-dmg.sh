#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
ci_root="$(cd "$script_dir/.." && pwd)"
source_dir="${ARDOUR_SOURCE_DIR:-$ci_root/ardour}"
jobs="${ARDOUR_BUILD_JOBS:-$(sysctl -n hw.ncpu)}"
clean_build=0
configure_args=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		--clean)
			clean_build=1
			shift
			;;
		-j|--jobs)
			if [[ $# -lt 2 ]]; then
				printf 'Missing value after %s\n' "$1" >&2
				exit 2
			fi
			jobs="$2"
			shift 2
			;;
		-h|--help)
			cat <<USAGE
Usage: $0 [--clean] [-j|--jobs N] [additional Waf configure options...]

Builds the ignored ./ardour checkout as an NLS-enabled --freebie app and DMG.
Set ARDOUR_SOURCE_DIR to use a different Ardour checkout, or
ARDOUR_TRANSLATION_DIR to overlay the private PO catalogs before building.
USAGE
			exit 0
			;;
		*)
			configure_args+=("$1")
			shift
			;;
	esac
done

if ! source_dir="$(cd "$source_dir" 2>/dev/null && pwd)" || \
	! git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
	[[ ! -f "$source_dir/waf" ]]; then
	printf 'Ardour checkout not found at %s\n' "$source_dir" >&2
	printf 'Clone it into %s/ardour or set ARDOUR_SOURCE_DIR.\n' "$ci_root" >&2
	exit 1
fi

if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
	printf 'Build job count must be a positive integer; received %s\n' "$jobs" >&2
	exit 2
fi

if [[ -n "${APPLE_DEVELOPER_ID_FOR_APPLICATION:-}" ]]; then
	printf 'This wrapper creates a local ad-hoc-signed DMG. Unset APPLE_DEVELOPER_ID_FOR_APPLICATION; use osx_build directly for Developer ID distribution.\n' >&2
	exit 1
fi

source "$script_dir/activate-macos-build-env.sh"

if [[ -n "${ARDOUR_TRANSLATION_DIR:-}" ]]; then
	"$script_dir/apply-translation-overlay.sh" "$source_dir" "$ARDOUR_TRANSLATION_DIR"
fi

if [[ "$clean_build" -eq 1 ]]; then
	printf 'Removing only the Ardour build directory requested by --clean.\n'
	rm -rf "$source_dir/build"
fi

printf 'Configuring Ardour freebie build at %s\n' "$source_dir"
"$script_dir/configure-macos.sh" "$source_dir" --freebie "${configure_args[@]}"

printf 'Compiling Ardour with %s jobs\n' "$jobs"
(cd "$source_dir" && "$ARDOUR_PYTHON" waf -j"$jobs")

printf 'Generating translations and building the freebie DMG\n'
ARDOUR_REQUIRE_FREEBIE=1 "$script_dir/package-macos-app.sh" "$source_dir"
