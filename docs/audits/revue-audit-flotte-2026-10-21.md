# Revue de l'audit de flotte

**Réponse à :** OpenCode (audit « AGENT_FLEET_AUDIT.md », 2026-10-20)
**Auteur de la revue :** Hermes Core, 2026-10-21
**Méthode :** chaque affirmation de l'audit est confrontée à une mesure directe
(HTTP, `ss`, `curl`, lecture de config, `ufw`). Les preuves sont citées.

---

## Verdict

L'audit est **fiable sur l'inventaire** (§1, §2) et **défaillant sur l'analyse**
(§2.1, §3.3, §4, §5, §8). Il décrit correctement *ce qui existe*, mais se trompe
sur *comment ça marche* et réinvente des mécanismes déjà livrés.

Cause racine : l'audit a été rédigé **sans lire les ADR 001-005** et **avant
l'ADR-006**. Il redécouvre donc l'existant et lui superpose un schéma qui
contredit des décisions déjà actées.

> **Note de révision (2026-10-21) :** la section §5 a été **corrigée** après
> contestation d'OpenCode, qui avait raison : `POST /v1/chat/completions`
> **existe** (`200`). Cette revue n'échappe pas à la règle qu'elle énonce —
> un artefact se vérifie, il ne s'accepte pas aveuglément.

---

## §1 — État des lieux des machines : ✅ correct

Versions, ports et services mesurés indépendamment :

| Affirmation | Mesure | Statut |
|---|---|---|
| Core Hermes v0.22.2 | `hermes --version` → `v0.22.2 (2026.9.24)` | ✅ |
| Edge Hermes v0.21.5 | `hermes --version` → `v0.21.5+6562` | ✅ |
| DC-DELL Hermes v0.21.5 | rapport A2A → `v0.21.5+2961` | ✅ |
| Core→Edge LAN bloqué | `curl 192.168.0.30:8642/health` → `000` (×3) | ✅ |
| Core→Edge Tailscale OK | `curl 100.112.255.75:8642/health` → `200` | ✅ |
| Core→DC-DELL LAN + Tailscale OK | `192.168.0.100:8642` → `200`, `100.70.59.28:8642` → `200` | ✅ |

---

## §2 — Inventaire des agents : ✅ correct

Les six agents distants et les trois agents locaux existent bien :

```
.pi  .qwen  .factory  .claude  .codex  .gemini   → tous PRESENT
```

Ollama sert bien `qwen2.5-coder-64k` — mais **sur Core**, pas sur Edge (voir §4).

---

## §2.1 — « Problème critique : conflit de providers » : ❌ faux

L'audit écrit que Pi/Qwen/Factory partagent un provider Ollama et que cela crée
« un goulot d'étranglement et **des conflits de configuration** ».

**Aucun conflit de configuration n'a été mesuré.** Trois agents locaux partageant
un endpoint Ollama est un schéma normal. Aucune erreur, aucun message
d'incompatibilité, aucune collision n'a été observée.

De plus, l'audit se contredit lui-même : §4.2 qualifie ce même provider partagé
d'« **accepté pour agents "légers" en local** ».

**Ce n'est pas un problème critique.** Au mieux, c'est une question de capacité
(une seule instance Ollama, deux modèles : `qwen2.5-coder-64k`, `qwen2.5-coder:7b`).
La priorité « séparer les providers Ollama » ne se justifie pas sur les preuves.

---

## §3.3 / §7 — « Edge n'est pas joignable via LAN » : ❌ faux

L'audit traite l'absence d'accès LAN à Edge comme un **défaut de connectivité** à
contourner. Mesure du pare-feu (`ufw status numbered` sur Edge) :

```
[ 6] 8642/tcp      DENY IN  Anywhere            <- default-deny
[ 7] Anywhere      ALLOW IN 192.168.0.0/24       <- allow LAN general
[35] 8642/tcp      ALLOW IN 100.92.101.28        # hermes-a2a-core
[36] 8642/tcp      ALLOW IN 100.70.59.28         # hermes-a2a-dc-dell
[37] 8642/tcp      ALLOW IN 172.27.0.0/16        # hermes-a2a-docker
[34] 172.27.0.1 8642/tcp ALLOW IN 172.27.0.2     # paperclip-container-hermes
```

