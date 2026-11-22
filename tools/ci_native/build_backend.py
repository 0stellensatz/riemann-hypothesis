#!/usr/bin/env python3
"""Compile only the pinned trusted infrastructure program, never project proofs."""
import argparse, os, subprocess
from pathlib import Path
import rpc
from producer import SOURCE_SHA

def main():
    p=argparse.ArgumentParser();p.add_argument('--toolchain',required=True);a=p.parse_args()
    root=Path(__file__).with_name('backend').resolve();tc=Path(a.toolchain).resolve()
    rpc.require(rpc.digest(root/'RuntimeProducer.lean')==SOURCE_SHA,'unreviewed compiler adapter source')
    version=subprocess.check_output([str(tc/'bin/lean'),'--version'],text=True)
    rpc.require('4.36.0' in version and '611c' in version,'stock pinned toolchain required')
    env={'PATH':str(tc/'bin')+':/usr/bin:/bin:/run/current-system/sw/bin','HOME':'/tmp/native-build-home','LANG':'C.UTF-8'}
    subprocess.run([str(tc/'bin/lake'),'build','runtime-producer'],cwd=root,env=env,check=True)
    binary=root/'.lake/build/bin/runtime-producer'
    rpc.atomic(root/'binary-receipt.json',{'source_sha256':SOURCE_SHA,'elf_sha256':rpc.digest(binary),'toolchain':version.strip()})
if __name__=='__main__':main()
