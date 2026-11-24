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
its dependency stack; Homebrew alone is not a supported full build environment.

## Translation

The translation overlay is not wired in yet. Its source repo/path and locale
need to be supplied, then the relevant `.po` files can be copied into the
matching paths in Ardour's source tree before the build. Ardour expects UI and
core-library translations in separate PO files; see upstream `TRANSLATORS`.
The build should run `waf i18n` so the `.mo` catalogs are generated and included.

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

Initial project setup. CI workflows and the translation overlay will be added
once the translation source is identified and the build/dependency strategy is
selected for each runner.
