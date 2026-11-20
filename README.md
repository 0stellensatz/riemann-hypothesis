# rh-lean-check

An independent [Comparator](https://github.com/leanprover/comparator) setup for the Lean
formalization claiming a proof of the Riemann Hypothesis and of GRH for Dirichlet L-functions,
announced on 2026-11-20 at <https://alpo.ge/remark.pdf> and distributed as
`https://alpo.ge/lean.tar.gz.part01` … `part14`.

The submission ships no challenge file that imports only Mathlib, and no Comparator config. This
repository mirrors the submission **unmodified** and adds both, so the claim can be checked
the standard way.

## Status

| Check | Result |
|---|---|
| Mirror is byte-identical to the published tarball (sha256 `9631b4f0…49c7fc`) | pass (CI, daily) |
| Static scan: no `axiom`, `sorry`, `native_decide`, `implemented_by`, `unsafe`, `opaque`, `debug.*`, or non-local notation | pass, see [`provenance/static-scan.txt`](provenance/static-scan.txt) |
| Challenge imports only Mathlib; its definitions are identical to the submission's `Statements.lean` | pass (CI) |
| Mathlib pin `0df444a3` is official | pass: it is Mathlib's `v4.33.1` tag, one commit on top of `v4.33.0` (on `master`) that changes only `lean-toolchain` (CI) |
| Challenge compiles against Mathlib alone | CI |
| **Full Comparator run** (compiles the solution in a sandbox, compares statements, checks axioms, replays in the kernel) | **pending**: see [`results/`](results/) |
| Independent kernel (nanoda) | not yet run |

## What the theorems say

`src/Main.lean` proves five theorems; [`src/Challenge.lean`](src/Challenge.lean) restates them.

- `riemannHypothesis : RiemannHypothesis` uses **Mathlib's own definition**: every zero of ζ
  other than the trivial zeros −2(n+1) has real part 1/2. The `s ≠ 1` clause only excludes
  Mathlib's junk value at the pole.
- `riemannZeta_eq_zero_re` states the same thing again, through the submission's `RiemannZetaZerosOnLine`.
- `LFunction_ne_zero_of_half_lt_re`: L(χ, s) ≠ 0 for Re s > 1/2, for every modulus N and every
  Dirichlet character χ (imprimitive included), except the trivial character at s = 1.
- `LFunction_eq_zero_re`: every zero of every L(χ, s) in the open strip 0 < Re s < 1 has Re s = 1/2.
- `LFunction_eq_zero_re_of_isPrimitive`: the primitive special case.

These are faithful statements of RH and of GRH for Dirichlet L-functions. The extra Euler
factors of an imprimitive character only vanish on Re s = 0, which the statements exclude. Every
`1 / 2` is real division. "GRH" here does not cover Dedekind zeta functions or other L-functions.

## Layout

| Path | Origin |
|---|---|
| `src/` (except `src/Challenge.lean`), `lean-toolchain`, `lake-manifest.json` | the submission, unmodified |
| `lakefile.toml` | the submission's bytes, plus one marked block at the end adding the `Challenge` library |
| `src/Challenge.lean`, `comparator/config.json` | added: the Comparator challenge and config |
| `provenance/` | sha256 of every original file, the original lakefile, the static scan |
| `scripts/` | the checks below |
| `results/` | full Comparator runs, one directory each |

The first commit is the submission exactly as published. Everything this repository adds is in later commits.

## Running the checks

Fast checks (these are what CI runs; none compiles the submission's code):

```bash
scripts/verify-mirror.sh          # tree == published tarball (offline manifest, then live download)
scripts/check-statements.sh       # challenge vs. Statements.lean / Main.lean / config
scripts/check-dependencies.sh     # every lake-manifest pin is official upstream
lake exe cache get && lake build Challenge
```

Full Comparator run (Linux, non-root, systemd user instance, Go, elan; hours on a large machine):

```bash
git clone https://github.com/Deicyde/rh-lean-check && cd rh-lean-check
scripts/run-comparator.sh
```

Start from a fresh clone: Comparator assumes the solution has never been compiled outside its
sandbox, and the script refuses a tree with other build outputs unless `PREBUILT_NOTE` says how
they were built (the run's summary then says it is not a fresh-clone run). It builds `landrun` (from `main`),
and `lean4export` and Comparator from their `v4.33.0` tags with the project's `v4.33.1` toolchain,
because Lean rejects `.olean` files written by a different Lean build. It fetches Mathlib's official
cache, then runs Comparator under `systemd-run --property=RestrictAddressFamilies=~AF_UNIX`, as the
Comparator README prescribes. If `nanoda_bin` is on `PATH`, it adds a second pass with the
independent nanoda kernel. Results go to `results/<UTC time>-<host>/`.

## Limits

- The project is on Lean `v4.33.1`. Comparator moved into Lean core as `lake comparator` /
  `lake check` only in `v4.35.0`, and the standalone repository is archived, so the newer in-core
  checks (including the stricter mode discussed on Zulip) are not available. This setup uses the
  last standalone tag for this Lean line.
- Comparator compares the challenge and solution against the same Mathlib, so it cannot detect a
  modified Mathlib. `scripts/check-dependencies.sh` covers that gap by tracing every pin to
  official upstream.
- What remains trusted after a passing run: the Lean kernel (or nanoda, too, with the nanoda
  pass), Mathlib's definitions, Mathlib's official build cache, and landrun's sandbox.

## License

The mirrored submission belongs to its author and was published without a license. It is
mirrored here unmodified, for verification only.
