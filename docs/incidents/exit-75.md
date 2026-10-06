# Post-mortem — Crash du gateway, exit code 75

**Date :** 2026-10-06 · **Durée de l'indisponibilité :** ~14 minutes
**Sévérité :** élevée (orchestration aveugle)
**Statut :** cause racine identifiée, correctif appliqué et vérifié

## Résumé

Le gateway de l'orchestrateur est mort en **exit code 75** : le chien de garde a tué
le processus après trois sondes de vivacité manquées. Conséquence : le service
d'orchestration (port 8642) et le canal de notification sont tombés.

## Chronologie (horodatage mesuré)

| Heure (UTC) | Événement | Preuve |
|---|---|---|
| 01:06:33 | Le répartiteur lance 3 workers en local | `dispatcher: spawned=3` |
| 01:09:45 | Les 3 workers sont tués manuellement | `reaped 3 zombie worker(s)` |
| 01:13:07 | **Le répartiteur en relance 2** | `reaped 2 zombie worker(s)` |
| 01:27:47 | **Il en relance encore 1** | `dispatcher: spawned=1` |
| 01:29–01:30 | Le canal de notification commence à timeouter | `polling degraded` |
| **01:32:37** | **Le chien de garde tue le gateway** | `missed 3 consecutive liveness probes; exiting with code 75` |
| 01:46:04 | Redémarrage | `control pipe listening` |
| 01:47:25 | Service d'orchestration de nouveau en écoute | `listening on :8642` |

## Cause racine

Le répartiteur **relance ses workers après chaque suppression**. Les tuer ne suffit
pas : il en a relancé 2, puis 1. Chaque worker est un agent complet (~100 Mo) avec
accès terminal, qui consomme le CPU et **affame la boucle d'événements asyncio** du
processus hôte.

Le chien de garde est conçu pour tuer le processus quand la boucle manque 3 sondes
consécutives — comportement correct, mais déclenché par un travail lourd exécuté
*dans* le gateway.

## Facteur aggravant

Désactiver le répartiteur **n'interrompt pas les workers déjà lancés** : la
configuration ne s'applique qu'aux cycles suivants. Il faut explicitement libérer
puis bloquer chaque tâche, et tuer les processus à la main.

## Correctif appliqué

1. Répartiteur automatique désactivé (`dispatch_in_gateway=false`) — vérifié
2. Décomposition automatique désactivée — vérifié
3. Tâches libérées puis bloquées une par une (le simple « libérer » ne suffit pas :
   le répartiteur les reprend)
4. Vérification qu'aucun worker ne tourne : comptage des processus → **0**

## Dégâts

| Élément | État |
|---|---|
| Dépôt git local | **INTACT** — 133 Ko, 31 objets, 2 commits, vérifié après incident |
| Données du registre de tâches | **INTACTES** — base SQLite, 7 tâches |
| Service d'orchestration | Rétabli |
| Plugin de notification | Timeout au chargement sous charge ; réseau joignable (302 en 3,1 s) |

## Leçon

> **Ne jamais exécuter de travail lourd dans le processus de l'orchestrateur.**
> Les compilations, installations et migrations tournent dans un terminal normal
> ou sur un worker distant. L'orchestrateur route et tient le plan — rien de plus.

## Actions préventives

- [x] Répartiteur automatique désactivé et vérifié
- [x] Règle inscrite dans la documentation d'identité de l'agent
- [x] Leçon ajoutée à la base de connaissances opérationnelle
- [ ] Supervision : alerter si un worker local apparaît alors que le répartiteur est désactivé
