"""Run the synthetic audio graph and peer tests in the locked Firefox build."""
import sys
from tools.ci.native.process import client, run


def main():
    web = client('web')
    cli = 'node_modules/playwright/cli.js'
    install = ['node', cli, 'install']
    if sys.platform.startswith('linux'):
        install.append('--with-deps')
    run(*install, 'firefox', cwd=web)
    run('node', cli, 'test', '-c', 'tests/audio/playwright.firefox.config.ts',
        'rnnoise.browser.spec.ts', cwd=web)


if __name__ == '__main__':
    main()
