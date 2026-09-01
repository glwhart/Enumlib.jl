# Releasing Enumlib.jl

**Register first, tag second.** TagBot creates the tag once the registry merges,
and the binary build follows from that tag push.

This order matters, and it is the opposite of what this project did through v0.3.9.
You cannot know in advance that the commit you submit will pass registration — it
may need amending — so a tag created beforehand can end up pointing at a commit
that was never registered. (Raised by @goerz on
[General#166515](https://github.com/JuliaRegistries/General/pull/166515); the
v0.3.0–v0.3.9 tags predate the fix and were harmless only by luck.)

## Steps

1. **Bump and land the version.**
   - `Project.toml`: set `version`.
   - `CHANGELOG.md`: add the entry.
   - Commit and push to `main`. **Do not tag.**

   Keep the commit message free of the CI-skip marker in any form — GitHub matches
   it anywhere in the message, including inside prose that merely mentions it, and
   the tag will share this commit. This silently suppressed the v0.3.7 release
   build once already.

2. **Register.** Comment on the commit:

   ```
   @JuliaRegistrator register
   ```

   Optionally follow it with a `Release notes:` block — TagBot copies that into the
   GitHub Release it creates.

3. **Wait for the General registry PR to merge.** AutoMerge handles it if the
   guidelines pass; new *versions* merge quickly, a new *package* waits 3 days.
   Do not comment on that PR — any comment without the literal text `[noblock]`
   blocks auto-merging.

4. **TagBot takes it from there**, on its schedule after the merge. It creates the
   `vX.Y.Z` tag and the GitHub Release. Because it pushes using the SSH deploy key
   in `DOCUMENTER_KEY`, that tag push *does* trigger workflows — so `release.yml`
   builds the three-platform binaries and attaches them, and `Documentation.yml`
   builds the docs for the tag.

   This is the load-bearing detail: GitHub does not fire `on: push` workflows for
   refs pushed with the default `GITHUB_TOKEN`. Without the deploy key, TagBot's
   tag would produce a Release with **no binaries attached** — one that looks
   complete and is useless to anyone downloading `enum.x`.

5. **Verify the release.** It should carry six assets — three `.tar.gz` and three
   `.sha256`, for `linux-x86_64`, `macos-aarch64` and `windows-x86_64`:

   ```bash
   gh release view vX.Y.Z --repo glwhart/Enumlib.jl --json assets \
     --jq '.assets[] | "\(.name) \(.size)"'
   ```

## If something goes wrong

- **Binaries missing from the Release.** The tag push did not trigger
  `release.yml`. Re-run it by hand against the tag:
  `gh workflow run release.yml --ref vX.Y.Z`. Then check that `DOCUMENTER_KEY` is
  still a valid write-enabled deploy key, since that is the usual cause.
- **Registration rejected.** Fix what AutoMerge flagged, push the fix to `main`,
  and re-comment `@JuliaRegistrator register` — the registry PR updates in place.
  Because nothing was tagged yet, there is nothing to undo.
- **Testing a build without releasing.** `release.yml` has a `workflow_dispatch`
  trigger that builds and uploads workflow artifacts only, publishing nothing.

## Credentials this depends on

| secret | used by | notes |
| --- | --- | --- |
| `DOCUMENTER_KEY` | TagBot, Documentation | base64-encoded private half of a **write-enabled** ed25519 deploy key. Rotating it means replacing both the deploy key and the secret. |
| `CODECOV_TOKEN` | CI | coverage upload only |
