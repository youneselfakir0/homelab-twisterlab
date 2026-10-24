# dns-records.ps1 - Enregistrements DNS A + MX sur DC-DELL
$ErrorActionPreference = 'Continue'
$zone = 'twisterlab.local'

"=== Zone ==="
Get-DnsServerZone -Name $zone | Select-Object ZoneName, ZoneType, DynamicUpdate, Stale | Format-List

"=== A: mail.twisterlab.local -> 192.168.0.12 ==="
$existing = Get-DnsServerResourceRecord -ZoneName $zone -Name 'mail' -ErrorAction SilentlyContinue
if ($existing) {
  "  mail existant: $($existing.RecordData.IPv4Address.IPAddressToString) -> remplacement"
  Remove-DnsServerResourceRecord -ZoneName $zone -Name 'mail' -Force -ErrorAction SilentlyContinue
}
Add-DnsServerResourceRecordA -Name 'mail' -ZoneName $zone -IPv4Address '192.168.0.12' -ErrorAction Stop | Out-Null
"  mail.twisterlab.local -> 192.168.0.12 CREE"

"=== MX: twisterlab.local -> mail.twisterlab.local (pref 10) ==="
$existingMx = Get-DnsServerResourceRecord -ZoneName $zone -Name '@' -RecordType MX -ErrorAction SilentlyContinue
if ($existingMx) {
  "  MX existant: $($existingMx.RecordData.MailExchange) -> remplacement"
  Remove-DnsServerResourceRecord -ZoneName $zone -Name '@' -RecordType MX -Force -ErrorAction SilentlyContinue
}
Add-DnsServerResourceRecord -MX -Name '@' -ZoneName $zone -MailExchange 'mail.twisterlab.local' -Preference 10 -ErrorAction Stop | Out-Null
"  MX twisterlab.local -> mail.twisterlab.local (pref 10) CREE"

"=== Verification ==="
"--- A records ---"
Get-DnsServerResourceRecord -ZoneName $zone -ErrorAction Stop |
  Where-Object { $_.RecordType -eq 'A' } |
  Select-Object HostName, @{n='IPv4';e={ $_.RecordData.IPv4Address.IPAddressToString }} |
  Format-Table -AutoSize | Out-String -Width 200
"--- MX records ---"
Get-DnsServerResourceRecord -ZoneName $zone -ErrorAction Stop |
  Where-Object { $_.RecordType -eq 'MX' } |
  Select-Object HostName, @{n='MailExchange';e={ $_.RecordData.MailExchange }}, @{n='Pref';e={ $_.RecordData.Preference }} |
  Format-Table -AutoSize | Out-String -Width 200
