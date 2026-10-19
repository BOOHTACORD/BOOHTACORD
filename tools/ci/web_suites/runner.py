"""Execute reviewed profiles; dependency restoration never replaces a command."""
from contextlib import nullcontext
import itertools
import os
import re
import sys
import time
from tools.audio.asset_build import build_assets
from tools.audio.livekit_fixture import IMAGE, local_sfu
from tools.ci.native.process import ROOT, client, run
from . import catalog


def checked(executor, command, **options):
    result = executor(*command, **options)
    if getattr(result, 'returncode', None) != 0:
        raise RuntimeError('Required Web command did not complete successfully')


def prepare(browser, executor, assets_builder):
    checked(executor, ['npm', 'ci'], cwd=client('web'))
    if browser:
        # Use the already locked local CLI; a missing package cannot fetch latest.
        checked(executor, ['node', 'node_modules/playwright/cli.js', 'install', '--with-deps', 'chromium'],
                cwd=client('web'))
    assets_builder(ROOT)


def run_profile(profile, source, *, executor=run, assets_builder=build_assets,
                sfu_factory=local_sfu, clock=time.monotonic, prepared=False):
    plan = catalog.plan()
    if profile not in plan['profiles'] or not re.fullmatch('[0-9a-f]{40}', source):
        raise ValueError('Reviewed Web profile and exact source revision required')
    execution = catalog.execution()
    started = clock()
    if not prepared:
        prepare(profile != 'fast', executor, assets_builder)
    completed = []
    operations = plan['profiles'][profile]
    for uses_sfu, group in itertools.groupby(operations, lambda name: plan['operations'][name]['sfu']):
        with sfu_factory() if uses_sfu else nullcontext():
            for name in group:
                operation = plan['operations'][name]
                command = [sys.executable if arg == '{python}' else arg for arg in operation['command']]
                options = {'cwd': client('web') if operation['cwd'] == 'web' else ROOT}
                if operation['smoke_env']:
                    options['env'] = {**os.environ, 'SCREEN_SHARE_SFU_URL': 'ws://127.0.0.1:17880',
                                      'SCREEN_SHARE_SFU_IMAGE': IMAGE}
                checked(executor, command, **options)
                completed.append(name)
    return {'source_revision': source, 'profile': profile, 'plan_sha256': catalog.digest(plan),
            'status': 'PASS', 'operations': completed, 'seconds': round(clock() - started, 6),
            'execution': execution}
