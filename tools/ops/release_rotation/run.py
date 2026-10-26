"""Host maintenance: signed old OCI archives and exact unused release images only."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
from datetime import datetime,timezone
from tools.release.bundle.manifest import require
from . import catalog,policy

RELEASE_ROOT=Path('/opt/voice-platform-releases')
PUBLIC_KEY=Path('/etc/voice-platform/release-signing.pub.pem')
VOLUME='voice-platform_attachments-data'
FORMAT='{"id":{{json .Id}},"image":{{json .Image}},"started":{{json .State.StartedAt}},"status":{{json .State.Status}},"revision":{{json (index .Config.Labels "org.opencontainers.image.revision")}},"directory":{{json (index .Config.Labels "com.docker.compose.project.working_dir")}},"service":{{json (index .Config.Labels "com.docker.compose.service")}},"project":{{json (index .Config.Labels "com.docker.compose.project")}},"mounts":{{json .Mounts}}}'

def command(*args):
    result=subprocess.run(args,capture_output=True,text=True,timeout=180)
    require(result.returncode==0,'Maintenance command failed; no command output is published')
    return result.stdout.strip()

def docker(*args):return command('docker',*args)

def containers():
    ids=docker('ps','-aq').splitlines();require(bool(ids),'Container inventory is empty')
    items=[json.loads(line) for line in docker('inspect','--format',FORMAT,*ids).splitlines()]
    for item in items:item['mounts']=sorted(item['mounts'],key=lambda mount:json.dumps(mount,sort_keys=True))
    return sorted(items,key=lambda item:item['id'])

def image_inventory():
    images={}
    for line in docker('image','ls','--digests','--no-trunc','--format','{{json .}}').splitlines():
        row=json.loads(line)
        if row['Repository'] in ('voice-platform-api','voice-platform-web') and re.fullmatch('sha256:[a-f0-9]{64}',row['Digest']):
            images[row['Repository']+'@'+row['Digest']]=row['ID']
    return images

def linked_releases(items):
    protected=set()
    for item in items:
        if re.fullmatch('[a-f0-9]{40}',item.get('revision') or ''):protected.add(item['revision'])
        paths=[item.get('directory')]+[m.get('Source') for m in item['mounts']]
        for value in paths:
            if not value:continue
            path=Path(value)
            try:relative=path.relative_to(RELEASE_ROOT)
            except ValueError:continue
            if relative.parts and re.fullmatch('[a-f0-9]{40}',relative.parts[0]):protected.add(relative.parts[0])
    return protected


def headroom(mount):
    value=os.statvfs(mount);total=value.f_blocks*value.f_frsize;available=value.f_bavail*value.f_frsize
    required=2*max(2147483648,(total+9)//10)+25000000
    return {'available_bytes':available,'total_bytes':total,'required_bytes':required,'guard_pass':available>=required}


def locked_plan():
    require(RELEASE_ROOT.resolve()==RELEASE_ROOT and RELEASE_ROOT.is_dir(),'Canonical release root is unavailable')
    mount=Path(docker('volume','inspect','--format','{{.Mountpoint}}',VOLUME))
    require(mount.is_absolute() and mount.is_dir(),'Attachment volume is unavailable')
    docker_root=Path(docker('info','--format','{{.DockerRootDir}}'))
    require(os.stat(mount).st_dev==os.stat(RELEASE_ROOT).st_dev==os.stat(docker_root).st_dev,'Release, Docker and attachment filesystems differ')
    before=containers();sources=[]
    for service in ('api','web'):
        active=[c for c in before if c['project']=='voice-platform' and c['service']==service and c['status']=='running']
        require(len(active)==1 and re.fullmatch('[a-f0-9]{40}',active[0]['revision'] or ''),'One source-labelled running service is required')
        sources.append(active[0]['revision'])
    require(sources[0]==sources[1],'API and web sources differ')
    current=sources[0];previous=catalog.previous(RELEASE_ROOT,current)
    rows=catalog.inventory(RELEASE_ROOT,PUBLIC_KEY)
    keep=policy.retained(rows,current,previous,linked_releases(before))
    # Confirm every kept release still has both complete archives for reinstall/rollback.
    require(all(len(r['archives'])==2 for r in rows if r['revision'] in keep),'A retained release archive is unavailable')
    images=image_inventory()
    candidates=policy.image_candidates(rows,keep,images,{c['image'] for c in before})
    obsolete=[r for r in rows if r['revision'] not in keep]
    receipt={'schema_version':1,'kind':'release-artifact-rotation','status':'PLAN','observed_at':datetime.now(timezone.utc).isoformat(),
             'current_revision':current,'previous_revision':previous,'retained_revisions':sorted(keep),'signed_release_count':len(rows),
             'obsolete_release_count':len(obsolete),'archive_candidates':sum(len(r['archives']) for r in obsolete),
             'archive_candidate_bytes':sum(p.stat().st_blocks*512 for r in obsolete for p,*_ in r['archives']),
             'image_candidates':len(candidates),'before':headroom(mount),'volume':VOLUME}
    return receipt,obsolete,candidates,(before,mount,images)


def rotate(*,apply=False):
    with (RELEASE_ROOT/'.install.lock').open('a') as lock:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:return {'status':'SKIPPED_BUSY','kind':'release-artifact-rotation'}
        receipt,obsolete,candidates,state=locked_plan()
        if not apply:return receipt
        before,mount,images=state
        # Fail before mutation if external orchestration changed anything despite the host lock.
        require(containers()==before,'Containers changed while planning retention')
        receipt['removed_archive_bytes']=sum(catalog.remove_archives(r) for r in obsolete)
        removed=0
        for ref in candidates:
            # Never force an image removal; recheck all container references immediately before it.
            if images[ref] in {c['image'] for c in containers()}:continue
            docker('image','rm','--no-prune',ref);removed+=1
        receipt['removed_image_references']=removed
        # Bound only unused historical builder cache; running builds are protected by Docker.
        docker('builder','prune','--all','--force','--filter','until=168h','--keep-storage','2GB')
        after=containers();require(after==before,'Container identity or runtime state changed during retention')
        receipt.update(status='PASS',containers_unchanged=True,after=headroom(mount),finished_at=datetime.now(timezone.utc).isoformat())
        require(receipt['after']['guard_pass'],'Cleanup completed but protected disk reserve is still insufficient')
        return receipt


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    try:print(json.dumps(rotate(apply=args.apply),sort_keys=True))
    except Exception:
        print(json.dumps({'kind':'release-artifact-rotation','status':'FAIL','reason':'retention_precondition_or_operation_failed'}))
        raise SystemExit(1)


if __name__=='__main__':main()
