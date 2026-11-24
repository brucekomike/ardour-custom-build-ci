#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	printf 'Usage: %s <ardour-source-dir>\n' "$0" >&2
	exit 2
fi

source_dir="$(cd "$1" && pwd)"
patch_file="$(cd "$(dirname "$0")/.." && pwd)/patches/macos-disable-elf-aliases.patch"

if git -C "$source_dir" apply --check "$patch_file" >/dev/null 2>&1; then
	git -C "$source_dir" apply "$patch_file"
	printf 'Applied Darwin alias workaround to %s\n' "$source_dir"
elif git -C "$source_dir" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
	printf 'Darwin alias workaround is already applied in %s\n' "$source_dir"
else
	git -C "$source_dir" apply --check "$patch_file" || true
	printf 'Patch does not apply cleanly to %s; check its Ardour revision and local changes.\n' "$source_dir" >&2
	exit 1
fi
