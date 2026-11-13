"""Run Firefox research graph and local SFU with a private Linux audio sink."""
from tools.audio.livekit_fixture import local_sfu
from tools.ci.native.process import client, run
from tools.ci.web_suites.audio_sink import isolated_sink


def main():
    web = client('web')
    cli = 'node_modules/@playwright/test/cli.js'
    config = 'tests/audio/playwright.deepfilter.firefox.config.ts'
    with isolated_sink() as sink_env:
        env = dict(sink_env, RNNOISE_LIVEKIT_URL='ws://127.0.0.1:17880',
                   RNNOISE_LIVEKIT_API_KEY='devkey', RNNOISE_LIVEKIT_API_SECRET='secret')
        run('node', cli, 'test', '-c', config, 'deepfilter_loader.research.spec.ts',
            'deepfilter_track.research.spec.ts', 'deepfilter.research.spec.ts', cwd=web, env=env)
        with local_sfu():
            run('node', cli, 'test', '-c', config, 'deepfilter_livekit.research.spec.ts',
                cwd=web, env=env)


if __name__ == '__main__':
    main()
