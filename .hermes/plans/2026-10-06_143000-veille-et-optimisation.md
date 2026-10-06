# Plan — Veille technologique & optimisation continue de l'infrastructure TwisterLab

## Goal

Mettre en place un système de veille technologique automatisé et un processus d'amélioration continue mesuré pour l'infrastructure TwisterLab (3 nœuds, 18 conteneurs, domaine AD).

## Current context / assumptions

- **Dépôt** : `C:\Users\administrator\homelab-twisterlab\` (GitHub: `youneselfakir0/homelab-twisterlab`)
- **Inventaire mesuré** : `docs/inventaire-mesure.json` (collecté le 2026-10-06)
- **Runbook** : `docs/runbook.md` (commandes de relevé reproductibles)
- **Scripts d'inventaire** : `scripts/inventory.ps1` (Windows), `scripts/inventory.sh` (Linux)
- **Orchestration** : Hermes pair-à-peer, api_server sur port 8642 sur les 3 machines
- **Services supervisés** : Prometheus 9090 + Grafana 3001 + Alertmanager 9093 (Edge)
- **Git self-hosté** : Forgejo sur Edge:3000
- **Contraintes** : DC-DELL 8 Go RAM (1 tâche à la fois), Edge disque 81 % (47 Go libres)
- **Pas de LLM local** (GTX 1050 2 Go insuffisant) — tout traitement lourd se fait sur Core (32 Go RAM, RTX 3060)

## Architecture / proposed approach

Deux axes complémentaires :

1. **Veille technologique** : un script Python (`scripts/veille.py`) qui interroge les flux RSS/Atom et APIs publiques des technologies du homelab (Docker, Prometheus, Grafana, Forgejo, n8n, RustDesk, Ubuntu, Windows Server) et produit un rapport Markdown hebdomadaire dans `docs/veille/`. Le script est exécuté manuellement ou via une tâche planifiée.

2. **Optimisation continue** : un script Python (`scripts/optimisation.py`) qui collecte les métriques d'infrastructure (RAM, disque, CPU, conteneurs, ports) via les scripts d'inventaire existants, les compare aux seuils définis dans `config/seuils.json`, et produit un rapport de recommandations priorisées dans `docs/optimisation/`. Le rapport est structuré en 3 catégories : critique (action immédiate), recommandé (prochaine fenêtre de maintenance), opportun (amélioration confort).

Les deux scripts partagent un module commun `scripts/mesures.py` qui encapsule l'exécution des scripts d'inventaire et le parsing de leur sortie.

## Step-by-step tasks

### Phase 1 — Module de mesures commun

#### T1.1 — Créer `scripts/mesures.py`

**Fichier** : `scripts/mesures.py`

```python
#!/usr/bin/env python3
"""Module commun de mesures pour les scripts d'inventaire TwisterLab."""
import subprocess
import json
import re
from pathlib import Path
from typing import Optional

REPO_ROOT = Path(__file__).resolve().parent.parent

def run_windows_inventory(host: str) -> dict:
    """Exécute inventory.ps1 sur un hôte Windows via WinRM/SSH et parse la sortie."""
    # Pour l'instant, lecture du dernier relevé local
    # TODO: exécuter à distance via hermes peer run
    out = REPO_ROOT / "docs" / "inventaire-mesure.json"
    if not out.exists():
        raise FileNotFoundError(f"{out} introuvable")
    data = json.loads(out.read_text(encoding="utf-8"))
    return data["machines"].get(host, {})

def run_linux_inventory(host: str) -> dict:
    """Exécute inventory.sh sur un hôte Linux et parse la sortie."""
    out = REPO_ROOT / "docs" / "inventaire-mesure.json"
    if not out.exists():
        raise FileNotFoundError(f"{out} introuvable")
    data = json.loads(out.read_text(encoding="utf-8"))
    return data["machines"].get(host, {})

def get_ram_libre_gb(host: str) -> Optional[float]:
    """Retourne la RAM libre en Go pour un hôte donné."""
    data = run_windows_inventory(host) if host in ("core", "dc-dell") else run_linux_inventory(host)
    if host == "core":
        return data.get("ram_libre_gb")
    elif host == "dc-dell":
        return data.get("ram_libre_gb")
    elif host == "edge":
        return data.get("ram_dispo_gb")
    return None

