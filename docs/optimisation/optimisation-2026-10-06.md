# Rapport d'optimisation — 2026-10-06

Généré le 2026-10-06 12:17

---

## CRITIQUE (1)

### dc-dell — ram_libre
- **Valeur** : 1.8 Go
- **Seuil** : < 2.0 Go
- **Action** : Identifier le processus consommateur et le terminer, ou ajouter de la RAM

## RECOMMANDE (4)

### core — ram_libre
- **Valeur** : 3.8 Go
- **Seuil** : < 4.0 Go
- **Action** : Surveiller la tendance, prévoir un nettoyage des processus

### core — disque_usage_pct
- **Valeur** : 82.6 %
- **Seuil** : >= 80 %
- **Action** : Planifier un nettoyage, vérifier la rotation des logs

### edge — disque_usage_pct
- **Valeur** : 81 %
- **Seuil** : >= 80 %
- **Action** : Planifier un nettoyage, vérifier la rotation des logs

### edge — ports_0_0_0_0
- **Valeur** : [22, 3000, 5000, 5678, 8055, 8888]
- **Seuil** : ports sensibles exposés sur 0.0.0.0
- **Action** : Restreindre l'exposition des services sensibles à l'overlay Tailscale ou au LAN uniquement
