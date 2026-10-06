# Relevé d'inventaire Windows — Core / DC-DELL
# Usage: powershell -ExecutionPolicy Bypass -File inventory.ps1

$os  = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor
$cs  = Get-CimInstance Win32_ComputerSystem
$gpu = Get-CimInstance Win32_VideoController

Write-Output "=== OS ==="
Write-Output ("Caption=" + $os.Caption)
Write-Output ("Version=" + $os.Version + " Build=" + $os.BuildNumber)
Write-Output ("Arch=" + $os.OSArchitecture)
Write-Output ("Uptime_h=" + [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours,1))

Write-Output "=== CPU ==="
Write-Output ("Name=" + $cpu.Name)
Write-Output ("Cores=" + $cpu.NumberOfCores + " Threads=" + $cpu.NumberOfLogicalProcessors)
Write-Output ("MaxClockMHz=" + $cpu.MaxClockSpeed)

Write-Output "=== RAM ==="
Write-Output ("Total_GB=" + [math]::Round($cs.TotalPhysicalMemory/1GB,1))
Write-Output ("Free_GB=" + [math]::Round($os.FreePhysicalMemory/1MB,1))

Write-Output "=== GPU ==="
foreach ($g in $gpu) {
  Write-Output ($g.Name + " | VRAM_GB=" + [math]::Round($g.AdapterRAM/1GB,1) + " | Driver=" + $g.DriverVersion)
}

Write-Output "=== DISKS ==="
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
  Write-Output ($_.DeviceID + " Total_GB=" + [math]::Round($_.Size/1GB,1) + " Free_GB=" + [math]::Round($_.FreeSpace/1GB,1))
}

Write-Output "=== NET ==="
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } | ForEach-Object {
  Write-Output ($_.InterfaceAlias + " = " + $_.IPAddress)
}

Write-Output "=== LISTEN ==="
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty LocalPort | Sort-Object -Unique | ForEach-Object { Write-Output ("port=" + $_) }

Write-Output "=== DOMAIN ==="
Write-Output ("Domain=" + $cs.Domain + " DomainRole=" + $cs.DomainRole)

Write-Output "=== DONE ==="
