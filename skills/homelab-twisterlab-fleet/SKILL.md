---
name: homelab-twisterlab-fleet
description: "Use when working on the TwisterLab homelab fleet."
category: devops
---

# TwisterLab fleet

Three-node homelab. These facts are **standing**, not details to rediscover:
assuming them wrong costs a full diagnostic cycle every time, and the operator
has to repeat them. Load this before touching any node.

## The domain is the access key

- The fleet is joined to the AD domain **`twisterlab.local`**; Core and DC-DELL are
  Windows, Edge is Ubuntu.
- The interactive account is a **domain administrator**. That is what unlocks the
  other Windows node — no separate credential is needed, and no SSH key will work.

## Windows nodes: WinRM, not SSH

When SSH keys are refused on a Windows node, WinRM is the path. Three
preconditions, all mandatory and all easy to miss — miss one and it looks like
"the port is closed":

```powershell
# 1. the LOCAL WinRM service must be running (default Manual -> often Stopped)
Start-Service WinRM
# 2. WinRM to an IP address needs the target in TrustedHosts (or an HTTPS transport)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value '100.70.59.28' -Force
# 3. then drive it with the current (domain-admin) credentials
Invoke-Command -ComputerName 100.70.59.28 -ScriptBlock { hostname; whoami }
```

- Step 1 is the one that bites: with the service stopped, `Set-Item WSMan:\...`
  fails with *"The client cannot connect to the destination"* — a message that
  reads like a remote problem while the fault is local.
- Step 2 is what produces *"Default authentication may be used with an IP address
  under the following conditions: the transport is HTTPS or the destination is in
  the TrustedHosts list"*. That error means "add it to TrustedHosts", not "WinRM is
  unavailable".
- Confirm success by the remote identity, not by exit code:
  `"HOST=$($env:COMPUTERNAME) USER=$($env:USERNAME)"`.

## Node inventory

| Node | Role | Tailscale | LAN | Reach it via |
|---|---|---|---|---|
| **Core** | orchestrator; hosts Ollama | `100.92.101.28` | `192.168.0.12` | local |
| **Edge** | worker + services (18 containers) | `100.112.255.75` | `192.168.0.30` | SSH `twister` + `id_rsa_twisterlab` |
| **DC-DELL** | AD controller, 1 task at a time | `100.70.59.28` | `192.168.0.100` | WinRM with domain-admin creds |

- Edge's `8642` is LAN-blocked by a deliberate ufw allowlist — reach it over
  Tailscale. DC-DELL answers on both.
- Full per-node access recipes and the A2A channel:
  `references/node-access.md`.

## Hermes home on Windows

With `HERMES_HOME` unset, Hermes on Windows uses **`%LOCALAPPDATA%\hermes`**
(`C:\Users\<user>\AppData\Local\hermes`): `config.yaml`, `.env`, `SOUL.md` and
`skills/`. The `~/.hermes` path is **not** the active home — on Core it is a
~130-byte stub holding only an `mcp_servers:` block, on DC-DELL it is an empty
shell that a file copied into `~/.hermes/skills/` lands in, silently invisible.

- An edit written to the wrong home is a **silent no-op that still reads as done**
  in a recap. Confirm with `ls -la`, the file's mtime, and a `grep` for the exact
  key before believing any "config updated" claim.
- Before copying a skill to a Windows node, find the real `skills/` dir first
  (`AppData\Local\hermes\skills` holds `.hub`, `.locks` and the category dirs).
- After copying, **verify it loads**: run `hermes skills list` and confirm the skill
  appears with `source: local, enabled`. If it is absent, the file landed in the
  wrong directory (`~/.hermes/skills/` is not scanned) — move it to
  `AppData\Local\hermes\skills\<category>\<name>\` and re-check.
- Edge has **no clone of the repo**. Push files to it with `scp` (key
  `id_rsa_twisterlab`, user `twister`), then verify the hash on the remote.

## Standing rules for this fleet

- **A peer's or a document's claim is not a measurement.** Verify from the node
  that actually holds the thing before relaying it. See the `agent-claim-verification`
  and `hermes-peer-a2a` skills for the method.
- **Measure from the right vantage point.** Host, LAN and container give three
  different answers for the same port. State which one you measured.
- **Never pass a credential on a command line or in chat.** Read it into a variable
  and pipe it over stdin; verify by length or hash, never by echoing it.
