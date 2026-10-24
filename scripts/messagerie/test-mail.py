#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Tests de bout en bout - Messagerie interne twisterlab.local (hMailServer)
Ne lit les mots de passe que depuis le fichier local, ne les affiche jamais.
"""
import re, socket, ssl, sys, time
import smtplib, imaplib

CRED = r"C:\Users\administrator\.twisterlab-mail\credentials.txt"
HOST = "mail.twisterlab.local"
IP   = "192.168.0.12"

raw = open(CRED, "r", encoding="utf-8", errors="replace").read()

def pw_of_admin_hms():
    m = re.search(r"Mot de passe admin hMailServer\s*:\s*(\S+)", raw)
    return m.group(1) if m else None

def pw_of_ad(sam):
    m = re.search(r"(?s)samaccountname=%s\s*\r?\n\s*mot de passe\s*=\s*(\S+)" % re.escape(sam), raw)
    return m.group(1) if m else None

PW_HMS = pw_of_admin_hms()
PW_ADMIN = pw_of_ad("admin")
PW_TEST = pw_of_ad("test")

results = []
def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print("%s  %s%s" % ("PASS" if ok else "FAIL", name, (" -- " + detail) if detail else ""))

print("=" * 78)
print("TESTS MESSAGERIE INTERNE twisterlab.local")
print("=" * 78)

# ---------------------------------------------------------------- 1. DNS
print("\n[1] RESOLUTION DNS")
try:
    ip = socket.gethostbyname("mail.twisterlab.local")
    check("A mail.twisterlab.local", ip == IP, "%s (attendu %s)" % (ip, IP))
except Exception as e:
    check("A mail.twisterlab.local", False, "erreur: %s" % e)

try:
    # MX: on utilise nslookup (commande demandee dans le cahier des charges)
    import subprocess
    out = subprocess.run(["nslookup", "-type=MX", "twisterlab.local", "192.168.0.100"],
                         capture_output=True, text=True, timeout=30).stdout
    m = re.search(r"mail exchanger\s*=\s*(\S+)", out, re.I)
    p = re.search(r"preference\s*=\s*(\d+)", out, re.I)
    if m:
        mx = (int(p.group(1)) if p else None, m.group(1).rstrip("."))
        ok = mx[1].lower() == "mail.twisterlab.local"
        check("MX twisterlab.local", ok, "MX=%s (nslookup: %s)" % (mx, out.strip().splitlines()[-1].strip()))
    else:
        check("MX twisterlab.local", False, "aucune reponse MX: %s" % out.strip()[:120])
except Exception as e:
    check("MX twisterlab.local", False, "erreur: %s" % e)

# ---------------------------------------------------------------- 2. AUTH AD (COM ValidatePassword)
print("\n[2] AUTHENTIFICATION ACTIVE DIRECTORY (via COM ValidatePassword)")
try:
    import subprocess, os
    # Le mot de passe passe par variable d'environnement (jamais en argument :
    # PowerShell -Command concatene les arguments restants dans la commande).
    ps = r'''
$credFile = 'C:\Users\administrator\.twisterlab-mail\credentials.txt'
$hmsAdmin = ((Get-Content $credFile | Select-String -Pattern 'Mot de passe admin hMailServer\s*:\s*(\S+)').Matches.Groups[1].Value)
$app = New-Object -ComObject hMailServer.Application
$app.Authenticate('Administrator', $hmsAdmin) | Out-Null
$dom = $app.Domains.ItemByName('twisterlab.local')
$a = $dom.Accounts.ItemByAddress($env:HMS_ADDR)
"$($a.Address)|isAD=$($a.IsAD)|ADUser=$($a.ADUsername)|ADDomain=$($a.ADDomain)|valid=$($a.ValidatePassword($env:HMS_PW))"
'''
    def validate(addr, password):
        env = dict(os.environ, HMS_ADDR=addr, HMS_PW=password)
        p = subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                           capture_output=True, text=True, timeout=90, env=env)
        return p.stdout.strip()
    if PW_ADMIN:
        r1 = validate("admin@twisterlab.local", PW_ADMIN)
        check("AD auth admin@ (bon mot de passe)", "valid=True" in r1, r1)
        r2 = validate("admin@twisterlab.local", "mauvais-mot-de-passe")
        check("AD auth admin@ (mauvais mot de passe -> refuse)", "valid=False" in r2, r2)
    if PW_TEST:
        r3 = validate("test@twisterlab.local", PW_TEST)
        check("AD auth test@ (bon mot de passe)", "valid=True" in r3, r3)
except Exception as e:
    check("AD auth (COM ValidatePassword)", False, "erreur: %s" % e)

# ---------------------------------------------------------------- 3. SMTP SUBMISSION + LIVRAISON INTERNE
print("\n[3] SMTP SUBMISSION (587) + LIVRAISON INTERNE")
SUBJ = "Test interne %s" % time.strftime("%H%M%S")
sent_ok = False
if not PW_ADMIN:
    check("SMTP AUTH admin@", False, "mot de passe AD admin introuvable")
else:
    # 3a. sans TLS
    try:
        s = smtplib.SMTP(HOST, 587, timeout=20)
        s.ehlo()
        s.login("admin@twisterlab.local", PW_ADMIN)
        s.sendmail("admin@twisterlab.local", ["test@twisterlab.local"],
                   "From: admin@twisterlab.local\r\nTo: test@twisterlab.local\r\n"
                   "Subject: %s\r\n\r\nMessage interne de test depuis admin.\r\n" % SUBJ)
        s.quit()
        sent_ok = True
        check("SMTP AUTH+soumission admin@ -> test@ (587, sans TLS)", True)
    except Exception as e:
        check("SMTP AUTH+soumission admin@ -> test@ (587, sans TLS)", False, "%s" % e)

    # 3b. avec STARTTLS
    try:
        ctx = ssl._create_unverified_context()
        s2 = smtplib.SMTP(HOST, 587, timeout=20)
        s2.ehlo()
        s2.starttls(context=ctx)
        s2.ehlo()
        s2.login("admin@twisterlab.local", PW_ADMIN)
        s2.sendmail("admin@twisterlab.local", ["test@twisterlab.local"],
                    "From: admin@twisterlab.local\r\nTo: test@twisterlab.local\r\n"
                    "Subject: %s TLS\r\n\r\nMessage interne via STARTTLS.\r\n" % SUBJ)
        s2.quit()
        check("SMTP AUTH+soumission via STARTTLS (587)", True)
    except Exception as e:
        check("SMTP AUTH+soumission via STARTTLS (587)", False, "%s" % e)

# ---------------------------------------------------------------- 4. RECEPTION IMAP (auth AD)
print("\n[4] RECEPTION IMAP (143) - AUTHENTIFICATION AD")
if not PW_TEST:
    check("IMAP login test@ (AD)", False, "mot de passe AD test introuvable")
else:
    try:
        m = imaplib.IMAP4(IP, 143, timeout=20)
        m.login("test@twisterlab.local", PW_TEST)
        typ, boxes = m.list()
        m.select("INBOX")
        typ, data = m.search(None, "SUBJECT", '"%s"' % SUBJ)
        ids = data[0].split() if data and data[0] else []
        check("IMAP login test@twisterlab.local (AD)", True,
              "boites=%s" % len(boxes))
        check("IMAP recherche message sujet '%s'" % SUBJ, len(ids) >= 1,
              "msg-id=%s" % ids)
        if ids:
            typ, msg = m.fetch(ids[-1], "(BODY[HEADER.FIELDS (FROM TO SUBJECT)])")
            hdr = msg[0][1].decode(errors="replace")
            check("IMAP contenu entete message recu",
                  "admin@twisterlab.local" in hdr and SUBJ.split()[0] in hdr,
                  hdr.replace("\r\n", " | ").strip()[:140])
        # mauvais mot de passe
        try:
            m2 = imaplib.IMAP4(IP, 143, timeout=20)
            m2.login("test@twisterlab.local", "mauvais-mot-de-passe")
            check("IMAP login test@ (mauvais mot de passe -> refuse)", False, "ACCEPTE !")
        except imaplib.IMAP4.error:
            check("IMAP login test@ (mauvais mot de passe -> refuse)", True)
        m.logout()
    except Exception as e:
        check("IMAP login test@twisterlab.local (AD)", False, "%s" % e)

# ---------------------------------------------------------------- 5. ANTI-RELAI / PAS D'INTERNET
print("\n[5] ANTI-RELAI / AUCUN ENVOI INTERNET")
if PW_ADMIN:
    try:
        s = smtplib.SMTP(HOST, 587, timeout=20)
        s.ehlo(); s.login("admin@twisterlab.local", PW_ADMIN)
        try:
            s.sendmail("admin@twisterlab.local", ["external@gmail.com"],
                       "From: admin@twisterlab.local\r\nTo: external@gmail.com\r\n"
                       "Subject: test relai\r\n\r\nDoit etre refuse.\r\n")
            check("RCPT vers domaine externe refuse", False, "ACCEPTE - RELAI OUVERT !")
        except smtplib.SMTPRecipientsRefused as e:
            check("RCPT vers domaine externe refuse", True, "%s" % e)
        except smtplib.SMTPException as e:
            check("RCPT vers domaine externe refuse", True, "%s" % e)
        s.quit()
    except Exception as e:
        check("RCPT vers domaine externe refuse", False, "erreur: %s" % e)

    try:
        s = smtplib.SMTP(HOST, 587, timeout=20)
        s.ehlo(); s.login("admin@twisterlab.local", PW_ADMIN)
        try:
            s.sendmail("admin@twisterlab.local", ["external@gmail.com"],
                       "Subject: x\r\n\r\nx\r\n")
            check("Envoi vers destinataire externe bloque", False, "ACCEPTE !")
        except smtplib.SMTPRecipientsRefused as e:
            check("Envoi vers destinataire externe bloque", True, "%s" % e)
        s.quit()
    except Exception as e:
        check("Envoi vers destinataire externe bloque", False, "erreur: %s" % e)
else:
    check("Anti-relai (auth requise)", False, "mot de passe introuvable")

# ---------------------------------------------------------------- 6. BANDE PASSANTE / COMPTE INEXISTANT
print("\n[6] COMPLÉMENTS")
if PW_ADMIN:
    try:
        s = smtplib.SMTP(HOST, 587, timeout=20)
        s.ehlo(); s.login("admin@twisterlab.local", PW_ADMIN)
        try:
            s.sendmail("admin@twisterlab.local", ["inexistant@twisterlab.local"],
                       "Subject: x\r\n\r\nx\r\n")
            check("RCPT compte local inexistant -> rejete", False, "ACCEPTE !")
        except smtplib.SMTPRecipientsRefused as e:
            check("RCPT compte local inexistant -> rejete", True, "%s" % e)
        s.quit()
    except Exception as e:
        check("RCPT compte local inexistant -> rejete", False, "erreur: %s" % e)
    # port 25 sans AUTH doit etre refuse
    try:
        s = smtplib.SMTP(IP, 25, timeout=20)
        s.ehlo()
        try:
            s.sendmail("admin@twisterlab.local", ["test@twisterlab.local"], "Subject: x\r\n\r\nx\r\n")
            check("Port 25 sans AUTH -> soumission refusee", False, "ACCEPTE !")
        except smtplib.SMTPException as e:
            check("Port 25 sans AUTH -> soumission refusee", True, "%s" % e)
        s.quit()
    except Exception as e:
        check("Port 25 sans AUTH -> soumission refusee", False, "erreur: %s" % e)

print("\n" + "=" * 78)
total = len(results)
passed = sum(1 for _, ok, _ in results if ok)
print("RESULTAT: %d/%d tests reussis" % (passed, total))
for n, ok, d in results:
    if not ok:
        print("  ECHEC: %s %s" % (n, d))
print("=" * 78)
sys.exit(0 if passed == total else 1)
