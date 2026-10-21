# Reaching each node

Access recipes per node. Credentials: read into a shell variable, never pasted.

## Edge (Ubuntu) — SSH

```bash
ssh -i G:/access-keys/ssh/id_rsa_twisterlab twister@100.112.255.75
```

- User **`twister`**, key **`id_rsa_twisterlab`**, `sudo` NOPASSWD.
- Reach it over Tailscale `100.112.255.75`. The LAN address pings fine but port 22
  may be throttled — if SSH times out there, switch to the Tailscale IP instead of
  retrying.
- The other keys in `G:/access-keys/ssh/` are Core keys and are NOT authorized for
  `twister` — do not burn attempts on them.
- Windows refuses a private key whose ACL lets other accounts read it; the failure is
  local and never looks like `Permission denied`. Copy the key into the profile and
  lock it with `icacls <key> /inheritance:r /grant:r <user>:R` (plus Administrators
  and SYSTEM or native tools cannot open it).

## Windows nodes (Core, DC-DELL) — WinRM

SSH is not the path here. Full recipe:

```powershell
# 0. who am I? (must be a domain account with admin rights on the target)
whoami
(Get-CimInstance Win32_ComputerSystem) | Select-Object Name,Domain,PartOfDomain

# 1. the local WinRM service must be RUNNING (Manual by default)
Get-Service WinRM
Start-Service WinRM

# 2. target the node by IP -> needs TrustedHosts (or HTTPS)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value '100.70.59.28' -Force

# 3. drive it
Invoke-Command -ComputerName 100.70.59.28 -ScriptBlock {
  "HOST=$($env:COMPUTERNAME) USER=$($env:USERNAME) PROFILE=$($env:USERPROFILE)"
}
```

Diagnostic order when it fails — each error points at a different layer:

| Symptom | Cause |
|---|---|
| `Set-Item` → *"client cannot connect to the destination"* | the **local** WinRM service is stopped — start it |
| *"Default authentication may be used with an IP address under the following conditions…"* | target missing from `TrustedHosts` (or no HTTPS) |
| `Get-Service WinRM` → `Stopped` | start it; it is `Manual`, not automatic |
| connection times out | wrong interface — try the other address |

Run commands with the **current** credentials: a domain-admin account passes
through to the other domain-joined node. Do not look for a separate password.

## Peer channel — A2A

When a node has no usable shell at all, the Hermes `api_server` is both a way to
ask and a way to *act*: see the `hermes-peer-a2a` skill.

## Sandboxes are not hosts

An agent running inside a Docker sandbox (`NetworkMode=bridge`, `PortBindings={}`)
publishes no ports and mounts a scratch `skills/` dir instead of the host's. Its
filesystem and network probes describe the **container** — never conclude about
host state from them.
