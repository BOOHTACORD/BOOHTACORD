"""The live delivery controller owns an isolated Unix-only nested daemon."""
from pathlib import Path
import tempfile
import unittest
from .daemon import mount_arguments, ssh_packages


class DeliveryDaemonTests(unittest.TestCase):
    def test_current_controller_is_separate_from_both_retained_product_sources(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            args = mount_arguments(root, root/'work', root/'objects', root/'cache')
        self.assertIn(str(root/'tools')+':/qa-builder/tools:ro', args)
        self.assertIn(str(root/'tools/qa/compatible_rollback')+':/qa-tools:ro', args)
        self.assertIn(str(root/'tools/qa/trusted_delivery')+':/qa-delivery:ro', args)
        self.assertFalse(any('/var/run/docker.sock' in value for value in args))
        self.assertNotIn('-p', args)

    def test_delivery_fixture_adds_real_sshd_without_changing_historical_qa60_image(self):
        text = (Path(__file__).parent/'Dockerfile').read_text()
        self.assertIn('docker:29.5.2-dind@sha256:', text)
        for package in ssh_packages(): self.assertIn(package, text)
        self.assertNotIn('EXPOSE', text)
