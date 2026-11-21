"""Remove only Flutter's untracked generated Java artifact, preserving source."""
import subprocess


def remove_generated(root):
    path = root/'clients/flutter/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'
    if not path.exists() and not path.is_symlink(): return
    tracked = subprocess.check_output(['git', '-C', str(root), 'ls-files', '--',
                                       str(path.relative_to(root))])
    if (tracked or path.is_symlink() or not path.is_file() or
            'Generated file' not in path.read_text(encoding='utf-8')[:200]):
        raise ValueError('Preserving tracked or unknown Android registrant')
    path.unlink()
