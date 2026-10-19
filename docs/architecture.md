# Architecture

## Vue d'ensemble
Trois nœuds, deux rôles, une règle : **rien ne s'exécute à distance sans être revérifié.**

```
        ┌──────────────────────────────────────────────┐
        │  CORE (Win11) — orchestration technique     │
        │  · Hermes / outils de coordination selon rôle│
        │  · revérifie les artefacts                   │
        │  · registre de tâches local historique       │
        └───────┬──────────────────────────────┬───────┘
                │  api_server :8642            │
                │  overlay WireGuard           │
        ┌───────▼──────────┐          ┌────────▼─────────┐
        │  EDGE (Ubuntu)   │          │  DC-DELL (WSrv)  │
        │  builds Linux    │          │  AD / DNS / DHCP │
        │  services        │          │  1 tâche à la fois│
        └──────────────────┘          └──────────────────┘
```

## Plan de contrôle multi-agent — décision 2026-10-19

**Statut : baseline conceptuelle verrouillée ; intégration réelle à valider.** Voir [ADR-005 — Gouvernance Paperclip et flotte d’agents](decisions/005-paperclip-agent-orchestration.md).

- **Paperclip CEO** conserve la responsabilité globale de la mission et du résultat.
- **Un coordinateur Paperclip dédié** est ajouté ou désigné via `paperclip_runner`, après audit des runners déjà présents. Un seul coordinateur opérationnel doit être identifié ; réutiliser un agent existant si possible.
- **Les agents spécialisés existants** sont invités dans Paperclip en conservant leurs souls/profils. Ne pas réécrire ces profils sans preuve qu’une correction est nécessaire.
- **Hermes** fournit la délégation/exécution A2A lorsque ses peers, credentials et capacités sont configurés et validés.
- **OpenCode** est utilisé pour les tâches de développement.
- **OpenClaw** peut rester un agent invité/spécialisé ; il n’est pas le coordinateur principal dans cette décision.
- Le coordinateur affecte une tâche à un responsable unique. Chaque tâche doit avoir un résultat attendu, des limites, une preuve de validation et une condition d’arrêt.
- Paperclip porte l’affectation et l’état des missions ; les services A2A portent l’exécution distribuée. Le registre de tâches historique n’est pas automatiquement le routeur Paperclip.

### État de preuve

Cette décision ne prouve pas que `paperclip_runner` invoque déjà les agents invités, que leurs souls sont chargées ou que les permissions sont correctes. Ces points restent à vérifier en lecture seule, puis avec une mission pilote non destructive. Aucun changement d’infrastructure ne découle de cette ADR.

## Pourquoi pair-à-pair au niveau de l’exécution

L’exécution distribuée conserve les services de nœud et les appels authentifiés ; Paperclip devient le plan de contrôle des missions. Ce sont deux couches différentes, pas deux orchestrateurs globaux concurrents.

Chaque nœud peut exposer son service d’exécution indépendamment. L’orchestrateur technique est un rôle logiciel, pas une propriété matérielle immuable. Les changements de configuration réseau restent soumis à audit et autorisation.

## Couche réseau

| Plan | Adressage | Usage |
|---|---|---|
| LAN physique | `192.168.0.0/24` | Services internes, RDP/SMB |
| Overlay WireGuard | `100.64.0.0/10` | Orchestration, accès distant chiffré |

L’overlay est le plan de confiance prévu pour l’orchestration. Toute exposition réelle différente, notamment une écoute sur `0.0.0.0`, doit être considérée comme un écart à examiner, et non comme une configuration conforme par défaut.

## Sécurité

- Le service d’orchestration devrait être lié à l’interface overlay uniquement, jamais à `0.0.0.0`, sauf décision documentée et contrôles compensatoires validés.
- Authentification par clé sur chaque appel ; une clé erronée doit échouer fermé.
- Les appels et actions doivent être associés à l’identité de l’agent/nœud pour permettre l’audit.
- Sur le contrôleur de domaine, aucune exécution distante entrante non autorisée : limiter les accès au strict nécessaire.
- Les secrets ne sont jamais écrits dans les logs ou dans Git.

## Contrainte matérielle assumée

DC-DELL dispose de ressources limitées et ne doit exécuter qu’une tâche à la fois. Cette limite doit être appliquée par un mécanisme de verrouillage/contrôle, pas seulement par discipline opérateur.

## Règle de vérification

> **Un exécutant qui annonce « OK » n’est pas une preuve.**

Chaque artefact rendu par un worker est revérifié depuis le côté demandeur : empreinte SHA-256 recalculée si applicable, chemin absolu confirmé, taille comparée et tests adaptés exécutés. Une étape dont la seule preuve est « OK » est indistinguable d’un échec silencieux.
