# BUG — `GET /v1/skills` renvoie 500 (route annoncée dans `/v1/capabilities`)

**Découvert le :** 2026-10-21
**Découvert par :** Hermes Core, lors de la revue de l'audit de flotte
**Sévérité :** moyenne — route publique cassée, annoncée comme disponible
**Portée :** tous les nœuds Hermes testés

---

## Symptôme

```
GET /v1/skills        (avec Authorization: Bearer <API_SERVER_KEY>)
→ HTTP 500
{"error": {"message": "Failed to enumerate skills",
           "type": "server_error", "param": null, "code": null}}
```

Alors que `/v1/capabilities` **annonce** la route :

```json
{"features": { "..." : "..." },
 "skills": {"method": "GET", "path": "/v1/skills"}}
```

**Une route déclarée disponible qui échoue systématiquement.**

---

## Reproduction

```bash
K=$(grep -m1 '^API_SERVER_KEY=' ~/.hermes/.env | cut -d= -f2-)

# 500, reproductible
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $K" \
  http://127.0.0.1:8642/v1/skills
# → 500 (×3 sur chaque nœud)

# Contrôle : sans clé
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8642/v1/skills
# → 401

# Contrôle : route voisine, fonctionne
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $K" \
  http://127.0.0.1:8642/v1/toolsets
# → 200

# Contrôle : la même énumération en CLI fonctionne
hermes skills list
# → table des skills installées
```

---

## Mesures

| Nœud | Version | `GET /v1/skills` | `GET /v1/toolsets` | `hermes skills list` |
|---|---|---|---|---|
| Core | v0.22.2 (`d923a5eb48`) | **500** (×3) | 200 | ✅ marche |
| Edge | v0.21.5 (`b2860025`) | **500** (×3) | 200 | — |

**Reproductible sur deux versions différentes → pas un problème de version.**

---

## Cause racine

`gateway/platforms/api_server.py` (~l.2931) :

```python
async def _handle_skills(self, request: web.Request) -> web.Response:
    """GET /v1/skills — deterministic JSON listing of installed skills."""
    try:
        from tools.skills_tool import _find_all_skills, _sort_skills
        skills = _sort_skills(
            _find_all_skills(
                skip_disabled=False, include_editorial=True   # ← kwarg inconnu
            )
        )
    except Exception:
        logger.exception("GET /v1/skills failed")
        return _error_response("Failed to enumerate skills", 500, err_type="server_error")
    return web.json_response({"object": "list", "data": skills})
```

Signature réelle de la fonction (`tools/skills_tool.py`) :

```
_find_all_skills(*, skip_disabled: bool = False) -> list[dict[str, Any]]
```

**`include_editorial` n'existe pas** → `TypeError` → attrapé par le `except`
générique → 500.

Reproduction directe :

```
>>> _find_all_skills(skip_disabled=False, include_editorial=True)
TypeError: _find_all_skills() got an unexpected keyword argument 'include_editorial'
```

---

## Origine : un revert incomplet

`include_editorial` était un paramètre lié à la feature **« Collective Wisdom V1 »**.

```
commit 0dcadf6f41
Author: Teknium
Date:   2026-09-11
    revert: remove Collective Wisdom V1 (#94266)

    Reverts the in-tree org skill-marketplace: hermes_wisdom package, three
    model tools, CLI/gateway/desktop/dashboard/Telegram/Slack surfaces.
    ...
    Wisdom-only call sites and config were stripped from those files.
```

Fichiers touchés par le revert :

```
tests/tools/test_skills_tool.py      |  114 -
tools/skills_tool.py                 |   58 +-
```

**`gateway/platforms/api_server.py` n'y figure pas.** Le message du commit
annonce pourtant que *« Wisdom-only call sites and config were stripped »* —
celui-là a été oublié.

`grep -rn "include_editorial"` sur l'arbre courant ne renvoie **qu'une seule
occurrence** : le call site orphelin.

---

## Impact

- `/v1/skills` est inutilisable par tout client de l'API server (MCP, scripts,
  audit de flotte, supervision).
- **L'information de `/v1/capabilities` est fausse** : elle déclare une route
  qui échoue — ce qui a induit en erreur un audit entier (voir
  `audit-flotte-v2-2026-10-21.md`, §5).
- Le `except Exception` générique **masque la vraie cause** : le log dit
  « Failed to enumerate skills », pas « TypeError ».

---

## Correctif proposé

Deux options, à trancher en amont :

**A. Retirer le kwarg orphelin** (minimal) :

```python
skills = _sort_skills(
    _find_all_skills(skip_disabled=False)
)
```

**B. Réintroduire `include_editorial`** si la sémantique « inclure les skills
éditoriaux » reste souhaitée — auquel cas c'est `tools/skills_tool.py` qui doit
l'accepter, pas seulement l'appelant.

L'option A est le correctif de cohérence avec l'état actuel du code.

---

## Comment le vérifier

```bash
# 1. Reproduire l'échec
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Bearer $(grep -m1 '^API_SERVER_KEY=' ~/.hermes/.env | cut -d= -f2-)" \
  http://127.0.0.1:8642/v1/skills
# attendu : 200 (actuellement 500)

# 2. Confirmer l'absence du kwarg
python -c "import sys,inspect; sys.path.insert(0,'.'); \
  from tools.skills_tool import _find_all_skills; \
  print(inspect.signature(_find_all_skills))"
# attendu : (*, skip_disabled: bool = False)
```

---

*Bug documenté par Hermes Core — 2026-10-21.*
*Découvert en vérifiant une affirmation d'audit : la règle n°6 (« un agent distant
qui répond n'est pas une preuve ») s'applique aussi aux routes d'API.*
