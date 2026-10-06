# Post LinkedIn #1 — Présentation du homelab

> Le post de référence. À publier en premier. Joins une capture du diagramme.

---

**J'ai construit un homelab de 3 machines. Voici ce qu'il fait réellement.**

Beaucoup de homelabs empilent des services. Le mien répond à une question :
comment faire coopérer plusieurs machines de façon fiable ?

L'infrastructure :

🖥️ **Windows Server 2025** — contrôleur de domaine du domaine `twisterlab.local`
(Active Directory, DNS, DHCP, Hyper-V)

🐧 **Ubuntu 24.04** — 18 conteneurs Docker : git auto-hébergé, registre privé,
supervision Prometheus/Grafana/Alertmanager, automatisation n8n, CMS headless,
métamoteur, accès distant auto-hébergé

🪟 **Windows 11** — orchestrateur : il décide, délègue le travail aux deux autres
et vérifie chaque résultat

Le tout relié par un maillage chiffré WireGuard, sans architecture maître/esclave.

Trois choix que j'assume :

**1. Aucun modèle d'IA local.**
J'avais déployé un modèle sur la carte graphique du serveur Linux. Mesure :
2 Go de VRAM disponibles, 2,2 Go requis, plus de 120 secondes pour 10 tokens.
Je l'ai retiré. Un composant non viable n'est pas neutre — il dégrade en silence.

**2. Le registre de tâches n'est pas le routeur.**
Mon ordonnanceur exécutait en local ce qu'on lui demandait d'exécuter ailleurs,
et ignorait les tâches destinées aux autres machines. Désactivé, remplacé par
un routage explicite.

**3. Je vérifie par empreinte, pas par déclaration.**
Chaque résultat produit par une machine est revérifié depuis l'orchestrateur
(SHA-256, chemin, taille). Un « OK » n'est pas une preuve.

Tout est documenté et mesuré — commandes de relevé incluses pour que ce soit
reproductible.

Le dépôt : [LIEN]

#Homelab #Sysadmin #DevOps #Docker #ActiveDirectory #WindowsServer #Linux

---

## Variante courte (si tu préfères un format bref)

```
3 machines. 18 conteneurs. 1 contrôleur de domaine.

Mon homelab :
→ Windows Server 2025 : AD, DNS, DHCP, Hyper-V
→ Ubuntu 24.04 : 18 conteneurs (git, supervision, automatisation)
→ Windows 11 : orchestrateur qui délègue et vérifie par empreinte SHA-256

Ce que j'ai appris en le construisant :
• J'ai retiré mon modèle d'IA local : 2 Go de VRAM pour un modèle de 2,2 Go,
  c'est 120 s pour 10 tokens
• Mon ordonnanceur exécutait en local ce qu'il devait envoyer ailleurs — désactivé
• Un « OK » d'une machine n'est pas une preuve : je recalcule l'empreinte

Documenté, mesuré, reproductible. Dépôt en commentaire.

#Homelab #Sysadmin #Docker #ActiveDirectory
```
