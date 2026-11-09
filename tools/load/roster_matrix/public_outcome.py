"""Keep the anonymous baseline and candidate measurements comparable."""


def classify_public(driver, exit_code, mode, guests, immutable):
    if (not isinstance(driver, dict) or exit_code != 0 or driver.get('Outcome') != 'PASS'
            or driver.get('StopReason') != 'bounded_initial_and_steady' or driver.get('Mode') != mode
            or driver.get('Guests') != guests):
        return 'FAIL'
    measurements = driver.get('Measurements')
    if not isinstance(measurements, dict): return 'FAIL'
    expected = {'maintenance': guests, 'ready': guests if mode == 'candidate' else 0, 'roster': 0}
    if any(not isinstance(measurements.get(k), dict) or measurements[k].get('Count') != v for k, v in expected.items()):
        return 'FAIL'
    resources = driver.get('Resources')
    if not isinstance(resources, list) or len(resources) < 2 or any(
            not isinstance(row, dict) or row.get('MetricsStatus') != 'AVAILABLE' for row in resources):
        return 'FAIL'
    metric = 'voice_platform_realtime_connections_active.scope.public'
    if mode == 'candidate' and not any(isinstance(row.get('Metrics'), dict) and row['Metrics'].get(metric) == guests for row in resources):
        return 'FAIL'
    return 'PASS' if immutable else 'SMOKE_PASS'
