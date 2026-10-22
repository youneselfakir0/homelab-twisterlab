# INFRASTRUCTURE.md — Source de vérité technique

> **Dernière vérification :** 2026-10-19
> **Méthode :** mesure directe + tests HTTP réels depuis Core
> **Repo :** youneselfakir0/homelab-twisterlab

---

## 1. Topologie réelle

| Nœud | Rôle | OS | CPU | RAM | IP LAN | IP Tailscale | Ports clés |
|---|---|---|---|---|---|---|---|
| **Core** | Orchestrateur | Windows 11 Pro Insider 26340 | Xeon E3-1225 v5 (4c/4t) | 32 Go (3,8 Go libres) | 192.168.0.12 | 100.92.101.28 | 22, 139, 3389, 5357, 8642 |
| **Edge** | Worker Linux + services | Ubuntu 24.04.5 LTS (kernel 6.8) | i5-6600K (4c/4t) | 15 Go (7,7 Go dispo) | 192.168.0.30 | 100.112.255.75 | 22, 2222, 3000, 3001, 5000, 5433, 5434, 5678, 6380, 6381, 8055, 8080, 8081, 8088, 8642, 8644, 8888, 9090, 9093, 9119, 18789, 21115-21117 |
| **DC-DELL** | Contrôleur de domaine | Windows Server 2025 (29667) | i5-2400 (4c/4t) | 8 Go (1,8 Go libres) | 192.168.0.100 | 100.70.59.28 | 389, 3389 |

### Réseau
- **LAN :** 192.168.0.0/24
- **Overlay WireGuard (Tailscale) :** 100.64.0.0/10
- **Domaine AD :** twisterlab.local

