#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	printf 'Usage: %s <Ardour.app>\n' "$0" >&2
	exit 2
fi

app="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
contents="$app/Contents"
libdir="$contents/lib"

if [[ ! -d "$app" || ! -d "$libdir" ]]; then
	printf 'Not an Ardour app bundle: %s\n' "$app" >&2
	exit 1
fi

# Homebrew's libbrotlidec links to this sibling library, which osx_build may
# omit from Contents/lib even though the app's @rpath expects it there.
if [[ -e "$libdir/libbrotlidec.1.dylib" && ! -e "$libdir/libbrotlicommon.1.dylib" ]]; then
	search_dirs=()
	if [[ -n "${ARDOUR_BROTLI_LIBDIR:-}" ]]; then
		search_dirs+=("$ARDOUR_BROTLI_LIBDIR")
	fi
	if command -v brew >/dev/null 2>&1; then
		brew_brotli_prefix="$(brew --prefix brotli 2>/dev/null || true)"
		if [[ -n "$brew_brotli_prefix" ]]; then
			search_dirs+=("$brew_brotli_prefix/lib")
		fi
	fi
	if [[ -n "${ARDOUR_MACPORTS_PREFIX:-}" ]]; then
		search_dirs+=("$ARDOUR_MACPORTS_PREFIX/lib")
	fi
	search_dirs+=(/opt/local/lib /opt/homebrew/opt/brotli/lib /usr/local/opt/brotli/lib "$HOME/gtk/inst/lib")

	brotli_common_source=""
	for search_dir in "${search_dirs[@]}"; do
		candidate="$search_dir/libbrotlicommon.1.dylib"
		if [[ -f "$candidate" ]]; then
			brotli_common_source="$candidate"
			break
		fi
	done
	if [[ -z "$brotli_common_source" ]]; then
		printf 'libbrotlicommon.1.dylib is required by the bundled libbrotlidec but was not found. Set ARDOUR_BROTLI_LIBDIR.\n' >&2
		exit 1
	fi
	cp -Lf "$brotli_common_source" "$libdir/libbrotlicommon.1.dylib"
	printf 'Bundled Brotli runtime dependency from %s\n' "$brotli_common_source"
fi

# Catch unresolved bundle-relative dependencies during CI instead of waiting
# for dyld to fail when a user launches the artifact.
dependency_failures=()
while IFS= read -r -d '' code_file; do
	if ! /usr/bin/file -b "$code_file" | /usr/bin/grep -q 'Mach-O'; then
		continue
	fi
	while IFS= read -r dependency; do
		case "$dependency" in
			@rpath/*)
				relative_path="${dependency#@rpath/}"
				if [[ ! -e "$libdir/$relative_path" && ! -e "$contents/Frameworks/$relative_path" ]]; then
					dependency_failures+=("$code_file -> $dependency")
				fi
				;;
			@loader_path/*)
				if [[ ! -e "$(dirname "$code_file")/${dependency#@loader_path/}" ]]; then
					dependency_failures+=("$code_file -> $dependency")
				fi
				;;
			@executable_path/*)
				if [[ ! -e "$contents/MacOS/${dependency#@executable_path/}" ]]; then
					dependency_failures+=("$code_file -> $dependency")
				fi
				;;
		esac
	done < <(/usr/bin/otool -L "$code_file" 2>/dev/null | /usr/bin/awk 'NR > 1 { print $1 }')
done < <(/usr/bin/find "$contents" -type f -print0)

if [[ ${#dependency_failures[@]} -gt 0 ]]; then
	printf 'Unresolved app-bundle dependencies:\n' >&2
	printf '  %s\n' "${dependency_failures[@]}" >&2
	exit 1
fi

sign_failures=()
while IFS= read -r -d '' code_file; do
	if ! /usr/bin/file -b "$code_file" | /usr/bin/grep -q 'Mach-O'; then
		continue
	fi

	# This third-party Harrison binary is not accepted by Apple's codesign tool
	# in ad-hoc mode. It is an optional plugin, not an Ardour startup dependency.
	case "$code_file" in
		"$libdir/LV2/Harrison.lv2/XT_SP.so")
			printf 'Warning: leaving unsupported optional plugin unsigned: %s\n' "$code_file" >&2
			continue
			;;
	esac

	chmod u+w "$code_file"
	if ! /usr/bin/codesign --force --sign - --timestamp=none "$code_file"; then
		sign_failures+=("$code_file")
	fi
done < <(/usr/bin/find "$contents" -type f -print0)

if [[ ${#sign_failures[@]} -gt 0 ]]; then
	printf 'Ad-hoc signing failed for bundled Mach-O files:\n' >&2
	printf '  %s\n' "${sign_failures[@]}" >&2
	exit 1
fi

# The outer bundle must be signed last, after copying dependencies and signing
# the code nested in Contents.
/usr/bin/codesign --force --sign - --timestamp=none "$app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app"

# Deep verification does not reliably descend into Ardour's nonstandard
# Contents/lib directory, so explicitly verify its Mach-O files as well.
while IFS= read -r -d '' code_file; do
	if /usr/bin/file -b "$code_file" | /usr/bin/grep -q 'Mach-O'; then
		case "$code_file" in
			"$libdir/LV2/Harrison.lv2/XT_SP.so") continue ;;
		esac
		/usr/bin/codesign --verify --strict "$code_file"
	fi
done < <(/usr/bin/find "$libdir" -type f -print0)

printf 'Finalized local ad-hoc-signed app: %s\n' "$app"
