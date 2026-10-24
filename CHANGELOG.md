# CHANGELOG

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-10-24
### 🟢 Ajouts (Added)
- **Messagerie interne** : déploiement de hMailServer 5.7.1 (build 3116) sur Core — `mail.twisterlab.local`.
- Protocoles : SMTP 25, SMTP Submission 587 (STARTTLS optionnel), IMAP 143.
- Authentification **Active Directory** par compte (`IsAD`/`ADDomain`/`ADUsername`), aucun mot de passe stocké dans hMailServer.
- 6 comptes : `administrator@`, `alex@`, `devuser@`, `maya@`, `devuser@`, `admin@`, `test@` (tous `@twisterlab.local`).
- DNS : enregistrement `A mail` (192.168.0.12) et `MX @` (préf. 10) sur la zone `twisterlab.local` (DC-DELL).
- Pare-feu Windows : règles entrantes 25/143/587 + **blocage sortant 25** pour `hMailServer.exe`.
- Scripts : `scripts/messagerie/` (déploiement, configuration, tests, DNS).
- Rapport : `docs/messagerie/2026-10-24-messagerie-interne.md`.
### 🟡 Modifications (Changed)
- INFRASTRUCTURE.md : Core porte désormais le rôle « serveur mail » ; section service de messagerie et endpoints mesurés.
### 🔴 Correctifs (Fixed)
- Anti-relais : priorité des plages de sécurité corrigée (évaluation par priorité **décroissante** : LAN 40 > My computer 30 > Internet 10).
### ⚪ Suppressions (Removed)
- POP3 (110) désactivé — non demandé par le cahier des charges.

## [0.1.0] - 2026-10-22
### 🟢 Ajouts (Added)
- Infrastructure : Implémentation du système de documentation permanente et versionnement.
- Documentation : Création du skill `homelab-docs` pour l'uniformisation des rapports d'incidents et du CHANGELOG.
- Vitrine : Refonte complète de la landing page (v3) avec architecture multi-agent.
- Mesures : Restauration des détails techniques ComfyUI via remesure directe sur machine.
### 🟡 Modifications (Changed)
- Architecture : Suppression totale de Paperclip des rôles et endpoints.
### 🔴 Correctifs (Fixed)
- Vitrine : Correction du paradoxe du hash de confiance (décalage de commit).
