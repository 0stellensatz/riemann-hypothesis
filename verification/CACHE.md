# Lake cache bootstrap

The proof artifacts come from [Jack McCarthy's published archive](https://huggingface.co/datasets/JackMcCarthy/riemann-hypothesis-build/tree/9036e64326acf4acfae159b96664e9708445c1d1): 175,187 `.olean`/`.ilean` pairs, 28,638,044,751 compressed bytes and 99,269,509,951 extracted bytes. `fetch-published-cache.py` verifies the archive, manifest, and every extracted file against pinned SHA256 checksums, rejecting links, duplicates, and unsafe paths.

The preferred C source is the separately published [Lake build extras](https://huggingface.co/datasets/JackMcCarthy/riemann-hypothesis-build/tree/d4a057ad21e2f699743f0ed061fa2be73edfd68b/lake-extras), pinned to revision `d4a057ad21e2f699743f0ed061fa2be73edfd68b`. These came from another build, so their C must be checked against the preserved proof artifacts before use. External traces and hash files are never installed over the build tree.

## Preserve proofs, supply C and traces

- These are legacy modules, without `module` headers. Separate `.ir`, `.ir.sig`, `.olean.server`, and `.olean.private` files are unnecessary.
- `Normalize.lean` changes the archived package metadata from `none` to `tree`, matching stock Lake. Constants and runtime IR remain unchanged; published ileans are retained. For modules without runtime code, stock Lean emits initialization-only C from import/package metadata.
- `fetch-published-extras.py` verifies both extras archives and manifests, then separately extracts C for the **20,955 runtime modules** and collects the external build's olean hashes. Resumption rechecks derived C and hash data against the pinned per-file SHA256 manifests; a completion marker cannot bypass those checks.
- `AttestExtras.lean` compares actual frozen olean bytes with the external build's Lake hash. Where necessary, it serializes a temporary copy changing only diagnostic filenames in `lintLogExt`; matching that copy certifies that the runtime/proof data is unchanged. The frozen olean is never replaced.
- The initial run attested **10,813 exact matches and 10,141 diagnostic-path-only matches**. The sole remaining module, `Formalism.LocalToGlobal.SiegelLatticeTheory.CokernelGLCounts.RankPointCounts.LocModel`, already had compatibility-checked source-generated C.
- `accept-published-c.py` rehashes frozen oleans, verifies published C SHA256 values, and installs only missing C. Previously validated C is preserved because indexing or packing may already have observed it.

An unattested module uses the guarded source fallback: stock Lean elaborates it in an offline Bubblewrap sandbox, and `CheckRuntime.lean` compares every archived constant—including theorem proof values—plus native signatures, runtime IR, imports/package metadata, and initializer order. Fresh oleans/ileans are discarded after acceptance; only C is retained. Thus a cold bootstrap needs fallback compilation only for unmatched modules, rather than all 20,955 runtime modules.

Source Lean commands explicitly pass **`-j1`**. `LEAN_NUM_THREADS=1` alone does not limit the [Lean 4.33.1 shell](https://github.com/leanprover/lean4/blob/v4.33.1/src/Lean/Shell.lean#L219), whose default pool uses the hardware thread count. Independent module jobs provide parallelism.

`Trace.lean` uses the pinned Lake's hashing/import-trace operations to reconstruct source/dependency/compiler/options/module/package input hashes. It writes synthetic fetch traces and packs complete `.ltar` artifacts with stock `leantar`; only root-package mappings are published. Ordinary Lake commands retain their normal graph-processing costs. Mathematical verification is separate: see [the Comparator instructions](../README.md#checking-it).

## Produce and test

```bash
ulimit -n 65536
MATHLIB_CACHE_GET_URL=https://cache.mathlib.org/mathlib4 lake exe cache get
python3 scripts/fetch-published-cache.py --download-dir .lake/published-cache
python3 scripts/bootstrap-cache.py --workers 16
```

The producer checks the pinned source tree, dependency manifest, and compiler configuration. Its preferred route is normalization, extras verification, attestation, C acceptance, guarded fallback for unmatched modules, then indexing/packing. State and validation records live in `.lake/bootstrap`; final artifacts and `outputs.jsonl` are staged in `.lake/cache-staging`. Re-extract the original archive before normalization, never during an already normalized resumed run.

Before packing, the producer raises its process stack soft limit to the existing hard limit. Stock `leantar` needs more than the usual 8 MiB stack to compress some deeply nested oleans; no system limits are changed. The resulting archives unpack with the default 8 MiB stack.

```bash
lake -d scripts/cache-bootstrap build trace-cache normalize-cache check-runtime hash-outputs attest-extras
python3 scripts/cache-bootstrap/test_bootstrap.py
```

Fixtures compare normalized outputs and input hashes with stock Lake builds, test compressed-cache restoration after deleting outputs, and check invalidation after source/options change. Actual samples `BuildAid.D1` and `Lemmata.CofiniteContinuousBounds.LeOfCofinite` produced byte-identical normalized oleans and C. Diagnostic-path differences are handled explicitly by attestation.

## Public cache reads

Set `PUBLIC_BASE_URL` to the published Cloudflare origin. Mathlib is fetched separately as above. Stock Lake requires `--repo` for a root-package cache on a custom service:

```bash
: "${PUBLIC_BASE_URL:?set the published Cloudflare cache origin}"
mkdir -p .lake
cat > .lake/rh-cache.toml <<TOML
cache.defaultService = "riemann-hypothesis"
[[cache.service]]
name = "riemann-hypothesis"
kind = "s3"
artifactEndpoint = "$PUBLIC_BASE_URL/artifacts"
revisionEndpoint = "$PUBLIC_BASE_URL/revisions"
TOML
export LAKE_CONFIG="$PWD/.lake/rh-cache.toml"
export LAKE_CACHE_DIR="$PWD/.lake/cache"
export LAKE_ARTIFACT_CACHE=true
export LAKE_RESTORE_ARTIFACTS=true
lake cache get --repo leanprover-community/riemann-hypothesis
lake build
```

Downloads populate mappings and compressed artifacts; builds restore required outputs and compile changed files. Public reads require no upload credential.

## Publish a completed cache

The bootstrap is pinned to the original submission. Publish its validated staging directory from a separate host holding the upload credential:

```bash
python3 scripts/publish-lake-cache.py .lake/cache-staging \
  --rev e50d09817ad81469f737e8f637561e6ccf86c670 --check-only
python3 scripts/publish-lake-cache.py .lake/cache-staging \
  --rev e50d09817ad81469f737e8f637561e6ccf86c670
```

The publisher reads a mode-0600 account R2 token from `~/.riemann-hypothesis-cf-token` and verifies the revision map through the anonymous endpoint. Never copy this credential to a proof-building machine. It rejects incomplete mappings, unexpected files, and links before upload. For a progressive upload, use `sync-cache-artifacts.py DIRECTORY --watch`; finalize with `publish-lake-cache.py DIRECTORY --rev REV --map-only-after-sync`, which checks every remote artifact's presence and size before publishing the map.

For future source revisions, use a completed stock Lake build and `lake cache stage` to create staging; the archive bootstrap deliberately rejects changed sources. Publish a map for the exact source revision. A map can also be published with `--map-only-after-sync --platform x86_64-unknown-linux-gnu` for clients predating the portable-cache setting.