def get_disk_usage_pct(host: str) -> Optional[float]:
    """Retourne le pourcentage d'utilisation du disque principal."""
    data = run_windows_inventory(host) if host in ("core", "dc-dell") else run_linux_inventory(host)
    if host == "core":
        for d in data.get("disques", []):
            if d["lettre"] == "C:":
                total = d["total_gb"]
                libre = d["libre_gb"]
                return round((1 - libre / total) * 100, 1) if total > 0 else None
    elif host == "dc-dell":
        d = data.get("disque_c", {})
        total = d.get("total_gb", 0)
        libre = d.get("libre_gb", 0)
        return round((1 - libre / total) * 100, 1) if total > 0 else None
    elif host == "edge":
        return data.get("disque_racine", {}).get("usage_pct")
    return None

def get_running_containers() -> list:
    """Retourne la liste des conteneurs actifs sur Edge."""
    data = run_linux_inventory("edge")
    return data.get("conteneurs", [])

def get_listening_ports(host: str) -> list:
    """Retourne les ports en écoute pour un hôte."""
    data = run_windows_inventory(host) if host in ("core", "dc-dell") else run_linux_inventory(host)
    if host == "edge":
        return data.get("ports_0_0_0_0", [])
    return data.get("ports_ecoute", [])
```

**Vérification** :
```bash
cd /c/Users/administrator/homelab-twisterlab && python3 -c "from scripts.mesures import get_ram_libre_gb, get_disk_usage_pct; print('RAM libre Core:', get_ram_libre_gb('core')); print('Disque Edge:', get_disk_usage_pct('edge'), '%')"
```
**Sortie attendue** :
```
RAM libre Core: 19.2
Disque Edge: 81 %
```

#### T1.2 — Créer `tests/test_mesures.py`

**Fichier** : `tests/test_mesures.py`

```python
#!/usr/bin/env python3
"""Tests pour scripts/mesures.py"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.mesures import get_ram_libre_gb, get_disk_usage_pct, get_running_containers

def test_ram_libre_core():
    ram = get_ram_libre_gb("core")
    assert ram is not None, "RAM libre Core introuvable"
    assert ram > 0, f"RAM libre Core anormale: {ram}"

def test_disk_usage_edge():
    pct = get_disk_usage_pct("edge")
    assert pct is not None, "Usage disque Edge introuvable"
    assert 0 <= pct <= 100, f"Pourcentage disque anormal: {pct}"

def test_containers_list():
    containers = get_running_containers()
    assert isinstance(containers, list), "Les conteneurs doivent être une liste"
    assert len(containers) > 0, "Aucun conteneur actif détecté"
```

**Vérification** :
```bash
cd /c/Users/administrator/homelab-twisterlab && python3 -m pytest tests/test_mesures.py -v
```
**Sortie attendue** :
```
tests/test_mesures.py::test_ram_libre_core PASSED
tests/test_mesures.py::test_disk_usage_edge PASSED
tests/test_mesures.py::test_containers_list PASSED
```

---

### Phase 2 — Veille technologique

#### T2.1 — Créer `config/veille_sources.json`

**Fichier** : `config/veille_sources.json`

```json
{
  "sources": [
    {
      "nom": "Docker",
      "type": "rss",
      "url": "https://blog.docker.com/feed/",
      "technos": ["docker", "containerd"]
    },
    {
      "nom": "Prometheus",
      "type": "rss",
      "url": "https://prometheus.io/blog/index.xml",
      "technos": ["prometheus"]
    },
    {
      "nom": "Grafana",
      "type": "rss",
      "url": "https://grafana.com/blog/index.xml",
      "technos": ["grafana"]
    },
    {
      "nom": "Forgejo",
      "type": "github_releases",
      "repo": "go-gitea/gitea",
      "technos": ["forgejo", "gitea"]
    },
    {
      "nom": "n8n",
      "type": "github_releases",
      "repo": "n8n-io/n8n",
      "technos": ["n8n"]
    },
    {
      "nom": "RustDesk",
      "type": "github_releases",
      "repo": "rustdesk/rustdesk",
      "technos": ["rustdesk"]
    },
    {
      "nom": "Ubuntu",
      "type": "rss",
      "url": "https://ubuntu.com/blog/feed",
      "technos": ["ubuntu"]
    },
    {
      "nom": "Windows Server",
      "type": "rss",
      "url": "https://techcommunity.microsoft.com/t5/windows-server-blog/bg-p/WindowsServerBlog",
      "technos": ["windows-server", "active-directory"]
    }
  ],
  "filtres": {
    "mots_cles": ["security", "vulnerability", "CVE", "release", "update", "critical"],
    "ignorer": ["deprecated", "end-of-life"]
  }
}
```

#### T2.2 — Créer `scripts/veille.py`

**Fichier** : `scripts/veille.py`

```python
#!/usr/bin/env python3
"""Script de veille technologique pour TwisterLab.

