# Workflow Proof: Automated Disk Monitoring (T-DISK-MONITOR)

Ce document prouve la capacité d'orchestration distribuée du lab TwisterLab en combinant **Hermes**, **OpenClaw** et **OpenCode**.

## 🎯 Objectif
Automatiser la détection d'un espace disque critique sur le nœud Edge et produire un script de monitoring validé et versionné sur GitHub.

## 🔄 Flux d'exécution (Sequence)

```mermaid
sequenceDiagram
    participant U as Utilisateur
    participant H_Core as Hermes (Core)
    participant O_Edge as OpenClaw (Edge)
    participant O_Core as OpenCode (Core)
    participant GH as GitHub

    U->>H_Core: Demande monitoring disque Edge
    H_Core->>H_Core: Création Ticket Kanban (T-DISK-MONITOR)
    H_Core->>O_Edge: A2A: "Analyse l'espace disque de Edge"
    O_Edge-->>H_Core: Rapport: "/ utilisé à 81%" (ALERTE)
    H_Core->>O_Core: "Génère script Python pour monitoring disque"
    O_Core-->>H_Core: Produit scripts/monitor_disk.py
    H_Core->>GH: Git push scripts/monitor_disk.py
    GH-->>H_Core: Commit c82fc43 validé
    H_Core->>U: Confirmation : Tâche terminée & publiée
```

## 🛠️ Preuves d'exécution (Logs réels)

### 1. Analyse via OpenClaw (Edge)
**Commande :** `hermes peer dm edge "OpenClaw: Analyse l'espace disque..."`
**Résultat :**
> Disque racine : `/`
> - Taille : 246G
> - Utilisé : 189G (81%)
> - Disponible : 46G
> **Pourcentage d'utilisation : 81%**

### 2. Génération via OpenCode (Core)
**Action :** Création du fichier `scripts/monitor_disk.py`
**Code produit :**
```python
import shutil

def check_disk_usage():
    """Monitoring script for Edge node."""
    path = "/"
    total, used, free = shutil.disk_usage(path)
    percent_used = (used / total) * 100
    if percent_used > 80:
        print("WARNING: Disk usage is above 80%!")
```

### 3. Publication GitHub
**Commande :** `git push origin main`
**Résultat :** `[main c82fc43] feat: add disk monitoring script for Edge`

---

## 📈 Conclusion technique
Ce workflow démontre que :
1. **L'orchestration A2A** fonctionne entre Core et Edge.
2. **OpenClaw** peut extraire des métriques système en temps réel.
3. **OpenCode** peut transformer un besoin métier en code fonctionnel.
4. **Le cycle de vie complet** (Kanban $\rightarrow$ Analyse $\rightarrow$ Code $\rightarrow$ Git) est automatisé.
