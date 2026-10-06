# Plan de publication LinkedIn

## Semaine 1

| Jour | Action | Contenu |
|---|---|---|
| J1 | Publier le profil | Titre + À propos + bannière (diagramme) + photo |
| J2 | Post #1 | Présentation du homelab + capture du diagramme |
| J4 | Commenter | Répondre à chaque commentaire (l'algorithme récompense) |

## Semaine 2

| Jour | Action | Contenu |
|---|---|---|
| J8 | Post #2 | Le post-mortem de l'incident (exit code 75) |
| J10 | Post #3 | « 3 décisions que j'assume » (LLM local, ordonnanceur, vérification) |

## Règles de publication

1. **Une image par post.** Le diagramme d'architecture pour le #1, une capture de
   terminal ou de Grafana pour les suivants. Un post avec visuel obtient nettement
   plus de portée.
2. **Ne jamais publier un chiffre que tu ne peux pas mesurer.** Tous les chiffres de
   ces posts sont vérifiables dans ton dépôt.
3. **Répondre dans l'heure.** Les 60 premières minutes déterminent la diffusion.
4. **Ne pas mettre le lien dans le post.** LinkedIn réduit la portée des posts avec
   lien externe. Mets-le **en premier commentaire**.
5. **Un post = une idée.** Ne pas mélanger le homelab et l'incident dans le même post.

## Le commentaire à mettre en premier

```
Le dépôt complet, avec le diagramme, l'inventaire mesuré, les décisions
d'architecture (ADR) et les post-mortems : [LIEN GITHUB]

Tout est reproductible — les commandes de relevé sont incluses.
```

## Profil : les 4 éléments à ne pas oublier

- [ ] **Photo** professionnelle
- [ ] **Bannière** : capture du diagramme d'architecture
- [ ] **Localisation** renseignée (les recruteurs filtrent dessus)
- [ ] **3 compétences épinglées** : Windows Server, Docker, Réseau

## Ciblage des candidatures

Pour chaque offre, envoie un message court au recruteur **avec le lien du dépôt**.
Le post-mortem est ton meilleur atout : il prouve que tu analyses, pas seulement
que tu exécutes.

```
Bonjour,

Je me permets de vous contacter au sujet du poste de [intitulé].

J'administre une infrastructure personnelle de 3 machines : un contrôleur de
domaine Windows Server 2025 (AD, DNS, DHCP), un serveur Ubuntu avec 18 conteneurs
Docker (supervision Prometheus/Grafana, git auto-hébergé), et une couche
d'orchestration maison.

Je documente tout par mesure directe — y compris mes incidents, avec analyse de
cause racine : [LIEN]

Seriez-vous disponible pour un échange court ?

[Prénom NOM]
```
