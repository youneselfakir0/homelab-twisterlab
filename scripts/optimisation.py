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
