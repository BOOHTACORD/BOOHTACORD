"""Review prompts; semantics cannot safely be inferred from filenames alone."""


def obligations(paths):
    result = {
        'Contracts': ('BLOCKED', 'Review schemas, consumers and fixtures; run python -m tools.ci.native.contracts'),
        'Traceability': ('BLOCKED', 'If applicable: pwsh -NoProfile -File tools/verify/spec_traceability/verify-spec-traceability.ps1'),
        'Evidence': ('BLOCKED', 'Review whether POC, integration, load or release work requires an evidence record'),
        'Generated': ('BLOCKED', 'Review generated state, including python -m tools.observability.signal_catalog.build --check if applicable'),
        'Dependencies': ('BLOCKED', 'Review lockfiles; if applicable run npm ci --prefix clients/web --ignore-scripts or python -m tools.verify.dependencies.dart'),
        'Client checks': ('BLOCKED', 'If applicable run ./tools/qa/local_features/check.sh --feature <feature> --base <base-ref> --real-stack'),
    }
    return {name: {'status': status, 'action': action} for name, (status, action) in result.items()}


def suspicious(path):
    parts = path.lower().split('/')
    name = parts[-1]
    return ('.out' in parts or name == '.env' or (name.startswith('.env.') and name != '.env.example')
            or name.endswith(('.pem', '.key', '.p12', '.pfx')) or 'node_modules' in parts
            or any(part in ('secrets', '.ssh', '.aws') for part in parts))
