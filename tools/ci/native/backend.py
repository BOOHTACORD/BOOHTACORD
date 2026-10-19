"""Run mandatory database, no-skip test, vet and compilation gates."""
import sys
from .process import ROOT, output, require_version, run


def run_profile(profile):
    backend = ROOT / "backend"
    if profile == 'static':
        run("go", "vet", "./...", cwd=backend)
        run("go", "build", "./...", cwd=backend)
        return
    if profile != 'database':
        raise ValueError('Unknown backend profile')
    run("go", "run", "./cmd/check-test-database", cwd=backend)
    destination = ROOT / ".out/checks"
    destination.mkdir(parents=True, exist_ok=True)
    events = destination / "backend.jsonl"
    with events.open("w", encoding="utf-8") as stream:
        result = run("go", "test", "-json", "-count=1", "./...", cwd=backend, stdout=stream, check=False)
    verified = run(sys.executable, "tools/verify/go_test_events/verify-go-test-events.py", str(events), check=False)
    if result.returncode or verified.returncode:
        raise SystemExit(1)


def main():
    require_version("go", output("go", "version", cwd=ROOT / "backend").split()[2].removeprefix("go"))
    run_profile('database')
    run_profile('static')


if __name__ == "__main__":
    main()
