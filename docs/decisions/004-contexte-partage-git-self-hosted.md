# ADR 004 — Contexte partagé = git auto-hébergé

**Date :** 2026-10-05
**Statut :** accepté

## Contexte

Trois machines maintenaient chacune un dépôt git local du même projet. Les historiques
avaient divergé : les nœuds ne partageaient plus la même base de code.

## Mesure

| Emplacement | État |
|---|---|
| Dépôt local orchestrateur | 2 commits, 31 objets, contenu réel (configuration, compétences, artefact) |
| Serveur git auto-hébergé | **1 dépôt vide** |

Conclusion : le contenu réel **n'était pas** sur le serveur partagé. Supprimer le
dépôt local aurait détruit des données non migrées.

## Décision

**Un seul serveur git auto-hébergé fait autorité.** Aucun dépôt local divergent.
La suppression des dépôts locaux est conditionnée à une **migration vérifiée** au
préalable (création du dépôt distant, poussée miroir, vérification des commits).

## Justification

Trois sources de vérité n'en sont aucune. Mais une migration destructive sans
vérification préalable est pire que la divergence : elle perd des données.

## Conséquence durable

> **Avant toute suppression, vérifier que la destination contient bien la donnée.**
> Un dépôt « vide » en face d'un dépôt local non vide est un signal d'arrêt.