### Accès et credentials (NE PAS OUBLIER)
- **Domaine AD :** `twisterlab.local` — DC-DELL est le contrôleur de domaine.
- **Core (CORE)** est membre du domaine. Le compte courant `administrator` est **ADMIN DE DOMAINE** (acces WinRM à DC-DELL avec les credentials courants).
- **Accès admin à DC-DELL :** WinRM (Invoke-Command) fonctionne depuis Core avec les credentials courants, après `Start-Service WinRM` sur Core + `Set-Item WSMan:\localhost\Client\TrustedHosts -Value '100.70.59.28' -Force`. C'est la voie d'administration directe.
- **Hermes home Core :** `C:\Users\administrator\AppData\Local\hermes` (HERMES_HOME). **DC-DELL :** `C:\Users\Administrator\AppData\Local\hermes`.
- **Skills DC-DELL** vivent dans `AppData\Local\hermes\skills\` (PAS dans `~/.hermes\skills\` qui n'est pas scanné).
- **Rôles :** Core = orchestrateur (Hermes), Edge = worker Linux + services (Forgejo, OpenClaw), DC-DELL = contrôleur de domaine AD + DNS/DHCP.

### Stockage Core (post-réinstallation Windows 11, 2026-10-15)
| Disque | Taille | Libre |
|---|---|---|
| C: | 297 Go | 52 Go |
| D: | 298 Go | 145 Go |
| F: | 932 Go | 438 Go |
| H: | 476 Go | 82 Go |
| I: | 297 Go | 219 Go |

> Note : les disques E: (Ventoy multiboot) et G: (clé USB Kali) décrits dans Notion sont pré-réinstallation. Ils ne figurent pas dans l'inventaire mesuré post-réinstall.

### Stockage Edge
- / : 246 Go, 81% utilisé, 47 Go libres

---

## 2. Services et conteneurs (Edge — 18 conteneurs)

| Conteneur | Rôle | Port |
|---|---|---|
| forgejo | Git self-hosted | 3000, 2222 (SSH) |
| forgejo-db | PostgreSQL (Forgejo) | — |
| registry | Docker registry privé | 5000 |
| prometheus | Métriques | 9090 |
| grafana | Tableaux de bord | 3001 |
| alertmanager | Alertes | 9093 |
| node-exporter | Exportateur système | — |
| n8n-standalone | Automatisation | 5678 |
| n8n-postgres | PostgreSQL (n8n) | 5434 |
| n8n-redis | Redis (n8n) | 6381 |
| instaswap_directus | CMS headless | 8055 |
| searxng | Métamoteur | 8888 |
| rustdesk-hbbs | Serveur identité RustDesk | 21115-21117 |
| rustdesk-hbbr | Relais RustDesk | 21117 |
| mcp-global-utils | Serveur MCP | 8080 |
| mcp-gitops | Serveur MCP | 8081 |
| itsm-postgres | PostgreSQL (ITSM) | 5433 |
| itsm-redis | Redis (ITSM) | 6380 |

### Services transverses
- **api_server Hermes :** port 8642 sur les 3 machines (peer-to-peer)
- **OpenClaw gateway :** Edge:18789
- **Forgejo :** Edge:3000 (git self-hosted, source de vérité)

---

## 3. Règles d'orchestration

1. **Pas d'architecture maître/esclave** — chaque nœud expose son api_server:8642. L'orchestrateur est un rôle, pas un composant matériel. (ADR 001)
2. **Le registre de tâches n'est PAS le routeur** — le répartiteur automatique est désactivé. L'orchestrateur route lui-même. (ADR 003)
3. **Contexte partagé = git self-hosted (Forgejo)** — source unique de vérité. (ADR 004)
4. **Aucun modèle LLM local** — la GTX 1050 (2 Go VRAM) ne peut pas servir de modèle. Modèles servis à distance. (ADR 002)
5. **Vérification par SHA-256** — chaque artefact rendu par un worker est revérifié depuis l'orchestrateur.
6. **Un exécutant qui dit "OK" n'est pas une preuve** — toujours vérifier l'artefact.
7. **DC-DELL : 1 tâche à la fois** (8 Go RAM, ~1,5 Go libres). Script check_lock.ps1.
8. **Hermes seul orchestre** — pas d'appels agents cross-machine sans dispatch explicite.
9. **KANBAN = registre du plan, PAS le routeur.**
10. **Alignement Administratif** — Aucun travail technique n'est considéré comme terminé tant que la carte Kanban correspondante n'est pas formellement clôturée. Un commit sans ticket fermé est une erreur de process.

---

## 4. Endpoints vérifiés (2026-10-19)

| Service | Endpoint | Statut | Notes |
|---|---|---|---|
| Hermes Core | http://127.0.0.1:8642/health | ✅ 200 | v0.22.2 |
| Hermes Core /v1/models | http://127.0.0.1:8642/v1/models | 🔒 401 | Sans auth (attendu) |
| Hermes Edge (LAN) | http://192.168.0.30:8642/health | ❌ TIMEOUT | Non joignable depuis Core via LAN |
| Hermes Edge (Tailscale) | http://100.112.255.75:8642/health | ✅ 200 | Accessible via Tailscale (bind 0.0.0.0) |
| OpenClaw | http://192.168.0.30:18789/ | ✅ 200 | Gateway accepte handshake |
| OpenCode service | http://127.0.0.1:45278/api/info | 🔒 401 | Sans auth (Hermes a mesuré 200 avec session) |
| OpenCode legacy | http://127.0.0.1:41000/api/info | ❌ connexion refusée | Port périmé (attendu) |
| Forgejo | http://192.168.0.30:3000/ | ✅ 200 | Git self-hosted |
| Grafana | http://192.168.0.30:3001/ | 302 | Redirection login |
| Grafana /api/health | http://192.168.0.30:3001/api/health | ✅ 200 | DB ok, v13.2.2 |
| Prometheus | http://192.168.0.30:9090/ | (non testé) | |
| n8n | http://192.168.0.30:5678/ | (non testé) | |

---

## 5. MCP Servers (OpenCode)

| Serveur | Type | Statut |
|---|---|---|
| figma | remote (mcp.figma.com/mcp) | ✅ connected |
| github | local (python wrapper) | ✅ connected |
| github-api | local (npx @mcp/server-github) | ✅ connected |
| luci | remote (127.0.0.1:8765/mcp) | ❌ failed (401 bearer token) |
| notion | remote (mcp.notion.com/mcp) | ✅ connected |
| fanvue | remote (mcp.fanvue.com/mcp) | ○ pending → ✅ connected (après OAuth) |

---

## 6. Incohérences Notion ↔ GitHub ↔ Réalité

| # | Sujet | Notion dit | GitHub/Réalité dit | Statut |
|---|---|---|---|---|
| 1 | MCP servers | stitch, notion seulement | figma, github, github-api, luci, notion, fanvue | ❌ À corriger |
| 2 | Disques Core | C:512, D:320, E:320(Ventoy), F:1To, I:320, G:14Go | C:297, D:298, F:932, H:476, I:297 (pas de E:/G:) | ❌ À corriger |
| 3 | Hermes écoute | 0.0.0.0:8642 (écart) | overlay uniquement, jamais 0.0.0.0 | ⚠️ Écart connu |
| 4 | Orchestration | "Hermes seul orchestre, pas de cross-machine" | Pair-à-pair, api_server:8642 sur chaque nœud | ❌ À réconcilier |
| 5 | Hermes Edge | v0.21.5 accessible | Timeout depuis Core | ❌ Inaccessible |
| 7 | DC-DELL rôles | Liste partielle | +FileAndStorage, FS-FileServer, RSAT, Windows-Defender | 🟡 Mineur |
| 8 | Services conteneurisés | Non documentés | 18 conteneurs documentés | 🟡 À ajouter |
| 9 | MCP Edge | Non documentés | mcp-global-utils:8080, mcp-gitops:8081 | 🟡 À ajouter |

---

## 7. Agents et espaces Notion

| Agent | Espace Notion | Règle d'écriture |
|---|---|---|
| OpenCode | 🤖 OpenCode (sous 📂 Espaces Agents) | Écrit uniquement dans son sous-arbre |
| Hermes | 🐍 Hermes (sous 📂 Espaces Agents) | Écrit uniquement dans son sous-arbre |
| OpenClaw | 🦞 OpenClaw (sous 📂 Espaces Agents) | Écrit uniquement dans son sous-arbre |

Projets partagés vivent à la racine du workspace.

---

## 8. Rôles Windows installés (DC-DELL)

AD-Domain-Services, DHCP, DNS, FileAndStorage-Services, File-Services, FS-FileServer, Hyper-V, GPMC, RSAT, RSAT-AD-Tools, RSAT-DHCP, RSAT-DNS-Server, Windows-Defender

---

## 9. Rôles des agents par machine (Architecture Hermes / OpenClaw / OpenCode)

### Matrice de responsabilité

| Machine | **Hermes** (orchestration) | **OpenClaw** (agent runtime) | **OpenCode** (coding agent) |
|---|---|---|---|
| **Core** (100.92.101.28) | **Cerveau / Orchestrateur principal**<br>• `api_server:8642` (bind 0.0.0.0)<br>• Gestion Kanban, routing et partage de tâches<br>• MCP servers: Composio, Figma, PostHog<br>• A2A peers: Edge, DC-DELL | ✅ Installé | ✅ Installé |
| **Edge** (Ubuntu, 100.112.255.75) | **Worker Hermes**<br>• `api_server:8642` (Tailscale only)<br>• Reçoit tâches via A2A<br>• 18 conteneurs Docker | ✅ **Runtime principal**<br>• Gateway: `192.168.0.30:18789`<br>• Plugin **Composio** installé + CLI 0.5.0<br>• 500+ tools (GitHub, Gmail, etc.) | ✅ Installé |
| **DC-DELL** (Win Server, 100.70.59.28) | **Worker Hermes**<br>• `api_server:8642`<br>• Skill `hermes-peer-a2a` chargée<br>• 1 tâche à la fois (8 Go RAM) | ✅ Installé | ❌ Pas installé (Contrôleur AD) |

### Distinction fonctionnelle

| Agent | Rôle | Ce qu'il **ne fait pas** |
|---|---|---|
| **Hermes** | **Le Cerveau** : coordination globale, partage des tâches via Kanban, routing A2A, agrégation preuves | N'exécute **pas** de code, n'appelle **pas** d'outils externes |
| **OpenClaw** | **Le Runtime** : exécution plugins/skills (Composio, Notion, etc.), conversations, hooks | Ne route **pas** vers d'autres machines, ne gère **pas** le Kanban |
| **OpenCode** | **Le Codeur** : écriture code, PR, review, tests | Ne connaît **pas** le lab, ne parle **pas** A2A |

### Flux type d'exécution

```
User → Core (Hermes orchestrateur + Kanban)
        │
        ├─→ Core (Hermes + OpenClaw + OpenCode) — tâches locales
        │
        ├─→ Edge (Hermes + OpenClaw + OpenCode) — plugins, coding
        │
        └─→ DC-DELL (Hermes + OpenClaw) — admin AD/DNS/DHCP
