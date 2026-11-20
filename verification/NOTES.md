# Verification notes

Everything in this folder was written by the people checking the submission, not by its author.
Comparator's output will be added here when the run finishes.

## Source

| Item | Value |
|---|---|
| Announcement | <https://alpo.ge/remark.pdf>, sha256 `3fc97784b71ddd44ff8aa0a177e99622a1c61b13cfa843a0989ee4a7a0cfeb8d` |
| Archive | `https://alpo.ge/lean.tar.gz.part01` … `part14`, downloaded 2026-11-20 |
| Joined archive | `cat lean.tar.gz.part{01..14} > lean.tar.gz`: 239,275,554 bytes, sha256 `9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc` |

The first commit of this repository, `40e56bab`, is the archive's `lean/` directory exactly as
published. Later commits add only `src/Challenge.lean`, `comparator.json`, a marked block at the
end of `lakefile.toml` that registers the `Challenge` library, the README, this folder and the CI
workflow. `git diff 40e56bab HEAD --stat` shows this, and CI downloads the archive again and
compares it with the tree.

The server answers HTTP 200 with an HTML page for any path, so a `part15` URL appears to exist.
Check the joined sha256, not the status codes.

## Size

175,187 `.lean` files and 1,030,531,854 bytes of source: 17,374,215 lines, of which 15,531,759
are non-blank. There are no comments. The source has 818,755 `theorem`/`lemma` declarations and
242,067 `def`/`abbrev`/`structure`/`class`/`instance`/`inductive` declarations. Every file is in
the import closure of `Main`.

| Library | Files | Lines |
|---|---:|---:|
| Development | 141,928 | 12,232,663 |
| Formalism | 18,254 | 3,200,748 |
| GroundTheory | 8,507 | 1,119,138 |
| ReciprocityTheory | 3,845 | 563,016 |
| CompanionTheory | 2,027 | 194,218 |
| PositivityTheory | 449 | 55,130 |
| Lemmata | 167 | 9,232 |
| Supplements, BuildAid, `Main.lean`, `Statements.lean` | 10 | 70 |

## Static scan

[`static-scan.txt`](static-scan.txt) is a text search over every file. It finds no `axiom`,
`sorry`, `admit`, `native_decide`, `implemented_by`, `extern`, `unsafe`, `opaque`, `debug.*`
option or `skipKernelTC`. All notation is `local` or `scoped`. The two uses of metaprogramming:

- `BuildAid/D1.lean` … `D5.lean` each add one name to Lean's deny list for library suggestions.
- `Formalism/HermitianCurvature/HermitianCurvatureProofs/CutCptCopy.lean` copies declarations
  under new names with `addDecl`, so the kernel checks every copy.

A text search is not a proof. The axiom check and kernel replay in Comparator are.

## Statements

`Main.lean` proves `riemannHypothesis` as `Formalism.VW.rh_of_every allChi`, where `allChi` says
that no Dirichlet L-function vanishes for Re s > 1/2. The step from that to RH and to the
critical-line statements (`Formalism/GammaFactorNonvanishing/CritLine.lean`) is the standard
functional-equation argument, using Mathlib's lemmas.

The statements were read by hand:

- Mathlib's `RiemannHypothesis` excludes the trivial zeros −2(n+1) and the point s = 1, where
  Mathlib's `riemannZeta` has a junk value.
- The Dirichlet statements quantify over every modulus and every character, imprimitive ones
  included. The extra Euler factors of an imprimitive character vanish only on Re s = 0, which
  the hypotheses exclude.
- Every `1 / 2` is compared with `s.re`, so it is real division.
- Dedekind zeta functions and other L-functions are not covered.

## Dependencies

Each pin in `lake-manifest.json` was compared with its repository on GitHub.

| Package | Pin | Result |
|---|---|---|
| mathlib | `0df444a360ea` | tag `v4.33.1`: one commit on top of `db584cd6d46c` (tag `v4.33.0`, on `master`) that changes only `lean-toolchain` |
| plausible | `b7eb3304aeae` | on `main` |
| LeanSearchClient | `5f4d51b81cbd` | on `main` |
| importGraph | `16f02aa76428` | on `main` |
| proofwidgets | `4be2e3d5087e` | on `main` |
| aesop | `3448c0bcc5ce` | on `master` |
| Qq | `92c15be17b7c` | on `master` |
| batteries | `4488d40d070b` | on `main` |
| Cli | `6130a47896ce` | on `main` |

To repeat the Mathlib check: `git diff --stat db584cd6d46c 0df444a360ea` in a Mathlib clone shows
only `lean-toolchain`, and `git merge-base --is-ancestor db584cd6d46c origin/master` succeeds.

## Tools

| Tool | Revision | Built with |
|---|---|---|
| [comparator](https://github.com/leanprover/comparator) | tag `v4.33.0` (`3927ad38`) | Lean `v4.33.1` |
| [lean4export](https://github.com/leanprover/lean4export) | tag `v4.33.0` (`15f6055e`), the revision Comparator pins | Lean `v4.33.1` |
| [landrun](https://github.com/Zouuup/landrun) | `main` (`ec104f6e`) | Go |
| [nanoda_lib](https://github.com/ammkrn/nanoda_lib) | `0da9f98f` | Rust, `cargo build --release` |

Comparator and lean4export carry a `v4.33.0` toolchain file. They are built with `v4.33.1`
because Lean refuses `.olean` files written by a different Lean build, and lean4export has to
read the project's.

## Sandbox

Comparator's README runs it under `systemd-run --property=RestrictAddressFamilies=~AF_UNIX` and
relies on landrun for the rest. On our machine (Linux 6.12) that left two gaps:

- **Network.** landrun's README says UDP restrictions need Linux 7.2 or later. Inside landrun
  alone, TCP was blocked but DNS lookups and UDP sends succeeded.
- **Files.** Comparator gives the build read access to the whole filesystem, which includes the
  home directory of the user running it.

The command in the README closes both with systemd: `PrivateNetwork=yes` removes the network,
and `ProtectHome=tmpfs` with the three bind paths leaves only the project, the Lean toolchain and
the tools visible under the home directory. With these flags, all network access failed in our
tests and Comparator's own 14 tests passed.

## Building

- On our machine the build is on course for 5 to 7 hours and about 86 GB of outputs.
- Lake writes a `.setup.json` file per module that lists the module's whole import closure. In
  this project they average about 6 MB, which over 175,187 modules is around a terabyte. A
  module's file is not needed once the module is built, and deleting it leaves the build up to
  date. Run this beside the build:

  ```bash
  while sleep 120; do
    find .lake/build/ir -name '*.setup.json' | while IFS= read -r f; do
      t=".lake/build/lib/lean/${f#.lake/build/ir/}"
      [ "${t%.setup.json}.trace" -nt "$f" ] && rm -f "$f"
    done
  done
  ```

- Comparator's README assumes the solution was never compiled outside its sandbox, so start
  from a fresh clone.

## Results

The Comparator run is in progress. Its output, the exact command line and the machine details
will be added to this folder.
