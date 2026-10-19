"""Verify all runnable Actions sources, optionally emitting an inert policy view."""
import argparse
import yaml
from .trust import check, sensitive
from pathlib import Path
from .policy import ROOT, check_source, normalized
from .references import references


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--policy-view', type=Path)
    args = parser.parse_args()
    view = args.policy_view.resolve() if args.policy_view else None
    if view and not view.is_relative_to((ROOT / '.out').resolve()):
        raise ValueError('Normalized policy views may only be written beneath .out')
    paths = sorted((ROOT / '.github/workflows').glob('*.y*ml'))
    composites = sorted((ROOT / '.github/actions').rglob('action.yaml')) + sorted((ROOT / '.github/actions').rglob('action.yml'))
    fixture = ROOT / 'tools/ci/required_gate/proof.yaml'
    approved_local = {'./' + p.relative_to(ROOT).as_posix() for p in paths}
    directories = [p.parent for p in composites]
    if len(set(directories)) != len(directories):
        raise ValueError('Ambiguous local action metadata')
    approved_local.update('./' + p.relative_to(ROOT).as_posix() for p in directories)
    documents = {}
    for path in paths + composites + ([fixture] if fixture.exists() else []):
        if path.is_symlink() or path.resolve() != path.absolute():
            raise ValueError('Indirect runnable Actions source')
        text = path.read_text(encoding='utf-8')
        check_source(text)
        if any(ref.startswith('./') and ref not in approved_local for ref in references(text)):
            raise ValueError('Missing or unreviewed local Actions source')
        document = yaml.load(normalized(text), Loader=yaml.BaseLoader)
        if path in paths:
            documents[path.name] = document
        elif path in composites:
            runs = document.get('runs', {})
            if runs.get('using') != 'composite' or sensitive(document) or not runs.get('steps'):
                raise ValueError('Reviewed secret-free local composite required')
            for step in runs['steps']:
                if step.get('continue-on-error') not in (None, False, 'false'):
                    raise ValueError('Local action failures cannot be ignored')
                if step.get('uses', '').startswith('actions/checkout@') and step.get('with', {}).get('persist-credentials') != 'false':
                    raise ValueError('Local checkout credentials cannot persist')
    check(documents)
    flutter_action = ROOT / ".github/actions/flutter-setup/action.yaml"
    if flutter_action in composites:
        from tools.ci.flutter_setup.workflow import validate
        validate(yaml.load(flutter_action.read_text(), Loader=yaml.BaseLoader), ROOT)
    if view:
        view.mkdir(parents=True, exist_ok=True)
        for path in paths:
            (view / path.name).write_text(normalized(path.read_text()), encoding='utf-8')
    print('Reviewed full action commits: OK (' + str(len(paths)) + ' workflows, ' + str(len(composites)) + ' local actions)')


if __name__ == '__main__':
    main()
