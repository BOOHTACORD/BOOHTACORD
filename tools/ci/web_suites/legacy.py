"""Read-only shadow control: the verified original driver on current source."""
import hashlib
import json
import re
import subprocess
import sys
import time
from tools.audio.livekit_fixture import IMAGE
from tools.ci.native.process import ROOT, client, run
from . import catalog, runner
from .run import checked_source


def require(value):
    if not value:
        raise ValueError('The complete verified legacy Web control is required')


def load_original(reader=subprocess.check_output):
    spec = catalog.baseline()
    data = reader(['git','show',spec['source_revision'] + ':' + spec['source_path']],cwd=ROOT)
    require(hashlib.sha256(data).hexdigest() == spec['source_sha256'])
    namespace = {'__name__':'tools.ci.native.web_legacy', '__package__':'tools.ci.native'}
    # This exact Git object is reviewed/hash-bound reference code, never a
    # user-selected ref, workspace file, artifact or shell command.
    exec(compile(data, '<verified-legacy-web>', 'exec'), namespace)
    require(callable(namespace.get('main')))
    return namespace


def run_legacy(source, *, executor=run, loader=load_original, clock=time.monotonic):
    require(isinstance(source,str) and re.fullmatch('[0-9a-f]{40}',source))
    execution = catalog.execution()
    spec = catalog.baseline()
    namespace = loader()
    expected = spec['operations']
    lookup = {tuple(value['command']):name for name,value in expected.items()}
    completed = []; installs = 0
    def observed(*command,**options):
        nonlocal installs
        normalized = tuple('{python}' if i==0 and a==sys.executable else a for i,a in enumerate(command))
        if normalized == ('npm','ci'):
            require(options.get('cwd') == client('web'))
            runner.checked(executor,list(command),**options)
            installs += 1
            return
        name = lookup.get(normalized)
        require(name is not None)
        definition = expected[name]
        require(options.get('cwd',ROOT) == (client('web') if definition['cwd']=='web' else ROOT))
        require(('env' in options) is definition['smoke_env'])
        if definition['smoke_env']:
            require(options['env'].get('SCREEN_SHARE_SFU_URL') == 'ws://127.0.0.1:17880'
                    and options['env'].get('SCREEN_SHARE_SFU_IMAGE') == IMAGE)
        runner.checked(executor,list(command),**options)
        completed.append(name)
    namespace['run'] = observed
    started = clock()
    # Preserve the original workflow's preparation AND the original driver's
    # second npm ci, rather than giving the legacy control a different workload.
    runner.checked(executor,['npm','ci'],cwd=client('web'))
    runner.checked(executor,['node','node_modules/playwright/cli.js','install','--with-deps','chromium'],cwd=client('web'))
    runner.check_ci_source(executor)
    namespace['main']()
    runner.check_ci_source(executor)
    require(completed == list(expected) and installs == 1)
    return {'source_revision':source, 'status':'PASS','operations':completed,
            'legacy_reference_revision':spec['source_revision'],'legacy_source_sha256':spec['source_sha256'],
            'seconds':round(clock()-started,6),'execution':execution}


def main():
    source, dirty = checked_source()
    require(not dirty)
    path = ROOT / '.out/ci/web-legacy.json'
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps({'source_revision':source,'status':'FAIL'})+'\n')
    result = run_legacy(source)
    final, dirty = checked_source()
    require(final == source and not dirty)
    path.write_text(json.dumps(result,sort_keys=True)+'\n')


if __name__ == '__main__':
    main()
