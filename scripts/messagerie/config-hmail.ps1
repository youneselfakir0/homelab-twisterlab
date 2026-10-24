# config-hmail.ps1 - Configuration hMailServer 5.7.1 / twisterlab.local
$ErrorActionPreference = 'Continue'
$credFile = 'C:\Users\administrator\.twisterlab-mail\credentials.txt'
$txt = Get-Content $credFile -Raw

function Get-Pw($sam) {
  $m = [regex]::Match($txt, "(?s)samaccountname=$sam\s*\r?\n\s*mot de passe\s*=\s*(\S+)")
  return $m.Groups[1].Value
}
$hmsAdmin = ((Get-Content $credFile | Select-String -Pattern 'Mot de passe admin hMailServer\s*:\s*(\S+)').Matches.Groups[1].Value)
$pwAdmin  = Get-Pw 'admin'
$pwTest   = Get-Pw 'test'
"TAILLE_MOTS_DE_PASSE: hms=$($hmsAdmin.Length) admin=$($pwAdmin.Length) test=$($pwTest.Length)"

# ============================================================
# 1. Certificat auto-signe mail.twisterlab.local
# ============================================================
$certDir = 'C:\ProgramData\hMailServer\Certificates'
New-Item -ItemType Directory -Path $certDir -Force | Out-Null
$crt = Join-Path $certDir 'mail.twisterlab.local.crt'
$key = Join-Path $certDir 'mail.twisterlab.local.key'
try {
  $rsa = [System.Security.Cryptography.RSA]::Create(2048)
  $req = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
      'CN=mail.twisterlab.local', $rsa, 'SHA256', [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
  $san = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
  $san.AddDnsName('mail.twisterlab.local'); $san.AddDnsName('twisterlab.local'); $san.AddDnsName('localhost')
  $req.CertificateExtensions.Add($san.Build())
  $cert = $req.CreateSelfSigned([DateTimeOffset]::Now.AddDays(-1), [DateTimeOffset]::Now.AddYears(10))
  $crtPem = "-----BEGIN CERTIFICATE-----`n" + [Convert]::ToBase64String($cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert), 'InsertLineBreaks') + "`n-----END CERTIFICATE-----"
  $keyPem = "-----BEGIN PRIVATE KEY-----`n" + [Convert]::ToBase64String($rsa.ExportPkcs8PrivateKey(), 'InsertLineBreaks') + "`n-----END PRIVATE KEY-----"
  Set-Content -Path $crt -Value $crtPem -Encoding ASCII
  Set-Content -Path $key -Value $keyPem -Encoding ASCII
  icacls $crt /inheritance:r /grant:r "$($env:USERNAME):(R)" /grant:r "Administrators:(R)" /grant:r "SYSTEM:(R)" /grant:r "NT SERVICE\hMailServer:(R)" | Out-Null
  icacls $key /inheritance:r /grant:r "$($env:USERNAME):(R)" /grant:r "Administrators:(R)" /grant:r "SYSTEM:(R)" /grant:r "NT SERVICE\hMailServer:(R)" | Out-Null
  "CERT_OK subject=$($cert.Subject) thumbprint=$($cert.Thumbprint) notAfter=$($cert.NotAfter)"
} catch { "CERT_ERR: $($_.Exception.Message)" }

# ============================================================
# 2. Connexion COM
# ============================================================
$app = New-Object -ComObject hMailServer.Application
$auth = $app.Authenticate('Administrator', $hmsAdmin)
if ($null -eq $auth) { throw 'ECHEC authentification COM' }
"HMS_VERSION=$($app.Version) AUTH=OK"

# ============================================================
# 3. Reglages globaux
# ============================================================
$s = $app.Settings
$s.HostName = 'mail.twisterlab.local'
$s.SMTPRelayer = ''                       # AUCUN relais externe
$s.MirrorEMailAddress = ''
$s.ServiceSMTP = $true
$s.ServiceIMAP = $true
$s.ServicePOP3 = $false                   # POP3 non demande -> desactive
$s.AllowSMTPAuthPlain = $true             # AUTH LOGIN/PLAIN (sur 587, STARTTLS dispo)
$s.SMTPRelayerRequiresAuthentication = $false
"SETTINGS: HostName=$($s.HostName) ServiceSMTP=$($s.ServiceSMTP) ServiceIMAP=$($s.ServiceIMAP) ServicePOP3=$($s.ServicePOP3) SMTPRelayer='$($s.SMTPRelayer)'"

