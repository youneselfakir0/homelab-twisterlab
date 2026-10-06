# ADR 002 — Retrait de tout modèle de langage local

**Date :** 2026-10-06
**Statut :** accepté

## Contexte

Un modèle de langage local (`phi3:3.8b`, ~2,2 Go quantifié) avait été déployé sur Edge
pour servir d'inférence locale et de repli.

## Mesure

| Élément | Valeur |
|---|---|
| VRAM disponible (GTX 1050) | 2048 Mio |
| Taille du modèle | ~2,2 Go |
| Latence observée | **>120 s pour 10 tokens** |

Le modèle ne tient pas en mémoire vidéo : il débordait en RAM système, avec une
latence rédhibitoire.

## Décision

**Aucun modèle local.** Les modèles sont servis à distance. Le service local a été
entièrement purgé (service système, binaires, modèles, port fermé).

## Justification

Un modèle local non viable n'est pas neutre : il dégrade silencieusement la flotte
et fausse les mesures de latence. Mieux vaut assumer la dépendance réseau.

## Vérification

Double mesure indépendante : depuis le nœud (`PORT_11434_FERME`, service absent) et
depuis l'orchestrateur (réponse vide sur le port = fermé).

## Conséquence durable

**Vérifier la VRAM avant de promettre un modèle local sur une machine.** Le disque
n'est jamais la contrainte : la carte graphique l'est.
