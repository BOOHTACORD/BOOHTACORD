import subprocess
import tempfile
import unittest
from pathlib import Path
from .dart import discover_sources, violations


class DartImportTests(unittest.TestCase):
    def test_missing_local_dependency_is_visible_before_clean_checkout(self):
        sources = {'clients/flutter/lib/src/services/api.dart': "import '../features/attachments/api.dart';"}
        self.assertIn('absent or ignored', violations(sources)[0])
        sources['clients/flutter/lib/src/features/attachments/api.dart'] = "import 'dart:io';"
        self.assertEqual(violations(sources), [])

    def test_package_import_resolves_to_the_single_flutter_project(self):
        sources = {'clients/flutter/test/api_test.dart': "import 'package:boohtacord_desktop/src/api.dart';",
                   'clients/flutter/lib/src/api.dart': "import 'package:http/http.dart';"}
        self.assertEqual(violations(sources), [])

    def test_feature_owner_cannot_depend_on_app_state(self):
        sources = {'clients/flutter/lib/src/features/voice/controller.dart': "import '../../app_state.dart';",
                   'clients/flutter/lib/src/app_state.dart': ''}
        self.assertIn('depends on application UI', violations(sources)[0])

    def test_feature_cannot_bypass_facade_by_importing_composition(self):
        sources = {'clients/flutter/lib/src/features/voice/controller.dart': "import '../../app/composition/owners.dart';",
                   'clients/flutter/lib/src/app/composition/owners.dart': ''}
        self.assertIn('depends on application UI', violations(sources)[0])


class DartSourceDiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)

    def write(self, name, source, tracked=False):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding='utf-8')
        if tracked:
            subprocess.run(['git', 'add', '--', name], cwd=self.root, check=True)

    def test_tracked_qa_dependency_and_transitive_cycle_are_discovered(self):
        self.write('clients/flutter/test/codec_test.dart',
                   "import '../../../tools/qa/codec/driver.dart';", tracked=True)
        self.write('tools/qa/codec/driver.dart', "export 'caps.dart';", tracked=True)
        self.write('tools/qa/codec/caps.dart',
                   "import 'driver.dart';\nimport 'package:boohtacord_desktop/src/api.dart';", tracked=True)
        self.write('clients/flutter/lib/src/api.dart', "import 'dart:async';", tracked=True)
        # This tracked QA entry is copied into a private build before use; it is
        # not an import edge of the checked Flutter lib/test project.
        self.write('tools/qa/unrelated/private_test.dart',
                   "import '../integration_test/private.dart';", tracked=True)
        sources = discover_sources(self.root)
        self.assertEqual(violations(sources), [])
        self.assertIn('tools/qa/codec/caps.dart', sources)
        self.assertNotIn('tools/qa/unrelated/private_test.dart', sources)

    def test_nonignored_qa_dependency_is_checked_before_staging(self):
        self.write('clients/flutter/test/codec_test.dart',
                   "import '../../../tools/qa/codec/driver.dart';")
        self.write('tools/qa/codec/driver.dart', "import 'dart:async';")
        self.assertEqual(violations(discover_sources(self.root)), [])
        self.assertIn('tools/qa/codec/driver.dart', discover_sources(self.root))

    def test_existing_ignored_qa_dependency_is_not_accepted(self):
        self.write('.gitignore', 'tools/qa/codec/ignored.dart\n', tracked=True)
        self.write('clients/flutter/test/codec_test.dart',
                   "import '../../../tools/qa/codec/ignored.dart';", tracked=True)
        self.write('tools/qa/codec/ignored.dart', '')
        sources = discover_sources(self.root)
        self.assertNotIn('tools/qa/codec/ignored.dart', sources)
        self.assertIn('absent or ignored', violations(sources)[0])

    def test_missing_transitive_qa_dependency_is_rejected(self):
        self.write('clients/flutter/test/codec_test.dart',
                   "import '../../../tools/qa/codec/driver.dart';", tracked=True)
        self.write('tools/qa/codec/driver.dart', "part 'missing.dart';", tracked=True)
        errors = violations(discover_sources(self.root))
        self.assertEqual(len(errors), 1)
        self.assertIn('tools/qa/codec/missing.dart', errors[0])

    def test_deleted_tracked_dependency_remains_absent(self):
        self.write('clients/flutter/test/codec_test.dart',
                   "import '../../../tools/qa/codec/driver.dart';", tracked=True)
        self.write('tools/qa/codec/driver.dart', '', tracked=True)
        (self.root / 'tools/qa/codec/driver.dart').unlink()
        self.assertIn('absent or ignored', violations(discover_sources(self.root))[0])

    def test_production_lib_cannot_import_even_a_tracked_qa_adapter(self):
        self.write('clients/flutter/lib/src/api.dart',
                   "import '../../../../tools/qa/codec/driver.dart';", tracked=True)
        self.write('tools/qa/codec/driver.dart', '', tracked=True)
        errors = violations(discover_sources(self.root))
        self.assertEqual(len(errors), 1)
        self.assertIn('production Dart imports QA', errors[0])

    def test_test_imports_owned_integration_helper_and_checks_its_dependencies(self):
        self.write('clients/flutter/test/storage_test.dart',
                   "import '../integration_test/desktop_updates/scoped_storage.dart';", tracked=True)
        self.write('clients/flutter/integration_test/desktop_updates/scoped_storage.dart',
                   "import 'package:boohtacord_desktop/src/api.dart';", tracked=True)
        self.write('clients/flutter/lib/src/api.dart', "import 'dart:io';", tracked=True)
        self.assertEqual(violations(discover_sources(self.root)), [])

    def test_production_must_not_import_integration_acceptance_helpers(self):
        self.write('clients/flutter/lib/main.dart',
                   "import '../integration_test/desktop_updates/scoped_storage.dart';", tracked=True)
        self.write('clients/flutter/integration_test/desktop_updates/scoped_storage.dart', '', tracked=True)
        self.assertTrue(any('production Dart imports QA' in error
                            for error in violations(discover_sources(self.root))))
