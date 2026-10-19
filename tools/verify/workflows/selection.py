"""Validate CI dependency edges independently of job and display-step names."""
from pathlib import Path
import yaml
from . import required

GATES = {'ci-backend.yaml': 'backend', 'ci-frontend.yaml': 'web',
         'ci-flutter.yaml': 'flutter', 'flutter-windows.yaml': 'windows', 'ci-actual-acceptance.yaml': 'actual'}


def require(value, message):
    if not value:
        raise ValueError(message)


def check(document):
    jobs = document['jobs']
    selectors = [name for name, job in jobs.items() if any(
        step.get('run') == 'python3 -m tools.ci.select_changes.run' for step in job.get('steps', []))]
    require(len(selectors) == 1, 'Exactly one change selector is required')
    selector = selectors[0]
    seen, roles = set(), {'changes': selector}
    for job_name, job in jobs.items():
        workflow = job.get('uses', '').rsplit('/', 1)[-1]
        if workflow == 'ci-contracts.yaml':
            from tools.ci.master_quality.workflow import PR_SCOPE
            require(job.get('if') in (None, PR_SCOPE), 'Contract/traceability policy must always run on PR and merge queue')
            seen.add('contracts')
            roles['contracts'] = job_name
        if workflow in GATES:
            gate = GATES[workflow]
            needs = job.get('needs', [])
            needs = [needs] if isinstance(needs, str) else needs
            require(selector in needs, f'{gate} must wait for change selection')
            require(job.get('if') == f"needs.{selector}.outputs.{gate + '_required' if gate == 'actual' else gate} == 'true'", f'{gate} must follow its selection')
            seen.add(gate)
            roles[gate] = job_name
    require(seen == {'contracts', *GATES.values()}, 'Missing a required native/contract gate')
    required.check(document, roles, require)
    require(document['concurrency']['cancel-in-progress'] == 'true', 'Stale CI checks should be cancellable')


def main():
    root = Path(__file__).resolve().parents[3]
    document = yaml.load((root / '.github/workflows/ci.yaml').read_text(encoding='utf-8'), Loader=yaml.BaseLoader)
    check(document)
    print('CI component selection and dependency edges: OK')


if __name__ == '__main__':
    main()