Interroge les flux RSS et APIs GitHub définis dans config/veille_sources.json
et produit un rapport Markdown dans docs/veille/.
"""
import json
import re
import sys
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime, timedelta
from email.utils import parsedate_to_datetime
from typing import Optional

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPO_ROOT / "config" / "veille_sources.json"
OUTPUT_DIR = REPO_ROOT / "docs" / "veille"

def fetch_rss(url: str, timeout: int = 15) -> Optional[str]:
    """Récupère le contenu d'un flux RSS/Atom."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "TwisterLab-Veille/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, OSError) as e:
        print(f"  [WARN] {url}: {e}", file=sys.stderr)
        return None

def fetch_github_releases(repo: str, timeout: int = 15) -> Optional[list]:
    """Récupère les 5 dernières releases GitHub d'un dépôt."""
    url = f"https://api.github.com/repos/{repo}/releases?per_page=5"
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "TwisterLab-Veille/1.0",
            "Accept": "application/vnd.github.v3+json"
        })
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return [{"nom": r["name"], "date": r["published_at"], "url": r["html_url"],
                     "corps": r.get("body", "")[:500]} for r in data]
    except (urllib.error.URLError, OSError, json.JSONDecodeError) as e:
        print(f"  [WARN] GitHub {repo}: {e}", file=sys.stderr)
        return None

def parse_rss_items(xml_content: str, max_items: int = 10) -> list:
    """Parse les items d'un flux RSS/Atom et retourne les titres + liens."""
    items = []
    # Regex simple pour extraire <item> ou <entry>
    entries = re.findall(r'<(?:item|entry)>(.*?)</(?:item|entry)>', xml_content, re.DOTALL)
    for entry in entries[:max_items]:
        title_m = re.search(r'<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>', entry, re.DOTALL)
        link_m = re.search(r'<link[^>]*>(?:<!\[CDATA\[)?(https?://[^\s<"]+?)(?:\]\]>)?</link>', entry, re.DOTALL)
        date_m = re.search(r'<(?:pubDate|published|updated)>(.*?)</(?:pubDate|published|updated)>', entry, re.DOTALL)
        if title_m and link_m:
            items.append({
                "titre": title_m.group(1).strip(),
                "lien": link_m.group(1).strip(),
                "date": date_m.group(1).strip() if date_m else "inconnue"
            })
    return items

def filtrer_pertinent(items: list, mots_cles: list, ignorer: list) -> list:
    """Filtre les items par mots-clés pertinents."""
    pertinent = []
    for item in items:
        texte = item["titre"].lower()
        if any(m.lower() in texte for m in mots_cles):
            if not any(i.lower() in texte for i in ignorer):
                pertinent.append(item)
    return pertinent

def generer_rapport(resultats: list, date_str: str) -> str:
    """Génère le rapport Markdown de veille."""
    lignes = [
        f"# Veille technologique — {date_str}",
        "",
        f"Généré le {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        "",
        "---",
        ""
    ]
    for source in resultats:
        lignes.append(f"## {source['nom']}")
        lignes.append("")
        if source["type"] == "rss":
            if source["items"]:
                for item in source["items"][:5]:
                    lignes.append(f"- [{item['titre']}]({item['lien']}) — {item['date']}")
            else:
                lignes.append("_Aucun article pertinent détecté._")
        elif source["type"] == "github_releases":
            if source["releases"]:
                for rel in source["releases"][:3]:
                    lignes.append(f"- **{rel['nom']}** ({rel['date'][:10]}) — [lien]({rel['url']})")
            else:
                lignes.append("_Aucune release récente._")
        lignes.append("")
    return "\n".join(lignes)

