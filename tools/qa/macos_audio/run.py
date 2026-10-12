"""Prepare owned physical macOS audio QA; acceptance remains manual."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

PORTS = {'https': 4850, 'api': 4851, 'tempo': 4852, 'sfu_http': 4890, 'sfu_tcp': 4891, 'sfu_udp': 4895}
REPLACEMENTS = dict(zip(('4810', '4820', '4812', '4880', '4881', '4882'), map(str, PORTS.values())))
MODULES = ('tools/qa/client_lifecycle', 'tools/qa/critical_client_acceptance', 'tools/qa/local_features', 'tools/audio')
PORT_MODULES = ('tools/qa/client_lifecycle/stack.py', 'tools/qa/client_lifecycle/services.py', 'tools/qa/critical_client_acceptance/stack.py', 'tools/qa/local_features/stack.py')


def private_json(path, data):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'w') as handle:
        json.dump(data, handle)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('debug', 'release', 'both'), default='both')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        raise SystemExit('Physical macOS required; no emulator acceptance')
    root = Path(__file__).resolve().parents[3]
    output = root / '.out/macos_audio'
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='owned-', dir=output) as temporary:
        work = Path(temporary)
        flutter = work / 'flutter'
        subprocess.run(['rsync', '-a', '--exclude', '/build/', '--exclude', '/.dart_tool/flutter_build/', '--exclude', '/macos/Flutter/ephemeral/', '--exclude', '/macos/Pods/', '--exclude', '.env', '--exclude', '.git', '--exclude', '*.keystore', '--exclude', '*.jks', str(root/'clients/flutter')+'/', str(flutter)+'/'], check=True)
        shutil.copy2(Path(__file__).with_name('native_app.dart'), flutter/'integration_test/macos_audio_native_app.dart')
        bundle = flutter/'macos/Runner/Configs/AppInfo.xcconfig'
        bundle.write_text(bundle.read_text().replace('ru.boohtacord.boohtacordDesktop', 'ru.boohtacord.localqa'))
        for module in MODULES:
            shutil.copytree(root/module, work/module, ignore=shutil.ignore_patterns('__pycache__'))
        for module in PORT_MODULES:
            path = work/module
            content = path.read_text()
            for old, new in REPLACEMENTS.items():
                content = content.replace(old, new)
            path.write_text(content)
        worker = work/'worker.py'
        shutil.copy2(Path(__file__).with_name('worker.py'), worker)
        private_json(work/'configuration.json', {'root':str(root), 'work':str(work), 'mode':args.mode, 'ports':PORTS})
        environment = dict(os.environ, DOCKER_CONTEXT='colima-boohtacord-qa')
        environment['PATH'] = '/opt/homebrew/bin:'+environment.get('PATH','')
        subprocess.run([sys.executable,str(worker)], cwd=work, env=environment, check=True)


if __name__ == '__main__':
    main()
