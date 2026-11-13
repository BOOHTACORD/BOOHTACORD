"""Run the native capture and queue CTest suite on the Windows runner."""
from pathlib import Path
import subprocess
import tempfile

from tools.ci.native.process import ROOT


def main():
    source = ROOT / 'clients/flutter/packages/flutter_webrtc/common/rnnoise'
    with tempfile.TemporaryDirectory(prefix='boohta-audio-ci-') as directory:
        build = Path(directory) / 'build'
        for command in (
            ('cmake', '-S', str(source), '-B', str(build), '-DBOOHTA_RNNOISE_TESTS=ON'),
            ('cmake', '--build', str(build), '--config', 'Release'),
            ('ctest', '--test-dir', str(build), '-C', 'Release', '--output-on-failure', '--no-tests=error'),
        ):
            subprocess.run(command, check=True)


if __name__ == '__main__':
    main()
