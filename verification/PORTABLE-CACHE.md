# Reusing an existing Lean 4.36 build

Keep the exact completed source checkout, `.lake/build`, and `.lake/packages`; do not clean them. Record the original commit, `HEAD:src`, and configuration hashes before applying infrastructure changes. The native cache is produced from the final committed checkout, while this original identity remains a separate audit record.

For the immutable `Vilin97/riemann-hypothesis` snapshot `0092a8320a85932ea5a71baa0c093880a7f2a784`, the prepared metadata patch preserves every proof source, compiler option and default target. It adds portable-cache configuration and changes Mathlib's tag spelling to its already-locked commit. The dependency manifest changes only `mathlib.inputRev`; all dependency commits remain identical. This fork has no `BuildAid` source directory, so the patch does not add a `BuildAid` target.

After the maintainer supplies the patch and trusted helper scripts, apply and commit the metadata changes while retaining the existing build. Use fresh output paths:

```bash
python3 "$HELPERS/run-complete-build.py" \
  --release leanprover/lean4:v4.36.0 --project "$PROJECT" \
  --build-map "$PRODUCER/outputs.jsonl" --build-log "$PRODUCER/full-build.log" \
  --receipt "$PRODUCER/build-receipt.json" --jobs 8

python3 "$HELPERS/stage-completed-build.py" \
  --release leanprover/lean4:v4.36.0 --project "$PROJECT" \
  --build-map "$PRODUCER/outputs.jsonl" --build-log "$PRODUCER/full-build.log" \
  --build-receipt "$PRODUCER/build-receipt.json" \
  --output "$PRODUCER/native" --metadata "$PRODUCER/metadata"
```

The first command performs the complete stock default-target check and packs LTARs; unchanged proofs reuse their existing traces and artifacts. It binds the final source/configuration identity, command, log and map in a receipt. The second command performs no proof compilation, verifies native content hashes and SHA256, and stages the compressed cache. Add `--cache-dir /path/to/completed/native/cache` if cache hits have no local IR-directory LTAR alias. Transfer `native/` and `metadata/` to the maintainer's publishing host; no Cloudflare credential is needed on the producer.

Tiny stock 4.36 fixtures verify unchanged input hashes, artifact bytes and mtimes across these infrastructure edits, for both legacy sources and the new module system. Stock LTAR staging/restoration also preserves server/private OLean and IR parts, followed by a successful no-build check. The producer's full default-target check remains the authority for the actual project.
