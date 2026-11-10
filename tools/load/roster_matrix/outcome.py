"""Only classify complete per-domain observations from the owned fixture."""
import math


def classify(driver, exit_code, mode, accounts, rooms, immutable, same_source=False, maintenance_change=False, messages=0, warmup_ms=0):
    if not isinstance(driver, dict) or exit_code != 0:
        return 'FAIL'
    stop_reason = 'bounded_initial_change_and_steady' if maintenance_change else 'bounded_initial_and_steady'
    if (driver.get('Outcome') != 'PASS' or driver.get('StopReason') != stop_reason
            or driver.get('Mode') != mode or driver.get('Accounts') != accounts or driver.get('Rooms') != rooms):
        return 'FAIL'
    if driver.get('SourceProfile', 'independent') != ('shared' if same_source else 'independent'):
        return 'FAIL'
    if (type(warmup_ms) is not int or not 0 <= warmup_ms <= 2000
            or (warmup_ms and not messages) or driver.get('MessageWarmupMS', 0) != warmup_ms):
        return 'FAIL'
    measurements = driver.get('Measurements')
    if not isinstance(measurements, dict):
        return 'FAIL'
    domains = ('ready', 'roster', 'maintenance', 'maintenance_change') if maintenance_change else ('ready', 'roster', 'maintenance')
    for name in domains:
        row = measurements.get(name)
        if not isinstance(row, dict) or row.get('Count') != accounts:
            return 'FAIL'
    if messages:
        row = driver.get('Message')
        delivery = row.get('Deliveries') if isinstance(row, dict) else None
        batches = row.get('Batches') if isinstance(row, dict) else None
        p95 = delivery.get('P95MS') if isinstance(delivery, dict) else None
        if (type(messages) is not int or not 1 <= messages <= 20 or not isinstance(row, dict)
                or not isinstance(delivery, dict) or row.get('Messages') != messages
                or row.get('Duplicates') != 0 or delivery.get('Count') != accounts * messages
                or not isinstance(batches, list) or len(batches) != messages
                or any(not isinstance(batch, dict) or batch.get('Count') != accounts for batch in batches)
                or type(p95) not in (float, int) or not math.isfinite(p95) or not 0 <= p95 <= 500):
            return 'FAIL'
    resources = driver.get('Resources')
    if not isinstance(resources, list) or len(resources) < 2:
        return 'FAIL'
    if any(not isinstance(row, dict) or row.get('MetricsStatus') != 'AVAILABLE' for row in resources):
        return 'FAIL'
    metric = ('voice_platform_realtime_connections_active.scope.authenticated' if mode == 'candidate'
              else 'voice_platform_realtime_connections_active')
    if not any(isinstance(row.get('Metrics'), dict) and row['Metrics'].get(metric) == accounts for row in resources):
        return 'FAIL'
    return 'PASS' if immutable else 'SMOKE_PASS'
