"""Select the exact engine compiler without changing the user's default toolchain."""
import os
import subprocess


def select():
    env = dict(os.environ)
    version = subprocess.check_output(['rustc', '--version'], text=True, env=env)
    if not version.startswith('rustc 1.97.1 '):
        subprocess.run(['rustup', 'toolchain', 'install', '1.97.1', '--profile', 'minimal', '--no-self-update'], check=True)
        env['RUSTUP_TOOLCHAIN'] = '1.97.1'
        version = subprocess.check_output(['rustc', '--version'], text=True, env=env)
    if not version.startswith('rustc 1.97.1 '):
        raise ValueError('DeepFilter production compiler must be Rust 1.97.1')
    return env, version
