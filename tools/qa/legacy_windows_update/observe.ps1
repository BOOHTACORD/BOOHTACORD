param([Parameter(Mandatory=$true)][int]$ClientProcess,
      [Parameter(Mandatory=$true)][ValidateSet('old','current')][string]$Mode,
      [Parameter(Mandatory=$true)][string]$Version,
      [Parameter(Mandatory=$true)][int]$Build,
      [Parameter(Mandatory=$true)][string]$TargetVersion,
      [Parameter(Mandatory=$true)][string]$Summary,
      [Parameter(Mandatory=$true)][string]$Output)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,WindowsBase,System.Drawing
Add-Type -Path @((Join-Path $PSScriptRoot 'window.cs'),(Join-Path $PSScriptRoot 'capture.cs')) -ReferencedAssemblies UIAutomationClient,UIAutomationTypes,WindowsBase,System.Drawing
$result=@{status='FAIL';mode=$Mode;version=$Version;native_build=$Build;pid_scoped=$false}
try {
  $client=Get-Process -Id $ClientProcess
  $info=[Diagnostics.FileVersionInfo]::GetVersionInfo($client.Path)
  $actualVersion="$($info.FileMajorPart).$($info.FileMinorPart).$($info.FileBuildPart)"
  if ($actualVersion -ne $Version -or $info.FilePrivatePart -ne $Build) { throw 'pe_identity_mismatch' }
  $deadline=[DateTime]::UtcNow.AddSeconds(60)
  do {
    try { $names=[LegacyWindow]::Names($ClientProcess) } catch { $names=@() }
    $versionSeen=[LegacyWindow]::Contains($names,$Version)
    $offer=[LegacyWindow]::Offer($names)
    if ($versionSeen -and ($Mode -eq 'current' -or ($offer -and [LegacyWindow]::Contains($names,$Summary)))) { break }
    Start-Sleep -Milliseconds 500
  } while ([DateTime]::UtcNow -lt $deadline)
  if (!$versionSeen -or ($Mode -eq 'old' -and !$offer)) { throw 'uia_offer_or_version_timeout' }
  $result.version_visible=$true
  $result.pid_scoped=$true
  if ($Mode -eq 'old') {
    [LegacyCapture]::Save($ClientProcess,(Join-Path $Output 'old-offer.png'))
    [LegacyWindow]::Details($ClientProcess)
    $detailsDeadline=[DateTime]::UtcNow.AddSeconds(10)
    do {
      Start-Sleep -Milliseconds 500
      $result.details_version_visible=[LegacyWindow]::Contains([LegacyWindow]::Names($ClientProcess),$TargetVersion)
    } while (!$result.details_version_visible -and [DateTime]::UtcNow -lt $detailsDeadline)
    if (!$result.details_version_visible) { throw 'details_target_version_missing' }
    [LegacyCapture]::Save($ClientProcess,(Join-Path $Output 'old-details.png'))
  } else {
    Start-Sleep -Seconds 20
    $names=[LegacyWindow]::Names($ClientProcess)
    $offer=[LegacyWindow]::Offer($names) -or [LegacyWindow]::Contains($names,$Summary)
    $result.incorrect_status_visible=[LegacyWindow]::Incorrect($names)
    if ($offer -or $result.incorrect_status_visible) { throw 'incorrect_current_update_offer' }
  }
  $result.offer_visible=$offer
  $result.screenshot="$Mode-offer.png"
  if ($Mode -eq 'current') { [LegacyCapture]::Save($ClientProcess,(Join-Path $Output $result.screenshot)) }
  $result.status='PASS'
} catch {
  $result.reason='native_observation_failed'
  foreach ($reason in @('pe_identity_mismatch','uia_offer_or_version_timeout','details_target_version_missing','incorrect_current_update_offer')) {
    if ($_.Exception.Message.Contains($reason)) { $result.reason=$reason }
  }
  $result.uia_visible_names=@($names).Count
  try { [LegacyCapture]::Save($ClientProcess,(Join-Path $Output "$Mode-failure.png")) } catch { }
} finally {
  $json=$result | ConvertTo-Json -Depth 4
  [IO.File]::WriteAllText((Join-Path $Output "$Mode.json"),$json,[Text.UTF8Encoding]::new($false))
}
if ($result.status -ne 'PASS') { exit 1 }
