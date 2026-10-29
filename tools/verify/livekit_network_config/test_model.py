"""Safety and wiring tests for the pinned LiveKit deployment model."""
import unittest
from pathlib import Path

from .fixtures import valid_model
from .metric_contract import BOUNDED_LABELS, METRIC_LABELS
from .model import metrics_reachable_peers, validate
from .check import load_configs, main


class LiveKitNetworkConfigTests(unittest.TestCase):
    def setUp(self):
        (self.livekit, self.deploy, self.observability_compose,
         self.prometheus, self.alerts) = valid_model()

    def assert_valid(self):
        validate(self.livekit, self.deploy, self.observability_compose, self.prometheus, self.alerts)

    def test_private_metrics_scrape_and_udp_tcp_publication_are_wired(self):
        self.assert_valid()

    def test_metrics_listener_reachability_matches_documented_network_peers(self):
        self.assertEqual(metrics_reachable_peers(self.deploy, self.observability_compose),
                         {"api", "postgres", "proxy", "prometheus"})
        self.deploy["services"]["livekit"]["networks"].append("edge")
        with self.assertRaisesRegex(ValueError, "remove extra LiveKit networks"):
            self.assert_valid()

    def test_allowed_livekit_metric_labels_are_all_bounded(self):
        self.assertEqual(METRIC_LABELS["livekit_packet_loss_percent_bucket"],
                         {"node_type", "direction", "source", "type", "le"})
        self.assertTrue(all(labels.isdisjoint({"node_id", "country", "room", "participant"})
                            for labels in METRIC_LABELS.values()))
        self.assertTrue(all(labels <= BOUNDED_LABELS for labels in METRIC_LABELS.values()))

    def test_rejects_livekit_version_without_a_reviewed_label_contract(self):
        self.deploy["services"]["livekit"]["image"] = "livekit/livekit-server:v1.13.8"
        with self.assertRaisesRegex(ValueError, "reviewed LiveKit image pin"):
            self.assert_valid()

    def test_checked_in_compose_peer_set_matches_private_listener_boundary(self):
        root = Path(__file__).resolve().parents[3]
        _, deploy, observability, _, _ = load_configs(root)
        self.assertEqual(metrics_reachable_peers(deploy, observability), {
            "api", "postgres", "web", "proxy", "migrate", "bootstrap-admin",
            "recover-admin", "recover-last-admin-access", "maintenance-admission",
            "cleanup-stale-staging", "cleanup-unattached-attachments",
            "cleanup-hidden-attachments", "prometheus", "redis", "egress",
            "screen-preview-storage-init",
        })

    def test_checked_in_compose_and_prometheus_files_match_the_model(self):
        main()

    def test_rejects_missing_udp_range_mapping(self):
        self.deploy["services"]["livekit"]["ports"].pop()
        with self.assertRaisesRegex(ValueError, "UDP range"):
            self.assert_valid()

    def test_rejects_published_metrics_port(self):
        self.deploy["services"]["livekit"]["ports"].append("6789:6789/tcp")
        with self.assertRaisesRegex(ValueError, "must not publish"):
            self.assert_valid()

    def test_rejects_public_signaling_api_port(self):
        self.deploy["services"]["livekit"]["ports"].append("7880:7880/tcp")
        with self.assertRaisesRegex(ValueError, "behind the proxy"):
            self.assert_valid()

    def test_rejects_metrics_network_access_for_api_or_database(self):
        self.deploy["services"]["api"]["networks"].append("livekit-metrics")
        with self.assertRaisesRegex(ValueError, "only LiveKit"):
            self.assert_valid()

    def test_rejects_node_and_country_labels_or_unbounded_metric_families(self):
        relabels = self.prometheus["scrape_configs"][0]["metric_relabel_configs"]
        relabels[1]["regex"] = "country"
        with self.assertRaisesRegex(ValueError, "node_id"):
            self.assert_valid()

        self.prometheus["scrape_configs"][0]["metric_relabel_configs"] = [
            {"source_labels": ["__name__"], "regex": "livekit_.*", "action": "keep"},
            {"regex": "node_id|country", "action": "labeldrop"},
        ]
        with self.assertRaisesRegex(ValueError, "allowlist"):
            self.assert_valid()

    def test_rejects_unreviewed_metric_label_rewrites(self):
        self.prometheus["scrape_configs"][0]["metric_relabel_configs"].append(
            {"source_labels": ["room"], "target_label": "room", "action": "replace"})
        with self.assertRaisesRegex(ValueError, "reviewed allowlist"):
            self.assert_valid()

    def test_rejects_scrape_target_outside_private_metrics_network(self):
        self.observability_compose["networks"]["livekit-metrics"]["name"] = "public-edge"
        with self.assertRaisesRegex(ValueError, "private network"):
            self.assert_valid()

    def test_rejects_external_ip_advertisement_drift(self):
        self.livekit["rtc"]["use_external_ip"] = False
        with self.assertRaisesRegex(ValueError, "external IP"):
            self.assert_valid()

    def test_rejects_tcp_fallback_mapping_drift(self):
        self.deploy["services"]["livekit"]["ports"][0] = "7881:7881/tcp"
        with self.assertRaisesRegex(ValueError, "TCP fallback"):
            self.assert_valid()


if __name__ == "__main__":
    unittest.main()
