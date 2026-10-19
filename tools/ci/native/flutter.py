"""Preserve application, vendor regression and analysis gates in one entrypoint."""
import json
from .process import client, output, require_version, run


def main():
    versions = json.loads(output("flutter", "--version", "--machine"))
    require_version("flutter", versions["frameworkVersion"])
    require_version("dart", versions["dartSdkVersion"].split()[0])
    app = client("flutter")
    run("python3", "-m", "unittest", "tools.verify.test_flutter_webrtc_public_headers")
    run("flutter", "pub", "get", "--enforce-lockfile", cwd=app)
    run("flutter", "test", "--no-pub", cwd=app)
    from tools.ci.flutter_setup.vendor_locks import prepare
    from .process import ROOT
    for package in ("livekit_client", "flutter_webrtc"):
        path = app / "packages" / package
        prepare(ROOT, package)
        run("flutter", "pub", "get", "--enforce-lockfile", cwd=path)
        run("flutter", "test", "--no-pub", cwd=path)
    run("flutter", "analyze", "--no-pub", "--no-fatal-infos", cwd=app)


if __name__ == "__main__":
    main()
