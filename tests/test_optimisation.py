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
