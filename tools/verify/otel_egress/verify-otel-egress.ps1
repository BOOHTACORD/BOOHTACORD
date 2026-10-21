$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Push-Location $projectRoot
try {
    if ($env:VOICE_PLATFORM_COMPOSE_CLI) {
        $json = & $env:VOICE_PLATFORM_COMPOSE_CLI --env-file .env.example -f deploy/compose.yaml config --format json
    } else {
        $json = docker compose --env-file .env.example -f deploy/compose.yaml config --format json
    }
    if ($LASTEXITCODE -ne 0) { throw 'Compose config failed.' }
    $api = ($json -join "`n" | ConvertFrom-Json).services.api

    $environmentNames = @($api.environment.PSObject.Properties.Name)
    foreach ($required in @('OTEL_EXPORTER_OTLP_ENDPOINT', 'OTEL_INGEST_AUTH')) {
        if ($environmentNames -notcontains $required) {
            throw "API must receive $required from the private deployment environment."
        }
    }
    if ($api.extra_hosts -and @($api.extra_hosts).Count -gt 0) {
        throw 'Shared API Compose must not hardcode deployment-specific host/IP overrides; use an operator overlay.'
    }
    if (@($api.networks.PSObject.Properties.Name) -notcontains 'telemetry-egress') {
        throw 'API needs a dedicated outbound network for OTLP export.'
    }
} finally {
    Pop-Location
}
