# Install LeanBar

LeanBar requires macOS 13 or newer. The download is a universal app for Intel
and Apple Silicon. Python 3 is required for its short-lived command helper;
Homebrew installs that dependency automatically. You do not need Xcode or the
Command Line Tools to run the downloaded app with Homebrew Python.

## Homebrew (recommended)

With [Homebrew](https://brew.sh) installed:

```sh
brew install --cask pvrlabs/tap/leanbar
```

Start with the bundled example menu:

```sh
open /Applications/LeanBar.app --args /Applications/LeanBar.app/Contents/Resources/menu.sh
```

Or pass your own executable script using its absolute path:

```sh
open /Applications/LeanBar.app --args /absolute/path/to/menu.sh
```

An optional interval in seconds enables periodic refresh:

```sh
open /Applications/LeanBar.app --args /absolute/path/to/menu.sh 10
```

Quit an already-running LeanBar from its menu before launching with different
arguments. Opening the app without a script does not configure a menu. See the
[README](../README.md#script-format) for supported script output and login startup.

## Download with curl

Install Python first. `brew install python` supplies it without developer tools.
LeanBar checks `/opt/homebrew/bin/python3`, `/usr/local/bin/python3`, then
`/usr/bin/python3` (the last option requires Apple's developer tools).

Download v0.1.0, verify its checksum, and extract into your user Applications
folder. These commands run in a subshell so your current directory stays the same:

```sh
(
  set -eu
  download_dir=$(mktemp -d)
  cd "$download_dir"
  curl -fLO https://github.com/PVRLabs/leanbar/releases/download/v0.1.0/LeanBar-0.1.0-universal.zip
  curl -fLO https://github.com/PVRLabs/leanbar/releases/download/v0.1.0/LeanBar-0.1.0-universal.zip.sha256
  shasum -a 256 -c LeanBar-0.1.0-universal.zip.sha256
  mkdir -p "$HOME/Applications"
  ditto -x -k LeanBar-0.1.0-universal.zip "$HOME/Applications"
)
open "$HOME/Applications/LeanBar.app" --args "$HOME/Applications/LeanBar.app/Contents/Resources/menu.sh"
```

You can also download the ZIP and checksum from the
[GitHub release](https://github.com/PVRLabs/leanbar/releases/tag/v0.1.0).
Use one installation method to avoid duplicate copies.

## First launch and Gatekeeper

This release is ad-hoc signed. It has no verified publisher identity and is not
notarized by Apple. macOS may block the first launch of a downloaded copy.

After attempting to launch with the command above, open **System Settings →
Privacy & Security**, find the LeanBar message, and choose **Open Anyway**.
Confirm **Open** if prompted, then run the launch command again if needed.
The cask leaves macOS quarantine protections in place.

## Upgrade or uninstall

Quit LeanBar from its menu first.

```sh
brew upgrade --cask pvrlabs/tap/leanbar
brew uninstall --cask pvrlabs/tap/leanbar
```

For a manual installation, replace or remove `~/Applications/LeanBar.app` in
Finder. Your menu scripts remain yours. If you configured a login LaunchAgent,
remove it separately when uninstalling.
