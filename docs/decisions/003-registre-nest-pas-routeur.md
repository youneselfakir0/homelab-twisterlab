# ADR 003 — Le registre de tâches n'est pas le routeur

**Date :** 2026-10-06
**Statut :** accepté — **décision corrective après incident**

## Contexte

Le registre de tâches intégré disposait d'un répartiteur automatique activé par défaut.
Cinq tâches furent créées, dont deux assignées à des machines distantes.

## Mesure (60 secondes après création)

| Tâche assignée à | Ce qui s'est produit |
|---|---|
| nœud local (×3) | **3 workers lancés en local**, accès terminal complet, ~100 Mo chacun |
| nœud distant (×2) | restées à l'état « prête » **indéfiniment** |

Le répartiteur exécutait en local ce qui devait être réfléchi, et ignorait ce qui
devait partir à distance. Une tâche intitulée « supprimer les dépôts » a été prise
en charge et exécutée **sans supervision ni vérification**.

## Décision

Répartiteur automatique **désactivé**. Le registre devient un **registre durable du
plan** ; l'orchestrateur route lui-même chaque tâche vers sa cible.

## Justification

- Le répartiteur ne connaît que les profils **de sa propre machine** : un nom de
  machine distante dans une colonne est une étiquette décorative, pas une route.
- Il n'existe aucune vérification d'artefact dans la boucle de complétion.
- Aucun verrou : deux tâches sur une machine à faible RAM passeraient en parallèle.

## Conséquence durable

> **Un ordonnanceur qui exécute en local ce qu'on lui demande d'exécuter ailleurs
> est plus dangereux qu'aucun ordonnanceur.**

Toujours vérifier **où** un travail s'exécute réellement, pas seulement qu'il a été
lancé.
