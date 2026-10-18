// Evidence readiness within one bounded connection attempt, not assertion/test retries.
const measured = value => typeof value === 'number' && Number.isFinite(value) && value >= 0
export function transportReady(report, requiredProtocol, role) {
  const bytes = role === 'sender' ? 'audioBytesSent' : 'audioBytesReceived'
  return Boolean(report?.outcome === 'connected'
    && ['signalMs', 'sdkJoinMs', 'iceObservedMs', 'firstRtpObservedMs'].every(field => measured(report[field]))
    && report.transports?.some(value => value.selected === true && value.protocol === requiredProtocol
      && measured(value[bytes]) && value[bytes] > 0))
}
export function observation(report, requiredProtocol, role) {
  return { ready: transportReady(report, requiredProtocol, role),
    selectedProtocols: (report?.transports ?? []).filter(value => value.selected)
      .map(value => ['tcp', 'udp'].includes(value.protocol) ? value.protocol : null),
    rtpObserved: measured(report?.firstRtpObservedMs) }
}
