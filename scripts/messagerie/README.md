# scripts/messagerie — Messagerie interne twisterlab.local

Déploiement et vérification de la messagerie interne (hMailServer 5.7.1, sans relais Internet).

| Script | Rôle | À lancer sur |
|---|---|---|
| `gen-ad-secrets.ps1` | Génère les mots de passe (admin hMailServer + comptes AD `admin`/`test`) dans `C:\Users\administrator\.twisterlab-mail\credentials.txt` (ACL restreinte) | Core |
| `mkadusers.ps1` | Crée les utilisateurs AD `admin` et `test` (lit le payload `C:\temp\ad-payload.txt`, le supprime après) | DC-DELL |
| `config-hmail.ps1` | Configure hMailServer : certificat, domaine, ports, plages de sécurité, comptes AD | Core |
| `fix-cert.ps1` | Régénère le certificat TLS (openssl) et l'enregistre dans hMailServer | Core |
| `fix-priority.ps1` | Corrige la priorité de la plage `LAN-TwisterLab` (évaluation par priorité décroissante) | Core |
| `fw-and-log.ps1` | Pare-feu Windows (25/143/587 entrant, blocage sortant 25) + journalisation | Core |
| `dns-records.ps1` | Enregistrements DNS `A mail` + `MX @` | DC-DELL |
| `reach-from-dc.ps1` | Test de joignabilité cross-machine (bannières SMTP/IMAP) | DC-DELL |
| `test-mail.py` | Suite de tests de bout en bout (DNS, auth AD, SMTP, IMAP, anti-relais) | Core |

## Prérequis

- hMailServer 5.7.1 build 3116 installé silencieusement :
  ```powershell
  hMailServer-5.7.1-B3116-x64.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ADMINPASSWORD=<mot-de-passe> /useinternaldbms=true
  ```
- Être administrateur du domaine `twisterlab.local`.
- `openssl` (fourni par Git for Windows) pour le certificat TLS.

## Ordre d'exécution

```powershell
# 1. Secrets (Core) -> genere aussi le payload
.\gen-ad-secrets.ps1
scp .\mkadusers.ps1 dc-dell:C:/temp/mkadusers.ps1
scp C:/Users/administrator/.twisterlab-mail/ad-payload.txt dc-dell:C:/temp/ad-payload.txt
ssh dc-dell "powershell -File C:/temp/mkadusers.ps1"

# 2. Configuration hMailServer (Core)
.\config-hmail.ps1
.\fix-cert.ps1        # certificat TLS
.\fix-priority.ps1    # priorite de plage LAN

# 3. Pare-feu (Core)
.\fw-and-log.ps1

# 4. DNS (DC-DELL)
scp .\dns-records.ps1 dc-dell:C:/temp/dns-records.ps1
ssh dc-dell "powershell -File C:/temp/dns-records.ps1"

# 5. Tests
python .\test-mail.py
scp .\reach-from-dc.ps1 dc-dell:C:/temp/reach-from-dc.ps1
ssh dc-dell "powershell -File C:/temp/reach-from-dc.ps1"
```

## Précautions

- **Aucun secret dans ce dépôt.** Les scripts lisent les mots de passe depuis
  `C:\Users\administrator\.twisterlab-mail\credentials.txt`.
- Le rapport de déploiement et les résultats : `docs/messagerie/2026-10-24-messagerie-interne.md`.
- Les mots de passe AD de `alex`, `devuser`, `maya` et `Administrator` sont inconnus de
  l'orchestrateur : leurs boîtes sont créées et liées à l'AD, mais non testées en IMAP.
