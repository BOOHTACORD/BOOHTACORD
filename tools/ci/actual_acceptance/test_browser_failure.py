"""The public browser failure boundary retains coordinates, never private strings."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from .evidence import collect_failure


def context():
    return dict(schema_version=1, status='FAIL', stage='navigation', failure_type='AssertionError',
                frames=[dict(module='navigation.mjs', line=65, column=10)])


def dom():
    return dict(main_history_visible=True, context_visible=False, saved_position_context=False,
                main_rendered_rows=12, main_reply_previews=1, context_rows=0,
                viewport=dict(scrollTop=100, scrollHeight=1000, clientHeight=500))


class BrowserFailureTests(unittest.TestCase):
    def test_retains_finite_context_safe_dom_and_original_png_without_logs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary).resolve(); folder=root/'.out/next-client-acceptance'; folder.mkdir(parents=True)
            (folder/'browser-failure.json').write_text(json.dumps(context()))
            (folder/'failure.json').write_text(json.dumps(dom()))
            # Original tiny valid PNG, not a generated substitute in actual CI evidence.
            import base64
            png=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
            (folder/'failure.png').write_bytes(png)
            (folder/'private.log').write_text('PRIVATE-CANARY')
            destination=root/'public'
            rows=collect_failure(root,'next',destination)
            self.assertEqual(len(rows),3)
            self.assertEqual(json.loads((destination/'diagnostics/next-browser.json').read_text()),context())
            self.assertEqual(json.loads((destination/'diagnostics/next-dom.json').read_text()),dom())
            self.assertEqual((destination/'diagnostics/next-browser.png').read_bytes(),png)
            for row in rows:
                self.assertEqual(hashlib.sha256((destination/row['path']).read_bytes()).hexdigest(),row['sha256'])
            self.assertFalse(list(destination.rglob('*.log')))

    def test_context_only_survives_unavailable_page_without_invented_dom_or_screenshot(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary).resolve(); folder=root/'.out/next-client-acceptance'; folder.mkdir(parents=True)
            (folder/'browser-failure.json').write_text(json.dumps(context()))
            self.assertEqual(len(collect_failure(root,'next',root/'public')),1)

    def test_private_fields_invalid_coordinates_and_links_are_rejected(self):
        for case in ('private','module','line','bool-line','too-many','duplicate','symlink','bad-dom','bad-png'):
            with tempfile.TemporaryDirectory() as temporary, self.subTest(case=case):
                root=Path(temporary).resolve(); folder=root/'.out/next-client-acceptance'; folder.mkdir(parents=True)
                value=context()
                if case=='private': value['message']='PRIVATE-CANARY'
                if case=='module': value['frames'][0]['module']='../private.mjs'
                if case=='line': value['frames'][0]['line']=-1
                if case=='bool-line': value['frames'][0]['line']=True
                if case=='too-many': value['frames']*=9
                path=folder/'browser-failure.json'; path.write_text(json.dumps(value))
                if case=='duplicate': path.write_text('{"stage":"PRIVATE-CANARY",'+json.dumps(value)[1:])
                if case=='symlink': path.rename(root/'foreign.json'); path.symlink_to(root/'foreign.json')
                if case=='bad-dom': (folder/'failure.json').write_text(json.dumps(dict(dom(), message='PRIVATE-CANARY')))
                if case=='bad-png': (folder/'failure.png').write_text('PRIVATE-CANARY')
                with self.assertRaises(ValueError): collect_failure(root,'next',root/'public')
