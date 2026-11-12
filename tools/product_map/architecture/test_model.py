import tempfile
import unittest
from pathlib import Path

from tools.product_map.architecture.model import validate_graph


def graph():
    return {'nodes': [
        {'id': 'sys.flutter.shared', 'label': 'Flutter', 'kind': 'shared_component',
         'path': 'src/flutter.dart', 'x': 200, 'y': 100},
        {'id': 'sys.windows', 'label': 'Windows', 'kind': 'platform_adapter',
         'path': 'src/windows.cpp', 'x': 20, 'y': 100}],
        'edges': [{'from': 'sys.windows', 'to': 'sys.flutter.shared', 'type': 'runs'}]}


class SystemGraphTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'src').mkdir()
        for name in ('flutter.dart', 'windows.cpp'):
            (self.root / 'src' / name).write_text('source', encoding='utf-8')

    def test_rejects_nodes_outside_the_view_box(self):
        for x, y in [(1021, 0), (0, 665)]:
            data = graph()
            data['nodes'][0].update(x=x, y=y)
            with self.subTest(x=x, y=y), self.assertRaises(ValueError):
                validate_graph(data, self.root)

    def test_valid_graph_and_duplicate_dangling_edges_rejected(self):
        data = graph()
        validate_graph(data, self.root)
        data['edges'].append(dict(data['edges'][0]))
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            validate_graph(data, self.root)
        data = graph()
        data['edges'][0]['to'] = 'sys.missing'
        with self.assertRaisesRegex(ValueError, 'edge'):
            validate_graph(data, self.root)

    def test_rejects_unsafe_path_kind_and_unbounded_coordinates(self):
        for key, value in [('path', '../secrets'), ('kind', 'invented'), ('x', -1), ('y', True)]:
            data = graph()
            data['nodes'][0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_graph(data, self.root)

    def test_rejects_malformed_and_empty_nodes_and_edges(self):
        for data in ({'nodes': [], 'edges': []}, {'nodes': [None], 'edges': []},
                     {'nodes': graph()['nodes'], 'edges': [None]},
                     {'nodes': graph()['nodes'], 'edges': [{'from': [], 'to': 'sys.windows', 'type': 'runs'}]}):
            with self.subTest(data=data), self.assertRaises(ValueError):
                validate_graph(data, self.root)

    def test_supports_contract_and_evidence_nodes_with_typed_edges(self):
        data = graph()
        data['nodes'].extend([
            {'id': 'sys.contract', 'label': 'Contract', 'kind': 'contract',
             'path': 'src/flutter.dart', 'x': 300, 'y': 100},
            {'id': 'sys.test', 'label': 'Test', 'kind': 'test_evidence',
             'path': 'src/windows.cpp', 'x': 400, 'y': 100},
        ])
        data['edges'].extend([
            {'from': 'sys.flutter.shared', 'to': 'sys.contract', 'type': 'calls'},
            {'from': 'sys.flutter.shared', 'to': 'sys.test', 'type': 'verified_by'},
        ])
        validate_graph(data, self.root)

    def test_rejects_control_characters_in_source_paths(self):
        data = graph()
        data['nodes'][0]['path'] = 'src/flutter.dart\n'
        with self.assertRaises(ValueError):
            validate_graph(data, self.root)
