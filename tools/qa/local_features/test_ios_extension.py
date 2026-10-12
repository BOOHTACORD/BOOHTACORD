"""Source metadata required for installing the ReplayKit extension."""
import plistlib
from pathlib import Path
import unittest


class ExtensionMetadataTests(unittest.TestCase):
    def test_installable_replaykit_identity(self):
        root = Path(__file__).resolve().parents[3]
        with (root / 'clients/flutter/ios/ScreenShareExtension/Info.plist').open('rb') as source:
            info = plistlib.load(source)
        name = info.get('CFBundleDisplayName')
        self.assertIsInstance(name, str)
        self.assertTrue(name.strip())
        self.assertNotIn('$(', name, 'The broadcast picker needs a concrete display name')
        extension = info['NSExtension']
        self.assertEqual(extension['NSExtensionPointIdentifier'], 'com.apple.broadcast-services-upload')
        self.assertEqual(extension['RPBroadcastProcessMode'], 'RPBroadcastProcessModeSampleBuffer')
        self.assertEqual(extension['NSExtensionPrincipalClass'], '$(PRODUCT_MODULE_NAME).SampleHandler')


if __name__ == '__main__':
    unittest.main()
