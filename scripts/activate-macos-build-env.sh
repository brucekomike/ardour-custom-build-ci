# Source this file in the shell that will run Waf.
_ardour_arch="$(uname -m)"
_ardour_extra_prefix="${ARDOUR_EXTRA_PREFIX:-$HOME/.local/opt/ardour-extra}"

case "$_ardour_arch" in
	arm64)
		command -v brew >/dev/null 2>&1 || { printf 'Homebrew is missing from PATH.\n' >&2; return 1 2>/dev/null || exit 1; }
		_ardour_prefix="$(brew --prefix)"
		_ardour_pc="$_ardour_prefix/lib/pkgconfig"
		for _ardour_formula in glibmm@2.66 libsigc++@2 cairomm@1.14 pangomm@2.46 libarchive libxml2 curl gettext readline jpeg; do
			_ardour_formula_prefix="$(brew --prefix "$_ardour_formula")"
			_ardour_pc="$_ardour_pc:$_ardour_formula_prefix/lib/pkgconfig"
		done
		export PATH="$_ardour_prefix/bin:$_ardour_prefix/opt/libarchive/bin:$PATH"
		export CPPFLAGS="-I$_ardour_prefix/include -I$_ardour_prefix/include/raptor2 ${CPPFLAGS:-}"
		export CPLUS_INCLUDE_PATH="$_ardour_prefix/include:$_ardour_prefix/include/raptor2${CPLUS_INCLUDE_PATH:+:$CPLUS_INCLUDE_PATH}"
		export LDFLAGS="-L$_ardour_prefix/lib -L$_ardour_prefix/opt/libarchive/lib -L$_ardour_prefix/opt/jpeg/lib ${LDFLAGS:-}"
		export PKG_CONFIG_PATH="$_ardour_pc${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
		;;
	x86_64)
		_ardour_prefix="${ARDOUR_MACPORTS_PREFIX:-}"
		if [ -z "$_ardour_prefix" ]; then
			if [ -x "$HOME/.local/opt/ardour-macports/bin/port" ]; then _ardour_prefix="$HOME/.local/opt/ardour-macports"; else _ardour_prefix=/opt/local; fi
		fi
		[ -x "$_ardour_prefix/bin/port" ] || { printf 'MacPorts not found under %s; run the setup script first.\n' "$_ardour_prefix" >&2; return 1 2>/dev/null || exit 1; }
		export ARDOUR_MACPORTS_PREFIX="$_ardour_prefix"
		export PATH="$_ardour_prefix/bin:$_ardour_prefix/sbin:$_ardour_extra_prefix/bin:$PATH"
		export CPPFLAGS="-I$_ardour_prefix/include -I$_ardour_extra_prefix/include ${CPPFLAGS:-}"
		export CPLUS_INCLUDE_PATH="$_ardour_prefix/include:$_ardour_extra_prefix/include${CPLUS_INCLUDE_PATH:+:$CPLUS_INCLUDE_PATH}"
		export LDFLAGS="-L$_ardour_prefix/lib -L$_ardour_extra_prefix/lib ${LDFLAGS:-}"
		export PKG_CONFIG_PATH="$_ardour_extra_prefix/lib/pkgconfig:$_ardour_prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
		;;
	*) printf 'Expected macOS arm64 or x86_64; found %s.\n' "$_ardour_arch" >&2; return 1 2>/dev/null || exit 1 ;;
esac

export ARDOUR_PYTHON="${ARDOUR_PYTHON:-$(command -v python3 || command -v python3.14 || true)}"
[ -n "$ARDOUR_PYTHON" ] || { printf 'Python 3 is required.\n' >&2; return 1 2>/dev/null || exit 1; }
unset _ardour_arch _ardour_prefix _ardour_pc _ardour_formula _ardour_formula_prefix _ardour_extra_prefix
