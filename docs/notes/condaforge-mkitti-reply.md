# Draft — reply to @mkitti on staged-recipes#34550

Target: https://github.com/conda-forge/staged-recipes/pull/34550
Replying to: https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment-5406647171
("Option 2 is the one to pursue. You do not need to declare the dependencies as
sources and we can do network activity at build time.")

Status: **posted** 2026-08-29 as
https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment-5465259308
Everything below the rule is the comment body verbatim.

---

Thanks — that settles it, I'll go with option 2. Two things I'd like to ask before
going further though.

**osx-arm64.** conda-forge's `julia` is linux-64 and osx-64 only, and
julia-feedstock #283 has been open since July 2024. `create_app` bundles the Julia
runtime into the application, so on linux-64/osx-64 what option 2 gets you is a
bundle built around conda-forge's own from-source Julia. (That's the point, right?)
But on osx-arm64 there's no conda-forge-built runtime to bundle at all.

I don't want to ship this without an Apple Silicon version — a large share of
computational materials scientists use Macs as their local machine, and
Rosetta-only osx-64 doesn't reach them since it won't install into an osx-arm64
env. So: is #283 blocked on something specific, or just on nobody having done it?
I'm not sure I have the ken for that, but I could work on the julia feedstock if
that's the unblocking move. Or would you prefer `build.sh` downloading the official
Julia aarch64 tarball for the arm build only, with conda-forge's `julia` used
everywhere it exists? (That sounds better to me, but these issues are beyond my
experience, frankly.)

In the meantime I'll add osx-64 alongside linux-64, so the recipe is exercised on
every platform staged-recipes CI builds it for.

**`JULIA_CPU_TARGET`**, following up on your earlier question: is there a profile
conda-forge prefers for Julia applications? Left alone, `create_app` uses
`"generic"`, which disables vectorized codegen — a measurable loss for a package
that is essentially one hot combinatorial loop. I'd otherwise set Julia's own
multi-versioning string (`generic;sandybridge,-xsaveopt,clone_all;haswell,-rdrnd,base(1)`),
which still runs on any x86-64.

---
---

# Draft 2 — reply to mkitti's two links


Replying to:
- https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment (2026-08-30)
  "There is also https://prefix.dev/channels/julia-forge/packages/julia"
- https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment (2026-08-31)
  "See https://prefix.dev/blog/building_cpu_optimized_packages"

Status: **posted** 2026-08-31 as
https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment-5486912177
Everything below the rule is the comment body verbatim.

---

Thanks for pointing out both of these. Sorry I was unaware of them.

**CPU optimization.** Understood: level 1/3/4 variants gated on
`x86_64-microarch-level`, with build numbers so the solver picks the best one the
hardware supports. That's a cleaner answer than what I was attempting.

One wrinkle specific to Julia, and I genuinely don't know which way I should do it.
Julia has its own version of this: `JULIA_CPU_TARGET` compiles several
microarchitecture code paths into a single system image and dispatches at load
time, which is how the official Julia binaries ship. So the same optimization can
land either as N conda variants or as one fatter package. The tradeoff is size:
the system image is already what dominates this package (~150 MB compressed per
platform), so variants mean three of those in the channel, while multi-versioning
inflates one. (I can measure both and report the numbers if that's useful. Do you
have a preference, or should the measurement decide?)

**osx-arm64.** I'm stuck on this. It seems to rule out option 2 for that one
platform.

conda-forge builds osx-arm64 by cross-compiling on osx-64 runners, and
staged-recipes only builds x64 in any case. But `PackageCompiler.create_app` has to
*execute* target-architecture code — it precompiles a system image, and my build
script runs the resulting binaries as a test. A Julia system image can't be
cross-compiled. So "build the application in the recipe" and "ship Apple Silicon"
look mutually exclusive given the available CI, independent of which channel
provides an arm64 Julia. And I don't think julia-forge helps me here anyway (am I
wrong?), since a conda-forge recipe can only build against conda-forge.

I did notice that julia-forge gets arm64 precisely by repackaging the official
Julia tarball unmodified. That is the thing I can't do here. So it seems this must
be outside conda-forge unless there's a route I'm missing.

So, concretely: would a repackage scoped to **osx-arm64 only** be acceptable, with
linux-64 and osx-64 built from source in the recipe as you've asked? That's a much
narrower exception than what I originally asked for. It's a CI limitation rather
than me trying to avoid more work.

