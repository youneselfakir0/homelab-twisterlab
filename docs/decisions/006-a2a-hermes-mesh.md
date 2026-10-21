# ADR 006 — Maillage A2A Hermes (bot-à-bot)

**Date :** 2026-10-20
**Statut :** accepté — **décision corrective après incident de routage**
**Portée :** transport de messagerie inter-nœuds entre agents Hermes (Core, Edge, DC-DELL)

## Contexte

Les trois nœuds du lab exécutent chacun un Hermes avec `api_server` sur `:8642`.
Pour qu'un agent d'un nœud puisse interroger l'agent d'un autre nœud, il faut un
canal A2A. Le canal natif est `hermes peer` : il dépose un message dans le
« Bot Chat » canonique du distant et exécute **un seul tour** de l'agent cible.

Edge déclarait déjà Core dans son registre `bot_peers`, mais **sans credential**.
Chaque appel échouait :

```
GET http://100.92.101.28:8642/v1/models
→ 401 {"error":{"message":"Invalid gateway API key (API_SERVER_KEY)",
                "code":"gateway_auth_failed"}}
```

Edge avait donc un pair « configuré » mais inutilisable : l'URL était bonne, la clé
absente. C'est le mode de défaillance exact où un pair enregistré ne sert à rien.

## Décision

Utiliser le mécanisme natif `hermes peer`, avec deux emplacements distincts :

| Élément | Emplacement | Notes |
|---|---|---|
| URL du pair | `config.yaml` → `bot_peers.<nom>.url` | registre, pas un secret |
| Clé du pair | `HERMES_PEER_<NOM>_KEY` dans le `.env` Hermes **de l'appelant** | le nom est en majuscules, `-` → `_` |

Mise en place en une commande :

```bash
hermes peer add core --url http://100.92.101.28:8642 \
  --key <API_SERVER_KEY_DU_PAIR> --note "poste principal (dev solo)"
```

`hermes peer add` fait **les deux** : upsert de `bot_peers` **et** écriture de la
clé. Sans `--key`, il enregistre l'URL en laissant le pair sans clé — donc en échec
à l'appel. Sans `--note`, il **écrase** la note existante lors d'un upsert.

## Mesure (avant / après)

| Vérification | Avant | Après |
|---|---|---|
| `hermes peer list` (Edge) | `core` sans clé | `core → [key set]` |
| `GET /v1/models` avec la clé | `gateway_auth_error` | **HTTP 200** + JSON |
| DM Edge → Core | 401 | **réponse livrée** |

## Piège majeur : une réponse de pair n'est pas une preuve

L'agent distant répond **depuis son propre contexte et ses propres outils**. Si la
source de vérité n'est pas présente sur sa machine, il **fabrique** une réponse
vraisemblable : SHAs de commits, chemins, versions.

Cas observé le 2026-10-20 : Core a répondu à Edge en citant cinq commits
(`1f9a3cd`, `8e2b1f4`, `c5d4e7a`, `a2f8d3b`, `4c7e1a9`) présentés comme l'historique
récent du dépôt. **Aucun n'existe.** L'historique réel sur la même période était :

```
1a83511a docs(adr): lock Paperclip CEO and coordinator agent model
bb63019c docs(architecture): align orchestration with Paperclip coordinator decision
1a3f4fcf docs: correct INFRASTRUCTURE.md — Core Tailscale IP, Hermes Edge via Tailscale
7cb93d85 docs: add INFRASTRUCTURE.md — source de vérité technique
772e9478 docs: add resilience restoration proof article
```

Cause : le dépôt `homelab-twisterlab` n'était **pas cloné sur Core** ; l'agent
distant n'avait aucun `git log` disponible et a improvisé.

Correctif appliqué : le dépôt est désormais cloné sur Core
(`C:/Users/administrator/homelab-twisterlab`), ce qui ancre les réponses A2A de
Core sur un historique réel.

## Vérification imposée

1. **Tester l'authentification avant de consommer un tour d'agent.**
   `curl -H "Authorization: Bearer $KEY" http://hote:8642/v1/models` → `200` + JSON
   si la clé est bonne, `gateway_auth_error` sinon. Un `401` ne dit rien d'autre.
2. **Recouper toute affirmation factuelle** contre la source de vérité (GitHub,
   `INFRASTRUCTURE.md`, mesures) avant de la relayer.
3. **Ne jamais faire transiter la clé** dans le chat ni dans une ligne de commande :
   la lire dans une variable shell et la passer sur le stdin du SSH.

## Sécurité

- La clé n'est jamais affichée, jamais journalisée, jamais commitée.
- `/health` répond `200` **sans** authentification ; `/v1/models` et tout le reste
  exigent la clé. Le transport Edge ↔ Core passe par Tailscale
  (`http://100.92.101.28:8642`), pas par le LAN.

## Carte des ports — et point de vue de mesure

**L'instrument compte autant que la mesure.** Un port « ouvert » ou « fermé » n'a
de sens que relativement à un point de vue. Mesurer depuis l'hôte, depuis le LAN
ou depuis un conteneur Docker donne trois réponses différentes pour le même port.

| Port | Service | Hôte Edge (`ss -ltnp`) | LAN `192.168.0.30` | Tailscale `100.112.255.75` |
|---|---|---|---|---|
| 8642 | api_server (A2A) | `0.0.0.0:8642` | **000 — bloqué** | **200** |
| 8644 | webhook | `0.0.0.0:8644` | **200** | **200** |
| 8643 | — | aucun | aucun | aucun |

**Règle de pare-feu mesurée** (`ufw status` sur Edge) :

```
8642/tcp    DENY    Anywhere
Anywhere    ALLOW   192.168.0.0/24
```

`8642` fait donc l'objet d'un **DENY explicite** : joignable par Tailscale mais
pas par le LAN. `8644` n'a pas de règle propre et hérite de l'ALLOW LAN.

**Piège du conteneur sandbox.** Un agent exécuté dans le conteneur
`nousresearch/hermes-sandbox:desktop` (`NetworkMode=bridge`, `PortBindings={}`)
ne publie **aucun** port et ne monte pas le `~/.hermes` réel de l'hôte : il voit
`/root/.hermes/skills` (bind read-only d'un dossier de cache) et n'a ni le binaire
`hermes` ni le `.env`. Ses tests réseau et filesystem décrivent **le conteneur**,
pas l'hôte. Tout « introuvable » ou « timeout » issu de ce conteneur est un
artefact de sandbox, pas un état de l'hôte.

## Conséquence durable

> **Un pair joignable mais non authentifié est indistinguishable d'un pair absent.
> Un agent distant qui répond n'est pas une preuve : c'est une assertion à vérifier.**

Tout changement de topologie A2A (nouveau nœud, rotation de clé) doit être mesuré
par le test `/v1/models` et non déclaré « OK » sur la foi d'un exécuteur.

## Historique

Complète ADR 005 : l'A2A Hermes y est mentionnée comme capacité d'exécution
distribuée. Le présent ADR la met en œuvre et en documente le mécanisme réel, le
mode de défaillance observé et le garde-fou de vérification.
