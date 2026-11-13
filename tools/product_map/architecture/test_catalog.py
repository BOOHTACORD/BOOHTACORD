import tempfile
import unittest
from pathlib import Path

from tools.product_map.architecture.catalog import load_system_graph


class SystemCatalogTests(unittest.TestCase):
    def test_system_graph_contains_one_shared_flutter_and_five_client_entries(self):
        root = Path(__file__).resolve().parents[3]
        graph = load_system_graph(root)
        nodes = {node['id']: node for node in graph['nodes']}
        self.assertTrue({'sys.web', 'sys.windows', 'sys.macos', 'sys.android',
                         'sys.ios', 'sys.flutter.shared', 'sys.api', 'sys.livekit',
                         'sys.postgres', 'sys.proxy'} <= nodes.keys())
        self.assertEqual(sum(node['id'] == 'sys.flutter.shared' for node in graph['nodes']), 1)
        edges = {(edge['from'], edge['to'], edge['type']) for edge in graph['edges']}
        for platform in ('windows', 'macos', 'android', 'ios'):
            self.assertIn((f'sys.{platform}', 'sys.flutter.shared', 'runs'), edges)
        self.assertIn(('sys.web', 'sys.livekit', 'media'), edges)
        self.assertIn(('sys.flutter.shared', 'sys.livekit', 'media'), edges)

    def test_duplicate_json_keys_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / 'product-map' / 'architecture'
            folder.mkdir(parents=True)
            (folder / 'system.json').write_text('{"nodes":[],"nodes":[],"edges":[]}', encoding='utf8')
            with self.assertRaisesRegex(ValueError, 'duplicate'):
                load_system_graph(root)
