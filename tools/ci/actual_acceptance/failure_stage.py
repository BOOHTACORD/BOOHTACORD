"""Finite QA stage names safe to retain from a private controller log."""
import json
import math
import re
from pathlib import Path

STAGES = frozenset({
    'actual-media-faults-accepted', 'actual-protected-bursts-accepted',
    'actual-reset-completed-focus', 'actual-reset-links-accepted',
    'actual-tempo-verified', 'actual-used-reset-rejected-focus',
    'admin-screen-ready', 'browser-api-ready-after-registration',
    'critical-burst-active-channel-confirmed', 'critical-burst-hidden-channel-created',
    'critical-burst-hidden-channel-selected', 'critical-burst-hidden-channel-visible',
    'critical-burst-navigation-open', 'header-voice-search-accepted',
    'isolated-tls-api-ready', 'member-profile-text-dm-accepted',
    'member-profile-voice-acl-accepted', 'mini-player-actual-start',
    'mini-player-auto-retained-logout-clean', 'mini-player-controls-and-cleanup-accepted',
    'mini-player-text-dm-retained', 'production-client-built',
    'qa-member-channel-log-complete', 'qa-member-dm-empty-complete',
    'qa-member-dm-message-sent', 'qa-member-dm-search-complete',
    'qa-member-first-message-visible', 'qa-member-global-search-complete',
    'qa-member-login', 'qa-member-message-actions-complete',
    'qa-member-message-actions-open-mouse', 'qa-member-message-actions-open-touch',
    'qa-member-message-history-visible', 'qa-member-navigation-overlay-complete',
    'qa-member-text-channel-selected', 'qa-member-voice-prejoin-complete',
    'reference-audit-history-seeded', 'reference-channel-heading-visible',
    'reference-channel-messages-visible', 'reference-channel-refresh-restored',
    'reference-channel-selected', 'reference-guild-journey-complete',
    'reference-live-guild-rename', 'reference-security-and-access-complete',
    'reference-topology-seeded', 'reference-welcome-complete',
    'registration-outcome-accepted', 'screen-configuration-status',
    'screen-share-short-height', 'sender-screen-preview',
    'settings-live-audio-accepted', 'settings-personal-api-accepted',
    'two-admin-clients-authenticated',
})
MARKER = re.compile(r'(?:^|\s)stage=([a-z][a-z0-9-]{0,80})(?=[:\s]|$)')


def last_failure_stage(log):
    if log is None:
        return None
    try:
        text = Path(log).read_text(encoding='utf-8', errors='replace')
    except OSError:
        return None
    stages = [match.group(1) for match in MARKER.finditer(text) if match.group(1) in STAGES]
    return stages[-1] if stages else None


def last_short_stage_geometry(log):
    if log is None:
        return None
    try:
        lines = Path(log).read_text(encoding='utf-8', errors='replace').splitlines()
    except OSError:
        return None
    geometry = None
    marker = 'stage=screen-share-short-height:'
    for line in lines:
        if marker not in line:
            continue
        try:
            value = json.loads(line.split(marker, 1)[1])
        except (ValueError, TypeError):
            continue
        if not isinstance(value, dict):
            continue
        dimensions = {key: value.get(key) for key in ('height', 'visibleHeight', 'dockHeight')}
        if not all(isinstance(item, (int, float)) and not isinstance(item, bool)
                   and math.isfinite(item) and 0 <= item <= 10000 for item in dimensions.values()):
            continue
        if type(value.get('dockCoversStage')) is not bool:
            continue
        geometry = {**dimensions, 'dockCoversStage': value['dockCoversStage']}
    return geometry
