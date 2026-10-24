# fix-priority.ps1 - Corrige la priorite de la plage LAN (desc: le plus haut gagne)
$ErrorActionPreference = 'Continue'
$credFile = 'C:\Users\administrator\.twisterlab-mail\credentials.txt'
$hmsAdmin = ((Get-Content $credFile | Select-String -Pattern 'Mot de passe admin hMailServer\s*:\s*(\S+)').Matches.Groups[1].Value)
$app = New-Object -ComObject hMailServer.Application
$app.Authenticate('Administrator', $hmsAdmin) | Out-Null
$sr = $app.Settings.SecurityRanges
"PRIORITY_AVANT:"
for ($i = 0; $i -lt $sr.Count; $i++) {
  $r = $sr.Item($i)
  "  name=$($r.Name) prio=$($r.Priority) range=$($r.LowerIP)-$($r.UpperIP)"
}
for ($i = 0; $i -lt $sr.Count; $i++) {
  $r = $sr.Item($i)
  if ($r.Name -eq 'LAN-TwisterLab') {
    $r.Priority = 40          # > My computer (30) et Internet (10)
    $r.Save()
    "  LAN-TwisterLab priority -> 40"
  }
}
"PRIORITY_APRES (ordre d'evaluation desc):"
for ($i = 0; $i -lt $sr.Count; $i++) {
  $r = $sr.Item($i)
  "  prio=$($r.Priority) name=$($r.Name) L2L=$($r.AllowDeliveryFromLocalToLocal) L2R=$($r.AllowDeliveryFromLocalToRemote) R2L=$($r.AllowDeliveryFromRemoteToLocal)"
}
Restart-Service hMailServer -Force
Start-Sleep -Seconds 5
Get-Service hMailServer | Select-Object Name, Status | Format-Table -AutoSize
