"""Expose only the verified public catalog mount to the nonroot API reader."""
from pathlib import Path
from tools.release.bundle.manifest import require


def prepare(directory):
    root = Path(directory)
    require(not root.is_symlink() and root.is_dir(), 'Invalid retained release directory')
    parent = root / 'deploy'
    if not parent.exists() and not parent.is_symlink():
        return
    require(not parent.is_symlink() and parent.is_dir(), 'Invalid public catalog parent')
    public = parent / 'client-updates'
    if not public.exists() and not public.is_symlink():
        return
    require(not public.is_symlink() and public.is_dir(), 'Invalid public catalog directory')
    catalog = public / 'catalog.json'
    require(not catalog.is_symlink() and catalog.is_file(), 'Invalid public catalog file')
    require(catalog.resolve().is_relative_to(root.resolve()) and catalog.stat().st_nlink == 1,
            'Public catalog escaped release or has aliases')
    public.chmod(0o755)
    catalog.chmod(0o644)