def main():
    if not CONFIG_PATH.exists():
        print(f"ERREUR: {CONFIG_PATH} introuvable", file=sys.stderr)
        sys.exit(1)

    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    date_str = datetime.now().strftime("%Y-%m-%d")
    resultats = []

    for source in config["sources"]:
        print(f"  Vérification: {source['nom']}...")
        if source["type"] == "rss":
            xml = fetch_rss(source["url"])
            items = parse_rss_items(xml) if xml else []
            items_pertinents = filtrer_pertinent(
                items, config["filtres"]["mots_cles"], config["filtres"]["ignorer"]
            )
            resultats.append({"nom": source["nom"], "type": "rss", "items": items_pertinents})
        elif source["type"] == "github_releases":
            releases = fetch_github_releases(source["repo"])
            resultats.append({"nom": source["nom"], "type": "github_releases", "releases": releases or []})

    rapport = generer_rapport(resultats, date_str)
    out_path = OUTPUT_DIR / f"veille-{date_str}.md"
    out_path.write_text(rapport, encoding="utf-8")
    print(f"\nRapport écrit: {out_path}")
    print(f"Sources vérifiées: {len(resultats)}")

if __name__ == "__main__":
    main()
```

**Vérification** :
```bash
cd /c/Users/administrator/homelab-twisterlab && python3 scripts/veille.py
```
**Sortie attendue** :
```
  Vérification: Docker...
  Vérification: Prometheus...
  Vérification: Grafana...
  Vérification: Forgejo...
  Vérification: n8n...
  Vérification: RustDesk...
  Vérification: Ubuntu...
  Vérification: Windows Server...

Rapport écrit: docs/veille/veille-2026-10-06.md
Sources vérifiées: 8
```

#### T2.3 — Créer `tests/test_veille.py`

**Fichier** : `tests/test_veille.py`

```python
#!/usr/bin/env python3
"""Tests pour scripts/veille.py"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.veille import parse_rss_items, filtrer_pertinent

def test_parse_rss_items():
    xml = """<?xml version="1.0"?>
    <rss><channel>
      <item><title>Docker 27.0 released</title><link>https://example.com/1</link><pubDate>Mon, 01 Jan 2026</pubDate></item>
      <item><title>Random post</title><link>https://example.com/2</link><pubDate>Tue, 02 Jan 2026</pubDate></item>
    </channel></rss>"""
    items = parse_rss_items(xml)
    assert len(items) == 2, f"Attendu 2 items, reçu {len(items)}"
    assert "Docker" in items[0]["titre"]

def test_filtrer_pertinent():
    items = [
        {"titre": "Critical security update", "lien": "http://a", "date": "x"},
        {"titre": "New feature release", "lien": "http://b", "date": "x"},
        {"titre": "Deprecated old API", "lien": "http://c", "date": "x"},
    ]
    result = filtrer_pertinent(items, ["security", "release"], ["deprecated"])
    assert len(result) == 2, f"Attendu 2 items pertinents, reçu {len(result)}"
    assert all("deprecated" not in r["titre"].lower() for r in result)
```

**Vérification** :
```bash
cd /c/Users/administrator/homelab-twisterlab && python3 -m pytest tests/test_veille.py -v
```
**Sortie attendue** :
```
tests/test_veille.py::test_parse_rss_items PASSED
tests/test_veille.py::test_filtrer_pertinent PASSED
```

---

### Phase 3 — Optimisation continue

#### T3.1 — Créer `config/seuils.json`

**Fichier** : `config/seuils.json`

```json
{
  "seuils": {
    "ram_libre_critique_gb": 2.0,
    "ram_libre_alerte_gb": 4.0,
    "disque_critique_pct": 90,
    "disque_alerte_pct": 80,
    "cpu_alerte_pct": 80,
    "conteneur_inactif_alerte_jours": 7
  },
  "priorites": {
    "critique": "Action immédiate — risque de défaillance",
    "recommande": "Prochaine fenêtre de maintenance",
    "opportun": "Amélioration de confort"
  }
}
```

#### T3.2 — Créer `scripts/optimisation.py`

**Fichier** : `scripts/optimisation.py`

```python
#!/usr/bin/env python3
"""Script d'optimisation continue pour TwisterLab.

