#!/usr/bin/env python3
"""Network/credential-isolated bwrap launcher. Invoke INSIDE a bounded systemd user unit."""
import argparse, os, shutil, subprocess, sys
from pathlib import Path
import rpc
from producer import dependency_paths

def command(root,control,output,producer,run_id,attempt,runner):
    root=Path(root).resolve();control=Path(control).resolve();output=Path(output).resolve();producer=Path(producer).resolve()
    lease=rpc.read(control/'lease.json');request=rpc.read(control/'request-0.json')
    rpc.check_lease(lease,request,run_id,attempt,runner);rpc.resource_limits(lease['worker'])
    rpc.require(rpc.digest(producer)==lease['producer_sha256'],'unreviewed backend wrapper')
    rpc.require((root/'.lake/build').is_dir(),'use a private candidate checkout with an existing empty .lake/build')
    rpc.require(not (root/'.lake/build').is_symlink(),'cache mount must not be a symlink')
    output.mkdir(parents=True,exist_ok=True);cache=output/'cache';cache.mkdir(exist_ok=True);returned=output/'returned';returned.mkdir(exist_ok=True)
    worker=lease['worker'];archive=Path(worker['archive_root']).resolve();deps=Path(worker['dependency_root']).resolve();tc=Path(worker['toolchain_root']).resolve()
    libs={Path(x)for x in dependency_paths(deps,root/'lake-manifest.json')}
    tools=Path(__file__).parent.resolve()
    rpc.require(producer.parent==tools,'backend wrapper must belong to the trusted tools bundle')
    rpc.require(shutil.which('bwrap') is not None,'bubblewrap required; no unsandboxed fallback')
    # Start with an empty filesystem, not a read-only view of host runner secrets.
    argv=['bwrap','--tmpfs','/','--dev','/dev','--proc','/proc','--unshare-net','--unshare-pid',
          '--die-with-parent','--new-session','--clearenv','--dir','/tmp','--dir','/tmp/native-home']
    for name in ['/nix/store','/usr','/bin','/sbin','/lib','/lib64']:
        path=Path(name)
        if path.exists():argv+=['--ro-bind',str(path.resolve()),name]
    for name in ['/sys/fs/cgroup']:
        argv+=['--ro-bind',name,name]
    sw=Path('/run/current-system/sw')
    if sw.exists():argv+=['--ro-bind',str(sw.resolve()),str(sw)]
    for path in sorted({root,tools,control,archive,deps,tc,*libs},key=lambda p:(len(p.parts),str(p))):
        argv+=['--ro-bind',str(path),str(path)]
    argv+=['--bind',str(cache),str(root/'.lake/build'),'--bind',str(returned),str(returned)]
    env={'PATH':str(tc/'bin')+':/usr/bin:/bin:/run/current-system/sw/bin','HOME':'/tmp/native-home','LANG':'C.UTF-8',
         'GIT_CONFIG_NOSYSTEM':'1','GIT_CONFIG_GLOBAL':'/dev/null'}
    for key,value in env.items():argv+=['--setenv',key,value]
    argv+=['--chdir',str(root),sys.executable,str(tools/'rpc.py'),'worker','--root',str(root),'--control',str(control),
           '--output',str(returned),'--producer',str(producer),'--run-id',str(run_id),'--attempt',str(attempt),'--runner',runner]
    return argv

def main():
    p=argparse.ArgumentParser()
    for name in ['root','control','output','producer','run-id','runner']:p.add_argument('--'+name,required=True)
    p.add_argument('--attempt',required=True,type=int);p.add_argument('--dry-run',action='store_true');a=p.parse_args()
    args=vars(a);dry=args.pop('dry_run');argv=command(**args)
    if dry:
        import json;print(json.dumps(argv));return 0
    return subprocess.run(argv,env={'PATH':os.environ.get('PATH','/usr/bin:/bin')},timeout=rpc.read(Path(a.control)/'lease.json')['worker']['timeout_seconds']+120).returncode
if __name__=='__main__':sys.exit(main())
