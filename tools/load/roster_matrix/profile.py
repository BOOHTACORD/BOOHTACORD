"""Describe exactly what the bounded roster fixture measures."""


def scope(guests, change, messages, warmup_ms):
    result = ('public maintenance and 10s steady connection only' if guests
              else 'initial empty roster and 10s steady connection only')
    if change:
        result = 'initial empty roster, maintenance activation to frame and 10s steady connection only'
    if messages:
        result += f'; {messages} synthetic messages to socket frame after {warmup_ms}ms warmup (no UI or media)'
    return result
