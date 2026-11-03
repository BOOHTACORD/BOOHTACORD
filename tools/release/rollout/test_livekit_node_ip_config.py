from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[3]


class LiveKitNodeIPConfigTests(unittest.TestCase):
    def test_explicit_public_node_ip_does_not_require_stun_discovery(self):
        config = (ROOT / "deploy/livekit/livekit.yaml").read_text()
        rtc = re.search(r"(?ms)^rtc:\s*\n(?P<body>(?:^[ \t].*\n?)*)", config)
        self.assertIsNotNone(rtc, "LiveKit RTC configuration must be present")
        self.assertRegex(
            rtc.group("body"),
            r"(?m)^[ \t]+use_external_ip:[ \t]*false[ \t]*$",
            "The deployment already passes LIVEKIT_NODE_IP; STUN discovery must be disabled",
        )

    def test_compose_requires_and_passes_the_explicit_node_ip(self):
        compose = (ROOT / "deploy/livekit/compose.yaml").read_text()
        self.assertIn(
            'exec /livekit-server --config /tmp/livekit.yaml --node-ip "$${LIVEKIT_NODE_IP}"',
            compose,
        )
        self.assertRegex(compose, r"(?m)^\s+LIVEKIT_NODE_IP: \$\{LIVEKIT_NODE_IP:\?set LIVEKIT_NODE_IP in \.env\}")


if __name__ == "__main__":
    unittest.main()
