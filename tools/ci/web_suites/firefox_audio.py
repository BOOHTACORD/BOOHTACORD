"""Run the synthetic audio graph and peer tests in the locked Firefox build."""
from contextlib import nullcontext
import os
import shutil
import sys
from tools.ci.native.process import client, run
from .audio_sink import isolated_sink


def main():
    web = client('web')
    cli = 'node_modules/playwright/cli.js'
    install = ['node', cli, 'install']
    if sys.platform.startswith('linux'):
        install.append('--with-deps')
    run(*install, 'firefox', cwd=web)
    linux = sys.platform.startswith('linux')
    if linux and os.environ.get('GITHUB_ACTIONS') == 'true':
        run('sudo', 'apt-get', 'install', '-y', '--no-install-recommends', 'pulseaudio', 'pulseaudio-utils')
    if linux and (not shutil.which('pulseaudio') or not shutil.which('pactl')):
        raise RuntimeError('Firefox audio tests require PulseAudio and pactl')
    with isolated_sink() if linux else nullcontext(dict(os.environ)) as env:
        run('node', cli, 'test', '-c', 'tests/audio/playwright.firefox.config.ts',
            'rnnoise.browser.spec.ts', cwd=web, env=env)


if __name__ == '__main__':
    main()
