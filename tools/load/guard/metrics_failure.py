"""Classify metrics failures without retaining addresses or exception text."""
from urllib.error import HTTPError, URLError


def stage(cause):
    if isinstance(cause, HTTPError):
        return 'resource_metrics_http'
    if isinstance(cause, URLError):
        cause = cause.reason
    if isinstance(cause, TimeoutError):
        return 'resource_metrics_timeout'
    if isinstance(cause, ValueError):
        return 'resource_metrics_invalid'
    return 'resource_metrics_unavailable'
