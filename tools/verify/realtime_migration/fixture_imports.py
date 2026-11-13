"""Reject production imports of test modules and the isolated load package."""
import posixpath
import re

IMPORT = re.compile(r'''(?:\b(?:import|export|part)\s+(?:[\w*{},\s]+\s+from\s+)?|\b(?:import|require)\s*\()\s*['"]([^'"]+)''')
GO_LOAD = re.compile(r'''["']voice-platform/backend/internal/load(?:/[^"']*)?["']''')
TEST_SUFFIXES = ('.spec', '.test', '.spec.ts', '.test.ts', '.spec.js', '.test.js',
                 '.spec.mjs', '.test.mjs', '_test.dart', '_test.go')


def test_module(path):
    parts = path.split('/')
    return 'test' in parts or 'tests' in parts or path.endswith(TEST_SUFFIXES)


def resolve(importer, target):
    if target.startswith('.') or (importer.startswith('clients/flutter/lib/') and ':' not in target):
        return posixpath.normpath(posixpath.join(posixpath.dirname(importer), target))
    prefix = 'package:boohtacord_desktop/'
    if importer.startswith('clients/flutter/lib/') and target.startswith(prefix):
        return 'clients/flutter/lib/' + target.removeprefix(prefix)
    return None


def imports_of_fixtures(relative, content, fixtures):
    findings = []
    if test_module(relative):
        return findings
    if relative.startswith(('clients/web/src/', 'clients/flutter/lib/')):
        for match in IMPORT.finditer(content):
            target = resolve(relative, match.group(1))
            if not target:
                continue
            choices = (target, *(target + ext for ext in ('.ts', '.tsx', '.js', '.mjs', '.dart')))
            if any(test_module(value) or value in fixtures for value in choices):
                findings.append((relative, content.count('\n', 0, match.start()) + 1))
    if (relative.startswith(('backend/internal/', 'backend/cmd/')) and relative.endswith('.go')
            and not relative.startswith(('backend/internal/load/', 'backend/cmd/roster-matrix/',
                                         'backend/cmd/backend-load/'))):
        for match in GO_LOAD.finditer(content):
            findings.append((relative, content.count('\n', 0, match.start()) + 1))
    return findings