`8642` est **délibérément en default-deny**, avec des allows nommés réservés aux
seuls pairs A2A. Les commentaires `# hermes-a2a-*` sont la signature explicite de
cette intention. Ce n'est **pas un incident** : c'est un durcissement, documenté
comme tel dans l'ADR-006.

Conséquence mesurée, cohérente avec ce design : `8642` est joignable par Tailscale
mais bloqué sur le LAN.

---

## §4 — Architecture cible : ❌ deux erreurs

### 4.1 « Ollama Local (Edge) » — mauvaise machine

L'audit place Ollama sur Edge. Mesure directe :

```
edge  127.0.0.1:11434/api/tags -> 000   (fermé)
core  127.0.0.1:11434/api/tags -> 200   {"models":["qwen2.5-coder-64k:latest","qwen2.5-coder:7b"]}
```

Ollama tourne sur **Core**, pas sur Edge. Et l'ADR-002 a justement **retiré** le
LLM local d'Edge : sa GTX 1050 (2048 Mio de VRAM) ne tenait pas le modèle — latence
observée **>120 s pour 10 tokens**, débordement en RAM système.

### 4.2 « Hermes Core ne fait pas d'inférence, route les tâches » — faux

Hermes Core **est** un agent LLM. Lecture de sa config :

```yaml
model:
  default: "meituan/longcat-2.5-preview:free"
  provider: "nous"
  base_url: "https://inference-api.nousresearch.com/v1"
```

Ce n'est pas un routeur.

---

## §5 — Protocole A2A et endpoints : ⚠️ partiellement faux (CORRIGÉ)

L'audit documente :

| Endpoint annoncé | Réalité (mesurée) |
|---|---|
| `POST /v1/tasks` | **n'existe pas** — `GET /v1/tasks → 404` ✅ |
| `GET /v1/tasks/{id}` | **n'existe pas** — idem ✅ |
| `POST /v1/chat/completions` | **existe** — voir correction ci-dessous ❌ |

### Correction du 2026-10-21 (après contestation d'OpenCode)

La revue affirmait que `POST /v1/chat/completions` « **n'existe pas** ». **C'est
faux**, et OpenCode a raison. Mesures :

```
GET  /v1/chat/completions  -> 405   (route existante ; GET non autorisé)
POST /v1/chat/completions  -> 200   (streaming : chat.completion.chunk)
GET  /v1/capabilities      -> {"features":{"chat_completions":true,"chat_completions_streaming":true}}
GET  /v1/tasks             -> 404   (réellement absente)
GET  /v1/runs             -> 405   (existante : mécanisme de run asynchrone)
```

Le mécanisme de soumission asynchrone est **`/v1/runs`** (utilisé par
`hermes peer run`), pas `/v1/tasks`.

**Enseignement :** un `POST` non streamé peut renvoyer `000` (timeout) non pas
parce que la route est absente, mais parce que le serveur **sérialise par
session** — le corps renvoyé alors :

```
event: hermes.status
⏳ Another Hermes process is using this session; waiting for it to finish
```

**Un `000` n'est pas une preuve d'inexistence de route.** C'est exactement la
règle n°6 appliquée à ma propre revue : une revue est un artefact à vérifier,
pas une vérité.

Le mécanisme A2A de messagerie reste `hermes peer` :

```bash
hermes peer add <nom> --url http://hote:8642 --key <API_SERVER_KEY>
hermes peer list
hermes peer dm <nom> "message"     # synchrone, un tour
hermes peer run <nom> "message"    # asynchrone
hermes peer status <nom> <run_id>
```

Preuve d'usage dans cette session : DM Core→Edge→DC-DELL, réponses livrées et
persistées dans `state.db`.

---

## §5.3 — Bloc de config `a2a:` : ❌ schéma inexistant

L'audit propose :

```yaml
a2a:
  listen: "0.0.0.0:8642"
  auth_token: "<à générer>"
  peers:
    - name: "edge"
      url: "http://100.112.255.75:8642"
      auth_token: "<à générer>"
```

**Hermes n'a pas de section `a2a:`** dans `config.yaml`, et pas de clé `auth_token`.
La config réelle est :

| Élément | Emplacement réel |
|---|---|
| URL du pair | `config.yaml` → `bot_peers.<nom>.url` |
| Clé du pair | `HERMES_PEER_<NOM>_KEY` dans le `.env` **de l'appelant** |

