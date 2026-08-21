# Decision: do not code-sign / notarize the macOS binaries (for now)

**Date:** 2026-08-21
**Status:** decided, revisit if user friction appears

## Context

Shyue Ping Ong, testing the v0.3.4 macOS tarball during the pymatgen integration
([pymatgen-core#123](https://github.com/materialsproject/pymatgen-core/pull/123)),
found the app would not start: Gatekeeper had quarantined the bundled `.dylib` and
`.framework` files. He recommended code-signing them, and the reply on that thread
agreed it was "the right fix" and promised to look into it. This note records what
looking into it concluded.

## What signing would require

- Apple Developer Program membership (~$99/year) and a Developer ID Application
  certificate.
- `codesign` over every Mach-O in the bundle with the hardened runtime, then
  `notarytool` submission per release. Stapling is not possible for loose files in
  a tarball (it needs an app bundle, dmg or pkg), so Gatekeeper would verify
  online.
- Certificate `.p12`, its password, and notary credentials as CI secrets, plus
  annual certificate renewal.
- Ad-hoc signing (`codesign -s -`) is **not** a cheaper substitute: it does nothing
  for Gatekeeper.

## Why we are not doing it

1. **Quarantine only comes from browser downloads.** `curl` and `wget` do not set
   `com.apple.quarantine`; verified directly against the published v0.3.4 tarball.
   The README's documented install path uses `curl`, so it is unaffected.
2. **conda users are unaffected.** Conda fetches through its own tooling, so once a
   conda package exists, macOS users get these binaries with no Gatekeeper
   involvement — and that is the channel the pymatgen audience will use.
3. **The failure could not be reproduced locally**, even after force-applying
   `com.apple.quarantine` to the whole extracted tree. It requires a stricter
   Gatekeeper policy than the machine tested on; the exact error was requested on
   the PR thread and never supplied.
4. **The residual exposure is small and documented**: macOS users who download via
   a browser, for whom the fix is one command,
   `xattr -dr com.apple.quarantine <dir>`, stated in the README.

The trade is ~$99/year plus per-release notarization machinery and annual
certificate maintenance, to remove one documented command for a shrinking minority.

## Revisit if

- Real user reports accumulate (not a single reproduction on one machine).
- We start shipping a `.app`, `.dmg` or `.pkg`, where stapling works and
  expectations are higher.
- conda-forge distribution does not materialize, leaving the browser download as a
  primary path.

## Loose end

The pymatgen thread carries a promise to "look into getting that set up." That has
now been done and the answer is no — which should be said on the thread rather than
left to lapse. Natural moment is whenever the conda package lands.
