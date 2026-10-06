# TwisterLab — Homelab d'infrastructure distribuée

> **3 nœuds hétérogènes · 18 conteneurs · 1 contrôleur de domaine · orchestration pair-à-pair**
> Infrastructure personnelle conçue, déployée et documentée par mesure directe.

> **Diagramme d'architecture :** [`diagrams/homelab-architecture.html`](diagrams/homelab-architecture.html)
> *(fichier SVG autonome — ouvrir dans un navigateur)*
>
> Inventaire brut mesuré : [`docs/inventaire-mesure.json`](docs/inventaire-mesure.json)

---

## En une phrase

Un homelab de trois machines (Windows 11, Ubuntu 24.04, Windows Server 2025) formant
un domaine Active Directory réel, avec une plateforme de services conteneurisée
(git self-hosted, observabilité, automatisation, CMS), et une couche d'orchestration
distribuée maison qui délègue le travail entre les nœuds et **vérifie chaque artefact
par empreinte SHA-256** avant de l'accepter.

---

## Pourquoi ce projet

La plupart des homelabs empilent des services. Celui-ci répond à une question
d'ingénierie : **comment faire travailler plusieurs machines ensemble de façon fiable,
sans architecture maître/esclave, et sans jamais faire confiance à un exécutant sur parole ?**

Chaque décision documentée ici a été prise après une mesure, pas par intuition.
Les échecs sont conservés : ils sont la partie la plus instructive.

---

## Topologie

| Nœud | Rôle | OS | CPU | RAM | GPU |
|---|---|---|---|---|---|
| **Core** | Orchestrateur | Windows 11 Pro Insider (26340) | Xeon E3-1225 v5 · 4c/4t @ 3,30 GHz | 32 Go | RTX 3060 12 Go |
| **Edge** | Worker Linux + services | Ubuntu 24.04.5 LTS (kernel 6.8) | Core i5-6600K · 4c/4t @ 3,50 GHz | 15 Go | GTX 1050 2 Go |
| **DC-DELL** | Contrôleur de domaine | Windows Server 2025 (29667) | Core i5-2400 · 4c/4t @ 3,10 GHz | 8 Go | — |

### Réseau

| Nœud | IP LAN | IP overlay (Tailscale) | Stockage |
|---|---|---|---|
| Core | 192.168.0.12 | 100.107.136.93 | 2,3 To (5 volumes) |
| Edge | 192.168.0.30 | 100.112.255.75 | 246 Go |
| DC-DELL | 192.168.0.100 | 100.70.59.28 | 465 Go |

- **Domaine Active Directory :** `twisterlab.local`
- **LAN :** `192.168.0.0/24`
- **Overlay chiffré (WireGuard via Tailscale) :** `100.64.0.0/10`

---

## Plateforme de services (Edge — 18 conteneurs)

| Catégorie | Services | Ports |
|---|---|---|
| **Git / registre** | Forgejo + PostgreSQL, Docker registry privé | 3000, 2222, 5000 |
| **Observabilité** | Prometheus, Grafana, Alertmanager, node-exporter | 9090, 3001, 9093 |
| **Automatisation** | n8n + PostgreSQL + Redis | 5678, 5434, 6381 |
| **Applications** | Directus (CMS headless), SearxNG (métamoteur), stack ITSM | 8055, 8888, 5433, 6380 |
| **Accès distant** | RustDesk hbbs + hbbr (auto-hébergé) | 21115-21117 |
| **MCP** | mcp-global-utils, mcp-gitops | 8080, 8081 |

## Socle Windows (DC-DELL)

Contrôleur de domaine **Primary** (`DomainRole=5`) du domaine `twisterlab.local`.

Rôles installés : `AD-Domain-Services`, `DNS`, `DHCP`, `GPMC`, `Hyper-V`,
`File-Services`, `RSAT-AD-Tools`, `RSAT-DHCP`, `RSAT-DNS-Server`.

---

## Architecture logicielle : orchestration pair-à-pair

Il n'y a **pas** d'architecture maître/esclave, et c'est délibéré.

