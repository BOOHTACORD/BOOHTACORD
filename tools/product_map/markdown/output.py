"""Write the derived Markdown set without deleting unexpected files."""
from .render import render_feature, render_index


def write_markdown(root, features, *, check):
    folder = root / 'features'
    if root.is_symlink() or folder.is_symlink():
        raise ValueError('generated Markdown directory is a symlink')
    index = render_index(features)
    documents = {root / 'index.md': index}
    for feature in features:
        content = render_feature(feature)
        documents[folder / (feature['id'] + '.md')] = content
    present = set(folder.glob('*.md')) if folder.is_dir() else set()
    expected = set(documents) - {root / 'index.md'}
    if present - expected:
        if check:
            return False
        raise ValueError('orphan generated Markdown feature files require review')
    for path in documents:
        if path.is_symlink():
            raise ValueError('generated Markdown file is a symlink')
    if check:
        return all(path.is_file() and path.read_text(encoding='utf-8') == content
                   for path, content in documents.items())
    folder.mkdir(parents=True, exist_ok=True)
    for path, content in documents.items():
        path.write_text(content, encoding='utf-8', newline='\n')
    return True
