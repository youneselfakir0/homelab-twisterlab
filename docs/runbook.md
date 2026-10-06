# Runbook — relevé reproductible

Commandes exactes utilisées pour produire l'inventaire. À exécuter sur chaque nœud.

## Windows (Core, DC-DELL)

### Système, CPU, RAM, GPU

```powershell
$os  = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor
$cs  = Get-CimInstance Win32_ComputerSystem
$gpu = Get-CimInstance Win32_VideoController

"OS=" + $os.Caption + " Build=" + $os.BuildNumber
"CPU=" + $cpu.Name + " Cores=" + $cpu.NumberOfCores + " Threads=" + $cpu.NumberOfLogicalProcessors
"RAM_Total_GB=" + [math]::Round($cs.TotalPhysicalMemory/1GB,1) + " Free_GB=" + [math]::Round($os.FreePhysicalMemory/1MB,1)
foreach ($g in $gpu) { $g.Name + " | VRAM_GB=" + [math]::Round($g.AdapterRAM/1GB,1) }
```

### Disques

```powershell
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
  $_.DeviceID + " Total_GB=" + [math]::Round($_.Size/1GB,1) + " Free_GB=" + [math]::Round($_.FreeSpace/1GB,1)
}
```

### Rôles Windows installés

```powershell
(Get-WindowsFeature | Where-Object {$_.Installed} | Select-Object -ExpandProperty Name) -join ','
```

### Ports en écoute

```powershell
Get-NetTCPConnection -State Listen | Select-Object -ExpandProperty LocalPort | Sort-Object -Unique
```

## Linux (Edge)

### Système et CPU

```bash
grep PRETTY /etc/os-release
uname -r
lscpu | grep -E 'Model name|^CPU\(s\)|Thread|Core'
```

### RAM et GPU

```bash
free -h
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
```

### Disques et uptime

```bash
df -h / /home
uptime
```

### Conteneurs et ports

```bash
docker ps --format '{{.Names}}|{{.Image}}|{{.Ports}}'
ss -tlnp | grep LISTEN | awk '{print $4}' | sort -u
```

## Vérification d'un service (règle)

Un service est **vivant** quand son port répond avec un vrai handshake — jamais parce
qu'un gestionnaire de processus le prétend.

```bash
curl -s --max-time 5 -o /dev/null -w "HTTP %{http_code} en %{time_total}s\n" http://<hote>:<port>/<endpoint>
```

> **Ne jamais conclure qu'un service est arrêté parce que le port est fermé sur une
> autre machine.** Un port peut être lié à une interface précise (loopback, overlay) ;
> toujours tester depuis l'interface où le service doit écouter.