```
        ┌──────────────────────────────────────────────┐
        │  CORE — décide, route, vérifie               │
        │  registre de tâches durable (SQLite/kanban)  │
        └───────┬──────────────────────────────┬───────┘
                │  peer api_server 8642        │
                │  (overlay Tailscale)         │
        ┌───────▼──────────┐          ┌────────▼─────────┐
        │  EDGE            │          │  DC-DELL         │
        │  builds Linux    │          │  infra Windows   │
        │  services        │          │  AD / DNS / DHCP │
        └──────────────────┘          └──────────────────┘
```

Chaque nœud expose son propre `api_server` sur le port **8642**, joignable via
l'overlay. La délégation se fait par appel HTTP authentifié :

- **asynchrone, durable** — lancer un travail long, récupérer un identifiant, poller le statut
- **synchrone** — poser une question courte, obtenir la réponse

### Règle de vérification

> **Un exécutant qui annonce « OK » n'est pas une preuve.**

Chaque artefact rendu par un worker est revérifié **depuis l'orchestrateur** :
empreinte SHA-256 recalculée, chemin absolu confirmé, taille comparée. Une étape dont
la seule preuve est « OK » est indistinguable d'un échec silencieux.

---

## Décisions d'ingénierie

Les décisions sont documentées en format ADR dans [`docs/decisions/`](docs/decisions/).

| # | Décision | Raison mesurée |
|---|---|---|
| 001 | Pas d'architecture maître/esclave | Chaque nœud expose son api_server ; un point central de défaillance aurait été inutile |
| 002 | Retrait de tout LLM local | La GTX 1050 (2 Go VRAM) ne peut pas servir un modèle de 2,2 Go — dépassement en RAM CPU, >120 s pour 10 tokens |
| 003 | Le registre de tâches n'est **pas** le routeur | Mesuré : le dispatcher exécutait en local au lieu de router, et ignorait les tâches distantes |
| 004 | Contexte partagé = git self-hosted | Trois dépôts divergents ne sont pas une source de vérité |

### L'incident le plus instructif

Le registre de tâches intégré a **tué le gateway de l'orchestrateur** (exit code 75).
Analyse complète dans [`docs/incidents/exit-75.md`](docs/incidents/exit-75.md) :
les workers lancés en local ont affamé la boucle d'événements asyncio jusqu'à ce que
le chien de garde tue le processus. C'est le genre de panne qu'on ne trouve qu'en
lisant ses propres logs — et qui a produit une règle durable.

---

## Compétences démontrées

- **Administration système** — Windows Server 2025, AD DS, DNS, DHCP, Hyper-V, GPO
- **Linux** — Ubuntu Server, systemd, permissions, diagnostic réseau
- **Conteneurisation** — Docker, Compose, réseaux internes, stacks multi-services
- **Observabilité** — Prometheus, Grafana, Alertmanager, exportateurs
- **Réseau** — segmentation LAN, overlay WireGuard (Tailscale), pare-feu, diagnostic
- **Automatisation** — orchestration distribuée, API REST, vérification par empreinte
- **Méthode** — mesure avant décision, analyse de cause racine, documentation ADR

---

## Méthode de documentation

Toute donnée de ce dépôt est **mesurée**, jamais déduite :

- Windows → `Get-CimInstance Win32_*` (PowerShell/CIM)
- Linux → `lscpu`, `free`, `nvidia-smi`, `df`, `docker ps`
- Réseau → sondes de port réelles, handshakes HTTP

Aucun chiffre n'est estimé. Les commandes exactes sont dans
[`docs/runbook.md`](docs/runbook.md) pour que le relevé soit reproductible.

---

## Structure du dépôt

```
.
├── README.md                  # ce fichier
├── diagrams/
│   └── homelab-architecture.html   # diagramme SVG autonome
├── docs/
│   ├── architecture.md        # architecture détaillée
│   ├── inventory.md           # inventaire matériel mesuré
│   ├── runbook.md             # commandes de relevé (reproductible)
│   ├── decisions/             # ADR — décisions d'ingénierie
│   └── incidents/             # analyses post-mortem
├── scripts/
│   ├── inventory.ps1          # relevé Windows
│   └── inventory.sh           # relevé Linux
└── LICENSE
```

---

## Licence

MIT — voir [LICENSE](LICENSE).

---

<sub>Infrastructure documentée par mesure directe · 2026-10-06</sub>
