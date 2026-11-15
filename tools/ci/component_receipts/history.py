"""Select immutable receipt archives from this source and run, preserving attempts."""
from pathlib import Path
import re


def valid_attempt(value, maximum):
    if (not isinstance(value, str) or not re.fullmatch(r'[1-9][0-9]{0,5}', value)
            or not isinstance(maximum, str) or not re.fullmatch(r'[1-9][0-9]{0,5}', maximum)
            or int(value) > int(maximum)):
        raise ValueError('Receipt attempt is invalid or newer than this execution')
    return value


def archive_pattern(kind, source, run, namespace='flutter'):
    if not re.fullmatch('[0-9a-f]{40}', source) or not re.fullmatch('[1-9][0-9]*', run):
        raise ValueError('Receipt source or run identity differs')
    context = re.escape(source + '-' + run + '-')
    if kind == 'flutter' and re.fullmatch('[A-Za-z0-9_-]{1,100}', namespace):
        return re.compile('flutter-part-' + re.escape(namespace) + '-' + context
                          + r'(?P<attempt>[1-9][0-9]*)-(?P<profile>dart|android|android-kotlin|macos)')
    if kind == 'actual':
        return re.compile(r'actual-(?P<profile>lifecycle|next|sfu)-' + context + r'(?P<attempt>[1-9][0-9]*)')
    raise ValueError('Unknown receipt archive family')


def select_archives(root, profiles, maximum, pattern):
    root = Path(root)
    if not root.is_dir() or root.is_symlink() or root.resolve() != root:
        raise ValueError('Receipt archive directory is absent or indirect')
    entries = list(root.iterdir())
    if not 0 < len(entries) <= 256 or len(set(profiles)) != len(profiles):
        raise ValueError('Receipt archive inventory is incomplete or oversized')
    selected, seen = {}, set()
    for folder in entries:
        match = pattern.fullmatch(folder.name)
        if not folder.is_dir() or folder.is_symlink() or not match:
            raise ValueError('Unexpected or indirect receipt archive')
        profile, attempt = match['profile'], valid_attempt(match['attempt'], maximum)
        if profile not in profiles or (profile, attempt) in seen:
            raise ValueError('Unexpected or ambiguous receipt profile')
        seen.add((profile, attempt))
        if profile not in selected or int(attempt) > int(selected[profile][1]):
            selected[profile] = folder, attempt
    if set(selected) != set(profiles):
        raise ValueError('Every selected receipt profile is mandatory')
    return {profile: selected[profile] for profile in profiles}
