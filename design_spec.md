# design_spec.md — Vitrine TwisterLab

**Kanban :** t_b65c2225  
**Date :** 2026-10-22  
**Auteur :** Hermes (Edge) — profil default  
**Statut :** Livrable final (contenu + structure + copywriting)  
**Direction :** Dark mode first, technique, centré sur le triptyque Hermes / OpenClaw / OpenCode  

---

## 0. Fondamentaux

### 0.1 Positionnement

TwisterLab n'est pas un produit. C'est une **preuve d'exécution** : trois machines
hétérogènes (Windows 11 / Ubuntu 24.04 / Windows Server 2025) qui orchestrent
des agents de bout en bout, sans maître ni esclave, avec une vérification par
SHA-256 à chaque artefact rendu.

Le ton : **précis, vérifié, sans hype.** Aucun buzzword. Chaque affirmation
doit être mesurable. On ne dit pas « fast », on dit « 140 201 fichiers scannés
en 5 min ».

### 0.2 Règle de preuve

> Une réponse d'exécutant n'est pas une preuve. L'artefact vérifié l'est.

Chaque section du site renvoie à une preuve : hash, sortie de commande, log.
Le site est lui-même un artefact vérifiable.

### 0.3 Public cible

- Ingénieurs plateforme / SRE / DevOps
- Équipes évaluant de l'orchestration d'agents
- Opérateurs homelab / infra autogérée

Ils ouvriront l'onglet Network. Ils chronomètreront le chargement. Ils liront
le code avant le copywriting.

---

## 1. Tendances UX/UI « Engineering / DevTools » 2026

Sources : inspirefusion.com, jtechbd.net, dragdropship.com, dev.to,
peal.dev, theavocado.co, weabers.com (recueil 2026-10-22).

### 1.1 Dark mode = défaut, pas option

- Dark-first : le thème clair devient le toggle, pas l'inverse.
- **Jamais de #000000 pur.** Palette de near-blacks : #0A0A0B, #0F0F13, #0D1117
  (approche GitHub).
- Sur fond sombre, **les ombres deviennent des glows** : on indique
  l'élévation par des surfaces plus claires, pas par des drop-shadows.
- Contraste : WCAG 2.2 AA (4.5:1) testé séparément en dark, pas dérivé du light.

### 1.2 Bento grid + grille technique

- Grilles « bento » (tuiles asymétriques) pour les capacités.
- Hairline frame grid (filets 1px), labels mono en eyebrow.
- Structure prévisible, scanning rapide.

### 1.3 Le code est le hero

> If a developer sees five scrolls before a line of code, you've already lost them.

Le bloc code du hero tient sur un écran. 5 lignes qui fonctionnent, pas 40.

### 1.4 Copywriting orienté douleur, pas mécanisme

Formule qui convertit :  
`[ce que ça fait] pour [qui] sans [la chose redoutée]`

### 1.5 La perf est un argument produit

Un bundle de 2 Mo sur un outil qui se prétend rapide se retourne contre lui.
Cible : LCP < 1,5 s, zéro third-party au premier paint, images en format moderne.

### 1.6 Tokens de design (source unique de vérité)

Format JSON (Design Token Community Group), synchronisé Figma → CSS.
Tokens nommés : `color.bg`, `color.text`, `space.*`, `radius.*`.

### 1.7 Motion purposeful

Micro-animations fonctionnelles (hover state, skeleton, scroll-triggered
storytelling), jamais décoratives. GSAP / Framer Motion / View Transitions API.

---

## 2. Design System

### 2.1 Couleurs

| Token | Valeur | Usage |
|---|---|---|
| `--bg-base` | `#0A0A0B` | fond principal |
| `--bg-surface` | `#111113` | surfaces / cartes |
| `--bg-elevated` | `#18181B` | modales, dropdowns |
| `--border-hairline` | `#26262B` | filets, séparations |
| `--text-primary` | `#E5E5E5` | corps |
| `--text-secondary` | `#A1A1AA` | métadonnées, labels |
| `--text-muted` | `#6B6B74` | eyebrow, timestamps |
| `--accent-hermes` | `#7C6CF6` | Hermes (violet) |
| `--accent-openclaw` | `#38BDF8` | OpenClaw (cyan) |
| `--accent-opencode` | `#F59E0B` | OpenCode (ambre) |
| `--accent-ok` | `#34D399` | états de succès / preuves |
| `--accent-warn` | `#FBBF24` | avertissements |
| `--accent-fail` | `#F87171` | erreurs, blocages |

