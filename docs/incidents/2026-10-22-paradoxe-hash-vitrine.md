# Incident : Paradoxe du Hash de la Vitrine
Date : 2026-10-22 | Statut : Résolu | Priorité : Basse

## 🚩 Symptômes
- Observation : La "ligne de confiance" en bas de la page vitrine affichait un hash de commit (`1a83511a`) alors que le HEAD du dépôt était déjà à `b6717fc`.
- Erreur : Décalage constant d'un commit dès que la ligne était mise à jour.

## 📜 Logs
- `git rev-parse HEAD` $\rightarrow$ `b6717fc...`
- Contenu HTML $\rightarrow$ `Dernier commit doc : 1a83511a`

## 🔍 Investigation
- Hypothèse : Erreur de copier-coller lors de la mise à jour.
- Test : Mise à jour manuelle du hash dans `index.html` $\rightarrow$ Commit $\rightarrow$ Nouveau hash généré.
- Résultat : Le fait d'écrire le hash du commit actuel dans le fichier modifie le contenu du fichier, ce qui change le hash du commit résultant.

## 🎯 Cause Racine
Tentative d'**auto-attestation**. L'agent a tenté d'inscrire la preuve de l'objet (le commit) à l'intérieur de l'objet lui-même. C'est un paradoxe logique : l'attestation modifie l'objet attesté.

## ✅ Solution Appliquée
- Remplacement des logs simulés par des hashes SHA-256 réels des artefacts (`design_spec.md`, `index.html`).
- Mise à jour du commit final.
- Décision architecturale : Passer à une injection dynamique via GitHub Actions (`${{ github.sha }}`) pour les futures mises à jour afin de sortir la preuve de l'objet.

## 🛡️ Vérification (Preuve Externe)
- Méthode : Calcul du hash SHA-256 de `index.html` depuis le Core et comparaison avec le commit HEAD.
- Preuve : `sha256sum index.html` $\rightarrow$ `6959c21a...` MATCH avec l'artefact déployé.

## 💡 Leçon Apprise
« Toute preuve interne est une narration. Seule l'attestation externe est une mesure. »
L'attestation ne doit jamais vivre dans la chose attestée.
