#!/usr/bin/env bash
# Check that every dependency pinned in lake-manifest.json is official upstream code.
#
# A pin passes if it is an ancestor of its repository's default branch, or if it is a release
# tag whose only difference from its merge-base with the default branch is `lean-toolchain`
# (Mathlib's patch releases, such as v4.33.1, are tagged this way). Uses the GitHub API; set
# GITHUB_TOKEN to avoid the unauthenticated rate limit.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 -I - lake-manifest.json <<'PY'
import json, os, subprocess, sys, urllib.request

def api(path):
    req = urllib.request.Request("https://api.github.com/" + path,
                                 headers={"Accept": "application/vnd.github+json", "User-Agent": "rh-lean-check"})
    tok = os.environ.get("GITHUB_TOKEN")
    if tok:
        req.add_header("Authorization", "Bearer " + tok)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def tags_at(url, rev):
    out = subprocess.run(["git", "ls-remote", "--tags", url], capture_output=True, text=True, check=True).stdout
    return sorted({line.split("\t")[1].removeprefix("refs/tags/").removesuffix("^{}")
                   for line in out.splitlines() if line.startswith(rev)})

gha = bool(os.environ.get("GITHUB_ACTIONS"))
bad = 0
for p in json.load(open(sys.argv[1]))["packages"]:
    url, rev, name = p["url"], p["rev"], p["name"]
    slug = url.removeprefix("https://github.com/").removesuffix(".git")
    branch = api(f"repos/{slug}")["default_branch"]
    cmp = api(f"repos/{slug}/compare/{branch}...{rev}")
    status, ahead = cmp["status"], cmp["ahead_by"]
    if status in ("behind", "identical"):
        print(f"ok   {name:16} {rev[:12]} is on {slug}@{branch}")
        continue
    base = cmp["merge_base_commit"]["sha"]
    files = [f["filename"] for f in api(f"repos/{slug}/compare/{base}...{rev}")["files"]]
    tags = tags_at(url, rev)
    if tags and files == ["lean-toolchain"]:
        print(f"ok   {name:16} {rev[:12]} is tag {', '.join(tags)}: {ahead} commit(s) on top of "
              f"{base[:12]} (on {branch}) that change only lean-toolchain")
        continue
    bad += 1
    msg = (f"{name} {rev[:12]} is not on {slug}@{branch} ({status}, {ahead} ahead); "
           f"tags: {tags or 'none'}; files changed vs merge-base {base[:12]}: {files[:20]}")
    print("FAIL " + msg)
    if gha:
        print("::error::" + msg)
sys.exit(1 if bad else 0)
PY
