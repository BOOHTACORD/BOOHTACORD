"""Write the operator key and separate opaque listener response sheets."""
import csv
import json

from .trials import listener_sheet


def write_plan(destination, assignments, listener_count):
    destination = destination.resolve()
    if any((parent / '.git').exists() for parent in (destination, *destination.parents)):
        raise ValueError('Keep listening assignments outside Git checkouts')
    destination.mkdir(parents=True, exist_ok=False, mode=0o700)
    (destination / 'operator-private.json').write_text(json.dumps(assignments, indent=2) + '\n', encoding='utf-8')
    for listener in range(1, listener_count + 1):
        with (destination / f'listener-{listener:02d}.csv').open('x', encoding='utf-8', newline='') as file:
            writer = csv.DictWriter(file, fieldnames=['trial', 'preferred', 'speech_defect'])
            writer.writeheader()
            writer.writerows(listener_sheet(assignments, listener))
