"""Require reviewed full Actions commits; tags exist only in an inert policy view."""
import json
from pathlib import Path
import re
from .references import references

ROOT = Path(__file__).resolve().parents[3]


def load_pins():
    document = json.loads(Path(__file__).with_name('pins.json').read_text())
    if document.get('schema_version') != 1:
        raise ValueError('Unsupported action pin registry')
    rows = document['actions']
    pins = {r['action']: r for r in rows}
    if len(pins) != len(rows) or not pins or any(not re.fullmatch('[a-f0-9]{40}', r['commit']) for r in rows):
        raise ValueError('Invalid/duplicate reviewed action commits')
    return pins


def check_source(source, pins=None):
    pins = load_pins() if pins is None else pins
    for reference in references(source):
        if reference.startswith('./') and '..' not in reference.split('/'):
            continue
        action, separator, revision = reference.partition('@')
        if not separator or action not in pins or revision != pins[action]['commit']:
            raise ValueError('Every external action must use its reviewed full commit')


def normalized(source, pins=None):
    """Non-executable view for legacy semantic validators, after strict pin validation."""
    pins = load_pins() if pins is None else pins
    check_source(source, pins)
    for name, pin in pins.items():
        source = source.replace(name + '@' + pin['commit'], name + '@' + pin['reviewed_ref'])
    return source
