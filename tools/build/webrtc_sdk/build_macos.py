#!/usr/bin/env python3
"""Build and install BOOHTACORD's pinned macOS WebRTC framework for SwiftPM."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess


REPO = Path(__file__).resolve().parents[3]
PLUGIN = REPO / "clients/flutter/packages/flutter_webrtc"
MANIFEST = PLUGIN / "third_party/apple-sdk.json"


def run(args, cwd, env=None):
    print("+ " + " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=cwd, env=env, check=True)


def revision(path):
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=path, text=True
    ).strip()


def checkout(url, commit, path):
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        run(["git", "clone", "--depth", "1", url, path], REPO)
    if revision(path) != commit:
        if subprocess.check_output(["git", "status", "--porcelain"], cwd=path):
            raise RuntimeError(f"Refusing to replace modified checkout: {path}")
        run(["git", "fetch", "--depth", "1", "origin", commit], path)
        run(["git", "checkout", "--detach", "FETCH_HEAD"], path)


def apply_patch(source, patch):
    already_applied = subprocess.run(
        ["git", "apply", "--reverse", "--check", str(patch)],
        cwd=source, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode == 0
    if not already_applied:
        run(["git", "apply", "--check", patch], source)
        run(["git", "apply", patch], source)


def gn_args(architecture, deployment_target, tests=False):
    return " ".join([
        'target_os="mac"', f'target_cpu="{architecture}"',
        f'mac_deployment_target="{deployment_target}"',
        "is_component_build=false", "is_debug=false", "dcheck_always_on=true",
        "enable_dsyms=false", "enable_stripping=true", "enable_libaom=true",
        "rtc_build_examples=false", "rtc_enable_protobuf=false",
        "rtc_enable_symbol_export=true", "rtc_use_h264=false",
        "rtc_include_dav1d_in_internal_decoder_factory=true",
        "rtc_libvpx_build_vp9=true", "use_rtti=true", "use_siso=false",
        # Xcode 27 TAPI targets require Apple's linker rather than m150's LLD.
        "use_lld=false",
        "rtc_include_tests=" + str(tests).lower(),
    ])


def verify_installed(settings):
    destination = PLUGIN / "macos/flutter_webrtc/Binary"
    info = json.loads((destination / "sdk.json").read_text())
    for key in ("version", "source_revision", "depot_tools_revision"):
        if info[key] != settings[key]:
            raise RuntimeError(f"Installed SDK does not match {key}; rebuild it")
    for key in ("routing_patch", "test_patch"):
        patch = PLUGIN / "third_party" / settings[key]
        if info["patch_sha256"][patch.name] != hashlib.sha256(patch.read_bytes()).hexdigest():
            raise RuntimeError(f"Installed SDK does not match {patch.name}; rebuild it")
    binary = next((destination / "WebRTC.xcframework").glob("*/WebRTC.framework/WebRTC"))
    if info["binary_sha256"] != hashlib.sha256(binary.read_bytes()).hexdigest():
        raise RuntimeError("Installed SDK binary checksum differs; rebuild it")
    print(f"Verified {settings['version']}: {binary}", flush=True)


def build(source, output, architecture, settings, jobs, env, tests=False):
    run(["gn", "gen", output, "--args=" + gn_args(
        architecture, settings["deployment_target"], tests)], source, env)
    target = "audio_engine_tests" if tests else "mac_framework_bundle"
    run(["ninja", "-C", output, target, "-j", jobs], source, env)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", type=Path, default=REPO / ".out/webrtc-sdk")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--test", action="store_true",
                        help="Run the native AudioSendStream regression suite first")
    parser.add_argument("--verify", action="store_true",
                        help="Verify the installed SDK against its pinned inputs and binary checksum")
    args = parser.parse_args()
    if platform.system() != "Darwin":
        parser.error("This builder requires macOS and Xcode")
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    settings = json.loads(MANIFEST.read_text())
    if args.verify:
        verify_installed(settings)
        return
    work = args.work_dir.resolve()
    source = work / "webrtc/src"
    depot = work / "depot_tools"
    checkout(settings["depot_tools_url"], settings["depot_tools_revision"], depot)
    checkout(settings["source_url"], settings["source_revision"], source)
    env = dict(os.environ, PATH=str(depot) + os.pathsep + os.environ["PATH"],
               DEPOT_TOOLS_UPDATE="0")
    if not (depot / "python3_bin_reldir.txt").exists():
        run([depot / "ensure_bootstrap"], work, env)
    (source.parent / ".gclient").write_text(
        "solutions = [{\"name\": \"src\", \"url\": "
        + repr(settings["source_url"])
        + ", \"deps_file\": \"DEPS\", \"managed\": False, \"custom_deps\": {}}]\n"
    )
    deps_stamp = work / "deps-ready"
    if not deps_stamp.exists() or deps_stamp.read_text().strip() != settings["source_revision"]:
        run(["gclient", "sync", "--no-history", "--shallow", "--jobs=4"], source.parent, env)
        deps_stamp.write_text(settings["source_revision"] + "\n")
    patches = [PLUGIN / "third_party" / settings[key]
               for key in ("routing_patch", "test_patch")]
    for patch in patches:
        apply_patch(source, patch)
    if args.test:
        # Reuse production objects, then regenerate with tests disabled before
        # linking the framework. Test targets are never copied into the SDK.
        test_architecture = "arm64" if platform.machine() == "arm64" else "x64"
        tests = source / ("out/boohtacord-macos-" + test_architecture)
        build(source, tests, test_architecture, settings, args.jobs, env, tests=True)
        run([tests / "audio_engine_tests", "--gtest_filter=AudioSendStreamTest.*",
             "--gtest_output=json:" + str(work / "audio-send-stream-tests.json")], source, env)

    frameworks = []
    for architecture in settings["architectures"]:
        output = source / ("out/boohtacord-macos-" + architecture)
        build(source, output, architecture, settings, args.jobs, env)
        frameworks.append(output / "WebRTC.framework")
    package = work / "package"
    if package.exists():
        shutil.rmtree(package)
    package.mkdir()
    universal = package / "universal/WebRTC.framework"
    shutil.copytree(frameworks[0], universal, symlinks=True)
    run(["lipo", "-create", *[framework / "WebRTC" for framework in frameworks],
         "-output", universal / "WebRTC"], source)
    artifact = package / "WebRTC.xcframework"
    run(["xcodebuild", "-create-xcframework", "-framework", universal,
         "-output", artifact], source)
    for framework in artifact.glob("*/WebRTC.framework"):
        binary = framework / "WebRTC"
        version = framework / "Versions/A"
        if version.exists() and not binary.is_symlink():
            binary.replace(version / "WebRTC")
            binary.symlink_to("Versions/Current/WebRTC")
    shutil.copy2(source / "LICENSE", artifact / "LICENSE")
    binary = next(artifact.glob("*/WebRTC.framework/WebRTC"))
    info = dict(settings,
                gn_args={arch: gn_args(arch, settings["deployment_target"])
                         for arch in settings["architectures"]},
                binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                patch_sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in patches},
                uuid=subprocess.check_output(["xcrun", "dwarfdump", "--uuid", str(binary)], text=True).strip())
    if args.test:
        results = json.loads((work / "audio-send-stream-tests.json").read_text())
        info["audio_send_stream_tests"] = {
            key: results[key] for key in ("tests", "failures", "disabled", "errors")
        }
    destination = PLUGIN / "macos/flutter_webrtc/Binary"
    destination.mkdir(exist_ok=True)
    pending = destination / "WebRTC.xcframework.pending"
    if pending.exists():
        shutil.rmtree(pending)
    shutil.copytree(artifact, pending, symlinks=True)
    installed = destination / "WebRTC.xcframework"
    if installed.exists():
        shutil.rmtree(installed)
    pending.rename(installed)
    (destination / "sdk.json").write_text(json.dumps(info, indent=2) + "\n")
    (work / "sdk.json").write_text(json.dumps(info, indent=2) + "\n")
    verify_installed(settings)
    print(f"Installed {settings['version']}: {installed}", flush=True)


if __name__ == "__main__":
    main()
