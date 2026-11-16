$relay = $openApi.paths.'/api/v1/voice/leases/{ownerLeaseID}/screen-telemetry'.post
$envelope = $openApi.components.schemas.ScreenTelemetryEnvelopeV1
$realtimeEvent = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'screen_telemetry.updated' } | Select-Object -First 1
$eventPayload = $realtime.'$defs'.ScreenTelemetryEventV1
$metric = $realtime.'$defs'.ScreenTelemetryField

if ($null -eq $relay -or $relay.operationId -ne 'publishScreenTelemetryV1' -or
    $relay.security[0].SessionCookie.Count -ne 0 -or
    $relay.parameters.name -notcontains 'Origin' -or $relay.parameters.required -notcontains $true -or
    $null -eq $relay.responses.'409' -or $null -eq $relay.responses.'429') {
    throw 'Screen telemetry publishing must use a session/Origin boundary and reject stale or over-frequent samples.'
}
if ($null -eq $envelope -or $envelope.additionalProperties -ne $false -or
    $envelope.properties.schema_version.const -ne 1 -or
    $envelope.properties.publication_generation.maximum -ne 9007199254740991 -or
    $envelope.properties.sender_sample_age_ms.maximum -ne 60000 -or
    $envelope.required -notcontains 'capture' -or $envelope.required -notcontains 'encode' -or $envelope.required -notcontains 'transport') {
    throw 'ScreenTelemetryEnvelopeV1 must be a bounded strict versioned schema.'
}
if ($null -eq $realtimeEvent -or $realtime.properties.kind.enum -notcontains 'screen_telemetry.updated' -or
    $realtimeEvent.then.properties.payload.'$ref' -ne '#/$defs/ScreenTelemetryEventV1' -or
    $eventPayload.additionalProperties -ne $false -or
    $eventPayload.required -notcontains 'server_received_at' -or
    $eventPayload.properties.PSObject.Properties.Name -contains 'track_sid') {
    throw 'Realtime telemetry must carry only the server-stamped, scoped versioned envelope.'
}
if ($metric.additionalProperties -ne $false -or
    $metric.properties.availability.enum -notcontains 'not_exposed' -or
    $metric.properties.availability.enum -notcontains 'permission_denied' -or
    $metric.properties.provenance.enum -notcontains 'sender_measured' -or
    $metric.allOf.Count -lt 3) {
    throw 'Every telemetry metric must declare availability/provenance and reject fabricated unavailable values.'
}
if ($relay.description -notmatch 'never journals or stores telemetry values' -or
    $relay.description -notmatch 'track ID' -or $relay.description -notmatch 'media payload') {
    throw 'The telemetry contract must state its ephemeral lifetime and prohibit media identifiers/payload.'
}
