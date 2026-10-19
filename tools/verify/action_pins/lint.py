"""Structural/expression Actions lint from a reviewed exact Go module commit."""
import json
import re
import subprocess
from .policy import ROOT
from tools.ci.native.process import output, require_version
from pathlib import Path


def command(versions):
    revision = versions.get('actionlint_source_revision')
    if not isinstance(revision, str) or not re.fullmatch('[a-f0-9]{40}', revision):
        raise ValueError('Reviewed full actionlint source commit required')
    return ['go', 'run', 'github.com/rhysd/actionlint/cmd/actionlint@' + revision, '-shellcheck=', '-pyflakes=']


def main():
    require_version('go', output('go', 'version', cwd=ROOT).split()[2].removeprefix('go'))
    versions = json.loads(Path(__file__).with_name('pins.json').read_text())
    subprocess.run(command(versions), cwd=ROOT, check=True)


if __name__ == '__main__':
    main()
