---
name: hermes-peer-a2a
description: "Use when messaging a Hermes peer (A2A)."
category: autonomous-ai-agents
---

# Contexte lab (NE PAS OUBLIER)

- **Domaine AD :** `twisterlab.local` — DC-DELL est le contrôleur de domaine.
- **Core (CORE)** est membre du domaine. Le compte courant `administrator` est **ADMIN DE DOMAINE** (acces WinRM a DC-DELL avec les credentials courants).
- **Acces admin a DC-DELL :** WinRM (Invoke-Command) depuis Core avec credentials courants, apres `Start-Service WinRM` + `Set-Item WSMan:\localhost\Client\TrustedHosts -Value '100.70.59.28' -Force`.
- **Roles :** Core = orchestrateur (Hermes), Edge = worker Linux + services (Paperclip, Forgejo, OpenClaw), DC-DELL = contrôleur de domaine AD + DNS/DHCP.
- **Hermes home :** Core = `C:\Users\administrator\AppData\Local\hermes`; DC-DELL = `C:\Users\Administrator\AppData\Local\hermes`.
- **Skills DC-DELL** vivent dans `AppData\Local\hermes\skills\` (PAS dans `~/.hermes\skills\`).

# Hermes peer A2A (bot-to-bot)

Cross-machine bot DM: `hermes peer` delivers into the remote agent's canonical
"Bot Chat" and runs ONE synchronous turn. The peer must run the `api_server`
platform; its stock HTTP API is the transport.

## Contract (verify before trusting)

| What | Where |
|---|---|
| Peer URL registry | `config.yaml` -> `bot_peers.<name>.url` |
| Peer credential | `HERMES_PEER_<NAME>_KEY` in the **caller's** Hermes `.env` |
| Set both | `hermes peer add <name> --url http://host:8642 --key <API_SERVER_KEY> --note "..."` |
| List | `hermes peer list` (shows `[key set]` vs `NO KEY`) |
| Message | `hermes peer dm <name> "msg"` (one turn, 600 s cap) |
| Async | `hermes peer run <name> <msg` / `status <name> <run_id>` / `stop` |
| Named profile | `hermes peer dm <name>/<profile> "msg"` |

`hermes peer add` upserts `bot_peers` **and** writes the credential. Without
`--key` it registers the URL but leaves the peer keyless — the exact failure
mode where a peer is "configured" yet every call 401s.

## TwisterLab specifics

- Core api_server: `0.0.0.0:8642`; its key is `API_SERVER_KEY` in Core's Hermes `.env`.
- Peer endpoints, all `api_server` on `:8642`:

  | Node | Tailscale | LAN |
  |---|---|---|
  | Core | `100.92.101.28` | `192.168.0.12` |
  | Edge | `100.112.255.75` | `192.168.0.30` |
  | DC-DELL | `100.70.59.28` | `192.168.0.100` |

  Edge `8642` is **LAN-blocked** by its ufw allowlist — reach Edge over Tailscale.
  DC-DELL answers on both. A peer that looks unreachable is usually reached on the
  wrong interface.
- `/health` answers 200 with **no** auth; `/v1/models` requires the key.
- Edge CLI is not on the non-interactive SSH PATH: use `/home/twister/.local/bin/hermes`.

## Pitfalls

- **Verify auth cheaply before spending an agent turn.**
  `curl -H "Authorization: Bearer $KEY" http://host:8642/v1/models` -> 200 + JSON
  when correct, `gateway_auth_error` when not. A 401 tells you the key is
  missing/wrong and nothing else.
- **A peer reply is not evidence — and neither is your own review.** The remote
  agent answers from its own context and tools. If the source of truth (e.g. the
  `homelab-twisterlab` repo) is not present on that machine, it will fabricate
  plausible commit hashes, paths and versions. Cross-check factual claims against
  GitHub ground truth before relaying them. This has happened: a Core reply
  invented five commit SHAs while the real history was entirely different
  docs/ADR commits. When *you* produce a review, verify each claim with your own
  measurement and keep "unverified" separate from "false" — then expect the
  reviewed party to challenge you, and re-measure instead of defending. A review
  is an artifact too; applying the rule to itself is what keeps it honest. For the
full workflow of verifying a document or a whole set of claims (inventory the
assertions, measure each, classify TRUE/FALSE/UNVERIFIABLE, publish a structured
rebuttal, handle the counter-rebuttal), see the `agent-claim-verification` skill.
- **Probe route existence with the right verb — never conclude from `000`.**
  `GET /v1/<route>` distinguishes an absent route (`404`) from one that exists but
  rejects GET (`405`). `GET /v1/capabilities` lists the server's declared features,
  so ask it before probing individual routes. A curl `000` is **not** absence: the
  api_server serializes per session and answers
  `event: hermes.status` + "Another Hermes process is using this session; waiting"
  while it queues. Confirm with a streaming POST before calling any route missing.
