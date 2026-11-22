"""Restore only the fixed unchanged #66 modules, with stock leantar in the sandbox."""
import gzip
import json
from pathlib import Path
import subprocess
import rpc


def restore(root, control, worker):
    policy = rpc.proof_policy()
    expected = policy['baseline']
    cache = Path(worker['baseline_cache_root'])
    manifest = cache / 'modules.jsonl.gz'
    mapping = cache / 'outputs.jsonl'
    rpc.require(rpc.readonly_mount(cache), 'baseline cache must be mounted read-only')
    rpc.require(rpc.digest(manifest) == expected['manifest_sha256'] and
                rpc.digest(mapping) == expected['map_sha256'], 'unapproved native baseline')
    lines = gzip.decompress(manifest.read_bytes()).splitlines()
    header = json.loads(lines[0])
    rows = [json.loads(line) for line in lines[1:]]
    rpc.require(header.get('source_tree') == expected['source_tree'] and
                header.get('map_sha256') == expected['map_sha256'] and
                header.get('modules') == len(rows) == expected['modules'], 'baseline scope mismatch')
    affected = rpc.proof_worklist(Path(control) / 'proof-worklist.txt')
    inputs = rpc.read(Path(control) / 'input-manifest.json')
    # An incoming current-snapshot artifact always takes precedence over a base.
    incoming = set(inputs['modules'])
    jobs, seen, unchanged = [], set(), 0
    for name, dep_hash, archive, digest in rows:
        rpc.module_name(name)
        rpc.require(name not in seen, 'duplicate baseline module')
        seen.add(name)
        rpc.require(rpc.SHA.fullmatch(digest) and len(dep_hash) == 16 and
                    all(c in '0123456789abcdef' for c in dep_hash) and
                    len(archive) == 21 and archive.endswith('.ltar') and
                    all(c in '0123456789abcdef' for c in archive[:-5]), 'invalid native baseline entry')
        if name in affected:
            continue
        unchanged += 1
        if name in incoming:
            continue
        source = cache / 'artifacts' / archive
        rpc.require(source.is_file() and not source.is_symlink() and
                    rpc.digest(source) == digest, 'native baseline LTAR SHA mismatch')
        relative = Path(*name.split('.'))
        bases = [Path(root) / '.lake/build' / part / relative.parent
                 for part in ['lib/lean', 'ir']]
        for directory in bases:
            directory.mkdir(parents=True, exist_ok=True)
        jobs.append({'file': str(source), 'hash': dep_hash, 'base': [str(p) for p in bases]})
    rpc.require(unchanged == expected['unchanged_modules'], 'unchanged baseline scope mismatch')
    if jobs:
        subprocess.run([str(Path(worker['toolchain_root']) / 'bin/leantar'), '--jobs',
                        str(min(worker.get('jobs', 1), 64)), '-f', '-x', '-j', '-'],
                       input=json.dumps(jobs), text=True, check=True)
    return {'baseline_modules': unchanged, 'restored_modules': len(jobs),
            'affected_modules_restored': 0}