```

### Preuves d'installation Edge (Ubuntu)

```bash
# Hermes worker
hermes --version          # → 0.21.5
curl 100.112.255.75:8642/health

# OpenClaw + Composio plugin
ls ~/.openclaw/extensions/composio/  # → openclaw.plugin.json, dist/index.js, skills/
composio --version         # → 0.5.0
composio whoami            # → youneselfafir0@gmail.com
```

---

## 10. Accès SSH (configuré 2026-10-21)

### Configuration Core (`~/.ssh/config`)

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

### DC-DELL — OpenSSH Server

| Élément | Valeur | Preuve |
|---|---|---|
| Service | `sshd` | `Get-Service sshd` → Running, Automatic |
| Port | 22 (inbound) | `Get-NetFirewallRule -Name sshd` → Enabled, Inbound |
| Auth | Clé publique (`id_rsa.pub`) | `C:\ProgramData\ssh\administrators_authorized_keys` |
| Installation | `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0` | Déléguée via A2A, exécutée par Hermes DC-DELL |

### Tests de connectivité (preuves)

| Lien | Commande | Résultat |
|---|---|---|
| Core → Edge | `ssh edge "echo OK-edge"` | ✅ `OK-edge` (hostname: `edgeserver.twisterlab.local`) |
| Core → DC-DELL | `ssh dc-dell "powershell ..."` | ✅ `DC-DELL` / `twisterlab\administrator` |

### A2A (messagerie agents)

| Canal | Preuve |
|---|---|
| Core → DC-DELL | `hermes peer dm dc-dell` → `CANAL_OK Hermes Agent v0.21.5+2961.g436b904.dirty` |
| Skill chargée DC-DELL | `hermes-peer-a2a` (local, enabled) dans `hermes skills list` |

### Règle d'usage

- **Agents ↔ Agents** : `hermes peer dm <node>` (A2A, port 8642) — voie canonique
- **Admin Core → Edge** : `ssh edge` (Tailscale uniquement, port 22 bloqué en LAN par ufw)
- **Admin Core → DC-DELL** : `ssh dc-dell` (port 22) ou WinRM (`Invoke-Command`)
- **Copie de fichiers** : `scp fichier edge:/dest/` ou `scp fichier dc-dell:C:/dest/`

---

*Ce fichier est la source de vérité technique pour tous les agents. Lire avant toute action sur l'infrastructure.*