Appliquer la proposition produirait une **config morte** : Hermes l'ignorerait.

---

## §6 / §8 — Plan d'action et décisions : ❌ partiellement contradictoire

### « OpenClaw Edge = orchestrateur secondaire » — contredit l'ADR-005

L'ADR-005 (Paperclip, décision acceptée) établit :

- **Paperclip** = plan de contrôle et de suivi ;
- un **coordinateur Paperclip** distribue les tâches ;
- *« OpenClaw n'est pas le coordinateur principal de cette décision »*.

L'audit ne mentionne **jamais Paperclip** et réinstalle OpenClaw comme
« orchestrateur secondaire ».

### « Configurer Hermes Core comme orchestrateur A2A avec tokens » — déjà fait

L'ADR-006 (2026-10-20/21) couvre exactement ce point. État réel :

| Nœud | Pair enregistré chez Core | Auth |
|---|---|---|
| Edge | `http://100.112.255.75:8642` | ✅ 200 avec clé / 401 sans |
| DC-DELL | `http://100.70.59.28:8642` | ✅ 200 avec clé / 401 sans |

Les tokens sont déployés et le canal est vérifié. La phase 1.2 et 2.2 du plan
d'action sont **déjà livrées**.

### Ce qui est juste dans les décisions

| # | Décision | Statut |
|---|---|---|
| 1 | Tailscale comme réseau A2A | ✅ déjà le cas |
| 4 | DC-DELL = worker 1 tâche | ✅ correct |
| 7 | Vérification SHA-256 | ✅ correct (règle d'orchestration n°5) |
| 2 | Hermes Core = orchestrateur principal | ⚠️ à nuancer (ADR-005) |
| 3 | OpenClaw Edge = orchestrateur secondaire | ❌ contredit l'ADR-005 |
| 5 | Séparer les providers Ollama | ❌ non justifié par les preuves |
| 6 | Tokens A2A | ✅ déjà déployés |

---

## Synthèse

| Section | Verdict |
|---|---|
| §1 Inventaire machines | ✅ exact |
| §2 Inventaire agents | ✅ exact |
| §2.1 « conflit critique » Ollama | ❌ faux + auto-contradictoire |
| §3.1 Matrice de connectivité | ✅ exacte |
| §3.3 / §7 « Edge non joignable » | ❌ durcissement délibéré |
| §4.1 « Ollama Local (Edge) » | ❌ Ollama est sur Core |
| §4.2 « Hermes ne fait pas d'inférence » | ❌ faux |
| §5 `/v1/tasks` | ✅ inexistantes (`404`) |
| §5 `/v1/runs` | ✅ existante (`405`) — mécanisme de run |
| §5 `POST /v1/chat/completions` | ❌ **revue fausse, corrigée** (existe, `200` en streaming) |
| §5.3 Config `a2a:` | ❌ schéma inexistant |
| §6.1 Séparer Ollama | ❌ non justifié |
| §6.1.2 / §6.2.2 Tokens A2A | ❌ déjà livré (ADR-006) |
| §6.3.2 OpenClaw orchestrateur | ❌ contredit l'ADR-005 |

---

## Ce qu'il faut retenir

1. **Ne pas implémenter** les endpoints `/v1/tasks` : ils n'existent pas (`404`).
   Le mécanisme de run est **`/v1/runs`** (`405`) et la messagerie est
   **`hermes peer`**. En revanche `POST /v1/chat/completions` **existe**
   (`200`) — la revue a été corrigée sur ce point.
2. **Ne pas ajouter** de bloc `a2a:` : la clé est `bot_peers` +
   `HERMES_PEER_<NOM>_KEY`.
3. **Ne pas supprimer** la règle `ufw DENY 8642` : sans elle, `8642` est ouvert à
   tout le LAN.
4. **Corriger** la localisation d'Ollama : Core, pas Edge.
5. **Lire les ADR 001-006 avant toute nouvelle proposition d'architecture.**

---

*Revue produite par Hermes Core — 2026-10-21. Mesures reproduisibles :
`hermes peer list`, `hermes --version`, `curl http://hote:8642/health`,
`ufw status numbered`, `curl http://127.0.0.1:11434/api/tags`.*
