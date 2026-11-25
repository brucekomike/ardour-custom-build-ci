#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	printf 'Usage: %s <ardour-source-dir>\n' "$0" >&2
	exit 2
fi

source_dir="$(cd "$1" && pwd)"
script_dir="$(cd "$(dirname "$0")" && pwd)"
packaging_dir="$source_dir/tools/osx_packaging"
python="${ARDOUR_PYTHON:-$(command -v python3 || true)}"

if [[ -n "${APPLE_DEVELOPER_ID_FOR_APPLICATION:-}" ]]; then
	printf 'This helper produces a local ad-hoc-signed app. Do not set APPLE_DEVELOPER_ID_FOR_APPLICATION; use osx_build directly for Developer ID signing and notarization.\n' >&2
	exit 1
fi

if [[ -z "$python" ]]; then
	printf 'Python 3 is required; source activate-macos-build-env.sh first.\n' >&2
	exit 1
fi
if [[ ! -f "$source_dir/waf" || ! -f "$packaging_dir/osx_build" ]]; then
	printf 'Expected an Ardour source checkout with tools/osx_packaging/osx_build: %s\n' "$source_dir" >&2
	exit 1
fi

bundle_hook_patch="$script_dir/../patches/macos-bundle-finalizer-hook.patch"
if ! git -C "$source_dir" apply --unidiff-zero --reverse --check "$bundle_hook_patch" >/dev/null 2>&1; then
	printf 'The app-finalizer hook is not applied. Run configure-macos.sh before building/packaging.\n' >&2
	exit 1
fi

printf 'Building gettext catalogs (NLS enabled) ...\n'
(cd "$source_dir" && "$python" waf i18n)

printf 'Packaging Ardour with NLS enabled ...\n'
(
	cd "$packaging_dir"
	ARDOUR_CI_FINALIZE_APP="$script_dir/finalize-macos-app.sh" \
		/bin/bash ./osx_build --public --nls
)

shopt -s nullglob
if [[ "${ARDOUR_REQUIRE_FREEBIE:-0}" == 1 ]]; then
	dmg_candidates=("$packaging_dir"/Ardour-*-demo*.dmg)
else
	dmg_candidates=("$packaging_dir"/Ardour-*.dmg)
fi
if [[ ${#dmg_candidates[@]} -eq 0 ]]; then
	printf 'osx_build did not produce an Ardour DMG in %s\n' "$packaging_dir" >&2
	exit 1
fi

dmg_path=""
newest_mtime=0
for candidate in "${dmg_candidates[@]}"; do
	mtime="$(/usr/bin/stat -f '%m' "$candidate")"
	if [[ -z "$dmg_path" || "$mtime" -gt "$newest_mtime" ]]; then
		dmg_path="$candidate"
		newest_mtime="$mtime"
	fi
done

printf 'macOS freebie DMG artifact ready: %s\n' "$dmg_path"
