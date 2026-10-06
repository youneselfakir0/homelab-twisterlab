# Architecture

## Vue d'ensemble

Trois nœuds, deux rôles, une règle : **rien ne s'exécute à distance sans être revérifié.**

```
        ┌──────────────────────────────────────────────┐
        │  CORE (Win11) — orchestrateur                │
        │  · décide du plan                            │
        │  · route le travail vers les workers         │
        │  · revérifie chaque artefact par SHA-256     │
        │  · tient le registre de tâches (SQLite)      │
        └───────┬──────────────────────────────┬───────┘
                │  api_server :8642            │
                │  overlay WireGuard           │
        ┌───────▼──────────┐          ┌────────▼─────────┐
        │  EDGE (Ubuntu)   │          │  DC-DELL (WSrv)  │
        │  builds Linux    │          │  AD / DNS / DHCP │
        │  18 conteneurs   │          │  Hyper-V         │
        │  git self-hosted │          │  1 tâche à la fois│
        └──────────────────┘          └──────────────────┘
```

## Pourquoi pair-à-pair et non maître/esclave

Une architecture maître/esclave crée un point de défaillance unique : si le maître
tombe, tout s'arrête. Ici, **chaque nœud expose son propre service** sur le port 8642
et peut être contacté indépendamment. L'orchestrateur est un rôle, pas un composant
matériel : il pourrait migrer sur n'importe quel nœud.

L'asymétrie est volontaire : DC-DELL héberge l'annuaire du domaine, donc son service
n'est joignable que depuis l'overlay et ses privilèges sont limités au strict nécessaire.

## Couche réseau

| Plan | Adressage | Usage |
|---|---|---|
| LAN physique | `192.168.0.0/24` | Services internes, RDP/SMB |
| Overlay WireGuard | `100.64.0.0/10` | Orchestration, accès distant chiffré |

L'overlay est le plan de confiance pour l'orchestration : il est chiffré, authentifié
par identité de nœud, et ne dépend pas de l'exposition du LAN.

## Sécurité

- Le service d'orchestration est **lié à l'interface overlay uniquement**, jamais à `0.0.0.0`.
- Authentification par clé sur chaque appel ; une clé erronée retourne 401, pas un accès partiel.
- Le point d'échange d'un nœud porte l'identité du nœud (`claim_lock = <host>:<pid>`),
  ce qui permet de tracer quel processus a pris quelle tâche.
- Sur le contrôleur de domaine, aucune exécution distante entrante : il **appelle**,
  il n'est pas **appelé**.

## Contrainte matérielle assumée

DC-DELL dispose de 8 Go de RAM (~1,5 Go libres en régime établi). Il ne peut donc
exécuter **qu'une tâche à la fois**. Cette contrainte est outillée : un script de
contrôle (`check_lock.ps1`) inspecte l'état avant de lancer quoi que ce soit, plutôt
que de compter sur la discipline de l'opérateur.
