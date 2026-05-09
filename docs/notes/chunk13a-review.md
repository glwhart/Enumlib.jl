# Chunk 13a — review and revise

Phase 13a (documentation infrastructure) landed as commit `9f3205d` on
`main`. This file is the standard chunk review-and-revise pad: you add inline
`#gh` comments to the new files and to this doc; I respond as numbered items;
we iterate to sign-off; I batch any code/doc changes as chunk 13a.1.

#gh instead of adding `#gh` to my changes, I just want you to check every file in the repo and see if diff reveals any changes. Look at those changes and if they look like they are mine, get back to me in the "design" or "review" chunk files. OK?

## Workflow

1. Read the files listed below (or open them in VS Code from the sidebar).
2. Edit any file directly — wording, restructuring, code, prose. No `#gh`
   markers needed.
3. Tell me you're done.
4. I run `git status` + `git diff` to find every change, distinguish review
   edits from unrelated in-flight work via judgment, and respond inline as
   numbered items in this doc.

(Process change locked in chunk 13a — see numbered response 1.)

## Files in scope

**New (Phase 13a infrastructure):**

- `docs/Project.toml` — Documenter + Enumlib + Spacey + MinkowskiReduction +
  LinearAlgebra deps. Spacey 0.8 now resolves from the General registry (your
  registration #155084 merged earlier today), so the docs env no longer needs
  the dev-path workaround.
- `docs/make.jl` — Diátaxis 4-quadrant page tree, `checkdocs = :none` for the
  placeholder phase, `deploydocs(...)` to `gh-pages` with `versions = ["stable" => "v^"]`.
- `docs/src/index.md` — minimal landing page; links to the four quadrants and
  shows a quick taste.
- `docs/src/{tutorials,how-to,reference,explanation}/index.md` — quadrant
  index pages, each linking to its subordinate stubs.
- `docs/src/tutorials/01-first-enumeration.md` — placeholder.
- `docs/src/tutorials/02-fixed-concentration.md` — placeholder.
- `docs/src/tutorials/03-dft-training-database.md` — placeholder; will be
  populated in Phase 13d by migrating `docs/notes/phase11-tutorial.md` here.
- `docs/src/how-to/*.md` (10 pages) — placeholders, populated in Phase 13c.
- `docs/src/reference/*.md` (7 pages) — placeholders, populated in Phase 13b
  via the docstring audit.
- `docs/src/explanation/*.md` (9 pages) — placeholders, populated in Phase
  13e.
- `.github/workflows/CI.yml` — Linux + macOS × Julia 1.10 LTS / 1.11 stable.
  codecov upload is `continue-on-error: true` so a missing token doesn't
  red-flag the run.
- `.github/workflows/Documentation.yml` — Julia 1.11 build, dev-links the
  current package, runs `julia --project=docs docs/make.jl`. The
  `DOCUMENTER_KEY` secret needs to be set in repo settings before
  gh-pages deploy fires; until then deploys are skipped with a warning.

**Modified:**

- `.gitignore` — adds `docs/build/`, `docs/site/`, and `.DS_Store`.

**Not committed (your separate in-flight work):**

- `docs/notes/v0.2-plan.md` — unrelated perf-baseline table; left alone for
  you to handle.
- `firstprompt.md` — local session file; let me know if you want it tracked
  or ignored.

## Transparency items I want to flag proactively

These are decisions I made during 13a that I want on the record so the review
focuses on real concerns instead of rediscovering them:

**A — Spacey-from-registry, not dev-link.** Earlier today the docs env
couldn't resolve because Spacey 0.8 wasn't yet on the General registry. I
worked around it locally by `Pkg.develop`-ing the sibling Spacey checkout and
told the Documentation.yml workflow to dev-link from the GitHub URL. After
your registration triggered and PR #155084 merged, I reset the docs Manifest
and confirmed Spacey 0.8 resolves from the registry. The committed
Documentation.yml is the clean version (no dev-link workaround). CI.yml needs
no special handling either — `julia-actions/julia-buildpkg` will resolve from
the registry.

**B — `checkdocs = :none` is intentional.** Documenter has three checkdoc
levels: `:exports` (default; warns on undocumented public API), `:all` (warns
on everything), `:none` (no checks). I set `:none` because every page is a
single-heading placeholder and the public API has docstrings of varying
quality. Phase 13b's docstring audit will raise this to `:exports`. I'd
rather defer the noise than fail the deploy pipeline on day 1.

**C — DOCUMENTER_KEY secret needed for gh-pages deploy.** The
Documentation.yml workflow refers to `secrets.DOCUMENTER_KEY`. That secret
doesn't exist in the repo yet — until you set it, the workflow will run, the
build will succeed, and the deploy step will skip with a warning. Standard
setup: `julia> using DocumenterTools; DocumenterTools.genkeys(user="glwhart",
repo="Enumlib.jl")` produces the public/private pair; the public goes in the
repo's Deploy Keys (write access), the private goes in the repo's Actions
Secrets as `DOCUMENTER_KEY`. Happy to walk you through it when you're ready
to flip on the live site.

**D — `repo = Remotes.GitHub("glwhart", "Enumlib.jl")` is the new-style
spelling.** Documenter 1.x deprecated the URL-template syntax in favour of
`Remotes.GitHub(...)`. I used the new form on day 1 so we don't accumulate a
deprecation warning to clean up later.

**E — `versions = ["stable" => "v^"]` in deploydocs.** Tracks the latest
released `v*` tag as `stable/`, with `dev/` always tracking `main`. There
will be no `stable/` until Enumlib has a real tag, but the field is harmless
until then.

**F — Documenter dev-doctest is on; it ran clean.** The make.jl smoke-test
ran the `Doctest:` step. Since no docstrings have `jldoctest` blocks yet, it
passed trivially. Once Phase 13b adds them, this will start catching API
drift in the docs.

**G — Quadrant page counts.**
- Tutorials: 3 pages + 1 index = 4.
- How-to: 10 pages + 1 index = 11.
- Reference: 7 pages + 1 index = 8.
- Explanation: 9 pages + 1 index = 10.
- Plus the home page: total 34 markdown files, all rendering.

This list mirrors `documentation_plan.md`; if you want any of those pages
split, merged, renamed, or removed, this is the moment — they're cheap to
restructure now and expensive once content lands.

**H — POSCAR archive workflow lives in tutorials/03 only.** The Phase 11
DFT/MLIP roundtrip narrative migrates to `tutorials/03-dft-training-database.md`
in Phase 13d. The how-to quadrant gets a thin "write-poscars-for-dft.md"
recipe page that links to the tutorial for the end-to-end story. I want to
flag this split now so we can debate it before content lands — alternative is
to lift the whole roundtrip into the how-to quadrant and keep tutorials
focused on the basics. Let me know your preference.

**I — `pages` order in make.jl.** I ordered Tutorials → How-to → Reference →
Explanation in the navigation bar (matching Diátaxis convention). Spacey's
docs do the same. If you'd rather lead with Reference (because that's what a
returning user wants first), trivial to flip.

