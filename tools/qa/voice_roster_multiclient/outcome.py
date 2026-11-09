"""Reject incomplete real-stack voice roster observations."""

REQUIRED = ('empty', 'first_join', 'second_join', 'microphone', 'audio_receiving', 'screen_share', 'screen_receiving', 'leave', 'rejoin', 'transfer', 'live_transport', 'ws_independent', 'socket_guard', 'public_privacy')


def classify(checks, browser_exit, stable, cleaned):
    if browser_exit != 0 or stable is not True or cleaned is not True:
        return 'FAIL'
    if not isinstance(checks, dict) or any(checks.get(name) is not True for name in REQUIRED):
        return 'FAIL'
    return 'SMOKE_PASS'
