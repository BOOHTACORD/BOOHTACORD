param([Parameter(Mandatory=$true)][string]$Path,
      [Parameter(Mandatory=$true)][string]$Thumbprint)
$ErrorActionPreference = 'Stop'
$signature = Get-AuthenticodeSignature -LiteralPath $Path
$valid = $signature.Status -eq 'Valid' -and
    $null -ne $signature.SignerCertificate -and
    $signature.SignerCertificate.Thumbprint -eq $Thumbprint -and
    $null -ne $signature.TimeStamperCertificate
@{valid=[bool]$valid} | ConvertTo-Json -Compress
