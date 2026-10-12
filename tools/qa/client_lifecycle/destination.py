"""Keep explicitly selected capture runs isolated from historical receipts."""
from pathlib import Path


def fresh_capture_destination(root, output_root, width):
    if width not in (390, 393, 1024, 1440):
        raise ValueError('Unsupported client lifecycle viewport width')
    root = Path(root).resolve()
    base = (root / '.out').resolve()
    selected = Path(output_root)
    if not selected.is_absolute():
        selected = root / selected
    selected = selected.resolve()
    if not base.is_relative_to(root) or not selected.is_relative_to(base):
        raise ValueError('Capture output must remain within this checkout .out directory')
    destination = selected / str(width)
    destination.mkdir(parents=True, exist_ok=False)
    return destination