# ============================================================
# 4. Certificat dans hMailServer
# ============================================================
$certObj = $null
try {
  $sc = $s.SSLCertificates
  foreach ($i in 0..($sc.Count - 1)) {
    try { if ($sc.Item($i).CertificateFile -eq $crt) { $certObj = $sc.Item($i); break } } catch {}
  }
  if (-not $certObj) {
    $certObj = $sc.Add()
    $certObj.Name = 'mail.twisterlab.local'
    $certObj.CertificateFile = $crt
    $certObj.PrivateKeyFile = $key
    $certObj.Save()
  }
  "SSL_CERT_ID=$($certObj.ID)"
} catch { "SSL_CERT_ERR: $($_.Exception.Message)" }

# ============================================================
# 5. Ports TCP/IP  (collection 0-based)
#    0=SMTP25  1=POP3-110  2=IMAP143  3=SMTP587
# ============================================================
$ports = $s.TCPIPPorts
"PORTS_AVANT:"
for ($i = 0; $i -lt $ports.Count; $i++) {
  $p = $ports.Item($i)
  "  [$i] proto=$($p.Protocol) port=$($p.PortNumber) ssl=$($p.UseSSL) connsec=$($p.ConnectionSecurity)"
}
function Set-Port($idx, $proto, $portNum, $connSec, $certId) {
  $p = $ports.Item($idx)
  if ($p.Protocol -ne $proto -or $p.PortNumber -ne $portNum) { "  ATTENTION slot $idx inattendu (proto=$($p.Protocol) port=$($p.PortNumber))" }
  $p.Protocol = $proto
  $p.PortNumber = $portNum
  $p.Address = '0.0.0.0'
  $p.UseSSL = $false
  $p.ConnectionSecurity = $connSec
  $p.SSLCertificateID = $certId
  $p.Save()
  "  slot $idx -> proto=$proto port=$portNum connsec=$connSec cert=$certId"
}
# SMTP 25 =clair (livraison interne)
Set-Port 0 1 25 0 0
# IMAP 143 = clair
Set-Port 2 5 143 0 0
# SMTP Submission 587 = STARTTLS optionnel
Set-Port 3 1 587 2 $certObj.ID
# POP3 110 -> supprime
try { $ports.Item(1).Delete(); "  slot 1 (POP3 110) SUPPRIME" } catch { "  POP3 delete err: $($_.Exception.Message)" }

"PORTS_APRES:"
for ($i = 0; $i -lt $ports.Count; $i++) {
  $p = $ports.Item($i)
  "  [$i] proto=$($p.Protocol) port=$($p.PortNumber) ssl=$($p.UseSSL) connsec=$($p.ConnectionSecurity) cert=$($p.SSLCertificateID)"
}

# ============================================================
# 6. Security ranges  (anti-relais + pas de reception Internet)
# ============================================================
$sr = $s.SecurityRanges
"SECURITY_RANGES_AVANT:"
for ($i = 0; $i -lt $sr.Count; $i++) {
  $r = $sr.Item($i)
  "  [$i] name=$($r.Name) prio=$($r.Priority) lower=$($r.LowerIP) upper=$($r.UpperIP)"
}
$LAN_LO, $LAN_HI = '192.168.0.0', '192.168.0.255'
$lanRange = $null
for ($i = 0; $i -lt $sr.Count; $i++) {
  $r = $sr.Item($i)
  if ($r.Name -eq 'LAN-TwisterLab') { $lanRange = $r; break }
}
if (-not $lanRange) {
  $lanRange = $sr.Add()
  $lanRange.Name = 'LAN-TwisterLab'
  $lanRange.LowerIP = $LAN_LO
  $lanRange.UpperIP = $LAN_HI
  $lanRange.Priority = 5
  $lanRange.Save()
}
$lanRange.AllowSMTPConnections = $true
$lanRange.AllowIMAPConnections = $true
$lanRange.AllowPOP3Connections = $true
$lanRange.AllowDeliveryFromLocalToLocal = $true
$lanRange.AllowDeliveryFromLocalToRemote = $false     # anti-relais sortant
$lanRange.AllowDeliveryFromRemoteToLocal = $true
$lanRange.AllowDeliveryFromRemoteToRemote = $false
$lanRange.RequireAuthForDeliveryToLocal = $true
$lanRange.RequireSMTPAuthLocalToLocal = $true
$lanRange.RequireSMTPAuthLocalToExternal = $true
$lanRange.IsForwardingRelay = $false
$lanRange.Save()
"  LAN-TwisterLab: prio=$($lanRange.Priority) range=$($lanRange.LowerIP)-$($lanRange.UpperIP)"