Ratios de contraste vérifiés ≥ 4,5:1 sur `--bg-base`.

### 2.2 Typographie

- **Corps** : Inter (sans-serif), `15–16px`, line-height 1,6.
- **Mono** : JetBrains Mono — code, hashes, logs, eyebrow labels.
- **Titres** : Inter, graisse 600–700, tracking serré (-0,02em).
- **Eyebrow** : JetBrains Mono, `11px`, uppercase, `letter-spacing: 0,08em`.

Échelle : 12 / 14 / 16 / 20 / 28 / 40 / 56.

### 2.3 Grille & espacements

- Container max-width : `1200px`, padding `24px`.
- Grille 12 colonnes, gutter `24px`.
- Bento : gap `1px` sur fond `--border-hairline` (filets visibles).
- Espacements : échelle 4/8/12/16/24/32/48/64/96.

### 2.4 Rayons & élévation

- Radius : `6px` (composants), `12px` (cartes), `16px` (bento).
- Élévation dark : `--bg-base` → `--bg-surface` → `--bg-elevated`,  
  plus un glow `0 0 0 1px` + `0 8px 24px rgba(0,0,0,0,5)`.

### 2.5 Motion

- Durées : 150ms (micro), 300ms (transition), 600ms (storytelling).
- Easing : `cubic-bezier(0.16, 1, 0.3, 1)` (sortie douce).
- `prefers-reduced-motion: reduce` → tout désactivé.

---

## 3. Structure des sections

### S1. Hero

- Eyebrow : `TWISTERLAB — ORCHESTRATION D'AGENTS, VÉRIFIÉE PAR SHA-256`
- H1 : « Trois machines. Zéro maître. Chaque artefact est vérifié. »
- Sous-titre : 1 phrase — pas de promesse vague, une mesure.
- Bloc terminal (code, tient sur un écran) :
```bash
$ hermes peer dm edge \"build:core-restore\"
✔ artefact reçu   sha256 350a360e…52afd   4,2s
$ hermes peer dm core \"verify\"
✔ hash vérifié    350a360e…52afd          MATCH
```
- Double CTA : `Voir la preuve` / `Lire l'architecture`
- Preuve en méta : `3 nœuds · 18 conteneurs · 0 secret en clair`

### S2. Le problème

Titre : « L'orchestration sans preuve, c'est de la narration. »  
3 points de douleur en bento :
1. Un exécuteur dit « OK » → pas de preuve.
2. Un routeur automatique → aucune idée de qui a fait quoi.
3. Une doc qui diverge du réel → source de vérité introuvable.

### S3. Le triptyque

Trois cartes égales, une par agent, accent dédié.

**Hermes — Le moteur**  
> Orchestration déterministe. Pas de routeur automatique :  
> l'orchestrateur route lui-même, vers le worker juste nécessaire.

**OpenClaw — Le contrôle**  
> Control plane. Planifie, valide, rapporte. Le KANBAN est registre,  
> pas routeur.

**OpenCode — L'exécution**  
> Boucle d'inférence free-tier bridgée vers Hermes.  
> Aucun modèle local : la GTX 1050 (2 Go) ne sert pas de modèle.

Chaque carte : 3 lignes de description, 2 métriques, 1 lien « voir ».

### S4. Architecture (diagramme)

Schéma en 3 nœuds, sans flèche maître→esclave. Légende :  
`Hermes = rôle`, `api_server:8642 = endpoint`, `KANBAN = registre`.

Encart preuve : latence de dispatch, nombre de missions vérifiées.

### S5. Vérification

