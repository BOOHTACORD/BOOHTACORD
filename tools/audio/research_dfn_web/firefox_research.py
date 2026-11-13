"""Run Firefox research graph and local SFU with a private Linux audio sink."""
from .livekit_linux import private_sfu
from tools.ci.native.process import client, run
from tools.ci.web_suites.audio_sink import isolated_sink


def main():
    web = client('web')
    cli = 'node_modules/@playwright/test/cli.js'
    config = 'tests/audio/playwright.deepfilter.firefox.config.ts'
    with isolated_sink() as env:
        run('node', cli, 'test', '-c', config, 'deepfilter_loader.research.spec.ts',
            'deepfilter_track.research.spec.ts', 'deepfilter.research.spec.ts', cwd=web, env=env)
        with private_sfu(env) as sfu_env:
            run('node', cli, 'test', '-c', config, 'deepfilter_livekit.research.spec.ts',
                'deepfilter_switch_livekit.research.spec.ts',
                cwd=web, env=sfu_env)


if __name__ == '__main__':
    main()
