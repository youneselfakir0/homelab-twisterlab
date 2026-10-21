# Audit & Architecture — Flotte d'Agents Multi-Machines (v2, corrigé)

> **Date :** 2026-10-21
> **Auteur :** OpenCode (Core)
> **Statut :** v2 — intègre la revue Hermes Core du 2026-10-21 (`b4e35b6`) **et corrige une erreur de cette revue**. Auto-corrigée ensuite sur Edge LAN (voir §0).
> **Méthode :** chaque affirmation est assortie d'une mesure reproductible (HTTP, `hermes`, lecture de config, code source)

---

## 0. Avis de correction — ce qui change depuis v1

La revue du 2026-10-21 (`docs/audits/revue-audit-flotte-2026-10-21.md`, commit `b4e35b6`)
a été **vérifiée point par point**. Elle est **correcte sur 10 points et fausse sur 1**.

| # | Point de la revue | Ma mesure indépendante | Verdict |
|---|---|---|---|
| 1 | §1 versions/ports exacts | `hermes --version` → `v0.22.2 (2026.9.24)` | ✅ revue exacte |
| 2 | §2 les 9 agents existent | dossiers `.pi .qwen .factory .claude .codex .gemini` présents | ✅ revue exacte |
| 3 | §2.1 « conflit Ollama » faux + auto-contradictoire | aucune erreur/collision mesurée ; v1 §4.2 contredisait §2.1 | ✅ revue exacte |
| 4 | §3.3/§7 Edge LAN = durcissement | ADR-006 + commit `4f040a1` documentent l'allowlist ufw | ✅ revue exacte |
| 5 | §4.1 Ollama est sur Core | `edge:11434 → fermé`, `core:11434 → 200` | ✅ revue exacte |
| 6 | §4.2 Hermes Core **fait** de l'inférence | config : `model.default=meituan/longcat-2.5-preview:free`, `provider=nous` | ✅ revue exacte |
| 7 | §5 `POST /v1/tasks` n'existe pas | `GET /v1/tasks → 404` ; absent de `/v1/capabilities` | ✅ revue exacte |
| 8 | **§5 `POST /v1/chat/completions` n'existe pas** | **`POST /v1/chat/completions → 200`, réponse `"pong — Hermes est là."`** | ❌ **REVUE FAUSSE** |
| 9 | §5.3 bloc `a2a:` inexistant | config : `bot_peers:` (l.2442) ; aucun `a2a:` | ✅ revue exacte |
| 10 | §6.3.2 OpenClaw orchestrateur secondaire | ADR-005 : *Paperclip* est le coordinateur | ✅ revue exacte |
| 11 | §6 tokens A2A déjà déployés | `hermes peer list` → `[key set]` ×2 ; `/v1/models` 200 avec clé | ✅ revue exacte |

> **Conclusion :** la revue est un artefact fiable **sauf sur le point 8**. L'appliquer
> aveuglément introduirait une **nouvelle** erreur — exactement le piège ADR-006 :
> *« Un agent distant qui répond n'est pas une preuve. »*

> **Auto-correction de la v2 (2026-10-21) :** la v2 marquait « Edge LAN ✅ » en §1,
> ce qui **contredisait sa propre §1.1** et réintroduisait l'erreur que la revue avait
> corrigée. Mesure : `http://192.168.0.30:8642/health → 000` (×3) ; Tailscale → `200`.
> Corrigé en **❌ bloqué**. Deux nuances ajoutées en §5 : `/v1/skills` → `500` (route
> présente, en erreur) et `/v1/runs/{id}/events` → ambigu (`404` avec un id fictif).
>
> **Point 3 levé (2026-10-21) :** un test avec un **vrai** `run_id` (`POST /v1/runs`
> → `run_id`, puis `GET /v1/runs/{id}/events`) renvoie **`200` SSE** (`event:
> message.delta`). La route est **opérationnelle** ; le `404` sur id fictif était le
> comportement attendu. OpenCode a fourni la mesure décisive.

---

## 1. Topologie mesurée

| Nœud | Rôle réel | Hermes | `8642` LAN | `8642` Tailscale |
|---|---|---|---|---|
| **Core** 192.168.0.12 / 100.92.101.28 | Orchestrateur A2A + hôte Ollama | v0.22.2 | ✅ | ✅ |
| **Edge** 192.168.0.30 / 100.112.255.75 | Worker + 18 conteneurs | v0.21.5 | **❌ bloqué** | ✅ |
| **DC-DELL** 192.168.0.100 / 100.70.59.28 | Contrôleur AD, 1 tâche | v0.21.5 | ✅ | ✅ |

Mesures (port `8642`, 3 essais par cible) :

