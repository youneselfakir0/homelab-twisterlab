# mkadusers.ps1 - Cree les utilisateurs AD admin/test sur DC-DELL
$ErrorActionPreference = 'Continue'
$payload = 'C:\temp\ad-payload.txt'
"=== Lecture du payload ==="
$lines = Get-Content $payload
$pwAdmin = ($lines | Where-Object { $_ -like 'admin=*' }) -replace '^admin=',''
$pwTest  = ($lines | Where-Object { $_ -like 'test=*' })  -replace '^test=',''
"LONGUEURS: admin=$($pwAdmin.Length) test=$($pwTest.Length)"

Import-Module ActiveDirectory

function Make-User($sam, $display, $pw) {
  $existing = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
  if ($existing) {
    "  $sam : DEJA EXISTANT (DN=$($existing.DistinguishedName))"
    return $existing
  }
  $upn = "$sam@twisterlab.local"
  $sec = ConvertTo-SecureString $pw -AsPlainText -Force
  $u = New-ADUser -Name $display -SamAccountName $sam -UserPrincipalName $upn `
        -DisplayName $display -GivenName $display -Enabled $true `
        -AccountPassword $sec -PasswordNeverExpires $true -ChangePasswordAtLogon $false `
        -EmailAddress "$upn" -PassThru
  Set-ADUser -Identity $u -Replace @{ mail = $upn }
  "  $sam : CREE  DN=$($u.DistinguishedName)  UPN=$upn  Enabled=$((Get-ADUser -Identity $sam -Properties Enabled).Enabled)"
  return $u
}

"=== Creation ==="
Make-User 'admin' 'Mail Admin' $pwAdmin
Make-User 'test'  'Mail Test'  $pwTest

"=== Verification finale (tous les users actifs) ==="
Get-ADUser -Filter * -Properties SamAccountName, DisplayName, Enabled, EmailAddress |
  Sort-Object SamAccountName |
  Select-Object SamAccountName, DisplayName, Enabled, EmailAddress |
  Format-Table -AutoSize | Out-String -Width 200

Remove-Item $payload -Force -ErrorAction SilentlyContinue
"PAYLOAD_SUPPRIME=$(-not (Test-Path $payload))"