Collecte les métriques d'infrastructure, les compare aux seuils définis
dans config/seuils.json, et produit un rapport de recommandations.
"""
import json
import sys
from pathlib import Path
from datetime import datetime

REPO_ROOT = Path(__file__).resolve().parent.parent
SEUILS_PATH = REPO_ROOT / "config" / "seuils.json"
OUTPUT_DIR = REPO_ROOT / "docs" / "optimisation"

sys.path.insert(0, str(REPO_ROOT))
from scripts.mesures import get_ram_libre_gb, get_disk_usage_pct, get_running_containers

def evaluer_ram(host: str, seuils: dict) -> list:
    """Évalue la RAM d'un hôte et retourne les recommandations."""
    recommandations = []
    ram = get_ram_libre_gb(host)
    if ram is None:
        return [{"niveau": "inconnu", "message": f"RAM {host} non mesurable"}]
    if ram < seuils["ram_libre_critique_gb"]:
        recommandations.append({
            "niveau": "critique",
            "hote": host,
            "metrique": "ram_libre",
            "valeur": f"{ram} Go",
            "seuil": f"< {seuils['ram_libre_critique_gb']} Go",
            "action": "Identifier le processus consommateur et le terminer, ou ajouter de la RAM"
        })
    elif ram < seuils["ram_libre_alerte_gb"]:
        recommandations.append({
            "niveau": "recommande",
            "hote": host,
            "metrique": "ram_libre",
            "valeur": f"{ram} Go",
            "seuil": f"< {seuils['ram_libre_alerte_gb']} Go",
            "action": "Surveiller la tendance, prévoir un nettoyage des processus"
        })
    return recommandations

def evaluer_disque(host: str, seuils: dict) -> list:
    """Évalue l'utilisation du disque d'un hôte."""
    recommandations = []
    pct = get_disk_usage_pct(host)
    if pct is None:
        return [{"niveau": "inconnu", "message": f"Disque {host} non mesurable"}]
    if pct >= seuils["disque_critique_pct"]:
        recommandations.append({
            "niveau": "critique",
            "hote": host,
            "metrique": "disque_usage_pct",
            "valeur": f"{pct} %",
            "seuil": f">= {seuils['disque_critique_pct']} %",
            "action": "Nettoyer les logs, images Docker inutilisées, anciens builds"
        })
    elif pct >= seuils["disque_alerte_pct"]:
        recommandations.append({
            "niveau": "recommande",
            "hote": host,
            "metrique": "disque_usage_pct",
            "valeur": f"{pct} %",
            "seuil": f">= {seuils['disque_alerte_pct']} %",
            "action": "Planifier un nettoyage, vérifier la rotation des logs"
        })
    return recommandations

def evaluer_conteneurs(seuils: dict) -> list:
    """Évalue l'état des conteneurs Docker sur Edge."""
    recommandations = []
    containers = get_running_containers()
    if not containers:
        return [{"niveau": "inconnu", "message": "Aucun conteneur détecté"}]
    # Vérifier les conteneurs exposés sur 0.0.0.0 (risque sécurité)
    # Cette info vient de inventaire-mesure.json
    data = json.loads((REPO_ROOT / "docs" / "inventaire-mesure.json").read_text(encoding="utf-8"))
    ports_exposes = data["machines"]["edge"].get("ports_0_0_0_0", [])
    ports_sensibles = [p for p in ports_exposes if p in [22, 3000, 5000, 5678, 8055, 8888]]
    if ports_sensibles:
        recommandations.append({
            "niveau": "recommande",
            "hote": "edge",
            "metrique": "ports_0_0_0_0",
            "valeur": str(ports_sensibles),
            "seuil": "ports sensibles exposés sur 0.0.0.0",
            "action": "Restreindre l'exposition des services sensibles à l'overlay Tailscale ou au LAN uniquement"
        })
    return recommandations

def generer_rapport(recommandations: list, date_str: str) -> str:
    """Génère le rapport Markdown d'optimisation."""
    lignes = [
        f"# Rapport d'optimisation — {date_str}",
        "",
        f"Généré le {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        "",
        "---",
        ""
    ]
    for niveau in ["critique", "recommande", "opportun", "inconnu"]:
        recs = [r for r in recommandations if r["niveau"] == niveau]
        if recs:
            lignes.append(f"## {niveau.upper()} ({len(recs)})")
            lignes.append("")
            for r in recs:
                lignes.append(f"### {r.get('hote', 'N/A')} — {r['metrique']}")
                lignes.append(f"- **Valeur** : {r['valeur']}")
                lignes.append(f"- **Seuil** : {r['seuil']}")
                lignes.append(f"- **Action** : {r['action']}")
                lignes.append("")
    return "\n".join(lignes)

