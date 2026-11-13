"""Read the bounded source-linked system topology without inferring status."""
from tools.product_map.serialization.strict_json import parse_record
from .model import validate_graph


def load_system_graph(root):
    root = root.resolve()
    path = root / 'product-map/architecture/system.json'
    if not path.resolve().is_relative_to(root) or not path.is_file():
        raise ValueError('missing or external system topology')
    if path.stat().st_size > 4_000_000:
        raise ValueError('system topology is too large')
    graph = parse_record(path.read_bytes())
    validate_graph(graph, root)
    return graph
