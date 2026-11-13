import tempfile
import unittest
from pathlib import Path

from tools.verify.realtime_migration.guard import scan
from tools.verify.realtime_migration.fixture_imports import imports_of_fixtures


class FixtureImportTests(unittest.TestCase):
    def test_import_forms_and_explicit_non_test_fixture(self):
        fixture = 'clients/web/src/known.ts'
        content = "import './known';\nexport * from './x.test';\nrequire('./y.spec');\n"
        self.assertEqual(imports_of_fixtures('clients/web/src/app.ts', content, {fixture}),
                         [('clients/web/src/app.ts', 1), ('clients/web/src/app.ts', 2),
                          ('clients/web/src/app.ts', 3)])
        dart = "import 'package:boohtacord_desktop/src/fixture_test.dart';\n"
        self.assertEqual(imports_of_fixtures('clients/flutter/lib/app.dart', dart, {}),
                         [('clients/flutter/lib/app.dart', 1)])

    def test_runtime_cannot_import_test_modules_or_legacy_load_packages(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            files = {
                'clients/web/src/app.ts': "import './legacy.spec'\n",
                'clients/web/src/legacy.spec.ts': 'export const fixture = 1\n',
                'clients/flutter/lib/src/app.dart': "import 'fixture_test.dart';\n",
                'clients/flutter/lib/src/fixture_test.dart': 'const fixture = 1;\n',
                'backend/internal/app/route.go': 'import "voice-platform/backend/internal/load/roster_matrix"\n',
                'backend/cmd/roster-matrix/main.go': 'import "voice-platform/backend/internal/load/roster_matrix"\n',
                'clients/web/src/other.test.ts': "import './legacy.spec'\n",
            }
            for name, contents in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(contents, encoding='utf8')
            self.assertEqual(set(scan(root)), {
                ('clients/web/src/app.ts', 1),
                ('clients/flutter/lib/src/app.dart', 1),
                ('backend/internal/app/route.go', 1),
            })


if __name__ == '__main__':
    unittest.main()
