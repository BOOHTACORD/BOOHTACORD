"""Bound Flutter's textual KGP warning; the native guard checks actual plugins."""
import sys
from pathlib import Path

PREFIX = 'WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):'


def validate(mode, output):
    if mode not in ('legacy', 'builtin'):
        raise ValueError('Unknown Kotlin compatibility mode')
    warnings = [line.strip() for line in output.splitlines() if PREFIX in line]
    # Flutter scans build-script text, including firebase_core's conditional apply.
    if warnings and warnings != [PREFIX + ' firebase_core']:
        raise ValueError('Unreviewed Kotlin Gradle Plugin usage')


if __name__ == '__main__':
    validate(sys.argv[1], Path(sys.argv[2]).read_text(encoding='utf-8', errors='replace'))
