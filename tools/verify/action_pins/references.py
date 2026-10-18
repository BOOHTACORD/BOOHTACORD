"""Read every YAML uses value, including quoted keys, flow style and folded scalars."""
import yaml


def references(source):
    try:
        document = yaml.load(source, Loader=yaml.BaseLoader)
    except yaml.YAMLError as error:
        raise ValueError('Invalid Actions YAML') from error
    pending = [document]
    count = 0
    while pending:
        count += 1
        if count > 100_000:
            raise ValueError('Actions YAML nesting/alias expansion exceeds policy bound')
        node = pending.pop()
        if isinstance(node, dict):
            if 'uses' in node:
                if not isinstance(node['uses'], str):
                    raise ValueError('Action reference must be a literal scalar')
                yield node['uses']
            pending.extend(node.values())
        elif isinstance(node, list):
            pending.extend(node)
