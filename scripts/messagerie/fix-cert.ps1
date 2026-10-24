# fix-cert.ps1 - Certificat TLS via openssl + enregistrement hMailServer + restart
$ErrorActionPreference = 'Continue'
$certDir = 'C:\ProgramData\hMailServer\Certificates'
$crt = Join-Path $certDir 'mail.twisterlab.local.crt'
$key = Join-Path $certDir 'mail.twisterlab.local.key'
New-Item -ItemType Directory -Path $certDir -Force | Out-Null
Remove-Item (Join-Path $certDir '*') -Force -ErrorAction SilentlyContinue

$ossl = 'C:\Program Files\Git\usr\bin\openssl.exe'
"=== Generation openssl ==="
& $ossl req -x509 -newkey rsa:2048 -nodes -keyout $key -out $crt -days 3650 `
    -subj '/CN=mail.twisterlab.local' `
    -addext 'subjectAltName=DNS:mail.twisterlab.local,DNS:twisterlab.local,DNS:localhost' 2>&1 | Out-String
"CERT_EXISTS=$(Test-Path $crt) KEY_EXISTS=$(Test-Path $key)"
"CERT_SIZE=$((Get-Item $crt -ErrorAction SilentlyContinue).Length) KEY_SIZE=$((Get-Item $key -ErrorAction SilentlyContinue).Length)"
& $ossl x509 -in $crt -noout -subject -ext subjectAltName 2>&1 | Out-String

"=== ACL ==="
icacls $crt /inheritance:r /grant:r "$($env:USERNAME):(R)" /grant:r "Administrators:(R)" /grant:r "SYSTEM:(R)" /grant:r "NT SERVICE\hMailServer:(R)" | Out-Null
icacls $key /inheritance:r /grant:r "$($env:USERNAME):(R)" /grant:r "Administrators:(R)" /grant:r "SYSTEM:(R)" /grant:r "NT SERVICE\hMailServer:(R)" | Out-Null
"ACL_OK"

"=== Enregistrement dans hMailServer ==="
$credFile = 'C:\Users\administrator\.twisterlab-mail\credentials.txt'
$hmsAdmin = ((Get-Content $credFile | Select-String -Pattern 'Mot de passe admin hMailServer\s*:\s*(\S+)').Matches.Groups[1].Value)
$app = New-Object -ComObject hMailServer.Application
$app.Authenticate('Administrator', $hmsAdmin) | Out-Null
$sc = $app.Settings.SSLCertificates
"CertCount=$($sc.Count)"
for ($i = 0; $i -lt $sc.Count; $i++) {
  $c = $sc.Item($i)
  "  [$i] id=$($c.ID) name=$($c.Name) crt=$($c.CertificateFile) key=$($c.PrivateKeyFile)"
  $c.Name = 'mail.twisterlab.local'
  $c.CertificateFile = $crt
  $c.PrivateKeyFile = $key
  $c.Save()
  "  -> mis a jour: crt=$($c.CertificateFile) key=$($c.PrivateKeyFile)"
}

"=== Redemarrage du service ==="
Restart-Service hMailServer -Force
Start-Sleep -Seconds 4
Get-Service hMailServer | Select-Object Name, Status | Format-Table -AutoSize
"=== Ports en ecoute ==="
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -in 25,110,143,587,993,2525 } |
  Select-Object LocalAddress, LocalPort, OwningProcess | Sort-Object LocalPort | Format-Table -AutoSize
