from .importer import PLATFORMS


def compare(features, left, right):
    if left not in PLATFORMS or right not in PLATFORMS or left == right:
        raise ValueError('Select two different client platforms')
    return [{'id': row['id'], left: row['platforms'][left],
             right: row['platforms'][right]} for row in features]