This is the open question I care most about, for the reason I mentioned earlier:
the local-workstation audience for this tool is heavily Mac, and Apple Silicon is
essentially all of that now. Losing it isn't a rounding error for me.

If the answer is no I'll live with it, but I want to be clear it's a real loss
rather than a shrug: I'd ship linux-64 and osx-64 here and send Apple Silicon users
to the GitHub release binaries, which are native arm64 and work today. To be
explicit about why osx-64 doesn't cover them — on Apple Silicon, conda and pixi
resolve osx-arm64 by default, so an osx-64 package is never a solver candidate
unless someone deliberately builds a Rosetta environment. In practice almost nobody
will, so osx-64 reaches Intel Macs and no one else.

None of this blocks me in the meantime: I'm proceeding with linux-64 + osx-64 via
option 2, so take whatever time you need on the arm64 question.

**One thing I found while converting the recipe**, in case it changes your advice:
conda-forge's `julia` strips Julia's vendored libraries in its build.sh
(`rm $PREFIX/lib/julia/{libcholmod,libcurl,libssh2,libgit2,libssl}.so`) so it links
against conda-forge's own openblas/gmp/mpfr/libgit2/curl. That means an application
built with it isn't self-contained the way my release tarballs are. There will be
runtime dependencies on those packages, which I assume is what you want, and means
dropping the `binary_relocation: false` I had. I'll let your CI tell me what it
actually links rather than guess further.

---
---

# Draft 3 — reporting the CI results of the from-source recipe


Context: commit 97d33e7a on the PR branch replaced the repackaging recipe with the
option-2 build-from-source one. conda-forge CI ran it and both platforms failed —
in conda-forge's `julia`, not in the recipe. Azure build 1577858.

Status: **posted** 2026-09-01 as
https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment-5497297331
Everything below the rule is the comment body verbatim.

---

I've pushed the option-2 recipe. It now builds the application in the recipe with
`PackageCompiler.create_app` against conda-forge's `julia`, instead of repackaging
a release tarball. Your CI ran it and both platforms failed, but neither failure is
in my recipe. Both are in the `julia` package.

**linux-64 never got past dependency resolution.**

```
Cannot solve the request because of: julia 1.12.* cannot be installed
  └─ julia 1.12.1 | ... | 1.12.7 would require
     └─ libunwind >=1.6.2,<1.7.0a0, for which no candidates were found
```

`julia 1.12.7` on linux-64 depends on `libunwind >=1.6.2,<1.7.0a0`, and the global
pinning is `libunwind: 1.8`. The ranges don't overlap, so nothing satisfies it —
conda-forge's `julia` 1.12 can't currently be used as a build dependency on
linux-64 at all. Is a libunwind migration on julia-feedstock the fix here, and is
there anything useful I can do towards it? I'd rather help than wait, though I
don't know that feedstock.

Dropping to `julia 1.10.4` isn't open to me: one of my dependencies (Spacey)
floors at Julia 1.11.6, and conda-forge has no 1.11 packaged — the versions go
1.10.4 straight to 1.12.x.

**osx-64 got much further** — it resolved (macOS uses `libosxunwind`, so it dodges
the above), rendered, and actually ran `create_app`, before failing during the
system-image build:

```
IOError: symlink("../libopenblas64_p-r0.3.30.dylib",
  "$PREFIX/libexec/enumlib.jl/lib/julia/libopenblas64_.dylib"): file already exists (EEXIST)
```

conda-forge's `julia` ships `libopenblas64_.dylib` as a symlink to the versioned
file. PackageCompiler appears to copy the resolved file into the app tree and then
try to recreate the link over the top of it. Is this a known interaction? If
there's an established way to run `create_app` against a conda-forge `julia`, I'd
rather adopt it than patch around it. If there isn't, I can take it upstream to
PackageCompiler with this as the reproducer — though packaging internals at this
level aren't really my wheelhouse, so tell me if I'd be filing it in the wrong
place.

This is not necessarily bad news for option 2. The recipe renders, the dependencies
are right, and on osx-64 it reached system-image compilation. As far as I can tell,
what stands between here and a working package is two fixes in the `julia` package,
rather than anything structural about building a Julia application in a recipe.

It does change the shape of the earlier osx-arm64 question, though. That platform
is blocked because `create_app` can't cross-compile a system image; linux-64 is now
blocked for a completely unrelated packaging reason. It might be better to get
linux-64 building first and treat arm64 as a different question.

---
---

# Draft 4 — answering mkitti's pinning question + the symlink diagnosis

