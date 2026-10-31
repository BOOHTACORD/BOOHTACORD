"""Deduplicate only identical synthetic payloads while preserving every logical file."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from . import captures

PNG = b'\x89PNG\r\n\x1a\n\0\0\0\rIHDR' + (1).to_bytes(4, 'big') * 2 + b'\x08\x06\0\0\0' + b'\0' * 4


def identity():
    return {'repository': 'BOOHTACORD/BOOHTACORD', 'source_revision': 'a' * 40,
            'run_id': '123', 'run_attempt': '1', 'namespace': 'web',
            'component': 'web', 'profile': 'browser-shell', 'platform': 'linux'}


class CapturePackageTests(unittest.TestCase):
    def fixture(self, root):
        source = root / 'source'; source.mkdir()
        (source / 'image.png').write_bytes(PNG)
        (source / 'result.json').write_text('{"status":"PASS","checks":4}\n')
        return {'case/reference.png': source / 'image.png', 'case/actual.png': source / 'image.png',
                'case/result.json': source / 'result.json'}

    def test_same_bytes_have_one_payload_and_every_original_path_restores_exactly(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); files = self.fixture(root); package = root / 'package'
            manifest = captures.pack(files, package, identity())
            self.assertEqual(set(files), set(manifest['files']))
            self.assertEqual(2, len(list((package / 'payload').iterdir())))
            self.assertEqual(manifest, captures.verify(package, identity()))
            destination = root / 'restored'; captures.restore(package, destination, identity())
            self.assertEqual(set(files), {p.relative_to(destination).as_posix() for p in destination.rglob('*') if p.is_file()})
            for name, path in files.items(): self.assertEqual(path.read_bytes(), (destination / name).read_bytes())

    def test_storage_integrity_does_not_turn_a_failed_qa_report_into_a_passing_gate(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); files = self.fixture(root)
            files['case/result.json'].write_text('{"status":"FAIL","reason":"layout_assertion"}')
            manifest = captures.pack(files, root / 'package', identity())
            self.assertEqual('PASS', manifest['integrity'])
            self.assertNotIn('status', manifest)
            captures.restore(root / 'package', root / 'restored', identity())
            self.assertEqual('FAIL', json.loads((root / 'restored/case/result.json').read_text())['status'])

    def test_source_attempt_namespace_or_role_cannot_be_substituted(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); captures.pack(self.fixture(root), root / 'package', identity())
            for key, value in [('source_revision', 'b' * 40), ('run_id', '124'), ('run_attempt', '2'),
                               ('namespace', 'foreign'), ('profile', 'browser-voice'),
                               ('repository', 'Egkurilov/BOOHTACORD'), ('repository', 'fork/repo')]:
                expected = identity(); expected[key] = value
                with self.subTest(field=key), self.assertRaises(ValueError): captures.verify(root / 'package', expected)

    def test_payload_tampering_missing_or_extra_files_fail_before_restore_writes(self):
        for mutation in ('tampered', 'missing', 'extra', 'empty-manifest'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); captures.pack(self.fixture(root), root / 'package', identity())
                payload = next((root / 'package/payload').iterdir())
                if mutation == 'tampered': payload.write_bytes(payload.read_bytes() + b'changed')
                if mutation == 'missing': payload.unlink()
                if mutation == 'extra': (root / 'package/unexpected.json').write_text('{}')
                if mutation == 'empty-manifest': (root / 'package/artifact-manifest.json').write_text('{}')
                with self.assertRaises(ValueError): captures.restore(root / 'package', root / 'restored', identity())
                self.assertFalse((root / 'restored').exists())

    def test_unsafe_logical_paths_or_unexpected_extensions_cannot_publish(self):
        for name in ('../escape.png', '/absolute.png', 'C:/private.png', 'case\\private.png',
                     'case/private.env', 'case/trace.zip', 'case/client.log', 'case/../escape.png'):
            with self.subTest(kind='invalid-path'), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); files = self.fixture(root)
                with self.assertRaises(ValueError): captures.pack({name: files['case/actual.png']}, root / 'package', identity())
                self.assertFalse((root / 'package').exists())

    def test_private_json_and_duplicate_key_masking_never_copy_private_bytes(self):
        examples=['{"token":"private-session-canary"}',
                  '{"token":123}', '{"session":{"value":"private-session-canary"}}',
                  '{"authorization":["private-session-canary"]}',
                  '{"nested":{"authorization":"private-session-canary"}}',
                  '{"token":"private-session-canary","token":null}',
                  '{"error":"eyJ12345678901234567890.abcdefghijklmnop.abcdefghijklmnop"}']
        for text in examples:
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); files = self.fixture(root); files['case/result.json'].write_text(text)
                with self.assertRaises(ValueError) as error: captures.pack(files, root / 'package', identity())
                self.assertNotIn('private-session-canary', str(error.exception))
                self.assertFalse((root / 'package').exists())

    def test_indirect_or_invalid_png_sources_are_not_capture_payloads(self):
        for mutation in ('symlink', 'linked-parent', 'bad-png', 'oversized'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); files = self.fixture(root); image = files['case/actual.png']
                if mutation == 'symlink':
                    target = root / 'external.png'; target.write_bytes(PNG); image.unlink(); image.symlink_to(target)
                elif mutation == 'linked-parent':
                    external = root / 'external'; external.mkdir(); (external / 'image.png').write_bytes(PNG)
                    link = root / 'source/linked'; link.symlink_to(external, target_is_directory=True)
                    files['case/actual.png'] = link / 'image.png'
                elif mutation == 'bad-png': image.write_bytes(b'not a PNG')
                else:
                    with image.open('wb') as stream: stream.seek(16 * 1024 * 1024); stream.write(b'x')
                with self.assertRaises(ValueError): captures.pack(files, root / 'package', identity())
                self.assertFalse((root / 'package').exists())

    def test_existing_destination_is_never_overwritten_or_used_as_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); files = self.fixture(root); output = root / 'occupied'; output.mkdir()
            marker = output / 'keep.txt'; marker.write_text('untouched')
            with self.assertRaises(ValueError): captures.pack(files, output, identity())
            self.assertEqual('untouched', marker.read_text())
            captures.pack(files, root / 'package', identity())
            with self.assertRaises(ValueError): captures.restore(root / 'package', output, identity())
            self.assertEqual('untouched', marker.read_text())

    def test_parent_links_cannot_redirect_pack_or_restore_writes(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); files = self.fixture(root)
            private = root / 'private'; private.mkdir()
            link = root / 'linked'; link.symlink_to(private, target_is_directory=True)
            with patch.object(captures, 'verify', side_effect=AssertionError('Pack wrote before rejecting linked parent')):
                with self.assertRaises(ValueError): captures.pack(files, link / 'package', identity())
            self.assertFalse((private / 'package').exists())
            captures.pack(files, root / 'package', identity())
            with self.assertRaises(ValueError): captures.restore(root / 'package', link / 'restored', identity())
            self.assertFalse((private / 'restored').exists())

    def test_portable_restore_rejects_windows_devices_and_case_or_normalization_aliases(self):
        for names in [('CON.png',), ('nul.json',), ('LPT1.png',), ('folder./image.png',),
                      ('frame /image.png',), ('case/image.png', 'Case/image.png'),
                      ('Case/image.png', 'case/other.png'), ('caf\u00e9/image.png', 'cafe\u0301/image.png'),
                      ('case/image.png', 'case/image.png/other.png')]:
            with self.subTest(kind='nonportable-alias'), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); files = self.fixture(root)
                inputs = {name: files['case/result.json'] if name.endswith('.json') else files['case/actual.png'] for name in names}
                with self.assertRaises(ValueError): captures.pack(inputs, root / 'package', identity())

    def test_manifest_duplicate_keys_unsafe_alias_or_wrong_payload_binding_is_rejected(self):
        for mutation in ('duplicate', 'path', 'payload', 'size', 'status'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); manifest = captures.pack(self.fixture(root), root / 'package', identity())
                path = root / 'package/artifact-manifest.json'
                if mutation == 'duplicate':
                    path.write_text('{"schema_version":99,' + path.read_text().lstrip()[1:])
                else:
                    value = copy.deepcopy(manifest); item = value['files']['case/actual.png']
                    if mutation == 'path': value['files']['../outside.png'] = value['files'].pop('case/actual.png')
                    if mutation == 'payload': item['payload'] = 'payload/foreign.png'
                    if mutation == 'size': item['bytes'] = True
                    if mutation == 'status': value['integrity'] = 'FAIL'
                    path.write_text(json.dumps(value))
                with self.assertRaises(ValueError): captures.verify(root / 'package', identity())

    def test_unknown_identity_fields_or_empty_input_cannot_be_a_successful_package(self):
        for changed in ({**identity(), 'private': 'private-session-canary'},
                        {**identity(), 'source_revision': 'master'}, {**identity(), 'run_attempt': True}):
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); files = self.fixture(root)
                with self.assertRaises(ValueError): captures.pack(files, root / 'package', changed)
                self.assertFalse((root / 'package').exists())
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError): captures.pack({}, Path(tmp).resolve() / 'package', identity())
