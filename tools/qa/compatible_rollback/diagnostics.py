"""Allowlisted failure facts; never export raw private build/runtime logs."""
import ast
import re


def public_guards(root):
    messages = set()
    for directory in ('tools/release', 'tools/build', 'tools/audio', 'tools/verify/oci'):
        for path in (root / directory).rglob('*.py'):
            for node in ast.walk(ast.parse(path.read_text())):
                if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                    index = 1 if node.func.id == 'require' else 0 if node.func.id in ('ValueError', 'RuntimeError') else None
                    if index is not None and len(node.args) > index and isinstance(node.args[index], ast.Constant) and isinstance(node.args[index].value, str):
                        messages.add(node.args[index].value)
    return messages


def diagnose(text, messages):
    frames = []
    for path, line, function in re.findall(r'File "([^"]+)", line (\d+), in ([\w<>]+)', text):
        relative = ''
        for prefix in ('/qa/current/', '/qa/previous/', '/qa-tools/'):
            if path.startswith(prefix):
                relative = path.removeprefix(prefix)
                break
        if re.fullmatch(r'(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+\.py', relative):
            frames.append({'file': relative, 'line': int(line), 'function': function})
    guards = re.findall(r'(?:ValueError|RuntimeError): ([^\n]*)', text)
    return {'frames': frames[-16:], 'guard_messages': sorted({m.strip() for m in guards if m.strip() in messages}),
            'exit_codes': sorted({int(n) for n in re.findall(r'(?:exit code: |non-zero exit status )(\d+)', text)}),
            'memory_exhaustion': 'out of memory' in text.lower() or 'signal: killed' in text.lower(),
            'disk_exhaustion': 'no space left on device' in text.lower(),
            'address_collision': 'address already in use' in text.lower(),
            'registry_failure': 'failed to resolve source metadata' in text.lower()}
