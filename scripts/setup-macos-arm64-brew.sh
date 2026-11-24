#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
	printf 'This setup is for native macOS arm64 (Apple Silicon).\n' >&2
	exit 2
fi
if ! command -v xcode-select >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then
	printf 'Install Xcode Command Line Tools first: xcode-select --install\n' >&2
	exit 1
fi
if ! command -v brew >/dev/null 2>&1 || [[ "$(brew --prefix)" != /opt/homebrew ]]; then
	printf 'Install native Apple Silicon Homebrew under /opt/homebrew first: https://brew.sh\n' >&2
	exit 1
fi

formulae=(
	boost cmake cppunit gettext glib glibmm@2.66 libsigc++@2 cairo cairomm@1.14
	pango pangomm@2.46 fontconfig libpng jpeg libxml2 libsndfile libsamplerate libarchive
	curl liblo taglib vamp-plugin-sdk rubberband fftw jack portaudio lv2 serd sord sratom lilv
	aubio lrdf libltc libusb libwebsockets flac libogg readline pkgconf python@3.15
)

if [[ "${1:-}" == --dry-run ]]; then
	printf 'Would run: brew install'
	printf ' %q' "${formulae[@]}"
	printf '\n'
	exit 0
fi
if [[ $# -gt 0 ]]; then
	printf 'Usage: %s [--dry-run]\n' "$0" >&2
	exit 2
fi

brew install "${formulae[@]}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
source "$script_dir/activate-macos-build-env.sh"
"$script_dir/check-macos-deps.sh"
printf '\nDependencies installed. Source "%s/activate-macos-build-env.sh", then run:\n' "$script_dir"
printf '  python3 waf configure --arm64 --noconfirm\n  python3 waf -j"$(sysctl -n hw.ncpu)"\n  python3 waf i18n\n'
