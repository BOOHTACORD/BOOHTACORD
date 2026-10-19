"""Stable native source authority is an existing master-reachable exact version tag."""
import os
import re
import subprocess
from tools.build.client_identity import load
from tools.ci.native.process import ROOT, output
from tools.ci.backend_gates.results import execution

PLATFORMS=('android','windows','macos')
REPOSITORY='Egkurilov/BOOHTACORD'


def require(value):
    if not value: raise ValueError('Native release source, version or artifact contract differs')


def preflight(platform):
    require(platform in PLATFORMS and os.environ.get('GITHUB_REPOSITORY') == REPOSITORY)
    identity=load(platform)
    require(re.fullmatch(r'\d+\.\d+\.\d+',identity['version']))
    tag=platform+'-v'+identity['version']
    mode=os.environ.get('NATIVE_RELEASE_DRY_RUN','false')
    require(mode in ('true','false'))
    candidate=mode=='true'
    ref=os.environ.get('GITHUB_REF')
    tagged=ref=='refs/tags/'+tag
    require(tagged or (candidate and ref=='refs/heads/master' and os.environ.get('GITHUB_EVENT_NAME')=='workflow_dispatch'))
    revision=output('git','rev-parse','HEAD')
    trigger=os.environ.get('GITHUB_SHA','')
    require(re.fullmatch('[0-9a-f]{40}',revision) and re.fullmatch('[0-9a-f]{40}',trigger)
            and output('git','rev-parse',trigger+'^{commit}') == revision)
    if tagged:require(output('git','rev-parse','refs/tags/'+tag+'^{commit}') == revision)
    subprocess.run(['git','diff','--exit-code','HEAD','--'],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
    subprocess.run(['git','merge-base','--is-ancestor',revision,'refs/remotes/origin/master'],
                   cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
    return {'schema_version':1,'repository':REPOSITORY,'platform':platform,'tag':tag,
            'source_revision':revision,'identity':identity,'execution':execution(),
            'release_mode':'candidate' if candidate else 'stable','source_ref':ref,'tag_verified':tagged,
            'trigger_revision':trigger}
