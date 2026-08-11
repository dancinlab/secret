# secret — Architecture (SSOT · update-in-place)

> Single source of truth for the final architecture. **Overwrite this file in place** on change (not append-only). History / decisions live in [CHANGELOG.jsonl](CHANGELOG.jsonl); governance in [CLAUDE.md](CLAUDE.md).

## Overview

`secret` is a credential CLI implemented as **one self-contained bash script** (`bin/secret`, near-zero deps — only `openssl` + `base64`). Secrets live in a single openssl-encrypted file (`store.enc`) inside a private git checkout, decrypted **in-memory** with a master password — no plaintext ever touches disk. The encrypted store is replicated between devices as ciphertext through a private git repo and unlocked everywhere with the same master password.

> **Backend note (0.6.x).** Versions ≤ 0.5.0 stored secrets in the macOS Keychain via the `security` CLI, which is bound to the GUI (Aqua) security session and returns empty over ssh / headless (`User interaction is not allowed`). The current backend is a session-independent encrypted file, so `secret get` works on macOS, mini (ssh), and Linux alike. The legacy Keychain path survives only inside the one-shot `migrate --from-keychain` importer.

## Component map

| Component | Path | Role |
|---|---|---|
| Main CLI script | `bin/secret` | Single bash entrypoint — argument dispatch + every subcommand. `set -euo pipefail`, TTY-aware color, `_die` helper. |
| Subcommand: `get` | `bin/secret` | Decrypt store in-memory → print one newline-terminated value to stdout. |
| Subcommand: `set` | `bin/secret` | Decrypt → modify → re-encrypt → atomic ciphertext write. High-value (wallet) refusal + argv-leak guard. |
| Subcommand: `rotate` | `bin/secret` | Generate random (`openssl rand`, `--bytes`/`--hex`) + store. Value **never** printed. |
| Subcommand: `check` | `bin/secret` | Existence test — exit 0/1, no value print. |
| Subcommand: `list`/`ls` | `bin/secret` | Enumerate keys (values withheld). |
| Subcommand: `delete`/`rm`/`del` | `bin/secret` | Remove an entry + re-encrypt. |
| Subcommand: `service` | `bin/secret` | Report / scope the `$SECRET_SERVICE` namespace. |
| Subcommand: `init github` | `bin/secret` | One-time per-device setup — bind the store to a private git repo. |
| Subcommand: `backup` / `sync` | `bin/secret` | Commit + push (`backup`) / pull --rebase + push (`sync`) the encrypted blob; optional second mirror. |
| Subcommand: `migrate --from-keychain` | `bin/secret` | One-shot legacy importer — read old macOS Keychain entries into `store.enc` (Mac GUI session only). |
| Encryption | `openssl` | `enc -aes-256-cbc -pbkdf2 -salt -iter 200000`; master password via fd (never argv). |
| BIP39 wordlist | `data/bip39_english.txt` | Canonical 2048-word list backing wallet-mnemonic detection on `set`. |
| `get` output regression | `tests/get-output.sh` | Byte-level check for unconditional trailing newline, multiline values, command substitution, and missing keys. |
| Package manifest | `install.hexa` | `hx install secret` wiring (shim into `~/.hx/bin/`). |
| Governance / harness | `CLAUDE.md`, `harness.config.json`, `.harness/`, `.harness-engine/` | AI-coding guardrails (lockdown, lint, docs discipline) — see [CLAUDE.md](CLAUDE.md). |

## Data flow

```
secret set <key> <value>           secret get <key>
        │                                  │
        ▼                                  ▼
 master password  ── $SECRET_MASTER → ~/.config/secret/master (0600) → tty
        │                                  │
        ▼                                  ▼
 openssl decrypt store.enc (in-memory)  openssl decrypt store.enc (in-memory)
        │                                  │
        ▼                                  ▼
 modify line  <key><TAB>base64(value)   find key → base64 -d → stdout
        │
        ▼
 openssl re-encrypt → atomic write (mktemp .store.enc.* → mv)
        │
        ▼
 auto git commit + push (private repo)  ── SECRET_BACKUP_AUTO=0 opts out
```

- **Input** — value via argv (low-risk), stdin (whole stream, multiline/ssh-key safe), or hidden tty prompt. argv refused for the master password and for high-value secrets.
- **Processing** — store.enc is decrypted to memory only; plaintext is never written to disk. Entries are `<key><TAB>base64(value)`; base64 keeps newlines / tabs / text-binary line-safe.
- **Output** — the store layer decodes the value exactly, then the public `get` command always appends one trailing newline, including through pipes and redirection, matching the original Keychain-backed CLI contract. `rotate` prints only a sentinel. `list` prints keys. Every mutating op optionally commits + pushes the ciphertext.

## Governance

All AI-assisted change is gated by the harness (`.harness-engine` submodule, `harness-hardcore` profile):

- **Lockdown** — `bin/secret` (the credential core) is L0; edits require an explicit CHANGELOG/issue-tracker update in the same change (`harness.config.json` → `lockdown`).
- **Docs discipline** — this `ARCHITECTURE.md` is the update-in-place SSOT; `CHANGELOG.jsonl` is the append-only log; scratch output goes under `scripts/scratch/`. Separate root docs carry a quickref pointer back here (`harness docs check`).
- **Branch protection** — `main` / `master` are protected; verification runs the script syntax check and byte-level `get` output regression before merge.
- **Never commit a real secret value.** `.gitignore` blocks `*.token` / `*.key` / `*.pem` / `*.env` / `credentials*`; the encrypted `store.enc` lives outside this repo.
