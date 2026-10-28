"""Reviewed plugin classes; source loss/addition needs an explicit inventory review."""
import re

EXPECTED = {
    'boohtacord_voice_foreground': {'ru.boohtacord.voice.start.AdmissionPolicyTest': 5},
    'livekit_client': {'io.livekit.plugin.AudioResamplerTest': 11},
    'flutter_webrtc': {
        'com.cloudwebrtc.webrtc.record.FrameCaptureGateTest': 2,
        'com.cloudwebrtc.webrtc.record.FrameCapturerBufferTest': 1,
        'com.cloudwebrtc.webrtc.RemoteTrackRegistryTest': 1,
        'com.cloudwebrtc.webrtc.ScreenCaptureConstraintsTest': 3,
        'com.cloudwebrtc.webrtc.ScreenCaptureDimensionsTest': 6,
        'com.cloudwebrtc.webrtc.ScreenCaptureFrameRateGateTest': 3,
        'com.cloudwebrtc.webrtc.screen.refresh.StationaryFrameRefreshTest': 6,
        'com.cloudwebrtc.webrtc.screen.refresh.FrameTimestampTest': 2,
        'com.cloudwebrtc.webrtc.SurfaceProducerAvailabilityTest': 1,
        'com.cloudwebrtc.webrtc.SurfaceReleaseBarrierTest': 3,
        'com.cloudwebrtc.webrtc.utils.ConstraintsMapTest': 1,
        'com.cloudwebrtc.webrtc.VideoFrameDimensionsTest': 3,
    },
}


def verify_sources(root):
    for plugin, expected in EXPECTED.items():
        directory = root / 'clients/flutter/packages' / plugin / 'android/src/test'
        actual = {}
        for path in directory.rglob('*'):
            if path.suffix not in ('.java', '.kt'): continue
            text = path.read_text(encoding='utf-8')
            count = len(re.findall(r'@Test\b', text))
            if not count: continue
            package = re.search(r'\bpackage\s+([\w.]+)', text)
            if not package: raise ValueError('Test package missing')
            actual[package[1] + '.' + path.stem] = count
        if actual != expected:
            raise ValueError('Android source inventory changed; review every class before updating it')
