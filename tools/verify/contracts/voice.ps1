if ($null -eq $openApi.paths.'/api/v1/voice/channels/{channelID}/leases'.post) {
    throw 'Voice contract must define POST /api/v1/voice/channels/{channelID}/leases.'
}

if ($null -ne $openApi.paths.'/api/v1/voice/rosters/events' -or
    $null -ne $openApi.paths.'/api/v1/maintenance/events') {
    throw 'Retired SSE routes must not appear in the contract.'
}
if ($null -eq $openApi.paths.'/api/v1/voice/participants'.get -or
    $null -eq $openApi.paths.'/api/v1/realtime'.get -or
    $null -eq $openApi.paths.'/api/v1/public/realtime'.get) {
    throw 'Roster snapshot and authenticated/public realtime contracts are required.'
}

$voiceParticipant = $openApi.components.schemas.VoiceParticipant
if ($voiceParticipant.required -notcontains 'microphone_muted' -or
    $voiceParticipant.properties.microphone_muted.type -ne 'boolean') {
    throw 'Voice participant contract must expose the server-observed microphone_muted state.'
}

if ($null -eq $openApi.paths.'/api/v1/voice/leases/{leaseID}'.delete) {
    throw 'Voice contract must define DELETE /api/v1/voice/leases/{leaseID}.'
}

if ($null -eq $openApi.paths.'/api/v1/voice/leases/{leaseID}/credential'.post) {
    throw 'Media contract must define POST /api/v1/voice/leases/{leaseID}/credential.'
}

if ($null -eq $openApi.paths.'/api/v1/admin/accounts/{accountID}/voice-kick'.post) {
    throw 'Voice contract must define POST /api/v1/admin/accounts/{accountID}/voice-kick.'
}

foreach ($operation in @(
    $openApi.paths.'/api/v1/admin/accounts/{accountID}/voice-kick'.post,
    $openApi.paths.'/api/v1/admin/voice-channels/{channelID}/close-admission'.post
)) {
    if ($operation.description -notmatch 'durable SFU revocation') {
        throw 'Voice revocation operations must describe the durable SFU-revocation outcome.'
    }
}
