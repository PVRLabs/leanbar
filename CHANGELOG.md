# Changelog

## Unreleased

- Renamed the screenshot example to `examples/menu-demo.sh` for future release
  screenshots; `examples/menu.sh` remains the live example shipped with the app.

## 0.1.0 — 2026-10-20

First public release.

- Native macOS menu-bar host with a small, flat subset of SwiftBar script output:
  labels, separators, colors, sizes, and executable actions with literal arguments.
- Cached menus refresh on opening and after actions; periodic refresh is optional.
- Commands run one at a time with a five-second timeout, 256 KiB output limit,
  bounded action queue, duplicate suppression, and child-process cleanup.
- Menu actions retain their original arguments while the menu is open;
  failures disable stale actions and a successful refresh restores the menu.
- Bundled example desk menu with time, battery, disk space, and simple actions.
- Universal Intel and Apple Silicon app targeting macOS 13 or newer, with the
  MIT license included. Ad-hoc signed; not notarized.
- Homebrew cask in `pvrlabs/tap`, with Python 3 declared as a dependency.
  The app locates Homebrew Python without relying on a shell's PATH.
