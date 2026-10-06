# ADR 001 — Pas d'architecture maître/esclave

**Date :** 2026-10-05
**Statut :** accepté

## Contexte

Trois machines doivent coopérer. La solution évidente consiste à désigner un
orchestrateur central qui pilote deux exécutants passifs.

## Décision

Aucun nœud n'est « esclave ». Chaque machine expose son propre service d'orchestration
sur le port 8642, joignable indépendamment via l'overlay chiffré. L'orchestrateur est
un **rôle**, pas un composant matériel.

## Justification

- Un maître unique est un point de défaillance unique : sa chute arrête la flotte.
- Un nœud esclave est pilotable mais ne peut pas rendre de compte ; la vérification
  devient impossible sans un canal retour.
- Le pair-à-pair permet à n'importe quel nœud de devenir orchestrateur si nécessaire.

## Conséquences

- **Positif :** pas de point unique de défaillance ; chaque lien est vérifiable.
- **Négatif :** il faut gérer une clé par nœud et un service par machine.
- **Mesure :** les trois nœuds répondent indépendamment (sondes de santé HTTP 200).
