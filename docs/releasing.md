# Releasing LeanBar

Keep releases manual and small. This is a personal utility shared as-is, with
occasional fixes rather than an active roadmap. Keep `CHANGELOG.md` current and
summarize the release in its GitHub description. No announcement process.

## Distribution choices

- `./build.sh --universal` builds Intel and Apple Silicon slices targeting macOS
  13. CI builds and runs noninteractive checks on both architectures; local GUI
  checks currently run on Intel macOS 15.
- The cask declares a Homebrew `python` dependency. The host looks for
  `/opt/homebrew/bin/python3`, then `/usr/local/bin/python3`, then Apple's
  `/usr/bin/python3` for source builds. Python runs in isolated mode. Manual
  downloads also require Python at one of those paths.
- Releases are ad-hoc signed, without Developer ID signing or notarization.
  Document Gatekeeper approval under System Settings → Privacy & Security;
  do not bypass quarantine in the cask.
- Include the MIT license and example menu inside the app's resources.

## Small release checklist

1. Review the changes, update `CHANGELOG.md`, and prepare a short user-facing summary. Set the exact
   version in `build.sh`'s bundle metadata. Get review/commit approval, commit,
   and push. Wait for the main CI build and noninteractive tests to pass.
2. Run the local GUI checks from README on the intended release app source.
   Run `./build.sh --universal` and verify the version, both slices, and app
   signature. Package each app as a ZIP and produce a SHA-256 checksum naming
   the archive, not a machine-specific path. Include the MIT license.
3. Tag the verified release commit `vX.Y.Z`. Create the GitHub Release with the
   change summary in its description; attach the ZIP(s) and checksum(s). No
   automated release workflow or announcement is needed initially.
4. Add/update `Casks/leanbar.rb` in `PVRLabs/homebrew-tap`, with the published
   version, archive URL(s), checksum(s), and `app "LeanBar.app"`. Review and
   commit that narrow change separately. Do not make the cask install private
   menu scripts, launch jobs, or configure a user's menu.
5. Verify a fresh cask install, a configured menu, and uninstall. The intended
   command is `brew install --cask pvrlabs/tap/leanbar`; document it in README
   only after the cask is published and verified.
6. After publishing, advance `build.sh`'s bundle version to the next version
   with a `-dev` suffix, and start the matching `CHANGELOG.md` section. For
   example, after releasing `0.1.1`, set the development version to
   `0.1.2-dev`. Keep this follow-up change off the tagged release commit.

The release tag stays on the exact released source. Keep GitHub Releases as the
binary source and the tap as a small distribution index. No cross-repository
credentials, release orchestrator, or automatic updater.