Replying to three comments of his (2026-09-02):
- "I do not quite understand where the `libunwind: 1.8` pinning is coming from."
- julia-feedstock#309: osx-64 builds functional for 1.12.7
- julia-feedstock#310: linux-64 libunwind pin 1.6 -> 1.8, merged; and "the osx-64
  IOError: symlink ... looks like an unrelated issue — I haven't looked into that
  one yet."

Verified before drafting: both rebuilt julia packages are live
(linux-64 1.12.7 h192eb0c_0, libunwind >=1.8.3,<1.9.0a0, uploaded 2026-09-02
05:39Z; osx-64 1.12.7 hcc9ce34_0, 2026-09-01 23:49Z). Both packages were
downloaded and their lib/julia layouts inspected directly.

Status: **posted** 2026-09-05 as
https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment-5554517015
Everything below the rule is the comment body verbatim.

---

Thank you — that was fast, and both rebuilds are already live: linux-64
`1.12.7 h192eb0c_0` now declares `libunwind >=1.8.3,<1.9.0a0` (uploaded 05:39Z),
and osx-64 `1.12.7 hcc9ce34_0` landed last night.

**On where `libunwind: 1.8` comes from:** the global pinning, in
`conda-forge-pinning-feedstock/recipe/conda_build_config.yaml`, which currently
has

```yaml
libunwind:
  - '1.8'
```

so any new build is offered only 1.8.x, and `julia 1.12`'s `<1.7.0a0` bound had
no overlap with it. Your conda-forge/julia-feedstock#310 is exactly the fix; I mention the location
only because you asked.

**One thing I should flag before you spend more time: linux-64 is going to hit
the same symlink failure as osx-64.** I downloaded both of the new packages and
looked at the layout rather than guessing. `lib/julia` contains symlinks pointing
out to `$PREFIX/lib` — 16 of them on osx-64, 13 on linux-64:

```
libopenblas64_.dylib        -> ../libopenblas64_p-r0.3.34.dylib
libgmp.dylib                -> ../libgmp.10.dylib
libmpfr.dylib               -> ../libmpfr.6.dylib
libsuitesparseconfig.dylib  -> ../libsuitesparseconfig.7.10.1.dylib
...
```

which I take to be deliberate — the counterpart of the
`rm $PREFIX/lib/julia/{libcholmod,libcurl,libssh2,libgit2,libssl}.so` in your
`build.sh`, so Julia uses the conda packages instead of vendored copies. It's the
right design for conda; it just doesn't survive `create_app`. So the libunwind fix
unblocks *dependency resolution* on linux-64, but I expect the build itself to
fail the same way osx-64 did.

**The mechanism**, in `PackageCompiler._copy_julia_libraries`:

```julia
destpath = joinpath(app_libjulia_dir, basename(match))
isfile(destpath) && continue
cp(match, destpath)
```

Julia's `cp` defaults to `follow_symlinks=false`, so it recreates each link
verbatim rather than copying the file. Inside the app tree `../libopenblas64_...`
resolves to `app/lib/`, where PackageCompiler never copies those libraries, so the
link dangles. `isfile` follows symlinks and therefore returns `false` for a
dangling one, so the guard doesn't skip it, a later pass retries the same
destination, and `symlink()` throws EEXIST.