```
Core    http://127.0.0.1:8642/health      -> {"status":"ok","platform":"hermes-agent","version":"0.22.2"}
Edge    http://192.168.0.30:8642/health   -> 000  (×3 — bloqué)
Edge    http://100.112.255.75:8642/health -> 200
DC-DELL http://192.168.0.100:8642/health  -> 200
DC-DELL http://100.70.59.28:8642/health   -> 200
```

> La colonne LAN mesurait la joignabilité de `8642`, pas la présence du nœud sur le
> réseau. Edge est bien sur le LAN (`192.168.0.30`) mais son `8642` y est **bloqué** —
> voir §1.1.

### 1.1 Pare-feu Edge — durcissement délibéré (pas un incident)

`8642` est en **default-deny** avec allows nommés (`# hermes-a2a-*`), documenté ADR-006.
Conséquence : `8642` joignable via Tailscale, bloqué sur LAN. **C'est le comportement voulu.**
Ne pas supprimer la règle `DENY`.

---

## 2. Inventaire des agents (confirmé)

| Agent | Dossier | Provider réel | Modèle |
|---|---|---|---|
| Hermes Core | `AppData/Local/hermes` | `nous` | `meituan/longcat-2.5-preview:free` |
| OpenCode | `AppData/Roaming/ai.opencode.desktop` | via Hermes | — |
| Claude Code | `.claude` | Anthropic | — |
| Codex | `.codex` | OpenAI | — |
| Gemini/Antigravity | `.gemini/antigravity-ide` | Google | — |
| Pi | `.pi/agent` | Ollama **Core** | qwen2.5-coder-64k |
| Qwen | `.qwen` | Ollama **Core** | qwen2.5-coder-64k |
| Factory | `.factory` | Ollama **Core** | qwen2.5-coder-64k |
| OpenClaw | `.openclaw-companion` | Edge gateway | — |

### 2.1 Ollama — sur Core, pas Edge

```
core  127.0.0.1:11434/api/tags -> 200   {"models":["qwen2.5-coder-64k:latest","qwen2.5-coder:7b"]}
edge  100.112.255.75:11434/api/tags -> fermé (connexion impossible)
```

L'ADR-002 a **retiré** le LLM local d'Edge (GTX 1050, 2048 Mio VRAM, >120 s / 10 tokens).
**Aucun « conflit de provider » n'est mesuré** : trois agents partageant un endpoint Ollama
est un schéma normal. La priorité v1 « séparer les providers Ollama » est **retirée**.

---

## 3. Architecture cible (corrigée selon ADR-005/006)

```
            ┌──────────────────────────────────────────────┐
            │            PAPERCLIP (plan de contrôle)        │
            │   CEO Paperclip + coordinateur (paperclip_runner)│
            │   source de vérité : missions, preuves, budgets │
            └───────────────┬──────────────────────────────┘
                            │ délégation (ADR-005 §6)
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  Hermes Core  │   │   OpenClaw    │   │   OpenCode    │
│  (exécuteur   │   │   (agent      │   │   (agent      │
│   A2A, Core)  │   │    invité)    │   │    invité)    │
│  provider:nous│   │  Edge         │   │  Core         │
└───────┬───────┘   └───────────────┘   └───────────────┘
        │  hermes peer (A2A)
        ▼
┌───────────────┐   ┌───────────────┐
│  Hermes Edge  │   │ Hermes DC-DELL│
│  (worker)     │   │ (worker 1 tâche)│
└───────────────┘   └───────────────┘
```

**Corrections vs v1 :**
- **Paperclip** est le plan de contrôle et le coordinateur (ADR-005). v1 ne le mentionnait pas.
- **OpenClaw** est un agent invité/spécialisé, **pas** un orchestrateur (ADR-005 §6).
- **Hermes Core** est un agent LLM (`nous`), pas un simple routeur.
- **Ollama** est sur Core.

---

## 4. Mécanisme A2A réel (ADR-006)

### 4.1 Le canal natif est `hermes peer`, pas des endpoints inventés

```bash
hermes peer list                                  # registre des pairs
hermes peer dm    <peer> "message"                # synchrone, 1 tour, via Bot Chat
hermes peer run   <peer> < long-task.txt         # asynchrone -> run_id
hermes peer status <peer> <run_id>
hermes peer stop  <peer> <run_id>
```

Sous le capot (`hermes_cli/subcommands/peer.py`) :
- `dm` → dépose dans la session **« Bot Chat »** du pair et attend **un tour**.
- `run` → `POST {base}/v1/runs` (l.326) → run_id.
- `status` → `GET {base}/v1/runs/{run_id}` (l.286).

### 4.2 Emplacements de configuration réels

| Élément | Emplacement réel (mesuré) |
|---|---|
| URL du pair | `config.yaml` → `bot_peers.<nom>.url` (l.2442) |
| Clé du pair | `HERMES_PEER_<NOM>_KEY` dans le `.env` de **l'appelant** |
| Serveur API | `API_SERVER_ENABLED` / `API_SERVER_HOST` / `API_SERVER_PORT` / `API_SERVER_KEY` |

