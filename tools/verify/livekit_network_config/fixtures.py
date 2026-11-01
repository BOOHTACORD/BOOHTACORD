"""Small policy fixture shared by LiveKit network unit tests."""
from .metric_contract import PINNED_LIVEKIT_IMAGE, SAFE_METRICS


def valid_model():
    livekit = {
        "port": 7880,
        "prometheus_port": 6789,
        "rtc": {"tcp_port": 7882, "port_range_start": 50000,
               "port_range_end": 50100, "use_external_ip": False},
    }
    deploy = {
        "name": "voice-platform",
        "services": {
            "livekit": {"image": PINNED_LIVEKIT_IMAGE,
                        "command": ['exec /livekit-server --node-ip "$${LIVEKIT_NODE_IP}"'],
                        "environment": {"LIVEKIT_NODE_IP": "${LIVEKIT_NODE_IP:?set LIVEKIT_NODE_IP in .env}"},
                        "ports": ["7882:7882/tcp", "50000-50100:50000-50100/udp"],
                        "networks": ["private", "livekit-metrics"]},
            "api": {"networks": ["private"]}, "postgres": {"networks": ["private"]},
            "proxy": {"ports": ["443:443"], "networks": ["edge", "private"]},
        },
        "networks": {"edge": {}, "private": {"internal": True},
                     "livekit-metrics": {"internal": True}},
    }
    observability = {
        "services": {"prometheus": {"networks": ["default", "livekit-metrics"]}},
        "networks": {"default": {}, "livekit-metrics": {
            "external": True, "name": "voice-platform_livekit-metrics"}},
    }
    prometheus = {"scrape_configs": [{
        "job_name": "boohtacord-livekit", "metrics_path": "/metrics",
        "static_configs": [{"targets": ["livekit:6789"]}],
        "relabel_configs": [{"target_label": "instance", "replacement": "boohtacord-livekit-sfu"}],
        "metric_relabel_configs": [
            {"source_labels": ["__name__"], "regex": SAFE_METRICS, "action": "keep"},
            {"regex": "node_id|country", "action": "labeldrop"},
        ],
    }]}
    alerts = {"groups": [{"name": "livekit-network", "rules": [{
        "alert": "LiveKitMetricsScrapeUnavailable",
        "expr": 'up{job="boohtacord-livekit"} == 0', "for": "2m",
    }]}]}
    return livekit, deploy, observability, prometheus, alerts
