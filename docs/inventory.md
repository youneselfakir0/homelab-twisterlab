# Inventaire matériel et logiciel

**Méthode :** mesure directe sur chaque machine, 2026-10-06. Aucune donnée estimée.

## Core — orchestrateur

| Élément | Valeur mesurée |
|---|---|
| OS | Windows 11 Pro Insider Preview, build 26340, 64-bit |
| CPU | Intel Xeon E3-1225 v5 @ 3,30 GHz — 4 cœurs / 4 threads |
| RAM | 31,9 Go (3,8 Go libres au relevé) |
| GPU | NVIDIA GeForce RTX 3060 (12 Go) + Intel HD Graphics P530 |
| Pilote GPU | 32.0.16.1692 |
| Stockage | C: 297 Go · D: 298 Go · F: 932 Go · H: 476 Go · I: 297 Go |
| IP LAN | 192.168.0.12 |
| IP overlay | 100.107.136.93 |
| Uptime au relevé | 68,5 h |

## Edge — worker Linux + services

| Élément | Valeur mesurée |
|---|---|
| OS | Ubuntu 24.04.5 LTS, kernel 6.8.0-142-generic |
| CPU | Intel Core i5-6600K @ 3,50 GHz — 4 cœurs / 4 threads |
| RAM | 15 Go (7,7 Go disponibles) |
| GPU | NVIDIA GeForce GTX 1050 — 2048 Mio |
| Pilote GPU | 580.178.04 |
| Stockage | / : 246 Go, 81 % utilisé, 47 Go libres |
| IP LAN | 192.168.0.30 |
| IP overlay | 100.112.255.75 |
| Uptime au relevé | 9 jours 15 h |
| Conteneurs | 18 |

## DC-DELL — contrôleur de domaine

| Élément | Valeur mesurée |
|---|---|
| OS | Windows Server 2025 Standard, build 29667 |
| CPU | Intel Core i5-2400 @ 3,10 GHz — 4 cœurs / 4 threads |
| RAM | 7,9 Go (1,8 Go libres) |
| Stockage | C: 465 Go, 418 Go libres |
| Domaine | twisterlab.local |
| Rôle domaine | 5 — Primary Domain Controller |
| IP LAN | 192.168.0.100 |
| IP overlay | 100.70.59.28 |

## Rôles Windows installés (DC-DELL)

`AD-Domain-Services` · `DHCP` · `DNS` · `FileAndStorage-Services` · `File-Services` ·
`FS-FileServer` · `Hyper-V` · `GPMC` · `RSAT` · `RSAT-AD-Tools` · `RSAT-DHCP` ·
`RSAT-DNS-Server` · `Windows-Defender`

## Services conteneurisés (Edge)

| Conteneur | Image / rôle | Port |
|---|---|---|
| forgejo | Git self-hosted | 3000 |
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
| rustdesk-hbbs | Serveur d'identité RustDesk | 21115-21117 |
| rustdesk-hbbr | Relais RustDesk | 21117 |
| mcp-global-utils | Serveur MCP | 8080 |
| mcp-gitops | Serveur MCP | 8081 |
| itsm-postgres | PostgreSQL (ITSM) | 5433 |
| itsm-redis | Redis (ITSM) | 6380 |
