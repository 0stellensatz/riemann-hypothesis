# riemann-hypothesis

[![checks](https://github.com/leanprover-community/riemann-hypothesis/actions/workflows/checks.yml/badge.svg)](https://github.com/leanprover-community/riemann-hypothesis/actions/workflows/checks.yml)

Build cache for a Lean formalization the proof of the Riemann Hypothesis, and of GRH for Dirichlet L-functions. The first commit is as posted by Levent Alpöge, retrieved on 2026-11-20 at <https://alpo.ge/remark.pdf>.

It has been changed since. Pull requests have deleted files the proof doesn't use, shortened proofs, and
ported it from Lean 4.33.1, which it was written for, to newer releases. The five theorems in
`src/Main.lean` still have the names and types they were published with, and the definitions
those types use, in `src/Statements.lean`, are unchanged. Their proofs are not the published
ones. `git diff --stat 40e56bab HEAD -- src` lists everything that has changed. If you want the
untouched original, check out `40e56bab` or use
[riemann-hypothesis-original](https://github.com/homeowmorphism/riemann-hypothesis-original).

## What is claimed

`src/Main.lean` proves five theorems:

| Theorem | Statement |
|---|---|
| `riemannHypothesis` | Mathlib's `RiemannHypothesis` |
| `riemannZeta_eq_zero_re` | the same, written out |
| `LFunction_ne_zero_of_half_lt_re` | L(χ, s) ≠ 0 for Re s > 1/2, for every modulus and every Dirichlet character, except the trivial character at s = 1 |
| `LFunction_eq_zero_re` | every zero of L(χ, s) with 0 < Re s < 1 has Re s = 1/2 |
| `LFunction_eq_zero_re_of_isPrimitive` | the same, for primitive characters |

[`src/Challenge.lean`](src/Challenge.lean) states the same five with `sorry` in place of the
proofs, in a file that imports only Mathlib. Comparator checks that `Main.lean` proves exactly
those statements, that it uses no axioms other than `propext`, `Quot.sound` and
`Classical.choice`, and that Lean's kernel and nanoda both accept the proof.

## Getting a build

Compiling the project takes hours on a large machine, so there is a cache of compiled files:

```bash
lake exe cache get
lake build --no-build
```

The first command needs Python 3.11 or newer. It downloads Mathlib's cache and then ours. Ours
has to match your checkout exactly. It looks for a successful CI build of the same source
(commits that only change documentation share one) and, failing that, for the baseline build
pinned in [`scripts/cache-baselines.json`](scripts/cache-baselines.json). If nothing matches,
it says so and you are left with `lake build`. The second command confirms that there is
nothing left to compile.

Don't treat the cache as a check of the proof. It contains files built from unreviewed pull
requests on volunteers' machines, and all the download verifies is that you received what was
uploaded. To check the proof, run Comparator as described below.
[CACHE.md](verification/CACHE.md) explains how the cache is made.

## Checking the proof

```bash
lake exe cache get
lake comparator
```

In this repository `lake exe cache get` downloads our compiled copy of the proof along with
Mathlib's cache. `lake comparator` then checks the proof against `Challenge.lean`, as described
under [What is claimed](#what-is-claimed). It needs Linux with
[bubblewrap](https://github.com/containers/bubblewrap), a lot of memory and several hours. To
have the proof compiled from source as well, start with `lake exe mathlib/cache get`, which
fetches only Mathlib.

We don't have a complete run on the current source yet. [NOTES.md](verification/NOTES.md) has
the long version, written for the published source on Lean 4.33.1.

## CI

Every push and pull request gets a quick check that `Challenge.lean` compiles against Mathlib
alone. A full build is too big for GitHub's runners, so pull requests are built on machines
lent by volunteers, and successful builds go into the cache. If you have a Linux machine with
plenty of memory and disk to spare, [CI-RUNNERS.md](verification/CI-RUNNERS.md) explains how to
lend it. The scripts behind all this are in [`scripts/`](scripts/) and
[`tools/ci_native/`](tools/ci_native/README.md).

## License

The submission belongs to its author and was published without a license. It is mirrored here
so that it can be checked. Commit `40e56bab` is the unmodified copy.
