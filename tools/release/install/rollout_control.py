"""Adapt only a proven unnecessary SQL replay in private current-controller space."""
from pathlib import Path
import shutil

MIGRATE = '"${compose[@]}" run --rm --no-deps migrate'


def inventory(manifest):
    if not isinstance(manifest, dict): return None
    compatibility = manifest.get('compatibility')
    if not isinstance(compatibility, dict): return None
    migrations = compatibility.get('migrations')
    return migrations if isinstance(migrations, dict) and migrations else None


def prepare(original, current, target, temporary):
    # Both manifests are authenticated by install.run before this call.
    original = Path(original)
    before = inventory(current)
    if before is None or before != inventory(target): return original
    if original.is_symlink() or original.parent.is_symlink():
        raise ValueError('Rollout source is indirect')
    text = original.read_text(encoding='utf-8')
    # Preserve unknown historical launchers rather than guessing their behaviour.
    if text.count(MIGRATE) != 1: return original
    if any(path.is_symlink() for path in original.parent.rglob('*')):
        raise ValueError('Rollout helpers are indirect')
    control = Path(temporary) / 'controlled-rollout'
    if control.resolve().is_relative_to(original.parent.resolve()):
        raise ValueError('Private rollout copy cannot be inside signed runtime')
    shutil.copytree(original.parent, control)
    selected = control / original.name
    selected.write_text(text.replace(MIGRATE, "printf '%s\\n' 'Signed migration inventory unchanged; no SQL applied.'"),
                        encoding='utf-8', newline='\n')
    return selected