Two separate problems there. One is the `EEXIST` crash itself — the failure that
ended the osx-64 build in my last comment. The other is that even with the crash
fixed, the application would still ship 13–16 dangling symlinks and would not
start. It looks like a
known family upstream rather than anything new —
[JuliaLang/PackageCompiler.jl#821](https://github.com/JuliaLang/PackageCompiler.jl/issues/821)
("add an option to remove symlinks in bundled libraries and artifacts") is
essentially the feature that would fix it, and
[#469](https://github.com/JuliaLang/PackageCompiler.jl/issues/469) is the same
layout mismatch with Arch's packaged Julia.

**Which leaves a design question.** Which of these is better?

1. **Dereference the links at build time** so the application bundles its own
   copies. That works today — a short loop in `build.sh` before `create_app`, no
   upstream change needed. The cost is duplication of libraries conda-forge
   already ships separately. I measured it rather than guessing, by resolving
   every one of the 16 targets against the packages that provide them on osx-64:

   | library | size |
   | --- | --- |
   | `libopenblas64_p-r0.3.34.dylib` | 66.5 MB |
   | `libcholmod.5.3.1.dylib` | 2.6 MB |
   | the other 14 combined | 5.0 MB |
   | **total** | **74.1 MB** |

   So it is really one library: OpenBLAS is 90% of the duplication, and everything
   else together is 7.6 MB. If bundling 66 MB of OpenBLAS into an application
   package is the objectionable part — and I'd assume it is — that at least
   narrows what needs solving.

2. **Have the application link against the conda packages** in `$PREFIX/lib`, which
   is the conda-forge-shaped answer and why those libraries are already in my
   recipe's `host:` section. But PackageCompiler has no way to express that today,
   so it needs the upstream change in
   [PackageCompiler.jl#821](https://github.com/JuliaLang/PackageCompiler.jl/issues/821)
   or something like it.

What do you think? I'm happy to attempt either.
---
---

# Draft 5 — asking whether create_app is the wrong shape entirely

Replying to: https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment-5558260926
("Option 2 is preferable, but implement Option 1 if that is the only way things
will work for now. Note that conda has some tricks ... placing libraries in
placeholder paths and then mangling the binaries on install.")

CI evidence behind this draft (all on staged-recipes#34550):
- 97d33e7 re-run: libunwind resolved; failed on symlink EEXIST as predicted
- cf07044: symlink fix worked ("materialised 13 host symlink(s)"); failed cert.pem ENOENT
- 58f49fb: JULIA_SSL_CA_ROOTS_PATH attempt—wrong diagnosis, identical ENOENT
- 2407d6d: real bundle_cert fix worked; sysimage object step SIGSEGV'd 23 min in
- 85ed19f, 84ec659: two void cpu-target bisects (create_app ignores the env var;
  and the recipe builds the v0.3.9 tarball, so upstream build_app.jl fixes are not
  in the build). Revert before or alongside posting this.

Status: **posted** 2026-09-14 as
https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment-5673284964
Everything below the rule is the proposed comment body.

---

First, thank you. You have responded quickly to all my posts, rebuilt the julia package
twice, and fixed the libunwind pin upstream to unblock me. Sorry for how long
this is taking. Packaging is well outside my wheelhouse.

It matters to me to get this right rather than to get it merged. The Fortran
`enumlib` this replaces is not a personal project: it is the reference
implementation for derivative-structure enumeration in alloy theory, the papers
behind it are the standard citations in that literature, pymatgen ships an adaptor
that shells out to its executables, and conda-forge already packages it—which is
how I ended up here. Enumlib.jl is meant to be its successor, and getting it into
conda-forge is what would let the people currently depending on the Fortran move
across without noticing. So I would rather spend another few rounds arriving at
the right shape than land on something awkward.

**Two corrections I owe you first, both on the CPU-target question you raised.**

I told you that, left alone, `create_app` uses `"generic"` and disables vectorized
codegen. That was backwards. `create_app`'s `cpu_target` keyword defaults to
`PackageCompiler.default_app_cpu_target()`, which on x86_64 is already
`generic;sandybridge,-xsaveopt,clone_all;haswell,-rdrnd,base(1)`. It has been
multi-versioning all along, and this project's released binaries always were
vectorized. Relatedly, the `JULIA_CPU_TARGET` I was exporting in `build.sh` did
nothing whatsoever—`create_app` ignores the environment variable in favour of that
keyword.

**Where the build actually got to.** Each round moved further and then hit
something new:

1. Dependency resolution—libunwind, which you fixed in julia-feedstock#310.
2. `create_app` recreated conda-forge julia's `lib/julia/*` symlinks inside the
   application, where `../` resolves into the app tree, so they dangled and a
   retry threw `EEXIST`. Fixed in `build.sh`: materialise those links for the
   build, then repoint the application's copies at `$PREFIX/lib` with relative
   links and restore the host links. **That is option 2, and it works**—the log
   reads "materialised 13 host symlink(s)" and no library is duplicated. Relative
   links never leave `$PREFIX`, so none of the placeholder-path mangling you
   mentioned turned out to be needed.
3. `PackageCompiler.bundle_cert` (v2.4.1, PackageCompiler.jl:1802) does an
   unconditional `cp` of `$BINDIR/../share/julia/cert.pem`, which conda-forge's
   julia does not ship because conda supplies `ca-certificates`. Fixed by creating
   it from `$PREFIX/ssl/cacert.pem` for the build, removing it afterwards so the
   package claims nothing in julia's namespace, and linking the application's copy
   at conda's bundle rather than shipping a private certificate snapshot.
4. Now the sysimage object-file step segfaults, about 23 minutes in:

   ```
   ERROR: LoadError: failed process: Process(`$PREFIX/bin/julia --pkgimages=no
     '--cpu-target=generic;sandybridge,...,clone_all;haswell,...'
     --sysimage=/tmp/jl_WKJKd9/sys.so --output-o=/tmp/jl_...-o.a --threads=1 ...`,
     ProcessSignaled(11)) [0]
   ```

**What I think this means, with one distinction I had wrong.** Roadblocks 2 and 3
are the same conflict: `create_app` exists to copy a *stock* Julia into a
self-contained tree, and conda-forge's julia is deliberately de-vendored. I was
ready to conclude from that pattern that the whole bundled-application approach is
the wrong tree, and to propose `create_sysimage` instead—a sysimage in
`$PREFIX/lib`, thin wrappers exec'ing conda's `julia -J`, and `julia` as a real
run dependency, which makes 2 and 3 and the duplication question disappear by
construction instead of by patch.

But roadblock 4 is not more of that. And `create_app` is roughly
`create_sysimage` plus the bundling, so the codegen step that is crashing is
common to both—switching would not obviously fix it. What is not common is that
this recipe passes `incremental = false`, building a fresh base sysimage, which is
much heavier than incremental mode against the one conda's julia already ships.
Notably, this same application builds fine with the same multi-versioned target in
this project's own GitHub Actions release workflow, on larger runners; the
difference here looks like the builder rather than the flags.

**So, three questions—sorry to ask still more of you.**

1. Is a sysimage against conda-forge's `julia` the right shape for a Julia
   application in conda-forge, or is a bundled application still preferred and I
   should keep working on `create_app`?
2. Are staged-recipes' builders simply too small for a fresh-base sysimage build?
   Is `incremental = true` the normal answer, and is a SIGSEGV in codegen a
   familiar symptom of hitting that ceiling?
3. Is there a conda-forge convention for the CPU target—separate packages per
   `x86_64` microarch level, or one multi-versioned binary? Now that I understand
   which knob actually controls it, I can set it to whatever you would prefer.

One thing I can judge: if a sysimage is the way, the jll library paths get baked
in from the build depot, which will not exist at runtime. I would guess either
shipping the artifacts or an `Overrides.toml` pointing the jlls at conda's own
libraries, and the latter sounds more conda-shaped—but if there is a recipe
already doing this properly I would rather copy it than invent it.

Happy to do the work either way, and I will also refresh the recipe to v0.4.0,
which is the current release.

---
---

# Draft 6 — it builds; reporting what it took and asking the shape question again

Replying to:
- https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment-6011296535
  ("If you do incremental = true, does it work?")
- https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment-6011459470
  ("Try limiting the number of threads during compilation: JULIA_CPU_THREADS=1")

CI: 1b85920 is the first all-green run on this PR. Verified the test phase really
executed (enum.x/polya.x/makestr.x --version, enum.x struct_enum.in.fcc,
test -f struct_enum.out, polya.x, makestr.x) in a fresh environment resolved from
the declared run deps, not skipped.

Status: **draft—not posted**

---

It builds, and the tests pass—first green run on this PR. Thank you: your
`incremental = true` is what cracked it, though not in the way either of us
expected.

**It did not fix the segfault. It made the segfault legible.** With a fresh base
sysimage the crash arrived 23 minutes in, buried in codegen. Incremental against
conda julia's own sysimage got there in 45 seconds, and Julia then told us where:

```
[1118] signal 11 (1): Segmentation fault
in expression starting at $SRC_DIR/src/Enumlib.jl:475
Allocations: 53855876 (Pool: 53854865; Big: 1011); GC: 22
```

Line 475 is my own package's PrecompileTools `@setup_workload`—it runs a small
enumeration at precompile time so a cold call in a REPL does not pay ~19 s of JIT.
54M allocations and 22 GCs is nowhere near a ceiling, so **the builder-memory
theory I gave you was wrong**, and I am sorry for sending you after it. Disabling
the workload for this build, which costs a packaged application nothing because
`create_app` does its own precompilation, cleared the segfault outright:
`create_app` now finishes in about 15 minutes.

**Then two more things, both informative.**

The built binary would not start: `libutf8proc.so.3: cannot open shared object
file`. `create_app` copies `lib/julia` into the application and points its RPATHs
at its own tree, but conda-forge's julia also links libraries straight out of
`$PREFIX/lib`, and those are invisible to the app. Rather than meet them one CI
round at a time I had `build.sh` link them in a loop driven by the loader's own
complaint. **It resolved sixteen**: `libutf8proc`, `libunwind`, the whole
SuiteSparse chain (`amd`, `camd`, `ccolamd`, `colamd`, `cholmod`, `btf`, `klu`,
`ldl`, `rbio`, `spqr`, `umfpack`, `suitesparseconfig`), and `libblas` / `liblapack`.

And the test environment then failed, which was the genuinely useful part: it
installs only declared run dependencies and this recipe declared none, relying on
the host entries' `run_exports`. `openlibm` exports nothing, so nothing pulled it
in and the symlink dangled. Declared explicitly, and everything went green.

**So, the shape question, now with a number instead of a guess.** You asked
whether a bundled application or something lighter is right here. Sixteen
libraries is my answer to my own question: the application does not stand alone
against conda-forge's julia—it leans on `$PREFIX/lib` for a long tail, and the
recipe has to hand-link each one. It works, but it is a lot of machinery for what
it is. If you still think a sysimage against conda's `julia`, with `julia` as a run
dependency, is the better shape, I am willing to redo it that way now that I know
what the bundled route actually costs. I would rather do that once, deliberately,
than ship this and maintain it.

**Two things I would value your read on either way:**

1. Relocation prints `new value is longer than old value` six times on every
   build. It is not fatal and the tests pass, but it means something embedded
   could not be rewritten, and I do not know whether that bites at a different
   install prefix. Should this recipe set `binary_relocation: false` and lean on
   the relative symlinks, or does that error point at something I should fix?
2. `JULIA_CPU_THREADS=1` is still set from your suggestion. With the real cause
   found it may be unnecessary; I left it because it is harmless and I did not
   want to change two things at once.

**One caveat before you spend review time:** `build.sh` currently patches the
extracted source with `sed` in two places—to set `incremental = true` and to
disable the precompile workload—because v0.4.0 exposes neither as an option. That
is fine for finding the problem and not fine to ship. I will add proper options
upstream, cut v0.4.1, and repoint the recipe, so the version you review will not
contain them.

---
---

# Draft 7 — replaces Draft 6, which is now the wrong posture

Draft 6 offered to redo the recipe as a sysimage. Do not send it: mkitti has since
posted "Let's get this merged, please" (2026-10-07T02:26Z). Reopening the
architecture question would stall a merge he is advocating for. Offer dropped.

Assumes caf1513 comes back green (linux-64 already has). If osx-64 fails, restore
the 1b85920 configuration before sending anything.

Status: **posted** 2026-10-07 as
https://github.com/conda-forge/staged-recipes/pull/34550#issuecomment-6031051713

---

Thanks. Good timing, because the recipe changed about an hour ago.

Until then build.sh was patching the extracted source with sed twice, once to set
`incremental = true` and once to switch off this package's PrecompileTools
workload. Both were left over from chasing the segfault and neither should be in
a recipe you're asking someone to merge. They're gone now and it builds the
released v0.4.0 tarball as-is.

The workload is switched off with PrecompileTools' own preference
(`precompile_workloads` in a LocalPreferences.toml) instead of by rewriting
src/Enumlib.jl. It only existed to save about 19 s of JIT on a cold call in a
REPL, and an application gets its native code from create_app anyway, so nothing
is lost. `incremental` is back to the upstream default.

I also owe you a correction. The segfault wasn't the builder memory ceiling I
told you it probably was. It was my own precompile workload running under
conda-forge's julia. Your `incremental = true` is what found it: it didn't fix
anything, but it cut the failure from 23 minutes to 45 seconds, and at that point
Julia printed the expression it died in (src/Enumlib.jl:475) instead of dying deep
in codegen where I couldn't see it.

For what it's worth I chased that the rest of the way afterwards. Installed your
julia 1.12.7 from conda-forge locally, resolved Enumlib's deps in a fresh depot
and precompiled it, workload and all, on osx-64 which is one of the platforms
that was crashing. It loads fine. So it isn't the de-vendored julia or the
workload itself, just something about running it inside create_app's --output-o
step, and nobody installing the package can hit it.

One thing you'll see in the logs that I'd rather mention than have you find.

Relocation prints "new value is longer than old value" six times per build. The
libraries create_app copies out of your julia package carry rpaths from julia's
own build environment, and patchelf can't rewrite them into our longer prefix. It
isn't fatal and the tests pass, but I don't know if it matters at a different
install prefix. If it does I'd rather sort it before merge.
