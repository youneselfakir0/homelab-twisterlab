---
name: homelab-docs
description: Use for lab versioning, incident reports and CHANGELOG.
category: devops
---

# Homelab Documentation & Versioning

Cette skill définit la discipline administrative du TwisterLab. L'objectif est de transformer chaque action technique en une trace vérifiable.

## 1. Procédure de Versionnement
Toute modification significative (config, script, infra) doit suivre ce flux :
1. **Identification** : Isoler le changement logique (un seul changement par commit).
2. **Exécution** : Appliquer la modification.
3. **Validation** : Mesurer le résultat et calculer la preuve (SHA-256, log de succès) depuis un nœud tiers.
4. **Documentation** : Mettre à jour le `CHANGELOG.md` et créer une fiche d'incident si nécessaire.
5. **Commit** : `git add` $\rightarrow$ `git commit -m "type: description"` $\rightarrow$ `git push`.
6. **Clôture** : Fermer la tâche Kanban. Une tâche n'est DONE que quand elle est documentée et commitée.

## 2. Template : Fiche d'Incident
Fichier : `docs/incidents/YYYY-MM-DD-titre-court.md`

```markdown
# Incident : [Titre Court]
Date : YYYY-MM-DD | Statut : [Ouvert / Résolu] | Priorité : [Basse / Moyenne / Haute]

## 🚩 Symptômes
- Observation : [Ce qui a été vu]
- Erreurs : [Messages exacts, codes HTTP, stacktraces]

## 📜 Logs
- [Extrait de log 1]
- [Extrait de log 2]
(Note : Nettoyer systématiquement tous les secrets/tokens)

## 🔍 Investigation
- Hypothèse 1 : [Description] -> [Résultat du test] -> [Écarté/Validé]
- Hypothèse 2 : [Description] -> [Résultat du test] -> [Écarté/Validé]
- Traçage : [Étapes de diagnostic effectuées]

## 🎯 Cause Racine
[Explication technique précise de l'origine du problème]

## ✅ Solution Appliquée
- Commandes exécutées : `command1`, `command2`
- Changements de config : [Fichier X -> Ligne Y]

## 🛡️ Vérification (Preuve Externe)
- Méthode : [Comment on a prouvé la résolution]
- Preuve : [Hash recalculé depuis un nœud tiers, log de succès, etc.]

## 💡 Leçon Apprise
[Règle ou réflexe à intégrer pour éviter la récurrence]
```

## 3. Structure du CHANGELOG.md
Format : Chronologique inverse.

```markdown
## [Version X.Y.Z] - YYYY-MM-DD
### 🟢 Ajouts (Added)
- [Description du nouvel outil/service]
### 🟡 Modifications (Changed)
- [Description du changement de config/comportement]
### 🔴 Correctifs (Fixed)
- [Description du bug corrigé + lien vers fiche incident]
### ⚪ Suppressions (Removed)
- [Description du composant retiré]
```

## 4. Règles et Discipline
### Checklist Pré-Commit (Zéro Secret)
Avant chaque `git commit`, l'agent DOIT valider :
- [ ] **Scan de secrets** : Aucun token, password, API key présent dans les fichiers modifiés.
- [ ] **Nettoyage Logs** : Les extraits de logs ne contiennent pas d'IPs publiques sensibles ou de headers d'auth.
- [ ] **Cohérence** : Le commit correspond à un seul changement logique.
- [ ] **Preuve** : L'attestation de succès est externe à l'artefact.

### Gestion de la Mémoire Durable
- **INTERDICTION STRICTE** : Aucune suppression ou modification d'entrée de mémoire durable sans la validation explicite de l'Utilisateur.
- En cas de saturation de la mémoire, l'agent doit signaler l'état et proposer une consolidation. L'Utilisateur tranche.

### Le Paradoxe du Hash ( la doctrine )
- ** la règle ** : « Toute preuve interne est une narration. Seule l'attestation externe est une mesure. »
- **Pitfall** : Ne jamais inscrire un hash de commit ou un SHA-256 d'artefact à l'intérieur de l'artefact lui-même. L'attestation doit vivre dans un manifeste externe (Kanban, Log, CI).
