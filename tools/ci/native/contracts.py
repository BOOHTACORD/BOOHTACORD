"""Execute the project-owned contract and traceability checks."""
import sys
from .process import run


def main():
    run(sys.executable, "-m", "tools.verify.toolchains.check")
    run(sys.executable, "-m", "tools.verify.python_tests.run")
    run(sys.executable, "-m", "tools.verify.realtime_migration.guard")
    run(sys.executable, "-m", "tools.verify.dependencies.dart")
    run(sys.executable, "-m", "tools.verify.links.check")
    run(sys.executable, "-m", "tools.verify.compose_layout.check")
    run(sys.executable, "-m", "tools.verify.writer_topology.check")
    for capability, name in (("contracts", "verify-contracts"), ("spec_traceability", "verify-spec-traceability"),
                             ("github_workflows", "verify-github-workflows"), ("ci_sbom", "verify-ci-sbom")):
        run("pwsh", "-NoProfile", "-File", f"tools/verify/{capability}/{name}.ps1")
    run("docker", "compose", "--env-file", ".env.example", "-f", "deploy/compose.yaml", "config", "--quiet")
    for capability, name in (("otel_egress", "verify-otel-egress"), ("compose_images", "verify-compose-images")):
        run("pwsh", "-NoProfile", "-File", f"tools/verify/{capability}/{name}.ps1")


if __name__ == "__main__":
    main()
