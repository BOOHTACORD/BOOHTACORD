"""Check tracked documentation links and repository evidence references in the task graph."""
import posixpath
import json
import subprocess
from pathlib import Path
import yaml
from .markdown import targets
from .evidence import references

VENDORED = ('clients/flutter/packages/', 'backend/vendor/', 'tools/audio/runtime_assets/')


def local_target(owner, target):
    return posixpath.normpath(posixpath.join(posixpath.dirname(owner), target))


def check_links(sources, paths):
    errors = []
    for owner, source in sources.items():
        for uri in targets(source):
            target = local_target(owner, uri)
            if target.startswith('../') or target not in paths:
                errors.append(f'{owner}: missing repository link: {uri}')
    return errors


def task_references(data):
    yield from data.get('action_catalog', {}).values()
    for task in data.get('tasks', []):
        for value in task.get('evidence', []):
            if '/' in value and not value.startswith(('http:', 'https:')):
                yield value


def main():
    root = Path(__file__).resolve().parents[3]
    names = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=root).decode().split('\0')
    files = {name for name in names if name and (root / name).is_file()}
    paths = files | {str(parent).replace('\\', '/') for name in files for parent in Path(name).parents}
    # Vendored package docs describe their upstream repository, not this project.
    documents = {name: (root / name).read_text(encoding='utf-8') for name in files
                 if name.endswith('.md') and not name.startswith(VENDORED)}
    errors = check_links(documents, paths)
    tasks = yaml.safe_load((root / 'backlog/tasks.yaml').read_text(encoding='utf-8'))
    errors += [f'backlog/tasks.yaml: missing evidence reference: {path}'
               for path in task_references(tasks) if path not in paths]
    for name in files:
        if name.startswith('evidence/') and name.endswith('.json'):
            record = json.loads((root / name).read_text(encoding='utf-8-sig'))
            errors += [f'{name}: missing document/evidence reference: {path}'
                       for path in references(record) if path not in paths]
    if errors:
        raise RuntimeError('\n'.join(sorted(set(errors))))
    print(f'Documentation links and task evidence references: OK ({len(documents)} documents)')


if __name__ == '__main__':
    main()