def main():
    if not SEUILS_PATH.exists():
        print(f"ERREUR: {SEUILS_PATH} introuvable", file=sys.stderr)
        sys.exit(1)

    seuils = json.loads(SEUILS_PATH.read_text(encoding="utf-8"))["seuils"]
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    date_str = datetime.now().strftime("%Y-%m-%d")
    recommandations = []

    print("  Évaluation de la RAM...")
    for host in ["core", "edge", "dc-dell"]:
        recommandations.extend(evaluer_ram(host, seuils))

    print("  Évaluation des disques...")
    for host in ["core", "edge", "dc-dell"]:
        recommandations.extend(evaluer_disque(host, seuils))

    print("  Évaluation des conteneurs...")
    recommandations.extend(evaluer_conteneurs(seuils))

    rapport = generer_rapport(recommandations, date_str)
    out_path = OUTPUT_DIR / f"optimisation-{date_str}.md"
    out_path.write_text(rapport, encoding="utf-8")
    print(f"\nRapport écrit: {out_path}")
    print(f"Recommandations: {len(recommandations)}")

if __name__ == "__main__":
    main()
```

**Vérification** :
```bash
cd /c/Users/administrator/homelab-twisterlab && python3 scripts/optimisation.py
```
**Sortie attendue** :
```
  Évaluation de la RAM...
  Évaluation des disques...
  Évaluation des conteneurs...

