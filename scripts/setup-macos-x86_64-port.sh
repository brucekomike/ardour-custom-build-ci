#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin || "$(uname -m)" != x86_64 ]]; then
	printf 'This setup is for macOS x86_64 (Intel).\n' >&2
	exit 2
fi
if ! command -v xcode-select >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then
	printf 'Install Xcode Command Line Tools first: xcode-select --install\n' >&2
	exit 1
fi

macports_version=2.12.7
user_port_prefix="$HOME/.local/opt/ardour-macports"
port_prefix="${ARDOUR_MACPORTS_PREFIX:-}"
force_user_space=0
dry_run=0

for arg in "$@"; do
	case "$arg" in
		--user-space) force_user_space=1 ;;
		--dry-run) dry_run=1 ;;
		*) printf 'Unknown option: %s\nUsage: %s [--user-space] [--dry-run]\n' "$arg" "$0" >&2; exit 2 ;;
	esac
done

if [[ -z "$port_prefix" && "$force_user_space" -eq 0 ]] && command -v port >/dev/null 2>&1; then
	port_bin="$(command -v port)"
	port_prefix="$(cd "$(dirname "$port_bin")/.." && pwd)"
elif [[ -z "$port_prefix" && "$force_user_space" -eq 0 && -x /opt/local/bin/port ]]; then
	port_prefix=/opt/local
elif [[ -z "$port_prefix" ]]; then
	port_prefix="$user_port_prefix"
fi
port_bin="$port_prefix/bin/port"

if [[ "$force_user_space" -eq 1 || ! -x "$port_bin" ]]; then
	case "$port_prefix/" in
		"$HOME"/*) ;;
		*) printf 'No-root MacPorts prefix must be under HOME, not %s\n' "$port_prefix" >&2; exit 2 ;;
	esac
fi

ports=(
	boost cmake cppunit gettext glib2 glibmm-2.4 libsigcxx2 cairo cairomm-1.0
	pango pangomm-1.4 fontconfig libpng jpeg libxml2 libsndfile libsamplerate libarchive
	curl liblo taglib rubberband fftw-3-single jack portaudio lv2 serd sord sratom lilv aubio
	liblrdf libltc libusb libwebsockets flac libogg readline pkgconfig python314
)

if [[ "$dry_run" -eq 1 ]]; then
	if [[ "$force_user_space" -eq 1 || ! -x "$port_bin" ]]; then
		printf 'Would bootstrap MacPorts %s under %s (no sudo; source builds may take a while).\n' "$macports_version" "$port_prefix"
	fi
	printf 'Would install ports:'
	printf ' %q' "${ports[@]}"
	printf '\nWould build Vamp SDK 2.10 into %s\n' "${ARDOUR_EXTRA_PREFIX:-$HOME/.local/opt/ardour-extra}"
	exit 0
fi

if [[ "$force_user_space" -eq 1 || ! -x "$port_bin" ]]; then
	# Official MacPorts no-root mode: all files stay under the user's prefix.
	mkdir -p "$port_prefix"
	bootstrap_dir="$(mktemp -d "${TMPDIR:-/tmp}/ardour-macports.XXXXXX")"
	trap 'rm -rf "$bootstrap_dir"' EXIT
	archive="$bootstrap_dir/MacPorts-${macports_version}.tar.bz2"
	curl -fL "https://github.com/macports/macports-base/releases/download/v${macports_version}/MacPorts-${macports_version}.tar.bz2" -o "$archive"
	tar -xjf "$archive" -C "$bootstrap_dir"
	cd "$bootstrap_dir/MacPorts-${macports_version}"
	./configure --prefix="$port_prefix" --with-no-root-privileges --without-startupitems
	make -j"$(sysctl -n hw.ncpu)"
	make install
	trap - EXIT
	rm -rf "$bootstrap_dir"
	port_bin="$port_prefix/bin/port"
fi

if [[ "$port_prefix" == /opt/local ]]; then
	sudo "$port_bin" selfupdate
	sudo "$port_bin" install "${ports[@]}"
else
	"$port_bin" selfupdate
	"$port_bin" install "${ports[@]}"
fi
export PATH="$port_prefix/bin:$port_prefix/sbin:$PATH"

# MacPorts has no Vamp SDK port; build its permissively licensed upstream SDK
# into a user-owned prefix, independent of the selected MacPorts prefix.
extra_prefix="${ARDOUR_EXTRA_PREFIX:-$HOME/.local/opt/ardour-extra}"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/ardour-vamp-sdk.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
sdk_tag=vamp-plugin-sdk-v2.10
archive="$build_dir/${sdk_tag}.tar.gz"
curl -fL "https://github.com/vamp-plugins/vamp-plugin-sdk/archive/refs/tags/${sdk_tag}.tar.gz" -o "$archive"
tar -xzf "$archive" -C "$build_dir"
sdk_source="$(find "$build_dir" -name CMakeLists.txt -print -quit | xargs dirname)"
cmake -S "$sdk_source" -B "$build_dir/build" \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$extra_prefix" \
	-DCMAKE_OSX_ARCHITECTURES=x86_64
cmake --build "$build_dir/build" --parallel "$(sysctl -n hw.ncpu)"
cmake --install "$build_dir/build"
script_dir="$(cd "$(dirname "$0")" && pwd)"
export ARDOUR_MACPORTS_PREFIX="$port_prefix"
export ARDOUR_EXTRA_PREFIX="$extra_prefix"
source "$script_dir/activate-macos-build-env.sh"
"$script_dir/check-macos-deps.sh"

printf '\nDependencies installed. Activate the build environment with:\n'
printf '  export ARDOUR_MACPORTS_PREFIX="%s"\n' "$port_prefix"
printf '  export ARDOUR_EXTRA_PREFIX="%s"\n' "$extra_prefix"
printf '  source "%s/activate-macos-build-env.sh"\n' "$script_dir"
printf 'Then build Ardour with: "$ARDOUR_PYTHON" waf configure --noconfirm && "$ARDOUR_PYTHON" waf -j"$(sysctl -n hw.ncpu)" && "$ARDOUR_PYTHON" waf i18n\n'
