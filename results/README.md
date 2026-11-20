# Comparator runs

Each run of `scripts/run-comparator.sh` writes one directory here, named `<UTC time>-<host>`:

| File | Contents |
|---|---|
| `SUMMARY.md` | Result, timings, peak memory, tool and dependency revisions, tail of the output |
| `comparator.log`, `comparator.exit` | Full Comparator output and exit code |
| `comparator-nanoda.*` | The same for the optional nanoda pass |
| `tools.txt` | Exact landrun, lean4export, and Comparator revisions, plus the toolchain override |
| `dependency-revs.txt` | Each `.lake/packages` checkout vs. its `lake-manifest.json` pin |
| `environment.txt`, `inputs.sha256`, `config.json`, `run.log` | Machine, input hashes, config, step log |

No run has been published yet.
