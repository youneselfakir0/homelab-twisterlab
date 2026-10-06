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
