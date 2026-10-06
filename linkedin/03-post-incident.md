# Post LinkedIn #2 — Le post-mortem (le post qui impressionne)

> À publier 3-5 jours après le premier. C'est celui qui montre ta valeur technique :
> peu de candidats publient une analyse d'incident réelle.

---

**Mon orchestrateur s'est tué lui-même. Voici l'analyse.**

Il y a quelques jours, mon gateway d'orchestration est tombé. Pas de plantage
aléatoire : **arrêt en code 75**, décidé par son propre chien de garde.

Ce que les logs ont montré, horodaté :

`01:06:33` — mon répartiteur de tâches lance 3 workers en local
`01:09:45` — je les tue (je pensais régler le problème)
`01:13:07` — **il en relance 2**
`01:27:47` — **il en relance encore 1**
`01:29` — le canal de notification commence à timeouter
`01:32:37` — **le chien de garde tue le processus : 3 sondes de vivacité manquées**

La cause racine :

Chaque worker lancé localement est un agent complet avec accès terminal. Ensemble,
ils affamaient la boucle d'événements asyncio du processus hôte. Le chien de garde
a fait exactement son travail : tuer un processus qui ne répond plus.

Mais le vrai problème était ailleurs : **tuer les workers ne suffisait pas.**
Le répartiteur les relançait à chaque cycle. Il fallait désactiver le répartiteur,
puis libérer et bloquer chaque tâche une par une.

Trois leçons que j'en tire :

**1. Ne jamais exécuter de travail lourd dans le processus d'orchestration.**
Les compilations et migrations vont dans un terminal dédié ou sur une machine
distante. L'orchestrateur route et tient le plan — rien de plus.

**2. Désactiver une configuration n'arrête pas ce qui tourne déjà.**
J'ai désactivé le répartiteur. Les workers lancés avant ont continué. La
configuration s'applique aux cycles suivants, pas au présent.

**3. Vérifier les dégâts avant de supposer.**
J'ai contrôlé mon dépôt git après l'incident : intact (31 objets, 2 commits).
La panne était réelle, la perte de données ne l'était pas. Sans vérification,
j'aurais pu « réparer » quelque chose qui n'était pas cassé.

Le post-mortem complet, avec la chronologie et le correctif, est dans mon dépôt :
[LIEN vers docs/incidents/exit-75.md]

Une panne documentée vaut mieux que dix succès non expliqués.

#Sysadmin #DevOps #PostMortem #SRE #IncidentManagement

---

## Pourquoi ce post fonctionne

- Il montre que tu **lis tes logs** et que tu comprends ce qu'ils disent.
- Il prouve que tu **corriges la cause**, pas le symptôme.
- Il expose un raisonnement en trois temps (constat → cause → règle) : c'est
  exactement ce qu'un employeur veut voir chez un profil infrastructure.
- Il admet une erreur sans s'excuser : signe de maturité technique.
