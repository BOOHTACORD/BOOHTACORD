param([Parameter(Mandatory)][string]$Client, [Parameter(Mandatory)][string]$Result)
$ErrorActionPreference = 'Stop'
$research = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../.out/audio-research'))
$clientPath = [IO.Path]::GetFullPath($Client)
$resultPath = [IO.Path]::GetFullPath($Result)
foreach ($candidate in @($clientPath, $resultPath)) {
    if (-not $candidate.StartsWith($research + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Only isolated research paths are allowed'
    }
}
if ((Test-Path -LiteralPath $resultPath) -or -not (Test-Path -LiteralPath $clientPath)) { throw 'Fresh result and existing research client required' }
$owned = @(Get-Process -Name 'boohtacord_desktop' | Where-Object Path -EQ $clientPath)
if ($owned.Count -ne 1) { throw 'Exactly one matching research client must be running' }
$processId = $owned[0].Id
$watch = [Diagnostics.Stopwatch]::StartNew()
$samples = [Collections.Generic.List[object]]::new()
while ($watch.Elapsed.TotalSeconds -lt 1900) {
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if (-not $process -or $process.Path -ne $clientPath) { break }
    $samples.Add([pscustomobject]@{
        seconds = [int]$watch.Elapsed.TotalSeconds
        workingSetBytes = $process.WorkingSet64
        privateBytes = $process.PrivateMemorySize64
    })
    $process.Dispose()
    Start-Sleep -Seconds 30
}
$value = [pscustomobject]@{ scope='owned-research-process-only'; samples=$samples }
$json = $value | ConvertTo-Json -Depth 4
$bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
$stream = [IO.File]::Open($resultPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
Write-Output "Memory observations saved: $($samples.Count) samples"
