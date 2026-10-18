"""Verify all runnable Actions sources, optionally emitting an inert policy view."""
import argparse
import yaml
from .trust import check
from pathlib import Path
from .policy import ROOT, check_source, normalized


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--policy-view', type=Path)
    args = parser.parse_args()
    view = args.policy_view.resolve() if args.policy_view else None
    if view and not view.is_relative_to((ROOT / '.out').resolve()):
        raise ValueError('Normalized policy views may only be written beneath .out')
    paths = sorted((ROOT / '.github/workflows').glob('*.y*ml'))
    fixture = ROOT / 'tools/ci/required_gate/proof.yaml'
    documents = {}
    for path in paths + ([fixture] if fixture.exists() else []):
        text = path.read_text(encoding='utf-8')
        check_source(text)
        if path in paths:
            documents[path.name] = yaml.load(normalized(text), Loader=yaml.BaseLoader)
    check(documents)
    if view:
        view.mkdir(parents=True, exist_ok=True)
        for path in paths:
            (view / path.name).write_text(normalized(path.read_text()), encoding='utf-8')
    print('Reviewed full action commits: OK (' + str(len(paths)) + ' workflows)')


if __name__ == '__main__':
    main()
