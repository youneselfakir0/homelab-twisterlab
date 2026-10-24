# fw-and-log.ps1 - Pare-feu Windows + journalisation hMailServer
$ErrorActionPreference = 'Continue'
$exe = 'C:\Program Files\hMailServer\Bin\hMailServer.exe'

"=== 1. Regles entrantes (TCP 25 / 143 / 587) ==="
$inbound = @(
  @{ port = 25;  proto = 'SMTP' },
  @{ port = 143; proto = 'IMAP' },
  @{ port = 587; proto = 'SMTP Submission' }
)
foreach ($r in $inbound) {
  $name = "hMailServer - entree TCP $($r.port) ($($r.proto))"
  Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName $name -Direction Inbound -Action Allow `
      -Protocol TCP -LocalPort $r.port -Profile Domain `
      -Description "Messagerie interne twisterlab.local - $($r.proto)" | Out-Null
  "  TCP $($r.port) entree -> AUTORISE (profil Domain)"
}

"=== 2. Blocage sortant TCP 25 pour hMailServer.exe (anti-relais sortant) ==="
$blk = 'hMailServer - BLOQUER relais SMTP sortant'
Get-NetFirewallRule -DisplayName $blk -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName $blk -Direction Outbound -Action Block `
    -Protocol TCP -RemotePort 25 -Program $exe -Profile Domain `
    -Description "Garantit l'absence totale de relais/envoi SMTP vers Internet" | Out-Null
"  TCP 25 sortant (hMailServer.exe) -> BLOQUE"

"=== 3. Journalisation hMailServer ==="
$credFile = 'C:\Users\administrator\.twisterlab-mail\credentials.txt'
$hmsAdmin = ((Get-Content $credFile | Select-String -Pattern 'Mot de passe admin hMailServer\s*:\s*(\S+)').Matches.Groups[1].Value)
$app = New-Object -ComObject hMailServer.Application
$app.Authenticate('Administrator', $hmsAdmin) | Out-Null
$log = $app.Settings.Logging
$log.Enabled = $true
$log.LogSMTP = $true
$log.LogIMAP = $true
$log.LogApplication = $true
$log.LogDebug = $false
$log.MaskPasswordsInLog = $true
"  Logging enabled=$($log.Enabled) SMTP=$($log.LogSMTP) IMAP=$($log.LogIMAP) APP=$($log.LogApplication)"

Restart-Service hMailServer -Force
Start-Sleep -Seconds 5
Get-Service hMailServer | Select-Object Name, Status | Format-Table -AutoSize

"=== 4. Verification pare-feu ==="
Get-NetFirewallRule -DisplayName 'hMailServer*' -ErrorAction SilentlyContinue |
  Select-Object DisplayName, Direction, Action, Enabled, Profile |
  Format-Table -AutoSize | Out-String -Width 200
"=== Ports en ecoute ==="
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -in 25,110,143,587 } |
  Select-Object LocalAddress, LocalPort | Sort-Object LocalPort | Format-Table -AutoSize
