# LeanBar contributor guidance

## Product focus

LeanBar is a small, low-resource host for script-driven status menus and actions.
It is intended as a simple replacement for SwiftBar and similar menu/taskbar
utilities when a user's scripts fit the supported format. Read `README.md` for
the current contract and `docs/releasing.md` before release work.

Keep scripts responsible for status collection, service management, scheduling,
and application-specific behavior. Keep the host responsible for displaying a
menu and safely invoking those scripts. Favor a small implementation that is
easy to understand and maintain.

## Resource use and simplicity

- Minimize retained memory, idle CPU, wakeups, and background processes.
- Prefer refresh on opening and after actions. Keep periodic polling opt-in;
  do not introduce continuous timers or watchers without a concrete need.
- Use native platform facilities and existing code before adding dependencies,
  frameworks, configuration, or infrastructure.
- Preserve bounded command duration, output, concurrency, and action queues.
  Clean up command descendants and keep work off the UI thread.
- Avoid settings surfaces, plugin marketplaces, automatic updaters, rich visual
  effects, or full SwiftBar compatibility unless explicitly requested.
- Make the smallest change that solves a real menu need. Do not add speculative
  extension points, generic frameworks, or compatibility layers.
- For changes that can affect resource use, compare representative idle and
  menu-interaction behavior. Include transient helpers in the assessment; do not
  trade lower host memory for persistent external processes. Report the setup
  and limits of measurements instead of claiming universal resource budgets.

## Platform direction

macOS is the implemented platform. Cross-platform support is an intended future
direction, including Linux and potentially other desktop menu/taskbar hosts.
Do not describe unimplemented platforms as supported.

Keep the script/output contract understandable independently of AppKit. When
practical, keep parsing and invocation behavior distinct from native menu code.
Prefer native UI and small platform-specific adapters when another platform is
actually implemented. Do not introduce a cross-platform framework or abstract
the current implementation solely for a hypothetical future port.

Document supported behavior precisely. Compatibility should follow useful
script semantics, not every feature of an existing host. Platform-specific
requirements belong in platform-specific documentation and implementation.

## Verification and releases

- Run `./build.sh` and `python3 tests/check.py` for relevant implementation
  changes. Run the documented GUI smoke and refresh-race checks when changing
  menu interaction, command execution, or refresh behavior.
- Use harmless fixtures. Do not invoke real service-management actions as tests.
- For releases, follow `docs/releasing.md`, build with `./build.sh --universal`,
  and verify the bundle version, both architecture slices, signature, and archive
  checksum. Wait for Intel and Apple Silicon CI to pass before publishing.
- Keep `CHANGELOG.md` and installation instructions current. State signing,
  notarization, runtime dependencies, and tested-platform limits accurately.
- Publish binaries through GitHub Releases and the cask through the shared
  `PVRLabs/homebrew-tap`. Keep private scripts and login jobs out of the cask.
