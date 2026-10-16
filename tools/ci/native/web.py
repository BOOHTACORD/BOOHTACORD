"""Identical locked web check for developers and CI."""
import os
import sys
from tools.audio.asset_build import build_assets
from tools.audio.livekit_fixture import IMAGE, local_sfu
from .process import ROOT, client, output, require_version, run


def main():
    require_version("node", output("node", "--version").removeprefix("v"))
    run(sys.executable, "-m", "tools.audio.native_tests.run")
    build_assets(ROOT)
    run("npm", "ci", cwd=client("web"))
    run("node", "--test", "tools/audio/browser_fixture/html.test.mjs")
    run("node", "--test", "tools/verify/dependencies/web_imports.test.mjs")
    run(sys.executable, "-m", "tools.verify.dependencies.web")
    run(sys.executable, "-m", "tools.verify.uiux_visual_matrix")
    run("npm", "test", cwd=client("web"))
    run("npm", "run", "test:accessibility", cwd=client("web"))
    run("npm", "run", "test:responsive-shell", cwd=client("web"))
    run("npm", "run", "test:controls", cwd=client("web"))
    run("npm", "run", "test:microcopy", cwd=client("web"))
    run("npm", "run", "test:chat-rhythm", cwd=client("web"))
    run("npm", "run", "test:message-social", cwd=client("web"))
    run("npm", "run", "test:navigation", cwd=client("web"))
    run("npm", "run", "test:screen-profile", cwd=client("web"))
    run("npm", "run", "test:member-popover", cwd=client("web"))
    run("npm", "run", "test:password-generation", cwd=client("web"))
    run("npm", "run", "test:own-sessions", cwd=client("web"))
    run("npm", "run", "test:delivery", cwd=client("web"))
    run("npm", "run", "test:guild-lifecycle", cwd=client("web"))
    run("npm", "run", "test:voice-shortcuts", cwd=client("web"))
    run("npm", "run", "test:voice-disconnect-notice", cwd=client("web"))
    run("npm", "run", "test:audio:quality", cwd=client("web"))
    with local_sfu():
        smoke_env = os.environ.copy()
        smoke_env["SCREEN_SHARE_SFU_URL"] = "ws://127.0.0.1:17880"
        smoke_env["SCREEN_SHARE_SFU_IMAGE"] = IMAGE
        run("npm", "run", "test:screen-profile-sfu", cwd=client("web"), env=smoke_env)
        run("npm", "run", "test:audio:browser", cwd=client("web"))
    run(sys.executable, "-m", "tools.network.restricted.run")
    run("npm", "run", "build", cwd=client("web"))
    run("npm", "run", "verify:social-preview", cwd=client("web"))


if __name__ == "__main__":
    main()
