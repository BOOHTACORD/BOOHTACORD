foreach ($kind in @('maintenance.snapshot', 'maintenance.changed')) {
    $branch = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq $kind } | Select-Object -First 1
    $payload = $branch.then.properties.payload
    if ($realtime.properties.kind.enum -notcontains $kind -or $null -eq $branch -or
        $payload.additionalProperties -ne $false -or $payload.properties.version.const -ne 1 -or
        $payload.properties.generation.format -ne 'uuid' -or $payload.properties.active.type -ne 'boolean' -or
        $payload.properties.revision.minimum -ne 1 -or $payload.properties.revision.maximum -ne 9007199254740991 -or
        (($payload.required | Sort-Object) -join ',') -ne 'active,generation,revision,version' -or
        (($payload.properties.PSObject.Properties.Name | Sort-Object) -join ',') -ne 'active,generation,revision,version') {
        throw "Realtime $kind must expose only the typed public maintenance state."
    }
}
foreach ($kind in @('direct_message.message_created', 'direct_message.message_updated', 'direct_message.message_deleted')) {
    if ($realtime.properties.kind.enum -notcontains $kind) {
        throw "Realtime contract must define private $kind."
    }
    $branch = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq $kind } | Select-Object -First 1
    if ($null -eq $branch -or
        $branch.then.properties.payload.required -notcontains 'direct_message_id' -or
        $branch.then.properties.payload.required -notcontains 'message_id' -or
        $null -ne $branch.then.properties.payload.properties.body -or
        $branch.then.properties.payload.additionalProperties -ne $false) {
        throw "Realtime $kind must expose only typed DM identifiers."
    }
}
$channelUpdated = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'channel.updated' } | Select-Object -First 1
if ($null -eq $channelUpdated -or
    $channelUpdated.then.properties.payload.required -notcontains 'revision' -or
    $channelUpdated.then.properties.payload.properties.revision.type -ne 'integer' -or
    $channelUpdated.then.properties.payload.additionalProperties -ne $false) {
    throw 'Realtime channel.updated must carry only a typed topology revision.'
}
$leaseRevoked = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'voice.lease_revoked' } | Select-Object -First 1
if ($null -eq $leaseRevoked -or
    $leaseRevoked.then.properties.payload.required -notcontains 'lease_id' -or
    $leaseRevoked.then.properties.payload.required -notcontains 'reason' -or
    $leaseRevoked.then.properties.payload.additionalProperties -ne $false) {
    throw 'Realtime voice.lease_revoked must identify only the caller lease and reason.'
}
$resync = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'connection.resync_required' } | Select-Object -First 1
if ($null -eq $resync -or
    $resync.then.properties.payload.required -notcontains 'reason' -or
    $resync.then.properties.payload.additionalProperties -ne $false) {
    throw 'Realtime resync_required must carry a typed reason.'
}
$realtimeUpgrade = $openApi.paths.'/api/v1/realtime'.get
if ($null -eq $realtimeUpgrade -or
    $realtimeUpgrade.parameters[0].name -ne 'after' -or
    $realtimeUpgrade.parameters[0].schema.format -ne 'uuid' -or
    $null -eq $realtimeUpgrade.responses.'101' -or
    $realtimeUpgrade.description -notmatch '7-day') {
    throw 'Realtime upgrade contract must define the acknowledged after cursor and retention.'
}
$heartbeat = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'connection.heartbeat' } | Select-Object -First 1
if ($realtime.properties.kind.enum -notcontains 'connection.heartbeat' -or
    $null -eq $heartbeat -or $heartbeat.then.properties.payload.additionalProperties -ne $false -or
    $heartbeat.then.not.required -notcontains 'telemetry') {
    throw 'Realtime heartbeat must have an empty payload.'
}
