import math
from collections import defaultdict


class Metrics:
    def __init__(self):
        self.samples = defaultdict(list)
        self.statuses = defaultdict(lambda: defaultdict(int))

    def record(self, result):
        operation, status, elapsed_ms = result
        self.samples[operation].append(elapsed_ms)
        self.statuses[operation][str(status)] += 1

    def report(self):
        result = {}
        for operation, samples in sorted(self.samples.items()):
            statuses = dict(sorted(self.statuses[operation].items()))
            result[operation] = {
                'requests': len(samples), 'statuses': statuses,
                'errors': sum(count for code, count in statuses.items() if code != '200' and
                              not (operation == 'login' and code == '204')),
                'latency_ms': {'p50': percentile(samples, .50),
                               'p95': percentile(samples, .95),
                               'p99': percentile(samples, .99)},
            }
        return result


def percentile(samples, quantile):
    ordered = sorted(samples)
    return round(ordered[max(0, math.ceil(len(ordered) * quantile) - 1)], 2)
