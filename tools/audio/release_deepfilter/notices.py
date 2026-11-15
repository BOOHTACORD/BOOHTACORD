"""Deliver canonical, hash-authenticated upstream notices on every host."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3] / 'tools/audio/runtime_assets/deepfilter'
UPSTREAM = ('LICENSE', 'LICENSE-MIT', 'LICENSE-APACHE', 'README.md')
RUST = 'LICENSE-Rust-1.97.1.html'


def expected(name, content):
    identity = json.loads((ROOT / 'engine.json').read_text(encoding='utf-8'))
    if hashlib.sha256(content).hexdigest() != identity['files'][name]:
        raise ValueError('Production DeepFilter notice checksum mismatch: ' + name)
    return content


def stage(source, output):
    # git archive honors Windows autocrlf; only canonical upstream LF is delivered.
    files = {name: expected(name, (source / name).read_bytes().replace(b'\r\n', b'\n'))
             for name in UPSTREAM}
    files[RUST] = expected(RUST, (ROOT / RUST).read_bytes())
    for name, content in files.items():
        (output / ('DeepFilterNet-' + name)).write_bytes(content)


def validate(output):
    for name in (*UPSTREAM, RUST):
        expected(name, (output / ('DeepFilterNet-' + name)).read_bytes())
