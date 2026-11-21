#!/usr/bin/env python3
"""A completed tiny stock build can seed a new baseline without rebuilding."""
import gzip
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
from unittest.mock import patch


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    here = Path(__file__).resolve().parent
    stage = load("completed_fixture", here.parent / "stage-completed-build.py")
    publisher = load("completed_publisher", here.parent / "publish-lake-cache.py")
    with tempfile.TemporaryDirectory(prefix="rh-completed-fixture-") as temporary:
        directory = Path(temporary)
        root, flat, metadata = directory / "project", directory / "native", directory / "metadata"
        (root / "src").mkdir(parents=True)
        (root / "src/Main.lean").write_text("def answer : Nat := 42\n")
        (root / "lean-toolchain").write_text(stage.ci.TOOLCHAIN + "\n")
        (root / "lakefile.toml").write_text('name="completedFixture"\nsrcDir="src"\nplatformIndependent=true\ndefaultTargets=["Main"]\n[[lean_lib]]\nname="Main"\n')
        environment = {key: value for key, value in os.environ.items() if not key.startswith("LAKE_")}
        environment["ELAN_TOOLCHAIN"] = stage.ci.TOOLCHAIN
        log = directory / "stock-build.log"
        mapping = directory / "stock-outputs.jsonl"
        with log.open("wb") as stream:
            subprocess.run(["lake", "--rehash", "build", "-o", str(mapping)], cwd=root, env=environment,
                           stdout=stream, stderr=subprocess.STDOUT, check=True)
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        subprocess.run(["git", "add", "src", "lean-toolchain", "lakefile.toml", "lake-manifest.json"], cwd=root, check=True)
        subprocess.run(["git", "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "fixture"], cwd=root, check=True)
        arguments = ["stage-completed", "--project", str(root), "--build-log", str(log),
                     "--build-map", str(mapping), "--output", str(flat), "--metadata", str(metadata), "--jobs", "2"]
        before = (root / ".lake/build/lib/lean/Main.olean").stat().st_mtime_ns
        selected = SimpleNamespace(**{**vars(stage.ci.settings.for_toolchain(stage.ci.TOOLCHAIN)),
                                     "DEPENDENCIES": stage.ci.sha256(root / "lake-manifest.json")})
        with patch.object(sys, "argv", arguments), patch.object(stage.ci.settings, "for_toolchain", return_value=selected):
            stage.main()
        assert (root / ".lake/build/lib/lean/Main.olean").stat().st_mtime_ns == before
        contents, report = publisher.validate_staging(flat)
        assert report["mapping_entries"] == 1
        manifest = metadata / "modules.jsonl.gz"
        publisher.validate_module_manifest(manifest, contents, flat)
        summary = json.loads((metadata / "completed-build.json").read_text())
        assert summary["baseline"]["map_sha256"] == stage.ci.sha256(mapping)
        assert summary["baseline"]["manifest_sha256"] == stage.ci.sha256(manifest)
        lines = gzip.decompress(manifest.read_bytes()).splitlines()
        header = json.loads(lines[0])
        assert header["toolchain"] == stage.ci.TOOLCHAIN and header["modules"] == 1
        header["toolchain"] = "leanprover/lean4:v0.0.0"
        manifest.write_bytes(gzip.compress((json.dumps(header) + "\n").encode() + lines[1] + b"\n", mtime=0))
        try:
            publisher.validate_module_manifest(manifest, contents, flat)
        except ValueError:
            pass
        else:
            raise AssertionError("cross-toolchain baseline was accepted")
    print("PASS completed baseline: no second build, native hash/SHA verified, publisher sidecar binding and cross-toolchain rejection")


if __name__ == "__main__":
    main()
