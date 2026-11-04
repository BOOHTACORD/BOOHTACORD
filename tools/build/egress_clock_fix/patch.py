"""Apply the receipt-clock correction to one pinned upstream Egress source."""
import hashlib
import sys
from pathlib import Path

UPSTREAM_SHA256 = 'a0348d65725a5d29541c970e9b6590a76637d6cbeb72b3213b75f311570695d7'
PATCHED_SHA256 = 'f04a801c4152725a0b60d57ad36b8b30fa89c6e34f98ee4a9e9d766f6e27b068'
OLD = b'w.buffer.Push(pkt)'
NEW = b'w.buffer.PushAt(pkt, receivedAt)'


def apply_patch(source: bytes) -> bytes:
    if source.count(OLD) != 1 or NEW in source:
        raise ValueError('Unexpected Egress packet writer source')
    return source.replace(OLD, NEW, 1)


def main() -> None:
    path = Path(sys.argv[1])
    source = path.read_bytes()
    if hashlib.sha256(source).hexdigest() != UPSTREAM_SHA256:
        raise ValueError('Unexpected upstream source digest')
    patched = apply_patch(source)
    if hashlib.sha256(patched).hexdigest() != PATCHED_SHA256:
        raise ValueError('Unexpected patched source digest')
    path.write_bytes(patched)


if __name__ == '__main__':
    main()
