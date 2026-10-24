# Messagerie interne — Rapport de déploiement

**Date :** 2026-10-24
**Statut :** ✅ Déployé et vérifié (15/15 tests)
**Porteur :** Hermes (Core), orchestration
**Objet :** Messagerie interne du domaine `twisterlab.local`, sans aucun relais ni flux Internet.

---

## 1. Synthèse

| Élément | Valeur |
|---|---|
| **Nom du serveur mail** | `CORE` (hôte), service `mail.twisterlab.local` |
| **Adresse IP (LAN)** | `192.168.0.12` |
| **Adresse IP (Tailscale)** | `100.92.101.28` |
| **Nom de domaine de messagerie** | `twisterlab.local` |
| **Logiciel** | hMailServer **5.7.1 build 3116** (officiel, x64) |
| **Emplacement** | `C:\Program Files\hMailServer` |
| **Service Windows** | `hMailServer` — Running, démarrage automatique, compte `NT SERVICE\hMailServer` |
| **Base de données** | Base interne hMailServer (fichiers sous `C:\ProgramData\hMailServer`) |
| **Type de serveur** | Serveur **membre** du domaine `twisterlab.local` |

### Choix d'emplacement (décision)

Le serveur mail a été installé sur **Core** (membre du domaine), et **non** sur DC-DELL.

| Option | Retenu ? | Raison |
|---|---|---|
| **Core** (Windows 11 Pro, 32 Go RAM) | ✅ **Retenue** | Membre du domaine, ressources largement disponibles, administrable directement. Sépare le rôle « serveur de mail » du contrôleur de domaine. |
| DC-DELL (Windows Server 2025, 8 Go RAM, ~1,8 Go libres) | ❌ Écartée | Contrôleur de domaine + DNS + DHCP ; règle de charge « 1 tâche à la fois » ; un redémarrage AD couperait la messagerie. |
| Edge (Ubuntu) | ❌ Écartée | hMailServer 5.7 est **Windows uniquement** (x64). |

> **Migration possible** : le service est autonome (comptes dans sa base interne). Pour déplacer le serveur sur une autre machine Windows : installer hMailServer, restaurer `C:\ProgramData\hMailServer`, puis rejouer `scripts/messagerie/config-hmail.ps1`.

---

## 2. Comptes créés

Tous les comptes sont **liés à Active Directory** (`IsAD = True`) : aucun mot de passe n'est stocké dans la base hMailServer, l'authentification est déléguée à `LogonUser()` côté AD.

| Adresse | Compte AD lié | État AD | Créé | Mot de passe stocké dans hMailServer |
|---|---|---|---|---|
| `administrator@twisterlab.local` | `Administrator` | Actif | ✅ | Non (auth AD) |
| `alex@twisterlab.local` | `alex` | Actif | ✅ | Non (auth AD) |
| `devuser@twisterlab.local` | `devuser` | Actif | ✅ | Non (auth AD) |
| `maya@twisterlab.local` | `maya` | Actif | ✅ | Non (auth AD) |
| `admin@twisterlab.local` | `admin` *(créé)* | Actif | ✅ | Non (auth AD) |
| `test@twisterlab.local` | `test` *(créé)* | Actif | ✅ | Non (auth AD) |

**Quota :** 1 000 Mo par boîte.

### Note sur `admin@` et `test@`
Ces deux comptes n'existaient pas dans l'AD. Ils ont été créés comme utilisateurs AD (`admin`, `test`) afin de satisfaire à la fois « créer et tester deux comptes » et « authentification avec comptes AD ». Ils sont documentés ici et réversibles (`Remove-ADUser`).

**Comptes AD non provisionnés** : `Guest` et `krbtgt` (désactivés) — aucun utilisateur AD **actif** n'a été oublié.

### Localisation des secrets
Les mots de passe (admin hMailServer + comptes AD créés) sont dans :
```
C:\Users\administrator\.twisterlab-mail\credentials.txt
```
Fichier en ACL restreinte (utilisateur + Administrators + SYSTEM). **Aucun secret dans le dépôt git ni dans ce rapport.**

---

## 3. Ports et protocoles

| Port | Protocole | Rôle | Sécurité | État |
|---|---|---|---|---|
| **TCP 25** | SMTP | Réception/livraison interne | clair | ✅ **Ouvert** |
| **TCP 587** | SMTP Submission | Dépôt par les clients | STARTTLS optionnel + AUTH | ✅ **Ouvert** |
| **TCP 143** | IMAP | Consultation des boîtes | clair | ✅ **Ouvert** |
| ~~TCP 110~~ | ~~POP3~~ | — | — | ❌ **Désactivé** (non demandé) |

