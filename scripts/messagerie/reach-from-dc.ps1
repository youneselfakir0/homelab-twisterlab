# reach-from-dc.ps1 - Test de joignabilite depuis DC-DELL (192.168.0.100)
$ErrorActionPreference = 'Continue'
$target = 'mail.twisterlab.local'
"=== Cible: $target ==="
"Resolution: " + ((Resolve-DnsName -Name $target -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress } | Select-Object -First 1).IPAddress)

foreach ($port in 25, 143, 587) {
  $r = Test-NetConnection -ComputerName $target -Port $port -WarningAction SilentlyContinue
  "TCP $port -> TcpTestSucceeded=$($r.TcpTestSucceeded) RemoteAddress=$($r.RemoteAddress)"
}

"=== Banners de service (lecture directe) ==="
function Get-Banner($port, $probe) {
  try {
    $c = New-Object System.Net.Sockets.TcpClient
    $c.Connect($target, $port)
    $s = $c.GetStream(); $s.ReadTimeout = 8000
    if ($probe) {
      $w = New-Object System.IO.StreamWriter($s); $w.AutoFlush = $true
      $w.WriteLine($probe)
    }
    Start-Sleep -Milliseconds 700
    $buf = New-Object byte[] 512
    $n = $s.Read($buf, 0, 512)
    $txt = [Text.Encoding]::UTF8.GetString($buf, 0, $n).Trim()
    $c.Close()
    return $txt
  } catch { return "ERREUR: $($_.Exception.Message)" }
}
"SMTP 25   : " + (Get-Banner 25 $null)
"SMTP 587  : " + (Get-Banner 587 $null)
"IMAP 143  : " + (Get-Banner 143 $null)
"SMTP 25 apres EHLO: " + (Get-Banner 25 "EHLO dc-dell.twisterlab.local")