# Plages existantes (My computer prio 1, Internet prio 10)
for ($i = 0; $i -lt $sr.Count; $i++) {
  $r = $sr.Item($i)
  if ($r.Name -eq 'LAN-TwisterLab') { continue }
  if ($r.Name -eq 'My computer') {
    $r.AllowSMTPConnections = $true; $r.AllowIMAPConnections = $true
    $r.AllowDeliveryFromLocalToLocal = $true
    $r.AllowDeliveryFromLocalToRemote = $false
    $r.AllowDeliveryFromRemoteToLocal = $true
    $r.AllowDeliveryFromRemoteToRemote = $false
    $r.RequireAuthForDeliveryToLocal = $true
    $r.RequireSMTPAuthLocalToLocal = $true
    $r.IsForwardingRelay = $false
    $r.Save(); "  My computer: localToLocal=True localToRemote=False"
  } elseif ($r.Name -eq 'Internet') {
    $r.AllowSMTPConnections = $true; $r.AllowIMAPConnections = $true
    $r.AllowDeliveryFromLocalToLocal = $false
    $r.AllowDeliveryFromLocalToRemote = $false     # pas de relais sortant
    $r.AllowDeliveryFromRemoteToLocal = $false     # pas de reception Internet
    $r.AllowDeliveryFromRemoteToRemote = $false
    $r.RequireSMTPAuthLocalToLocal = $true
    $r.RequireSMTPAuthLocalToExternal = $true
    $r.IsForwardingRelay = $false
    $r.Save(); "  Internet: localToLocal=False localToRemote=False remoteToLocal=False"
  }
}
"SECURITY_RANGES_APRES:"
for ($i = 0; $i -lt $sr.Count; $i++) {
  $r = $sr.Item($i)
  "  name=$($r.Name) prio=$($r.Priority) L2L=$($r.AllowDeliveryFromLocalToLocal) L2R=$($r.AllowDeliveryFromLocalToRemote) R2L=$($r.AllowDeliveryFromRemoteToLocal) R2R=$($r.AllowDeliveryFromRemoteToRemote) relay=$($r.IsForwardingRelay)"
}

# ============================================================
# 7. Domaine twisterlab.local
# ============================================================
$dom = $null
for ($i = 0; $i -lt $app.Domains.Count; $i++) { if ($app.Domains.Item($i).Name -eq 'twisterlab.local') { $dom = $app.Domains.Item($i) } }
if (-not $dom) { $dom = $app.Domains.Add() }
$dom.Name = 'twisterlab.local'
$dom.Active = $true
$dom.ADDomainName = 'twisterlab.local'
$dom.MaxAccountSize = 1000          # 1 Go par boite
$dom.MaxNumberOfAccounts = 0        # illimite
$dom.Save()
"DOMAINE: name=$($dom.Name) active=$($dom.Active) ADDomainName=$($dom.ADDomainName) maxAccountSizeMB=$($dom.MaxAccountSize) maxAccounts=$($dom.MaxNumberOfAccounts)"

# ============================================================
# 8. Comptes - 1 par utilisateur AD actif (+ admin/test)
# ============================================================
$adUsers = @(
  @{ sam = 'Administrator'; disp = 'Administrator' },
  @{ sam = 'alex';          disp = 'alex rusk' },
  @{ sam = 'devuser';       disp = 'devuser' },
  @{ sam = 'maya';          disp = 'Maya' },
  @{ sam = 'admin';         disp = 'Mail Admin' },
  @{ sam = 'test';          disp = 'Mail Test' }
)
"COMPTES:"
foreach ($u in $adUsers) {
  $addr = "$($u.sam)@twisterlab.local"
  $exists = $null
  try { $exists = $dom.Accounts.ItemByAddress($addr) } catch { $exists = $null }
  if (-not $exists) {
    for ($i = 0; $i -lt $dom.Accounts.Count; $i++) {
      if ($dom.Accounts.Item($i).Address -eq $addr) { $exists = $dom.Accounts.Item($i); break }
    }
  }
  if ($exists) {
    "  $addr -> DEJA PRESENT (isAD=$($exists.IsAD))"
    continue
  }
  $a = $dom.Accounts.Add()
  $a.Address = $addr
  $a.Active = $true
  $a.MaxSize = 1000
  $a.PersonFirstName = $u.disp
  $a.IsAD = $true                    # auth via AD, aucun mot de passe stocké
  $a.ADDomain = 'twisterlab.local'
  $a.ADUsername = $u.sam
  $a.Save()
  "  $addr -> CREE isAD=True ADUser=$($u.sam) sizeMB=$($a.MaxSize)"
}

"COMPTES_FINAL:"
for ($i = 0; $i -lt $dom.Accounts.Count; $i++) {
  $a = $dom.Accounts.Item($i)
  "  $($a.Address)  active=$($a.Active) isAD=$($a.IsAD) ADDomain=$($a.ADDomain) ADUser=$($a.ADUsername) adminLevel=$($a.AdminLevel)"
}
