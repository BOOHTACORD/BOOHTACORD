"""Produce the per-user Velopack bootstrap and immutable full update package."""
from pathlib import Path
import json
import subprocess
from tools.ci.native.process import ROOT, run
from tools.build.client_identity import load

VERSION = '1.2.161'


def prepare_packager():
    tools = ROOT / '.out/desktop-updater/vpk'
    tools.mkdir(parents=True, exist_ok=True)
    executable = tools / 'vpk.exe'
    if not executable.is_file():
        run('dotnet', 'tool', 'install', 'vpk', '--version', VERSION,
            '--tool-path', str(tools), '--framework', 'net8.0')
    measured = subprocess.check_output(
        ['dotnet', 'tool', 'list', '--tool-path', str(tools)], text=True)
    records = [line.split() for line in measured.splitlines()
               if line.split() and line.split()[0].lower() == 'vpk']
    if len(records) != 1 or records[0][1:] != [VERSION, 'vpk']:
        raise ValueError('Velopack packaging tool differs from pinned version')
    return executable


def package(release: Path):
    identity = load('windows')
    executable = prepare_packager()
    destination = ROOT / '.out/releases/windows'
    destination.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(executable), 'pack', '--packId', 'boohtacord_desktop',
                    '--packVersion', identity['version'], '--packDir', str(release),
                    '--mainExe', 'boohtacord_desktop.exe', '--channel', 'stable',
                    '--packTitle', 'BOOHTACORD', '--packAuthors', 'BOOHTACORD',
                    '--outputDir', str(destination), '--noPortable'], check=True)
    packages = list(destination.glob('*-full.nupkg'))
    installers = list(destination.glob('*Setup.exe'))
    if len(packages) != 1 or len(installers) != 1:
        raise ValueError('Velopack did not produce one full package and installer')
    # This is unsigned feed metadata, never promoted as client trust metadata.
    (destination / 'build-identity.json').write_text(json.dumps(identity, indent=2)+'\n')
    return destination
