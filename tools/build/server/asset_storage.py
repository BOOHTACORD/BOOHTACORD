"""Release a newly pulled compiler reference on the disposable hosted builder."""
import os
import subprocess
from tools.audio.asset_build import COMPILER_IMAGE, build_assets

REFERENCE=COMPILER_IMAGE.split('@')[0].rsplit(':',1)[0]+'@'+COMPILER_IMAGE.split('@')[1]


def references():
    return set(subprocess.check_output(
        ['docker','image','ls','--all','--digests','--format','{{.Repository}}@{{.Digest}}'],
        text=True,timeout=30).splitlines())


def build_release_assets(root):
    report={'removed_new_compiler_reference':False}
    hosted=(os.environ.get('GITHUB_ACTIONS')=='true' and
            os.environ.get('RUNNER_ENVIRONMENT')=='github-hosted')
    preexisting=REFERENCE in references() if hosted else True
    try:
        build_assets(root)
    finally:
        # Never prune the daemon or remove a pre-existing/shared image. Removing
        # just this new digest reference preserves other tags; without --force,
        # Docker also refuses removal if a container still depends on the image.
        if hosted and not preexisting and REFERENCE in references():
            subprocess.run(['docker','image','rm',REFERENCE],check=True,timeout=60)
            report['removed_new_compiler_reference']=True
    return report
