import tempfile
import unittest
from pathlib import Path

from tools.product_map.markdown.architecture import render_architecture, write_architecture


def graph():
    return {'nodes': [
        {'id': 'sys.a', 'label': '<script>bad</script>', 'path': 'clients/web/src/main.ts'},
        {'id': 'sys.b', 'label': 'Flutter', 'path': 'clients/flutter/lib/main.dart'}],
        'edges': [{'from': 'sys.a', 'to': 'sys.b', 'type': 'calls'}]}


class ArchitectureMarkdownTests(unittest.TestCase):
    def test_safe_deterministic_links_and_readable_connections(self):
        content = render_architecture(graph())
        self.assertNotIn('<script>', content)
        self.assertIn('../../../clients/web/src/main.ts', content)
        self.assertIn('sys.a', content)
        self.assertIn('sys.b', content)
        self.assertIn('calls', content)
        self.assertEqual(content, render_architecture(graph()))

    def test_rejects_unsafe_paths(self):
        for unsafe in ('../../secret', 'https://evil', '/absolute', 'a\\b', 'a\nsource'):
            item = graph()
            item['nodes'][0]['path'] = unsafe
            with self.subTest(unsafe=unsafe), self.assertRaises(ValueError):
                render_architecture(item)

    def test_generation_check_detects_missing_and_stale_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'architecture.md'
            self.assertFalse(write_architecture(path, graph(), check=True))
            self.assertTrue(write_architecture(path, graph(), check=False))
            self.assertTrue(write_architecture(path, graph(), check=True))
            path.write_text('stale', encoding='utf-8')
            self.assertFalse(write_architecture(path, graph(), check=True))
