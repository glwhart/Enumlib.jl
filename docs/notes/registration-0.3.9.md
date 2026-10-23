# General registry re-registration (v0.3.9) — DONE, no action needed

Registration PR: https://github.com/JuliaRegistries/General/pull/166515
Triggered by `@JuliaRegistrator register` on commit e51ebf0 (2026-08-29).

**AutoMerge passed all guidelines.** Scheduled to merge automatically after the
mandatory 3-day waiting period for new packages, i.e. on or after 2026-09-01.

## ⚠️ Do not comment on that PR

Any comment lacking the literal text `[noblock]` blocks auto-merging and forces a
human to intervene. There is nothing to say there; leave it alone.

## Why the first attempt failed

[General#154300](https://github.com/JuliaRegistries/General/pull/154300)
("New package: Enumlib v0.1.0", 2026-04-29) failed AutoMerge on exactly one
guideline — `MinkowskiReduction` had no upper-bounded `[compat]` entry — was never
followed up, and the bot auto-closed it as stale on 2026-06-09. That single missing
line is why the package went unregistered for four months. Fixed in v0.3.9:
`MinkowskiReduction = "1"`, which is what actually resolves (1.5.0), since Spacey
0.9 constrains it to `1.2.0 - 1`.

## A prediction that was wrong, recorded so it isn't repeated

Before triggering, I expected AutoMerge to reject 0.3.9 for not being a "standard
initial version number" (`0.0.1`, `0.1.0`, `1.0.0`, or `X.0.0`) and planned to
request a manual merge. That guideline does still exist in RegistryCI's
`AutoMerge/src/guidelines.jl` as `guideline_standard_initial_version_number`, but
it is **dead code** — it is not in the `NewPackage` list that
`get_automerge_guidelines` actually runs. Registering a package at an arbitrary
0.x version is fine and auto-merges.

## Loose end, unrelated to registration

`src/LatticeEnumeration2D.jl` still exports non-snake_case names (`genHNFs`,
`plotSuperTile`, `convertGtoOrd`, `convertCarttoG`, `getinequivHNFs`). It is not
included by `src/Enumlib.jl` — reachable only from `test/runtests2D.jl` — so it is
dead code shipped in the package rather than public API. Worth removing or
folding in.
