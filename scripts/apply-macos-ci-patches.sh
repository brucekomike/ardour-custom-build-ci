#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	printf 'Usage: %s <ardour-source-dir>\n' "$0" >&2
	exit 2
fi

source_dir="$(cd "$1" && pwd)"
patch_dir="$(cd "$(dirname "$0")/.." && pwd)/patches"

for patch_name in macos-disable-elf-aliases.patch macos-enable-nls-option.patch; do
	patch_file="$patch_dir/$patch_name"
	if git -C "$source_dir" apply --check "$patch_file" >/dev/null 2>&1; then
		git -C "$source_dir" apply "$patch_file"
		printf 'Applied %s\n' "$patch_name"
	elif git -C "$source_dir" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
		printf '%s is already applied\n' "$patch_name"
	else
		git -C "$source_dir" apply --check "$patch_file" || true
		printf 'Cannot apply %s cleanly to %s; check the Ardour revision and local changes.\n' "$patch_name" "$source_dir" >&2
		exit 1
	fi
done
