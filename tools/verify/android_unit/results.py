"""Validate actual JUnit cases, rejecting missing classes, skips and failures."""
from collections import Counter
import xml.etree.ElementTree as ET


def validate(directory, expected):
    paths = sorted(directory.glob('TEST-*.xml'))
    if not paths:
        raise ValueError('Missing JUnit XML')
    seen, counts = set(), Counter()
    for path in paths:
        if path.is_symlink() or not 0 < path.stat().st_size <= 4 * 1024 * 1024:
            raise ValueError('Invalid JUnit file')
        root = ET.parse(path).getroot()
        for suite in root.iter('testsuite'):
            if any(int(suite.get(key, '0')) != 0 for key in ('failures', 'errors', 'skipped')):
                raise ValueError('Unsuccessful JUnit suite')
        for case in root.iter('testcase'):
            key = case.get('classname'), case.get('name')
            if (not all(key) or key in seen or case.find('failure') is not None
                    or case.find('error') is not None or case.find('skipped') is not None):
                raise ValueError('Duplicate, skipped or failed JUnit case')
            seen.add(key)
            counts[key[0]] += 1
    if dict(counts) != expected:
        raise ValueError('JUnit discovery differs from the required per-class inventory')
    return dict(counts)
