#!/usr/bin/env bash
set -euo pipefail

if ! command -v pkg-config >/dev/null 2>&1; then
	printf 'pkg-config is not available. Source activate-macos-build-env.sh first.\n' >&2
	exit 1
fi

modules=(
	glib-2.0 gthread-2.0 glibmm-2.4 giomm-2.4
	sndfile libcurl libarchive liblo taglib
	vamp-sdk vamp-hostsdk rubberband fftw3f
	cairo pango pangocairo cairomm-1.0 pangomm-1.4 sigc++-2.0 fontconfig
	libxml-2.0 samplerate lv2 serd-0 sord-0 sratom-0 lilv-0
	libpng ogg flac ltc lrdf aubio
)

missing=()
for module in "${modules[@]}"; do
	if ! pkg-config --exists "$module"; then
		missing+=("$module")
	fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
	printf 'Missing pkg-config modules: %s\n' "${missing[*]}" >&2
	printf 'Check that the package install completed and the activation script was sourced.\n' >&2
	exit 1
fi

printf 'All checked Ardour macOS dependency modules are visible to pkg-config.\n'
