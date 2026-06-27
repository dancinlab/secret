# secret

`secret` is an encrypted-file credential CLI — a single self-contained bash script (`bin/secret`, deps: `openssl` + `base64`). Secrets live in one openssl-encrypted file (`store.enc`) inside a private git checkout, decrypted in-memory with a master password, and synced between devices as ciphertext through a private git repo. Architecture SSOT: [ARCHITECTURE.md](ARCHITECTURE.md). Change history: [CHANGELOG.jsonl](CHANGELOG.jsonl). Machine-readable governance: [project.tape](project.tape).

## Structure

```
secret/
├─ bin/secret              — the entire CLI (bash) — dispatch + all subcommands (get/set/rotate/check/list/delete/service/init/backup/sync/migrate)
├─ data/bip39_english.txt  — canonical BIP39 2048-word list backing wallet-mnemonic refusal on `set`
├─ install.hexa            — `hx install secret` package manifest (shim into ~/.hx/bin/)
├─ ARCHITECTURE.md         — architecture SSOT (update-in-place)
├─ CHANGELOG.jsonl            — append-only change log (date-keyed)
├─ CLAUDE.md               — this file — governance + harness entrypoint
├─ project.tape            — machine-readable identity + governance directives (@D s1…s7)
├─ LATTICE_POLICY.md       — cross-project verify-against-real-limits policy
├─ README.md              — user-facing install + usage docs
├─ harness.config.json     — harness profile + lockdown + lint + docs config
├─ .harness/               — harness rule data (enforcement / keywords / severity-map / prefs)
└─ .harness-engine/        — harness engine submodule (dancinlab/harness, harness-hardcore)
```

## Governance

Core security invariants (full directives in [project.tape](project.tape) `@D s1…s7`):

- **Encrypted store is the SSOT** — all secrets in the openssl-encrypted `store.enc`; never write plaintext to the repo, shell history, or any cached file.
- **Master password is the trust root** — the sole decryption secret. Strong + unique, never stored in a synced location, never accepted via argv.
- **High-value secrets refused by default** — BIP39 mnemonics / `xprv`-`xpub` / WIF keys are auto-detected on `set` and refused unless `--allow-mnemonic` **and** the value arrives via stdin/tty (argv leaks through `ps aux`).
- **`rotate` emits a sentinel only** — the rotated value is never printed to stdout / stderr / logs.
- **Sync = same encrypted blob** — `backup` / `sync` push the ciphertext as-is to a **private** git repo; auto-push is ON by default (`SECRET_BACKUP_AUTO=0` opts out per call).
- **Never commit a real secret value** — `.gitignore` blocks `*.token`/`*.key`/`*.pem`/`*.env`/`credentials*`; `store.enc` lives outside this repo.

## Harness

This repo is guarded by the `dancinlab/harness` engine (`harness-hardcore` profile) vendored as the `.harness-engine` submodule. Config: [harness.config.json](harness.config.json); rule data: `.harness/`; agent hooks: `.claude/settings.json`.

- **Lockdown (L0)** — `bin/secret` is the credential core; edits require a CHANGELOG/issue-tracker update in the same change.
- **Docs discipline** — `ARCHITECTURE.md` is the update-in-place SSOT, `CHANGELOG.jsonl` is append-only, scratch output goes under `scripts/scratch/`. Separate root docs must carry a quickref pointer back to the SSOT (`harness docs check`).
- **Verify** — `bash -n bin/secret` (syntax check) runs before merge; `main`/`master` are protected.

## Quick reference

```bash
# Run the harness (engine = .harness-engine submodule)
bash .harness-engine/bin/harness <cmd>          # docs check · lint · verify · audit

# CLI usage
secret set <key> <value>      # store (decrypt → modify → re-encrypt → atomic write)
secret get <key>              # print one value to stdout (pipe-friendly)
secret rotate <key>           # random value, never printed
secret check <key>            # exit 0 if exists, else 1
secret list                   # enumerate keys
secret delete <key>           # remove an entry
secret init github <git-url>  # bind store to a private git repo (one-time/device)
secret sync                   # git pull --rebase + push the encrypted store

# Master password (priority): $SECRET_MASTER → ~/.config/secret/master (0600) → tty
bash -n bin/secret            # syntax check (harness verify)
```
