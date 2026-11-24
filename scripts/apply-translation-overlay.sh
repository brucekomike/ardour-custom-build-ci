#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
	printf 'Usage: %s <ardour-source-dir> <translation-repo-dir>\n' "$0" >&2
	exit 2
fi

ardour_source=$(cd "$1" && pwd)
translation_source=$(cd "$2" && pwd)

translation_files=(
	gtk2_ardour/po/zh.po
	gtk2_ardour/appdata/po/zh.po
	libs/ardour/po/zh.po
	libs/tk/ytk/po/zh.po
	libs/gtkmm2ext/po/zh.po
)

for relative_path in "${translation_files[@]}"; do
	from="$translation_source/$relative_path"
	to="$ardour_source/$relative_path"
	if [[ ! -f "$from" ]]; then
		printf 'Missing translation file: %s\n' "$from" >&2
		exit 1
	fi
	if [[ ! -f "$to" ]]; then
		printf 'Ardour source has no matching path: %s\n' "$to" >&2
		exit 1
	fi
	cp "$from" "$to"
	printf 'Applied %s\n' "$relative_path"
done
