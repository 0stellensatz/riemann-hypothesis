# Source of the mirror

Downloaded 2026-11-20 (about 13:50 UTC).

| Item | Value |
|---|---|
| Announcement | <https://alpo.ge/remark.pdf>, sha256 `3fc97784b71ddd44ff8aa0a177e99622a1c61b13cfa843a0989ee4a7a0cfeb8d` (4 pages, created 2026-11-20 07:52 EST) |
| Archive parts | `https://alpo.ge/lean.tar.gz.part01` … `part14`: parts 01–13 are 18,000,000 bytes each, part 14 is 5,275,554 bytes |
| Joined archive | `cat lean.tar.gz.part{01..14} > lean.tar.gz`: 239,275,554 bytes, sha256 `9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc` |
| Archive contents | top-level `lean/`: `lean-toolchain`, `lakefile.toml`, `lake-manifest.json`, `src/` (175,187 `.lean` files). No symlinks, absolute paths, or `..` entries |
| Mirror | the contents of `lean/`, at the repository root |

The server answers HTTP 200 with an HTML page for any path, so a `part15` URL "exists" but is not
part of the archive. Check each part's size or the joined sha256, not the status code.

`files.sha256` holds the sha256 of every file in the original archive, in `sha256sum -c` format.
`lakefile.original.toml` holds the original lakefile bytes.

## Size

1,030,531,854 bytes of Lean source: 17,374,215 lines, of which 15,531,759 are non-blank. There
are no comments at all. The source has 818,755 `theorem`/`lemma` declarations and 242,067
`def`/`abbrev`/`structure`/`class`/`instance`/`inductive` declarations. Every file is in the import
closure of `Main`.

| Library | Files | Lines |
|---|---:|---:|
| Development | 141,928 | 12,232,663 |
| Formalism | 18,254 | 3,200,748 |
| GroundTheory | 8,507 | 1,119,138 |
| ReciprocityTheory | 3,845 | 563,016 |
| CompanionTheory | 2,027 | 194,218 |
| PositivityTheory | 449 | 55,130 |
| Lemmata | 167 | 9,232 |
| Supplements | 3 | 22 |
| BuildAid | 5 | 20 |
| `Main.lean`, `Statements.lean` | 2 | 28 |
