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

printf 'Building gettext catalogs (NLS enabled) ...\n'
(cd "$source_dir" && "$python" waf i18n)

printf 'Packaging Ardour with NLS enabled ...\n'
(cd "$packaging_dir" && /bin/bash ./osx_build --public --nls)

app="$packaging_dir/Ardour/Ardour9.app"
if [[ ! -d "$app" ]]; then
	printf 'Expected packaged app was not produced: %s\n' "$app" >&2
	exit 1
fi

"$script_dir/finalize-macos-app.sh" "$app"
printf 'macOS CI artifact ready: %s\n' "$app"
