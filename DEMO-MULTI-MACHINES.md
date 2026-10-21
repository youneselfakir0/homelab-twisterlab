# Démonstration multi-machines — SSH, A2A et OpenSSH

**Date :** 2026-10-21
**Nœuds :** Core (192.168.0.12), Edge (192.168.0.30), DC-DELL (192.168.0.100)

## 1. SSH Core → Edge

**Commande :** `ssh edge "echo OK-edge; hostname; uptime"`

**Résultat :**
```
OK-edge
edgeserver.twisterlab.local
 17:57:01 up 25 days,  3:14,  4 users,  load average: 1.50, 1.64, 1.86
```

**Preuve :** connexion SSH réussie via Tailscale (port 22 bloqué en LAN par ufw).

## 2. SSH Core → DC-DELL

**Commande :** `ssh dc-dell "powershell -Command \"Write-Host (hostname); Write-Host (whoami)\""`

**Résultat :**
```
DC-DELL
twisterlab\administrator
```

**Preuve :** connexion SSH réussie avec clé `id_rsa`. Utilisateur = admin de domaine.

## 3. A2A Core → DC-DELL

**Commande :** `hermes peer dm dc-dell "Reponds uniquement: A2A_OK + hostname + la date du jour"`

**Résultat :**
```
A2A_OK DC-DELL vendredi 16 octobre 2026
```

**Preuve :** canal de messagerie agent fonctionnel. DC-DELL exécute Hermes v0.21.5.

## 4. Copie de fichier Core → Edge (scp)

**Commande :** `scp demo.txt edge:/tmp/demo-hermes.txt`

**Résultat :** fichier transféré et vérifié (contenu identique).

**Preuve :** transfert SCP réussi via Tailscale.

## 5. Vérification skill sur DC-DELL

**Skill :** `hermes-peer-a2a` (local, enabled)
**Emplacement :** `C:\Users\Administrator\AppData\Local\hermes\skills\autonomous-ai-agents\hermes-peer-a2a\SKILL.md`
**Hash SHA-256 :** `ba4853b51d179662e1fb93e0ca3d3fb3fda5aaf778587f82bdade66ceab95509`

## Configuration SSH (Core)

Fichier : `~/.ssh/config`

```
Host edge
    HostName 100.112.255.75
    User twister
    IdentityFile G:/access-keys/ssh/id_rsa_twisterlab
    StrictHostKeyChecking accept-new

Host dc-dell
    HostName 100.70.59.28
    User Administrator
    IdentityFile G:/access-keys/ssh/id_rsa
    StrictHostKeyChecking accept-new
```

## DC-DELL — OpenSSH Server

| Élément | Valeur |
|---|---|
| Service | `sshd` — Running, Automatic |
| Port | 22 (inbound, firewall rule `sshd` enabled) |
| Auth | Clé publique (`id_rsa.pub`) dans `administrators_authorized_keys` |
| Installation | `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0` |

## Règles d'usage

- **Agents ↔ Agents** : `hermes peer dm <node>` (A2A, port 8642) — voie canonique
- **Admin Core → Edge** : `ssh edge` (Tailscale uniquement)
- **Admin Core → DC-DELL** : `ssh dc-dell` (port 22) ou WinRM (`Invoke-Command`)
- **Copie de fichiers** : `scp fichier edge:/dest/` ou `scp fichier dc-dell:C:/dest/`

## Références

- Source de vérité : [INFRASTRUCTURE.md](https://github.com/youneselfakir0/homelab-twisterlab/blob/main/INFRASTRUCTURE.md)
- Skill A2A : `hermes-peer-a2a` (chargée sur Core, Edge, DC-DELL)
- Page Notion : https://app.notion.com/p/D-monstration-multi-machines-SSH-A2A-et-OpenSSH-2026-10-21-4001f21b3b0681768cf6c70b55143b61