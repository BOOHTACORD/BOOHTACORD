"""Project only fixed, non-identifying pool partition samples into load evidence."""
import math
import re


NAME = 'voice_platform_database_partition_connections'


def pool_partition_metric(line):
    match = re.fullmatch(NAME + r'\{partition="(main|session|shared)",state="(acquired|idle|total|max|constructing)"\} ([0-9.eE+\-]+)', line)
    if not match:
        return None
    try:
        value = float(match[3])
    except ValueError:
        return None
    if not math.isfinite(value) or value < 0:
        return None
    return NAME + '.' + match[1] + '.' + match[2], value