## Items awaiting your review

(You'll fill this in via inline `#gh` comments. I'll then respond as numbered
items below.)

## Numbered responses

**1 — New review workflow: `git diff` instead of `#gh` markers (chunk13a-review.md line 8).**
Acknowledged and locked in. Going forward, the workflow on every chunk's
review/design pad is:

1. You edit files directly — any file in the working tree.
2. When you say "I'm done" / "see my comments" / "respond", I run `git status`
   + `git diff` to surface every uncommitted change.
3. I judge which diffs are review feedback for the active chunk and which are
   unrelated in-flight work (e.g., the perf baseline in `v0.2-plan.md` today —
   clearly your separate work, not chunk 13a feedback).
4. I respond inline as numbered items in the chunk's design or review file.
5. Iterate to sign-off; batch any code/doc fixes as chunk N.1.

I've updated the **Workflow** section above to reflect this and saved the
preference to my persistent memory so future review docs use the new pattern
out of the gate.

One small clarification I want on the record so we don't have to re-litigate
later: if there are uncommitted edits in files that look like they have
nothing to do with the active chunk (today's `v0.2-plan.md` perf table is the
canonical example), my default is to **not** treat them as review feedback
and to leave them uncommitted for you to handle separately. If you ever
*want* such an edit pulled into a chunk's commit, just tell me. I'd rather
default to leaving your work alone than swallow it into the wrong commit.

