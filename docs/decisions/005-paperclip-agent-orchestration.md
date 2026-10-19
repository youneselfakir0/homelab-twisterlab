# ADR-005 — Gouvernance Paperclip et flotte d’agents

- **Statut : DÉCISION ACCEPTÉE / BASELINE VERROUILLÉE**
- **Date : 2026-10-19**
- **Portée :** architecture cible d’orchestration TwisterLab
- **Nature du changement :** décision documentaire seulement ; aucune configuration d’infrastructure n’est modifiée par cet ADR.

## Contexte

TwisterLab vise une plateforme multi-agent distribuée qui reçoit une mission, l’attribue, l’exécute, vérifie le résultat et conserve des preuves. Les agents existants possèdent déjà des profils/souls et des runtimes différents. La priorité est de réutiliser cet existant plutôt que de reconstruire les agents ou de multiplier les orchestrateurs.

## Décision

1. **CEO Paperclip conservé.** Il reste le responsable global de l’objectif, de la priorité et du résultat de la mission.
2. **Un coordinateur Paperclip dédié.** Ajouter ou désigner un seul agent coordinateur utilisant l’adaptateur `paperclip_runner`, après audit des agents runner déjà présents. Ne pas créer un doublon si un agent existant peut être réutilisé sans ambiguïté.
3. **Agents spécialisés invités.** Inviter les agents existants (notamment Hermes, OpenClaw et OpenCode selon leur rôle réel) dans l’organisation Paperclip. Préserver leurs souls/profils comme source de leur identité et expertise.
4. **Pas de réécriture préventive des souls.** Ne modifier un profil que si l’audit démontre un écart concret entre rôle souhaité, profil chargé et capacités disponibles.
5. **Intégration vérifiée séparément.** Pour chaque agent, vérifier son adaptateur/runtime, le chargement effectif de sa soul, son modèle, ses outils/MCP, ses permissions, son nœud d’exécution et le retour de statut/résultat à Paperclip.
6. **Responsabilités distinctes.** Paperclip est le plan de contrôle et de suivi ; le coordinateur distribue les tâches ; les agents invités exécutent leur spécialité. Hermes peut effectuer des délégations A2A si configuré et testé. OpenClaw n’est pas le coordinateur principal de cette décision ; il demeure un agent spécialisé/invité selon sa configuration. OpenCode reste spécialisé dans le développement lorsque la tâche le requiert.
7. **Contrat commun de mission.** Chaque tâche précise objectif, agent responsable unique, entrées, limites, nœud cible, budget/délai, preuve attendue, condition d’arrêt et statut final.
8. **Validation avant succès.** Une réponse « OK » de l’agent ne suffit pas : vérifier le livrable, les tests et les journaux. Toute reprise doit être limitée et tenir compte du risque de doublon.
9. **Garde-fous maintenus.** Pas de redémarrage, changement de configuration, publication, merge ou déploiement sans autorisation explicite ; maximum deux niveaux de délégation ; une tâche active à la fois sur DC-DELL.
10. **Sources de vérité.** Notion = vision, décisions et suivi ; GitHub/Forgejo = code, ADR, issues et PR ; Paperclip = agents, affectations, état d’exécution, budgets et approbations ; les profils/runtimes = configuration effective de chaque agent.

## Ce qui est verrouillé et ce qui ne l’est pas

**Verrouillé :** cette répartition conceptuelle des responsabilités et la stratégie de réutilisation des souls existantes.

**Non présumé ni déclaré terminé :** capacité de `paperclip_runner` à invoquer correctement les agents invités, compatibilité des adaptateurs, chargement des souls, permissions effectives, routage inter-nœuds et retour des preuves. Ces points doivent être audités et démontrés avec une mission pilote sans risque.

## Séquence d’implémentation

1. Audit en lecture seule de la compagnie Paperclip et de ses agents runner/gateway existants.
2. Choisir un coordinateur unique en réutilisant un agent existant si possible.
3. Inviter un seul agent spécialisé et confirmer soul + runtime + outils + permissions.
4. Exécuter une mission de test non destructive ; vérifier attribution, logs, résultat et statut Paperclip.
5. Ajouter progressivement les autres agents et documenter les exceptions.
6. Modifier les profils ou permissions uniquement sur preuve et avec autorisation explicite.

## Critères d’acceptation

- Un CEO Paperclip et un coordinateur opérationnel clairement identifiés, sans double orchestration.
- Chaque agent invité est associé au bon runtime/adaptateur et charge le profil attendu.
- Permissions minimales et MCP nécessaires uniquement.
- Une mission test suit le cycle attribution → exécution → validation → preuve → statut.
- Les échecs sont visibles et les reprises ne provoquent pas d’actions externes en double.

## Historique

Cette ADR remplace les formulations historiques contradictoires sur le rôle principal d’OpenClaw ou d’Hermes pour l’orchestration globale. Les mécanismes A2A Hermes restent une capacité d’exécution distribuée, pas une seconde source de vérité pour les tâches Paperclip.
