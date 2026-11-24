# Ardour Custom Build CI

Build automation for a self-compiled Ardour with a user-supplied translation
overlay. Ardour source remains in `brucekomike/ardour`; this repository is for
build configuration, translation overlay, and CI only.

## Planned build targets

| Platform | Architecture | Packaging |
| --- | --- | --- |
| macOS | x86_64, arm64 | `.app` / `.dmg` |
| Windows | x86_64 | installer or build artifact |
| Ubuntu | x86_64, arm64 | AppImage |

Ardour's checked-in Windows build configuration currently targets x64, not
Windows ARM64. Other targets will be enabled only when their toolchains and
upstream build scripts support them. Ardour's macOS source build also requires
many dependencies, so these setup scripts are a convenience and not a guarantee
that every current Ardour revision will build against the latest package-manager
libraries.

The setup scripts are not Ardour's official macOS release build environment.
The upstream macOS packaging tools use separate dependency stacks (notably
`~/gtk/inst` and `~/a3/inst`); reproduce those stacks when matching an official
release build is important.

## macOS runners and local setup

GitHub currently offers Intel macOS runners (`macos-15-intel` and
`macos-26-intel`) as well as Apple Silicon runners (`macos-15` and `macos-26`).
Intel support is transitional, so keep arm64 as the long-term target and verify
the live labels before pinning a workflow. See the [GitHub-hosted runner reference](https://docs.github.com/actions/reference/runners/github-hosted-runners-reference).

MacPorts is a package manager, not a CI worker provider. Its port tree supports
Intel macOS and has ports for Ardour's main native dependencies. There is no
Vamp SDK port, so the Intel setup script builds Vamp SDK 2.10 into a separate
user-owned prefix. If MacPorts is absent, the script bootstraps MacPorts in
`~/.local/opt/ardour-macports` using its official no-root mode; that fallback
builds ports from source and can take significantly longer than the standard
`/opt/local` installation. Use `--user-space` to force this isolated route even
when a system MacPorts install exists. System MacPorts installs use `sudo` for
the `/opt/local` tree; the private-prefix mode does not require it.

Run the architecture dispatcher:

```sh
scripts/setup-macos.sh
```

Or call a specific manager directly:

```sh
scripts/setup-macos-arm64-brew.sh       # Apple Silicon
scripts/setup-macos-x86_64-port.sh      # Intel; add --user-space for isolated, no-sudo MacPorts
```

Both setup scripts support `--dry-run`. After setup, source the environment
helper, overlay the private translation, then use the configure helper. It
passes keg-only libarchive include/lib paths through Waf's `--also-include` and
`--also-libdir` options and applies the Darwin alias workaround:

```sh
source scripts/activate-macos-build-env.sh
scripts/apply-translation-overlay.sh /path/to/ardour /path/to/ardour_zh_hans
scripts/configure-macos.sh /path/to/ardour
cd /path/to/ardour
"$ARDOUR_PYTHON" waf -j"$(sysctl -n hw.ncpu)"
"$ARDOUR_PYTHON" waf i18n
```

The Darwin workaround defines `DISABLE_VISIBILITY` for the bundled YDK/YTK GTK
targets. Their generated alias wrappers use ELF-style `__attribute__((alias))`,
which Apple Clang rejects. The source guards both the wrapper declarations and
the matching header aliases with this macro; the workaround is target-specific
and only enabled for Darwin. It is a local build patch, not an upstream Ardour
change. The script checks that the patch applies cleanly before modifying the
checkout.

## Translation

The Simplified Chinese translation lives in the private
[`brucekomike/ardour_zh_hans`](https://github.com/brucekomike/ardour_zh_hans)
repo. Apply its five `.po` files to an Ardour checkout before compiling:

```sh
scripts/apply-translation-overlay.sh /path/to/ardour /path/to/ardour_zh_hans
```

The CI workflow will need authenticated read access to that private repository.
Use a fine-grained GitHub token restricted to **Contents: read** on
`ardour_zh_hans`, stored in the public CI repo as the Actions secret
`ARDOUR_TRANSLATION_READ_TOKEN`. Do not put the token in source or logs.

Ardour expects UI and core-library translations in separate PO files; see
upstream `TRANSLATORS`. The build should run `waf i18n` so the `.mo` catalogs
are generated and included.

## Redistribution and licensing notes

Ardour's top-level `COPYING` identifies Ardour as **GNU GPL version 2 or later**.
The GPL permits redistribution of modified source and binaries, whether for no
charge or for a fee, provided the distributor follows the license. In
particular, a binary release should include the applicable license and notices,
identify modifications, and provide the complete corresponding source for the
exact binary—including the Ardour revision, translation changes, and build
scripts/configuration—under the applicable GPL terms. Keep source available to
recipients and do not add restrictions that conflict with the GPL.

This does not automatically license every item that might be bundled with an
Ardour build. Check the licenses and redistribution terms for dependencies,
plugins, artwork, fonts, and other bundled assets; omit anything you do not have
permission to redistribute. Ardour's name and logos are also separate from the
GPL: avoid implying that a custom build is an official Ardour release, and check
trademark requirements before using the name or artwork to market it.

The `--freebie` build option is a demo behavior (it adds periodic audio
silencing); it is not a GPL redistribution requirement. This summary is
informational, not legal advice. See the full upstream `COPYING` file and the
licenses of all shipped components before publishing an installer.

## Status

The translation overlay script is ready. Platform build workflows remain to be
added; each runner needs an appropriate Ardour dependency/build stack.
