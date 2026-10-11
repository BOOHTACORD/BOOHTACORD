"""Prevent C++-only implementation headers from leaking into SwiftPM modules."""
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PUBLIC_HEADERS = ROOT / "clients/flutter/packages/flutter_webrtc/macos/flutter_webrtc/Sources/flutter_webrtc/include/flutter_webrtc"
PRIVATE_HEADER = ROOT / "clients/flutter/packages/flutter_webrtc/macos/flutter_webrtc/Sources/flutter_webrtc/audio_device_change_coalescer.h"


class FlutterWebRtcPublicHeadersTest(unittest.TestCase):
    def test_cpp_only_coalescer_header_is_private_to_the_plugin_target(self):
        offenders = [
            str(path.relative_to(PUBLIC_HEADERS))
            for path in PUBLIC_HEADERS.rglob("*.h")
            if "#include <cstdint>" in path.read_text(encoding="utf-8")
        ]
        self.assertEqual(
            [],
            offenders,
            "SwiftPM exports these headers as a Clang module; C++-only headers must stay outside include/.",
        )
        self.assertTrue(PRIVATE_HEADER.is_file(), "The C++ helper must remain part of the plugin target.")


if __name__ == "__main__":
    unittest.main()