- **A `404` on a resource-scoped route with a made-up id proves nothing.** For
  `/v1/<resource>/{id}/...`, probing with a fabricated id cannot distinguish
  "route absent" from "resource not found". Create a real resource first, then
  probe its sub-resource. Likewise `/v1/capabilities` is a **declaration**, not a
  measurement: a route it lists can still answer `500`. And a `500` under a
  catch-all `except` is a label, not a diagnosis — find the real exception (a
  `TypeError` on an unknown kwarg means caller and signature drifted).
  Probes and commands: `references/endpoint-probing.md`. How to *classify* the
  result (TRUE / FALSE / UNVERIFIABLE): `agent-claim-verification`.
- **A credential reported ABSENT may simply be searched in the wrong file.** A
  peer keeps its key in the Hermes `.env`, not in `config.yaml`. A remote agent
  that only greps `config.yaml` will report a working key as "ABSENT" — confirm
  with an authenticated request before relaying that claim.
- **A skill inside a Docker sandbox is not the host's skill.** Sandboxes mount a
  read-only scratch cache at `/root/.hermes/skills` and carry no `hermes` binary
  and no `.env`. Filesystem and network tests run from inside describe the
  container, not the host — copy skills to the host for them to take effect.
- **Read `ufw status numbered`, not `ufw status`.** The numbered form shows rule
  order and inline comments, which is where deliberate hardening is documented.
  A bare `DENY` that reads like breakage is often a default-deny allowlist — check
  the companion `ALLOW` lines before calling it a defect.
- **Pairing links are single-use and short-lived.** A 401 "Pairing link expired or
  already used" means generate a new one; re-sending the same link never works.
- **No shell on a node? Delegate the change to its own agent.** When SSH keys are
  refused and the only other admin path needs credentials you do not have, the A2A
  channel is a first-class way to *make* a change, not just to ask about one: the
  remote agent holds the terminal and file tools you lack. Send **one mission** —
  exact commands, a strict order, and a rule that it reports the raw output of each
  step and stops on error rather than working around it. Ship anything it needs (a
  skill, a script) through the shared git repo first so the mission can pull it
  instead of you pasting content. Keep it to a handful of steps: a node with a
  single-task budget spends it all on one long turn.
- **Correct the remote's false claims, with proof.** A peer may misattribute
  where something lives, or report a 404 for a route that returns 200. Assert
  only what you measured, state the measurement, and separate "unverified" from
  "false".
- `hermes peer add` without `--note` **drops** the existing note on upsert — pass
  `--note` to preserve it.
- **Never pass the key on a command line or in chat.** Read it into a shell var
  and pipe over SSH stdin:
  `printf '%s' "$KEY" | ssh ... 'hermes peer add <name> --url ... --key "$(cat)"'`
- Nested quoting: build the remote message with base64 to avoid paren/newline
  shell errors, then `base64 -d` on the remote side.
- An empty/short reply can mean the turn timed out silently — retry once and
  read the exit code before concluding the channel is broken.
- **Native tools ignore MSYS paths — git is only the commonest victim.** On Windows
  the MSYS layer translates `/c/Users/...` for bash builtins but **not** for native
  binaries, and the conversion is disabled in some shells. A native program reads
  `/c/Users/x` as a *relative* path from the current drive and creates `C:/c/Users/x`
  — invisible to `ls`, yet still working for `git -C`. Always pass native
  `C:/Users/x/...` paths to native tools (`git`, `curl`, `python`, `node`), and
  confirm with `git rev-parse --show-toplevel` rather than trusting an exit code.
  Three concrete bites: `git clone <url> /c/Users/x/repo` lands in `C:/c/Users/x/repo`;
  `curl --data-binary @/c/Users/x.json` fails with *"error encountered when reading
  a file"* while the same call with `C:/Users/x.json` succeeds; `curl -o "$TMPDIR/o"`
  silently writes nothing because the native binary cannot see the MSYS path.
- **No global git identity is configured** on these nodes. `git commit` needs
  `git config user.name` / `user.email` (repo-local is fine); copy the author of an
  existing commit for consistency. Pushing works via the Windows Credential Manager
  entry `git:https://github.com` even when `gh auth status` reports "not logged in".
- **Verify delivery, not just the reply.** A peer DM lands in the remote's
  canonical "Bot Chat" session (`source=api_server`). Confirm it persisted by
  querying the remote `state.db`: `select ... from messages where content like
  '%<marker>%'`. The returned text is a rendering of the turn, not proof of storage.

## Ground truth for "what changed"

`https://api.github.com/repos/youneselfakir0/homelab-twisterlab/commits?per_page=15`

The repo **is** cloned on Core (`C:/Users/administrator/homelab-twisterlab`) so its
git log is a local source; the other nodes fetch it from GitHub instead.
