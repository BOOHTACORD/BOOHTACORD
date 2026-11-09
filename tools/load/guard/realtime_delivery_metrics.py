"""Bounded, label-free projection of the existing WebSocket latency histogram."""
import math
import re

NAME = 'voice_platform_realtime_event_delivery_seconds'
BUCKETS = {'0.005', '0.01', '0.025', '0.05', '0.1', '0.25', '0.5', '1', '2.5', '5', '10', '+Inf'}


def delivery_metric(line):
    bucket = re.fullmatch(NAME + r'_bucket\{le="([^"\n]+)"\} ([0-9.eE+\-]+)', line)
    scalar = re.fullmatch(NAME + r'_(count|sum) ([0-9.eE+\-]+)', line)
    if bucket and bucket[1] in BUCKETS and math.isfinite(float(bucket[2])):
        return NAME + '_bucket.le.' + bucket[1], float(bucket[2])
    if scalar and math.isfinite(float(scalar[2])):
        return NAME + '_' + scalar[1], float(scalar[2])
    return None


STAGE_NAME = 'voice_platform_realtime_event_stage_seconds'
STAGES = {'before_handler', 'handler'}
STAGE_BUCKETS = BUCKETS | {'0.001', '0.0025'}


def stage_metric(line):
    scalar = re.fullmatch(STAGE_NAME + r'_(count|sum)\{stage="([^"\n]+)"\} ([0-9.eE+\-]+)', line)
    if scalar and scalar[2] in STAGES and math.isfinite(float(scalar[3])):
        return STAGE_NAME + '.' + scalar[2] + '.' + scalar[1], float(scalar[3])
    bucket = re.fullmatch(STAGE_NAME + r'_bucket\{stage="([^"\n]+)",le="([^"\n]+)"\} ([0-9.eE+\-]+)', line)
    reverse = re.fullmatch(STAGE_NAME + r'_bucket\{le="([^"\n]+)",stage="([^"\n]+)"\} ([0-9.eE+\-]+)', line)
    if reverse:
        stage, bound, value = reverse[2], reverse[1], reverse[3]
    elif bucket:
        stage, bound, value = bucket[1], bucket[2], bucket[3]
    else:
        return None
    if stage in STAGES and bound in STAGE_BUCKETS and math.isfinite(float(value)):
        return STAGE_NAME + '.' + stage + '.bucket.' + bound, float(value)
    return None