Titre : « Chaque artefact est revérifié depuis l'orchestrateur. »  
Log réel, style terminal :
```
[SHA-256] validate_post_reinstall_v2.ps1   db309180…4f483
[SHA-256] restore_core_windows11.ps1      350a360e…52afd
[SHA-256] .env (fusionné, 24 vars)        DA1F6D27…66F03
[ ISO ]   Windows 11  8,4 Go   BD4307DF…A650   MATCH
[ ISO ]   Ubuntu 24.04 5,9 Go  FAABCF33…8328   MATCH
[ ISO ]   Kali 2025.3  4,3 Go  FCF19997…F42A   MATCH
```

### S6. Contrainte = design

Titre : « Les limites sont publiées, pas masquées. »  
Tableau : nœud / contrainte / raison.  
Exemples : DC-DELL 1 tâche à la fois (8 Go RAM), Edge sans GPU (pas de  
modèle local), UFW `DENY` sur 8642 (durcissement volontaire).

### S7. Stack & mesures

Grille de métriques techniques : conteneurs actifs, ports exposés,  
version Hermes, volume de backups, taille du dépôt Git.

### S8. Preuve sociale / adoptants

Uniquement si mesurable : commits doc, tests passés, tâches Kanban  
clôturées. Sinon, section absente.

### S9. FAQ

1. Qui route les tâches ? → Hermes, explicitement.
2. Pourquoi dark ? → 2026 = défaut, contraintes OLED/contraste.
3. Comment est-ce vérifié ? → SHA-256 à chaque artefact.
4. Puis-je le cloner ? → Forgejo, dépôt self-hosted.

### S10. CTA final

- H2 : « Clonez, vérifiez, n'exécutez pas. »
- CTA primaire : `git clone` (commande exacte)
- CTA secondaire : `Lire INFRASTRUCTURE.md`
- Ligne de confiance : `Dernier commit doc : 1a83511a · 5 commits / 7 j · 0 changement infra`

---

## 4. Copywriting final

### Titres
- Hero H1 : « Trois machines. Zéro maître. Chaque artefact est vérifié. »
- H2 S2 : « L'orchestration sans preuve, c'est de la narration. »
- H2 S3 : « Hermes orchestre. OpenClaw contrôle. OpenCode exécute. »
- H2 S4 : « Une maille, pas une pyramide. »
- H2 S5 : « Chaque artefact est revérifié depuis l'orchestrateur. »
- H2 S6 : « Les limites sont publiées, pas masquées. »
- H2 S7 : « Ce qui tourne, en chiffres. »
- H2 S8 : « Ce qui est documenté, pas promis. »
- H2 S9 : « Questions d'ingénieur. »
- H2 S10 : « Clonez, vérifiez, n'exécutez pas. »

### Arguments techniques

- « Un exécuteur qui dit \"OK\" n'est pas une preuve. L'artefact revérifié l'est. »
- « Le registre de tâches n'est pas le routeur. `dispatch_in_gateway=false`. »
- « Pas de maître, pas d'esclave. Chaque nœud expose `api_server:8642`. »
- « Le contexte partagé vit dans un Forgejo self-hosted. Une seule source de vérité. »
- « Aucun modèle LLM local. La GTX 1050 (2 Go VRAM) ne peut pas servir de modèle. »
- « DC-DELL : une tâche à la fois. 8 Go RAM, ~1,5 Go libres. »

### Interdit

- Buzzwords, adjectifs sans mesure, screenshots consommateurs, vidéo marketing, affirmations non recoupables.

---

## 5. Implémentation

- Stack : Astro/Next.js, CSS custom properties, View Transitions API
- Accessibilité : WCAG 2.2 AA, `prefers-reduced-motion`, skip-link
- Perf : LCP < 1,5 s, zéro third-party au premier paint
- Source de vérité : INFRASTRUCTURE.md (fait foi sur tout conflit)

## 6. Livrables associés

- `design_spec.md`
- Repo : https://github.com/youneselfakir0/homelab-twisterlab
- Source : INFRASTRUCTURE.md
- Décision archi : docs/decisions/006-a2a-hermes-mesh.md
