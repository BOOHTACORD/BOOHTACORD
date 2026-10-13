#!/usr/bin/env python3
"""Run actual Objective-C SCK boundary tests without capture or Flutter builds."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'clients/flutter/packages/flutter_webrtc/macos/flutter_webrtc/Sources/flutter_webrtc'


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--framework-dir', required=True, type=Path,
                        help='Directory containing the pinned macOS WebRTC.framework')
    parser.add_argument('--suite', choices=['boundary', 'processor', 'diagnostics', 'lifecycle', 'startup'], default='boundary')
    parser.add_argument('--flutter-framework-dir', type=Path,
                        help='Directory containing FlutterMacOS.framework headers (processor suite only)')
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    binary = args.out.resolve() / 'boundary_test'
    if args.suite in ['processor', 'startup'] and args.flutter_framework_dir is None:
        parser.error('--flutter-framework-dir is required for processor/startup suites')
    suites = {'boundary': ('boundary_test.m', 'FlutterScreenCaptureKitCapturer.m'),
              'processor': ('processor_test.m', 'FlutterScreenShareResolutionProcessor.m'),
              'diagnostics': ('diagnostics_test.m', 'FlutterScreenCaptureDiagnostics.m'),
              'lifecycle': ('lifecycle_test.m', 'FlutterScreenCaptureKitCapturer.m'),
              'startup': ('startup_test.m', 'FlutterRTCDesktopCapturer.m')}
    test_name, native_name = suites[args.suite]
    test = Path(__file__).with_name(test_name)
    native = SOURCE / native_name
    framework = args.framework_dir.resolve() / 'WebRTC.framework/WebRTC'
    report = {
        'schema': 'boohtacord.native_capture_boundary.v1',
        'suite': args.suite,
        'scope': 'synthetic CoreMedia/CoreVideo input against actual vendored macOS SCK class; no OS capture',
        'source_sha256': {str(path.relative_to(ROOT)): sha(path) for path in [test, native]},
        'framework_sha256': sha(framework),
        'hardware_gate': 'NOT_RUN',
        'limitations': ['Private stream identity seam bypasses startup; does not validate permissions, actual capture, queue age, audio, performance or physical selection.'],
    }
    command = ['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-Wno-incompatible-pointer-types',
               '-I', str(SOURCE / 'include/flutter_webrtc'), '-F', str(args.framework_dir.resolve()),
               str(test), str(native), '-framework', 'WebRTC', '-framework', 'Foundation',
               '-framework', 'ScreenCaptureKit', '-framework', 'CoreMedia', '-framework', 'CoreVideo',
               '-framework', 'CoreGraphics', '-Wl,-rpath,' + str(args.framework_dir.resolve()), '-o', str(binary)]
    if args.suite in ['boundary', 'lifecycle']:
        diagnostics = SOURCE / 'FlutterScreenCaptureDiagnostics.m'
        command.append(str(diagnostics))
        report['source_sha256'][str(diagnostics.relative_to(ROOT))] = sha(diagnostics)
        if args.suite == 'lifecycle':
            report['scope'] = 'actual SCK readiness, generation cancellation and bounded video/audio routing with synthetic private-state seams'
            report['limitations'] = ['Native stream identities/start acknowledgments and audio sink are synthetic. No permissions, OS startup, PCM decoding or physical audio/capture acceptance is proved.']
    elif args.suite == 'diagnostics':
        report['scope'] = 'actual bounded capture diagnostics state machine and numeric aggregates; no OS capture'
        report['limitations'] = ['Does not prove native bridge dispatch, actual capture, pipeline timing or hardware throughput.']
    elif args.suite == 'startup':
        extras = ['FlutterScreenCaptureKitCapturer.m', 'FlutterScreenCaptureDiagnostics.m',
                  'FlutterScreenShareResolutionProcessor.m', 'VideoProcessingAdapter.m',
                  'LocalVideoTrack.m', 'LocalAudioTrack.m']
        for name in extras:
            path = SOURCE / name
            command.append(str(path))
            report['source_sha256'][str(path.relative_to(ROOT))] = sha(path)
        report['scope'] = 'actual DesktopCapturer/SCK startup failure ownership with injected factory and SC enumeration; no OS capture'
        report['limitations'] = ['Factory, audio owner and FlutterError are fakes; no native permission, real factory, playback or OS capture behavior is proved.']
    if args.suite == 'processor':
        command.extend(['-F', str(args.flutter_framework_dir.resolve()), '-framework', 'CoreImage',
                        '-fmodules', '-fmodules-cache-path=' + str(args.out.resolve() / 'modules')])
        report['scope'] = 'actual vendored macOS resolution processor with synthetic native buffers and controlled conversion helper; no OS capture'
        report['limitations'] = ['Old generic conversion helper is a spy; real WebRTC I420 scaling and CV pool exhaustion/reuse are tested. Processing performance and total heap allocations are not measured.']
        report['flutter_header_sha256'] = sha(args.flutter_framework_dir / 'FlutterMacOS.framework/Headers/FlutterMacOS.h')
    elif args.suite == 'startup':
        command.extend(['-I', str(SOURCE), '-F', str(args.flutter_framework_dir.resolve()), '-framework', 'CoreImage',
                        '-framework', 'AppKit', '-fmodules', '-fmodules-cache-path=' + str(args.out.resolve() / 'modules')])
    compiled = subprocess.run(command, capture_output=True, text=True)
    (args.out / 'compile.log').write_text(compiled.stderr)
    if compiled.returncode:
        report['status'] = 'BLOCKED'
        report['reason'] = 'native boundary test compile failed; see local compile.log'
        code = 2
    else:
        executed = subprocess.run([str(binary)], capture_output=True, text=True, env=os.environ.copy())
        (args.out / 'run.stderr.log').write_text(executed.stderr)
        try:
            report.update(json.loads(executed.stdout))
            report['status'] = 'PASS' if executed.returncode == 0 else 'RED'
            code = executed.returncode
        except json.JSONDecodeError:
            report['status'] = 'BLOCKED'
            report['reason'] = 'native boundary test did not produce case results'
            code = 2
    (args.out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return code


if __name__ == '__main__':
    sys.exit(main())
