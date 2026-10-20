# Releasing LeanBar

Keep releases manual and small. This is a personal utility shared as-is, with
occasional fixes rather than an active roadmap. Summarize changes directly in
the GitHub release description. No separate changelog or announcement process.

## Before the first public binary

Local source builds and CI work now. Binary distribution and Homebrew packaging
are still pending. Resolve these once before shipping:

- Choose a minimum macOS version and build/test Intel and Apple Silicon artifacts
  (or a single universal app). The current build targets the build machine.
- Resolve the helper's `/usr/bin/python3` dependency. It currently assumes Apple
  developer tools; either use a declared Homebrew Python dependency with matching
  runtime lookup, or implement the bounded runner natively. Do not claim the
  current app runs on a clean Mac without developer tools.
- Choose and verify signing/notarization for downloaded app bundles. The current
  local build is ad-hoc signed.

## Small release checklist

1. Review the changes and prepare a short user-facing summary. Set the exact
   version in `build.sh`'s bundle metadata. Get review/commit approval, commit,
   and push. Wait for the main CI build and noninteractive tests to pass.
2. Run the local GUI checks from README on the intended release app source.
   Build the supported architecture artifacts and verify the version and app
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

The release tag stays on the exact released source. Keep GitHub Releases as the
binary source and the tap as a small distribution index. No cross-repository
credentials, release orchestrator, or automatic updater.
