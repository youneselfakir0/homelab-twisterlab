# Architecture

## Vue d'ensemble
Trois nœuds, trois agents, une règle : **rien ne s'exécute à distance sans être revérifié.**

```
        ┌──────────────────────────────────────────────┐
        │  CORE (Win11) — Orchestration (Hermes)      │
        │  · Cerveau : coordination, Kanban, A2A       │
        │  · revérifie les artefacts                   │
        │  · registre de tâches local historique       │
        └───────┬──────────────────────────────┬───────┘
                │  api_server :8642            │
                │  overlay WireGuard           │
        ┌───────▼──────────┐          ┌────────▼─────────┐
        │  EDGE (Ubuntu)   │          │  DC-DELL (WSrv)  │
        │  · Hermes Worker  │          │  · Hermes Worker  │
        │  · OpenClaw (Tools)│          │  · Admin AD / DNS  │
        │  · OpenCode (Dev) │          │  · 1 tâche à la fois│
        └──────────────────┘          └──────────────────┘
```

## Plan de contrôle multi-agent — Architecture Hermes / OpenClaw / OpenCode

**Statut : Baseline verrouillée.** L'orchestration est centralisée via Hermes pour optimiser la consommation de tokens et simplifier le routing.

- **Hermes** est le **cerveau** : il gère le Kanban, affecte les tâches aux workers et coordonne les flux via A2A.
- **OpenClaw** est le **runtime d'exécution** : il utilise des plugins et des skills pour interagir avec des outils externes (via Composio, Notion, etc.).
- **OpenCode** est l'**agent de développement** : spécialisé dans l'écriture de code, les PRs, les reviews et les tests.

### Distribution des rôles

| Machine | Hermes | OpenClaw | OpenCode | Usage Principal |
|---|---|---|---|---|
| **Core** | ✅ Orchestrateur | ✅ Installé | ✅ Installé | Coordination + Dev local |
| **Edge** | ✅ Worker | ✅ Principal | ✅ Installé | Exécution Tools + Dev Linux |
| **DC-DELL** | ✅ Worker | ✅ Installé | ❌ Non installé | Administration AD / DNS |

### Flux d'exécution

1. **Saisie** : L'utilisateur définit une mission dans le Kanban (Core).
2. **Routing** : Hermes (Core) analyse la tâche et la route vers le worker adapté via A2A.
3. **Exécution** : 
    - Si Tool/Plugin $
ightarrow$ **OpenClaw** (Edge/Core/DC-DELL).
    - Si Coding $
ightarrow$ **OpenCode** (Edge/Core).
4. **Validation** : L'artefact est retourné à Hermes (Core) pour vérification (SHA-256, tests).

---

## Pourquoi l'architecture Hermes / OpenClaw / OpenCode

L'utilisation d'une orchestration centralisée via Hermes permet de réduire drastiquement la consommation de tokens en évitant les boucles de coordination redondantes et en utilisant des adaptateurs légers pour l'exécution.

- **Efficacité** : Pas de doublons d'orchestration.
- **Spécialisation** : OpenClaw pour les outils, OpenCode pour le code.
- **Scalabilité** : Ajout facile de nouveaux workers Hermes.

## Couche réseau

| Plan | Adressage | Usage |
|---|---|---|
| LAN physique | `192.168.0.0/24` | Services internes, RDP/SMB |
| Overlay WireGuard | `100.64.0.0/10` | Orchestration A2A, accès distant chiffré |

L’overlay est le plan de confiance prévu pour l’orchestration. Toute exposition réelle différente, notamment une écoute sur `0.0.0.0`, doit être considérée comme un écart à examiner.

## Sécurité

- Le service d’orchestration (`api_server:8642`) est lié à l’interface overlay uniquement sur Edge (ufw DENY LAN).
- Authentification par clé sur chaque appel A2A.
- Les appels et actions sont associés à l’identité de l’agent/nœud pour permettre l’audit.
- Sur le contrôleur de domaine, aucune exécution distante entrante non autorisée.
- Les secrets ne sont jamais écrits dans les logs ou dans Git.

## Contrainte matérielle assumée

DC-DELL dispose de ressources limitées et ne doit exécuter qu’une tâche à la fois. Cette limite est appliquée via un verrouillage (`check_lock.ps1`).

## Règle de vérification

> **Un exécutant qui annonce « OK » n’est pas une preuve.**

Chaque artefact rendu par un worker est revérifié depuis le côté demandeur : empreinte SHA-256 recalculée si applicable, chemin absolu confirmé, taille comparée et tests adaptés exécutés. Une étape dont la seule preuve est « OK » est indistinguable d’un échec silencieux.
