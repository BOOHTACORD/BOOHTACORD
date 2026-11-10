"""Project only fixed low-cardinality roster WebSocket fixture metrics."""
import math
import re


COUNTER = re.compile(r'voice_platform_voice_roster_ws_(initial|delivery|refresh)_total\{outcome="(success|failure|unavailable)"\} ([0-9.eE+\-]+)')


def roster_counter(line):
    match = COUNTER.fullmatch(line)
    if not match:
        return None
    value = float(match[3])
    if not math.isfinite(value):
        return None
    return f'voice_platform_voice_roster_ws_{match[1]}_total.outcome.{match[2]}', value