**Certificat TLS** : auto-signé `CN=mail.twisterlab.local`, SAN `mail.twisterlab.local`, `twisterlab.local`, `localhost`, validité 10 ans.
Fichiers : `C:\ProgramData\hMailServer\Certificates\mail.twisterlab.local.{crt,key}` (ACL : `NT SERVICE\hMailServer` en lecture).

### Pare-feu Windows (hôte Core, profil **Domain**)

| Règle | Direction | Action | Port |
|---|---|---|---|
| `hMailServer - entree TCP 25 (SMTP)` | Inbound | Allow | 25 |
| `hMailServer - entree TCP 143 (IMAP)` | Inbound | Allow | 143 |
| `hMailServer - entree TCP 587 (SMTP Submission)` | Inbound | Allow | 587 |
| `hMailServer - BLOQUER relais SMTP sortant` | **Outbound** | **Block** | 25 (programme `hMailServer.exe`) |

> Les deux interfaces de Core (Ethernet et Tailscale) sont en catégorie `DomainAuthenticated` : les règles s'appliquent donc aussi au accès Tailscale.

### Désactiver/réactiver POP3
```powershell
# Réactiver POP3 110
$p = $app.Settings.TCPIPPorts.Add(); $p.Protocol = 3; $p.PortNumber = 110; $p.Address = '0.0.0.0'; $p.Save()
```

---

## 4. Intégration Active Directory

- **Mode d'authentification** : par compte, via `IsAD`/`ADDomain`/`ADUsername` (implémentation hMailServer : `SSPIValidation::ValidateUser` → `LogonUser(user, domain, password, LOGON32_LOGON_NETWORK)`).
- **`ADDomain`** = `twisterlab.local`.
- **Domaine hMailServer** : `ADDomanName` = `twisterlab.local`.
- **Aucun mot de passe hMailServer stocké** pour ces comptes.

---

## 5. Anti-relais et absence totale de flux Internet

Mesures superposées (défense en profondeur) :

