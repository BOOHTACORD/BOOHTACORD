$watch = $openApi.paths.'/api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}'.put
$stop = $openApi.paths.'/api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}'.delete
$list = $openApi.paths.'/api/v1/voice/leases/{ownerLeaseID}/screen-viewers'.get
$viewerList = $openApi.paths.'/api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}'.get
$clear = $openApi.paths.'/api/v1/voice/leases/{ownerLeaseID}/screen-viewers'.delete
if ($null -eq $watch -or $watch.operationId -ne 'reportScreenViewerPresence' -or
    $watch.description -notmatch 'active, unrevoked voice leases in the same open VOICE channel' -or
    $watch.requestBody.content.'application/json'.schema.additionalProperties -ne $false -or
    $watch.requestBody.content.'application/json'.schema.properties.track_sid.maxLength -ne 128) {
    throw 'Screen viewer reporting must bind a bounded current-track report to active same-channel voice leases.'
}
if ($null -eq $stop -or $stop.operationId -ne 'stopScreenViewerPresence' -or
    $stop.parameters.name -notcontains 'track_sid') {
    throw 'Viewer cleanup must identify the unsubscribed track to protect replacement publications.'
}
if ($null -eq $list -or $list.operationId -ne 'listScreenViewerPresence' -or
    $list.responses.'200'.headers.'Cache-Control'.schema.const -ne 'private, no-store, max-age=0' -or
    $list.responses.'200'.content.'application/json'.schema.properties.PSObject.Properties.Name.Count -ne 1) {
    throw 'Only the authenticated owner may read a private/no-store viewer snapshot.'
}
if ($null -eq $viewerList -or $viewerList.operationId -ne 'listScreenViewerPresenceForViewer' -or
    $viewerList.description -notmatch 'active, unrevoked voice leases in the same open VOICE channel' -or
    $viewerList.description -notmatch 'active media subscription' -or
    $viewerList.responses.'200'.headers.'Cache-Control'.schema.const -ne 'private, no-store, max-age=0' -or
    $viewerList.security[0].SessionCookie.Count -ne 0) {
    throw 'An active same-channel viewer may read only a private/no-store screen audience snapshot.'
}
if ($null -eq $clear -or $clear.operationId -ne 'clearScreenViewerPresence' -or
    $clear.security[0].SessionCookie.Count -ne 0) {
    throw 'Only the session-authenticated owner may clear its viewer presence.'
}
$viewerEvent = $realtime.allOf | Where-Object { $_.if.properties.kind.const -eq 'screen_viewers.changed' } | Select-Object -First 1
if ($realtime.properties.kind.enum -notcontains 'screen_viewers.changed' -or $null -eq $viewerEvent -or
    $viewerEvent.then.properties.payload.additionalProperties -ne $false -or
    $viewerEvent.then.properties.payload.maxProperties -ne 0) {
    throw 'Realtime screen viewer updates must be empty invalidations without account IDs.'
}
