"""Check expanded signed runtime files and provision the host-only environment."""
import os
import shutil
import tempfile
from pathlib import Path
from tools.release.archive.extract import extract
from tools.release.bundle.files import sha256
from tools.release.bundle.manifest import require
from .public_catalog.prepare import prepare as prepare_public_catalog


def check_expanded(directory, runtime):
    for source in runtime.rglob('*'):
        if source.is_file():
            target = directory / source.relative_to(runtime)
            require(target.resolve().is_relative_to(directory.resolve()) and target.is_file()
                    and not target.is_symlink() and sha256(target) == sha256(source),
                    'Retained runtime differs from the signed artifact')


def verify_runtime(directory):
    with tempfile.TemporaryDirectory(prefix='.runtime-check.', dir=directory.parent) as temporary:
        runtime = Path(temporary) / 'expanded'
        extract(directory / 'runtime.tar.gz', runtime, max_bytes=100_000_000)
        check_expanded(directory, runtime)


def prepare_environment(directory, environment):
    require(environment.is_file(), 'Production environment is unavailable')
    env_path = directory / '.env'
    require(not env_path.is_symlink(), 'Environment path must not be a symlink')
    prepare_public_catalog(directory)
    descriptor = os.open(env_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, 'wb') as target, environment.open('rb') as source:
        shutil.copyfileobj(source, target)
    env_path.chmod(0o600)