1. **Aucun relais SMTP configuré** — `Settings.SMTPRelayer` vide, `SMTPRelayerRequiresAuthentication = False`.
2. **Aucune route externe** — `Settings.Routes` = 0 (pas de smart host, pas de catch-all).
3. **Plages de sécurité hMailServer** (ordre d'évaluation : priorité **décroissante**) :

| Plage | Priorité | L→L | L→R | R→L | R→R | Relais |
|---|---|---|---|---|---|---|
| `LAN-TwisterLab` (192.168.0.0–192.168.0.255) | 40 | ✅ | ❌ | ✅ | ❌ | ❌ |
| `My computer` (127.0.0.1) | 30 | ✅ | ❌ | ✅ | ❌ | ❌ |
| `Internet` (0.0.0.0–255.255.255.255) | 10 | ❌ | ❌ | ❌ | ❌ | ❌ |

   L→L = client local vers destinataire local ; L→R = relais sortant ; R→L = réception depuis l'extérieur.
4. **Authentification SMTP obligatoire** — `RequireSMTPAuthLocalToLocal = True`, `RequireAuthForDeliveryToLocal = True`.
5. **Blocage pare-feu sortant TCP 25** pour `hMailServer.exe` — garantie réseau qu'aucune livraison externe ne peut partir, quelle que soit la configuration de hMailServer.

---

## 6. DNS (DC-DELL, zone `twisterlab.local`)

| Type | Propriétaire | Donnée | Préference |
|---|---|---|---|
| A | `mail` | `192.168.0.12` | — |
| MX | `@` (racine de zone) | `mail.twisterlab.local.` | 10 |

---

## 7. Résultats des tests

Suite : `scripts/messagerie/test-mail.py` — **15/15 tests réussis**.

### [1] Résolution DNS
| Test | Résultat |
|---|---|
| `A mail.twisterlab.local` | ✅ `192.168.0.12` |
| `MX twisterlab.local` | ✅ `preference = 10, mail exchanger = mail.twisterlab.local` |

### [2] Authentification Active Directory (COM `ValidatePassword`)
| Test | Résultat |
|---|---|
| `admin@` avec le bon mot de passe AD | ✅ `valid=True` |
| `admin@` avec un mauvais mot de passe | ✅ `valid=False` |
| `test@` avec le bon mot de passe AD | ✅ `valid=True` |

### [3] SMTP Submission (587) et livraison interne
| Test | Résultat |
|---|---|
| AUTH + envoi `admin@` → `test@` (587, sans TLS) | ✅ accepté |
| AUTH + envoi `admin@` → `test@` via **STARTTLS** | ✅ accepté |

### [4] Réception IMAP (143) — authentification AD
| Test | Résultat |
|---|---|
| `IMAP LOGIN test@twisterlab.local` (mot de passe AD) | ✅ connexion, 5 boîtes |
| Recherche du message envoyé | ✅ retrouvé (`msg-id`) |
| En-tête du message reçu | ✅ `FROM: admin@…` / `TO: test@…` / `SUBJECT: …` |
| `IMAP LOGIN test@` avec mauvais mot de passe | ✅ refusé |

### [5] Anti-relais / aucun envoi Internet
| Test | Résultat |
|---|---|
| `RCPT TO: external@gmail.com` | ✅ `550 Delivery is not allowed to this address.` |
| Envoi vers destinataire externe | ✅ `550 Delivery is not allowed to this address.` |

### [6] Compléments
| Test | Résultat |
|---|---|
| `RCPT TO: inexistant@twisterlab.local` | ✅ `550 Unknown user` |
| Port 25 sans authentification | ✅ `530 SMTP authentication is required.` |

### Preuve cross-machine (depuis **DC-DELL** `192.168.0.100`)
| Test | Résultat |
|---|---|
| TCP 25 | ✅ `TcpTestSucceeded=True` |
| TCP 143 | ✅ `TcpTestSucceeded=True` |
| TCP 587 | ✅ `TcpTestSucceeded=True` |
| Bannière SMTP | ✅ `220 mail.twisterlab.local ESMTP` |
| `EHLO` | ✅ `250-AUTH LOGIN PLAIN`, `SIZE 20971520` |
| Bannière IMAP | ✅ `* OK IMAPrev1` |

### Preuve dans le journal hMailServer
`C:\ProgramData\hMailServer\Logs\hmailserver_2026-10-24.log` :
```
SENT: 550 Delivery is not allowed to this address.
SENT: 550 Unknown user
SENT: 530 SMTP authentication is required.
```

---

## 8. Configuration d'un client de messagerie

| Paramètre | Valeur |
|---|---|
| Serveur entrant (IMAP) | `mail.twisterlab.local` — port **143**, STARTTLS si proposé, auth **mot de passe normal** |
| Serveur sortant (SMTP) | `mail.twisterlab.local` — port **587**, STARTTLS, auth **mot de passe normal** |
| Identifiant | `prenom.nom@twisterlab.local` |
| Mot de passe | **mot de passe du compte AD** |
| Domaine | `twisterlab.local` |

---

## 9. Réversibilité

```powershell
# 1. Arreter et desinstaller le service
Stop-Service hMailServer
& 'C:\Program Files\hMailServer\uninst.exe' /VERYSILENT

# 2. Retirer les regles de pare-feu
Get-NetFirewallRule -DisplayName 'hMailServer*' | Remove-NetFirewallRule

# 3. Retirer les enregistrements DNS (sur DC-DELL)
Remove-DnsServerResourceRecord -ZoneName 'twisterlab.local' -Name 'mail' -RecordType A -Force
Remove-DnsServerResourceRecord -ZoneName 'twisterlab.local' -Name '@' -RecordType MX -Force

# 4. Retirer les comptes AD crees
Remove-ADUser -Identity 'admin' -Confirm:$false
Remove-ADUser -Identity 'test'  -Confirm:$false

# 5. Supprimer les fichiers
Remove-Item 'C:\ProgramData\hMailServer' -Recurse -Force
Remove-Item 'C:\Users\administrator\.twisterlab-mail' -Recurse -Force
```

---

## 10. Limites connues

- **Comptes `alex`, `devuser`, `maya`, `Administrator`** : comptes de messagerie créés et liés à l'AD, mais leur mot de passe AD n'est pas connu de l'orchestrateur — leur authentification n'a donc pas été testée en IMAP (seuls `admin@` et `test@` le sont).
- **Certificat TLS auto-signé** : les clients doivent accepter l'avertissement ou importer le certificat (`C:\ProgramData\hMailServer\Certificates\mail.twisterlab.local.crt`).
- **IMAP en clair sur 143** : conforme au cahier des charges ; IMAPS (993) non configuré.
- **Accès Tailscale** : possible (interface en profil Domain), mais l'enregistrement A pointe sur l'IP LAN `192.168.0.12`.
- **IP du serveur mail** : `192.168.0.12` fournie par DHCP/réservation ; à figer si elle ne l'est pas déjà.