Rapport écrit: docs/optimisation/optimisation-2026-10-06.md
Recommandations: 3
```

#### T3.3 — Créer `tests/test_optimisation.py`

**Fichier** : `tests/test_optimisation.py`

```python
#!/usr/bin/env python3
"""Tests pour scripts/optimisation.py"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts.optimisation import evaluer_ram, evaluer_disque

def test_ram_critique():
    seuils = {"ram_libre_critique_gb": 2.0, "ram_libre_alerte_gb": 4.0}
    recs = evaluer_ram("core", seuils)
    # Core a ~19 Go libres, donc aucune alerte critique
    assert all(r["niveau"] != "critique" for r in recs), "Core ne devrait pas être en critique RAM"

def test_disque_edge_alerte():
    seuils = {"disque_critique_pct": 90, "disque_alerte_pct": 80}
    recs = evaluer_disque("edge", seuils)
    # Edge est à 81%, donc alerte (pas critique)
    assert any(r["niveau"] == "recommande" for r in recs), "Edge devrait être en alerte disque"
```

**Vérification** :
```bash
cd /c/Users/administrator/homelab-twisterlab && python3 -m pytest tests/test_optimisation.py -v
```
**Sortie attendue** :
```
tests/test_optimisation.py::test_ram_critique PASSED
tests/test_optimisation.py::test_disque_edge_alerte PASSED
```

---

### Phase 4 — Automatisation et intégration

#### T4.1 — Créer `scripts/planifier.ps1` (tâche planifiée Windows)

**Fichier** : `scripts/planifier.ps1`

```powershell
# Tâche planifiée : exécute la veille et l'optimisation chaque lundi à 08:00
# Installation : schtasks /Create /TN "TwisterLab-Veille" /TR "powershell -File C:\Users\administrator\homelab-twisterlab\scripts\planifier.ps1" /SC WEEKLY /D MON /ST 08:00

$ErrorActionPreference = "Stop"
$root = "C:\Users\administrator\homelab-twisterlab"
Set-Location $root

Write-Output "=== TwisterLab — Veille & Optimisation ==="
Write-Output "Date: $(Get-Date)"

Write-Output "`n--- Veille technologique ---"
python3 scripts/veille.py

Write-Output "`n--- Optimisation ---"
python3 scripts/optimisation.py

Write-Output "`n--- Tests ---"
python3 -m pytest tests/ -v --tb=short

Write-Output "`n=== Terminé ==="
```

**Vérification** :
```bash
cd /c/Users/administrator/homelab-twisterlab && powershell -ExecutionPolicy Bypass -File scripts/planifier.ps1
```
**Sortie attendue** :
```
=== TwisterLab — Veille & Optimisation ===
Date: 06/10/2026 14:30:00

--- Veille technologique ---
  Vérification: Docker...
  ...
Rapport écrit: docs/veille/veille-2026-10-06.md

--- Optimisation ---
  Évaluation de la RAM...
  ...
Rapport écrit: docs/optimisation/optimisation-2026-10-06.md

--- Tests ---
tests/test_mesures.py::test_ram_libre_core PASSED
...
=== Terminé ===
```

#### T4.2 — Mettre à jour `docs/runbook.md` avec les nouvelles commandes

**Fichier** : `docs/runbook.md` (ajout à la fin)

```markdown

---

## Veille technologique et optimisation

### Exécuter la veille

```bash
cd /c/Users/administrator/homelab-twisterlab
python3 scripts/veille.py
```

Produit `docs/veille/veille-YYYY-MM-DD.md`.

### Exécuter l'optimisation

```bash
cd /c/Users/administrator/homelab-twisterlab
python3 scripts/optimisation.py
```

Produit `docs/optimisation/optimisation-YYYY-MM-DD.md`.

### Automatisation hebdomadaire

```powershell
# Installer la tâche planifiée (lundi 08:00)
schtasks /Create /TN "TwisterLab-Veille" /TR "powershell -File C:\Users\administrator\homelab-twisterlab\scripts\planifier.ps1" /SC WEEKLY /D MON /ST 08:00

# Vérifier
schtasks /Query /TN "TwisterLab-Veille"

# Supprimer
schtasks /Delete /TN "TwisterLab-Veille" /F
```

### Sources de veille configurables

Éditer `config/veille_sources.json` pour ajouter/retirer des sources.

### Seuils d'optimisation configurables

Éditer `config/seuils.json` pour ajuster les seuils d'alerte.
```

#### T4.3 — Mettre à jour `README.md` avec la section veille/optimisation

**Fichier** : `README.md` (ajout après la section "Documentation")

```markdown

---

## Veille & optimisation

| Script | Usage | Production |
|---|---|---|
| `scripts/veille.py` | Veille technologique (RSS + GitHub releases) | `docs/veille/veille-YYYY-MM-DD.md` |
| `scripts/optimisation.py` | Rapport d'optimisation continu | `docs/optimisation/optimisation-YYYY-MM-DD.md` |
| `scripts/planifier.ps1` | Exécution hebdomadaire automatisée | Tâche planifiée Windows |

Configuration :
- `config/veille_sources.json` — sources de veille
- `config/seuils.json` — seuils d'alerte

Automatisation :
```powershell
schtasks /Create /TN "TwisterLab-Veille" /TR "powershell -File C:\Users\administrator\homelab-twisterlab\scripts\planifier.ps1" /SC WEEKLY /D MON /ST 08:00
```
```

---

### Phase 5 — Validation finale

#### T5.1 — Exécuter tous les tests

```bash
cd /c/Users/administrator/homelab-twisterlab && python3 -m pytest tests/ -v
```
**Sortie attendue** :
```
tests/test_mesures.py::test_ram_libre_core PASSED
tests/test_mesures.py::test_disk_usage_edge PASSED
tests/test_mesures.py::test_containers_list PASSED
tests/test_veille.py::test_parse_rss_items PASSED
tests/test_veille.py::test_filtrer_pertinent PASSED
tests/test_optimisation.py::test_ram_critique PASSED
tests/test_optimisation.py::test_disque_edge_alerte PASSED

7 passed in 0.15s
```

#### T5.2 — Vérifier les rapports générés

```bash
cd /c/Users/administrator/homelab-twisterlab && ls -la docs/veille/ docs/optimisation/
```
**Sortie attendue** :
```
docs/optimisation/:
optimisation-2026-10-06.md

docs/veille/:
veille-2026-10-06.md
```

#### T5.3 — Commit et push

```bash
cd /c/Users/administrator/homelab-twisterlab && git add -A && git commit -m "feat: veille technologique et optimisation continue" && git push origin main
```
**Sortie attendue** :
```
[main abc1234] feat: veille technologique et optimisation continue
 12 files changed, 450 insertions(+)
 create mode 100644 config/seuils.json
 create mode 100644 config/veille_sources.json
 create mode 100644 scripts/mesures.py
 create mode 100644 scripts/veille.py
 create mode 100644 scripts/optimisation.py
 create mode 100644 scripts/planifier.ps1
 create mode 100644 tests/test_mesures.py
 create mode 100644 tests/test_veille.py
 create mode 100644 tests/test_optimisation.py
 create mode 100644 docs/veille/veille-2026-10-06.md
 create mode 100644 docs/optimisation/optimisation-2026-10-06.md
```

---

## Tests / validation

Chaque tâche suit le cycle TDD :
1. **RED** : écrire le test, vérifier qu'il échoue
2. **GREEN** : implémenter le minimum, vérifier que le test passe
3. **COMMIT** : valider le commit

Commande de validation globale :
```bash
cd /c/Users/administrator/homelab-twisterlab && python3 -m pytest tests/ -v
```

---

## Risks, tradeoffs, and open questions

### Risques

| Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|
| Flux RSS indisponibles (rate-limit, 403) | Moyen | Faible | Le script continue sur les autres sources, log un warning |
| API GitHub rate-limit (60 req/h sans token) | Moyen | Faible | Utiliser les releases uniquement (peu de requêtes), ou ajouter un token |
| `inventaire-mesure.json` périmé | Élevé | Moyen | Le script d'optimisation lit le dernier relevé ; prévoir une tâche de collecte automatique |
| Tâche planifiée ne s'exécute pas (éteint à 08h) | Moyen | Faible | Vérifier manuellement, ou utiliser un trigger "au démarrage" |

### Tradeoffs

- **Simplicité vs exhaustivité** : le script de veille utilise des regex RSS simples plutôt qu'une librairie type `feedparser`. Choix délibéré : zéro dépendance externe, mais parsing moins robuste pour les flux complexes.
- **Mesure statique vs dynamique** : l'optimisation lit `inventaire-mesure.json` (relevé du 2026-10-06) plutôt que de mesurer en temps réel. Choix délibéré : pas d'exécution à distance automatique (risque sur DC-DELL), mais nécessite de relancer `inventory.ps1`/`inventory.sh` périodiquement.
- **Automatisation Windows vs Linux** : la tâche planifiée est en PowerShell (Windows). Choix délibéré : Core est l'orchestrateur et tourne 24/7, contrairement à Edge qui peut être redémarré.

### Questions ouvertes

1. **Faut-il un token GitHub** pour éviter le rate-limit de l'API ? (Recommandé : oui, `gh auth token` et variable d'environnement `GITHUB_TOKEN`)
2. **Faut-il exécuter les inventaires à distance** via `hermes peer run` pour avoir des métriques en temps réel ? (Recommandé : oui, mais uniquement sur Edge — pas sur DC-DELL)
3. **Faut-il intégrer les rapports de veille/optimisation dans le site vitrine GitHub Pages** ? (Recommandé : non, garder le site statique, les rapports restent dans le dépôt)
4. **Faut-il ajouter des métriques Prometheus** pour le suivi temporel (tendance RAM/disque) ? (Recommandé : oui, mais dans un second temps — nécessite un exporteur custom ou un job Prometheus)

---

## Résumé des fichiers créés

| Fichier | Rôle |
|---|---|
| `scripts/mesures.py` | Module commun de mesures (RAM, disque, conteneurs, ports) |
| `scripts/veille.py` | Script de veille technologique (RSS + GitHub releases) |
| `scripts/optimisation.py` | Script d'optimisation continue (seuils + recommandations) |
| `scripts/planifier.ps1` | Tâche planifiée Windows (exécution hebdomadaire) |
| `config/veille_sources.json` | Configuration des sources de veille |
| `config/seuils.json` | Configuration des seuils d'alerte |
| `tests/test_mesures.py` | Tests du module de mesures |
| `tests/test_veille.py` | Tests du script de veille |
| `tests/test_optimisation.py` | Tests du script d'optimisation |
| `docs/veille/veille-YYYY-MM-DD.md` | Rapport de veille (généré) |
| `docs/optimisation/optimisation-YYYY-MM-DD.md` | Rapport d'optimisation (généré) |
