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