**2 — `# binary case, one site` wording on `docs/src/index.md` (line 46).**
Accepted as-is. My phrasing "binary on one site" was a slight grammatical
compression — readable to someone who's been doing CE for years, but yours is
plain English. I'll match this register in the rest of the docs as we
populate them: prefer "binary case, one site" / "ternary case, two sites" /
etc. over the compressed forms. No code change needed; the edit is already
in your working tree and I'll leave it there for the next commit (chunk
13a.1, or whatever bundles your sign-off changes).

**3 — Generalize from your edits, suggest similar fixes proactively.**
Acknowledged and saved as a persistent rule. The right move on every prose
edit you make is:

1. Articulate the abstract style preference in one sentence.
2. Scan the files I authored in the active chunk for places where the same
   anti-pattern shows up.
3. Propose those similar fixes in this numbered response, with file:line and
   before/after.
4. Generalize the rule to my own writing going forward, not just chase the
   next instance.

Applying it to today's edit:

- **Abstract rule.** In code-block comments, prefer two noun phrases separated
  by a comma (or a full plain-English noun phrase) over compressed
  prepositional shorthand where the noun is doing double duty as adjective.
  Concrete > clever; punctuation is cheap.
- **Scan.** I grep'd every code-block comment across the 34 chunk-13a doc
  pages I authored. Three total comments: `# while unregistered`,
  `# FCC primitive`, and `# binary case, one site` (your fix). The first two
  are clean noun phrases; the third was the only lapse.
- **Conclusion.** This was a one-off edit, not a systemic pattern, in the
  chunk-13a footprint. The rule still applies forward — when Phase 13c-13e
  start populating the placeholder pages with code blocks, I'll write
  comments under this register from the start.

(Awaiting any further comments.)

## Summary

Signed off 2026-05-09. Two review-pass diffs landed:

1. **Process change** — chunk reviews use direct file edits + my `git diff`
   sweep, not `#gh` markers. Workflow section above updated; saved as
   persistent feedback so future chunk-review docs lead with the new pattern.
   Companion rule: on every prose edit, generalize the abstract style
   preference and proactively scan for similar lapses (saved as a separate
   feedback memory).
2. **Wording tweak** — `docs/src/index.md:46` comment changed to `# binary
   case, one site`. Bundled into the chunk 13a.1 sign-off commit. Audit of
   all other code-block comments in the chunk-13a footprint came up clean
   (one-off lapse, not systemic).

The `docs/notes/v0.2-plan.md` perf-baseline diff in your working tree was
correctly identified as separate in-flight work and left untouched.

**State at sign-off.**
- Phase 13a infrastructure (commit `9f3205d`) is on `origin/main`.
- Chunk 13a.1 (this review doc + the index.md tweak) lands as the next commit.
- Phase 13b (docstring audit + reference quadrant) is the next chunk;
  proposal due before implementation per the standard chunk pattern.

**Followups carried into 13b or later, not blocking sign-off.**
- DOCUMENTER_KEY secret needs to be set in repo Actions Secrets before the
  Documentation.yml workflow can deploy to gh-pages. Run
  `DocumenterTools.genkeys(user="glwhart", repo="Enumlib.jl")` when ready
  (transparency item C above).
- `checkdocs` raises from `:none` to `:exports` as part of Phase 13b
  (transparency item B above).
