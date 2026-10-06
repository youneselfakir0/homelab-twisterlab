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
