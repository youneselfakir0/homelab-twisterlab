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
