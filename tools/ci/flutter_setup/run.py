"""Prepare public SDK cache metadata or install the source-pinned Flutter SDK."""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
from tools.ci.toolchains.spec import ROOT
from .metadata import prepare, describe, check_machine

STATE = ROOT / '.out/ci/flutter-setup.json'
INSTALLER = ROOT / '.out/ci/flutter-installer'


def context():
    system = {'Darwin': 'macOS'}.get(platform.system(), platform.system())
    architecture = {'x86_64': 'X64', 'AMD64': 'X64', 'arm64': 'ARM64',
                    'aarch64': 'ARM64', 'ARM64': 'ARM64'}.get(platform.machine(), '')
    if os.environ.get('RUNNER_OS') != system or os.environ.get('RUNNER_ARCH') != architecture:
        raise ValueError('Actual runner platform must match the Flutter SDK cache context')
    return (ROOT, Path(os.environ['RUNNER_TOOL_CACHE']), Path(os.environ['RUNNER_TEMP']),
            system, architecture, os.environ['REQUESTED_FLUTTER'], os.environ['REQUESTED_CHANNEL'])


def write_environment(value):
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as stream:
        for name, text in value.items():
            stream.write(name + '=' + text + '\n')
    with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as stream:
        stream.write('PUB_CACHE=' + value['pub_cache'] + '\n')


def installer_shell():
    if platform.system() != 'Windows':
        executable = shutil.which('bash')
        if executable:
            return executable
    else:
        # CreateProcess searches System32 before PATH for a bare executable;
        # its bash.exe starts WSL. Resolve bash from the installed Git instead.
        executable = shutil.which('git')
        if executable:
            git = Path(executable).resolve()
            for directory in (git.parent, *git.parents[:3]):
                for relative in ('bash.exe', 'bin/bash.exe', 'usr/bin/bash.exe'):
                    bash = directory / relative
                    if bash.is_file():
                        return str(bash)
    raise ValueError('The installed Git Bash interpreter is required')


def installed(value):
    if INSTALLER.resolve() != INSTALLER:
        raise ValueError('Refusing an indirect Flutter installer directory')
    revision = subprocess.check_output(['git', '-C', str(INSTALLER), 'rev-parse', 'HEAD'], text=True).strip()
    if revision != value['installer_revision']:
        raise ValueError('Reviewed Flutter installer revision required')
    subprocess.run(['git', '-C', str(INSTALLER), 'diff', '--exit-code', 'HEAD', '--'],
                   check=True, stdout=subprocess.DEVNULL)
    script = subprocess.check_output(['git', '-C', str(INSTALLER), 'show',
                                      value['installer_revision'] + ':setup.sh'])
    # Execute canonical Git blob bytes: Windows checkout line endings are not input.
    subprocess.run([installer_shell(), '-s', '--', '-n', value['version'],
                    '-a', value['architecture'], '-c', value['cache_path'],
                    '-d', value['pub_cache'], '-g', 'https://github.com/flutter/flutter.git', 'stable'],
                   check=True, input=script, env=dict(os.environ, PUB_CACHE=value['pub_cache']))
    sdk = Path(value['flutter_root'])
    binary = sdk / 'bin' / ('flutter.bat' if platform.system() == 'Windows' else 'flutter')
    if not binary.resolve().is_relative_to(sdk.resolve()) or not binary.is_file():
        raise ValueError('Owned reviewed SDK executable required')
    subprocess.run([str(binary), '--version'], check=True, capture_output=True)
    result = subprocess.run([str(binary), '--version', '--machine'], check=True, capture_output=True, text=True)
    check_machine(json.loads(result.stdout), value)
    print('PASS: exact Flutter/Dart/framework identity; private uncached pub directory')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('prepare', 'install'))
    args = parser.parse_args()
    root, toolcache, temporary, system, architecture, requested, channel = context()
    if STATE.is_symlink() or STATE.parent.resolve() != STATE.parent or INSTALLER.resolve() != INSTALLER:
        raise ValueError('Refusing indirect Flutter setup metadata/source paths')
    STATE.parent.mkdir(parents=True, exist_ok=True)
    if args.phase == 'prepare':
        value = prepare(root, toolcache, temporary, system, architecture, requested, channel)
        STATE.write_text(json.dumps(value, indent=2) + '\n')
        write_environment(value)
        return
    value = json.loads(STATE.read_text())
    expected = describe(root, toolcache, system, architecture, requested, channel)
    pub = Path(value['pub_cache'])
    if (any(value.get(k) != v for k, v in expected.items()) or not pub.is_dir()
            or pub.resolve() != pub or not pub.is_relative_to(temporary.resolve())
            or not pub.name.startswith('boohtacord-pub-')):
        raise ValueError('Flutter SDK setup metadata changed')
    installed(value)


if __name__ == '__main__':
    main()