Le `.env` Core contient bien `HERMES_PEER_EDGE_KEY` et `HERMES_PEER_DC_DELL_KEY`.
**Aucune section `a2a:` n'existe** dans `config.yaml` (l'ajouter produirait une config morte).

### 4.3 État A2A mesuré

```
$ hermes peer list
dc-dell  http://100.70.59.28:8642   [key set] — controleur AD (1 tache a la fois)
edge     http://100.112.255.75:8642 [key set] — worker linux (18 conteneurs)

GET /v1/models (sans clé)  -> 401
GET /v1/models (avec clé)  -> 200
```

**Les tokens A2A sont déjà déployés et vérifiés** (phases 1.2 et 2.2 de v1 = déjà livrées).

---

## 5. Surface d'API réelle (source de vérité : `GET /v1/capabilities`)

Mesure directe sur `http://127.0.0.1:8642/v1/capabilities` (200) :

| Méthode | Chemin | Existe ? |
|---|---|---|
| GET | `/health`, `/v1/health`, `/health/detailed` | ✅ |
| GET | `/v1/models`, `/api/model/options` | ✅ |
| **POST** | **`/v1/chat/completions`** | **✅ (200 — "pong")** |
| POST | `/v1/responses` | ✅ |
| **POST** | **`/v1/runs`** | ✅ |
| GET | `/v1/runs/{run_id}` | ✅ |
| GET | `/v1/runs/{run_id}/events` | ✅ `200` SSE avec un **vrai** `run_id` (`event: message.delta`) |
| POST | `/v1/runs/{run_id}/{approval,steer,stop}` | ✅ |
| GET | `/v1/skills` | ⚠️ `500` — route présente mais en erreur |
| GET | `/v1/toolsets`, `/api/sessions` | ✅ |
| POST | `/v1/artifacts/upload`, GET `/v1/artifacts/download/{id}` | ✅ |
| GET/POST | `/v1/browser-control/register`, `/ws` | ✅ |
| — | **`/v1/tasks`** | **❌ inexistant (404)** |

> **Correction de la revue :** `/v1/chat/completions` **existe et répond 200**.
> Seul `/v1/tasks` est inventé (le bon chemin est `/v1/runs`).

---

## 6. Plan d'action corrigé

| # | Action | Statut |
|---|---|---|
| 1 | Lire les ADR 001-006 avant toute proposition | ✅ fait (v2) |
| 2 | Ne pas implémenter `/v1/tasks` → utiliser `/v1/runs` | ✅ acté |
| 3 | Ne pas ajouter de bloc `a2a:` → `bot_peers` + `HERMES_PEER_<NOM>_KEY` | ✅ acté |
| 4 | Ne pas supprimer `ufw DENY 8642` | ✅ acté |
| 5 | Considérer Paperclip comme coordinateur (ADR-005) | ✅ acté |
| 6 | Retirer la priorité « séparer Ollama » (non justifiée) | ✅ acté |
| 7 | **Corriger la revue sur `/v1/chat/completions`** | ✅ fait (§0) |
| 8 | Mission pilote Paperclip : attribution → exécution → validation → preuve | ⬜ à faire |
| 9 | Vérifier `paperclip_runner` (adapter, soul, permissions) | ⬜ à faire |

---

## 7. Décisions (corrigées)

| # | Décision | Source |
|---|---|---|
| 1 | Tailscale = réseau A2A | ADR-006, déjà le cas |
| 2 | Hermes = exécuteur A2A distribué (pas une 2e source de vérité) | ADR-005 §6 |
| 3 | Paperclip = plan de contrôle + coordinateur | ADR-005 |
| 4 | DC-DELL = worker 1 tâche | règle d'orchestration n°7 |
| 5 | Vérification SHA-256 des artefacts | règle n°5 |
| 6 | `8642` = allowlist ufw délibérée | ADR-006 |

---

## 8. Comment reproduire les mesures

```powershell
hermes --version
hermes peer list
curl http://127.0.0.1:8642/health
curl -H "Authorization: Bearer $API_SERVER_KEY" http://127.0.0.1:8642/v1/models
curl -H "Authorization: Bearer $API_SERVER_KEY" http://127.0.0.1:8642/v1/capabilities
curl http://100.112.255.75:11434/api/tags   # fermé
curl http://127.0.0.1:11434/api/tags       # 200 (Ollama = Core)
curl -X POST -H "Authorization: Bearer $API_SERVER_KEY" http://127.0.0.1:8642/v1/chat/completions ...
```

---

*v2 produite par OpenCode — 2026-10-21. Mesures reproductibles ci-dessus.*
