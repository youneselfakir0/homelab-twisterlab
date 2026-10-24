# gen-ad-secrets.ps1 - Genere les mots de passe AD (local, ne jamais afficher)
$ErrorActionPreference = 'Stop'
$secretDir = 'C:\Users\administrator\.twisterlab-mail'
$credFile  = Join-Path $secretDir 'credentials.txt'
$payload   = Join-Path $secretDir 'ad-payload.txt'
New-Item -ItemType Directory -Path $secretDir -Force | Out-Null

function New-Pw([int]$n) {
  $a = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz23456789_.+'
  $b = New-Object byte[] $n
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
  $s = -join ($b | ForEach-Object { $a[$_ % $a.Length] })
  if ($s[0] -notmatch '[A-Za-z]') { $s = 'Q' + $s.Substring(1) }
  return $s
}

$pwAdmin = New-Pw 28
$pwTest  = New-Pw 28

# -- credentials file (local, ACL restreint) --
$block = @"

=== Comptes AD crees pour la messagerie (2026-10-24) ===
samaccountname=admin
  mot de passe = $pwAdmin
  upn = admin@twisterlab.local
samaccountname=test
  mot de passe = $pwTest
  upn = test@twisterlab.local
"@
Add-Content -Path $credFile -Value $block -Encoding UTF8
icacls $credFile /inheritance:r /grant:r "$($env:USERNAME):(R,W)" /grant:r "Administrators:(R,W)" /grant:r "SYSTEM:(R)" | Out-Null

# -- payload pour DC-DELL (sera supprime apres usage) --
Set-Content -Path $payload -Value "admin=$pwAdmin`ntest=$pwTest" -Encoding ASCII
"CRED_FILE=$credFile"
"PAYLOAD=$payload"
"PAYLOAD_LEN=$((Get-Item $payload).Length)"
"ADMIN_PW_LEN=$($pwAdmin.Length)  TEST_PW_LEN=$($pwTest.Length)"
