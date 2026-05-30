# 🔐 secret

Encrypted-file credential CLI. Bash, near-zero dependencies (`openssl` + `base64`). Secrets live in a single openssl-encrypted file (`store.enc`) inside a private git checkout, decrypted **in-memory** with a master password. **No macOS Keychain, no GUI security session** — works headless / over ssh / on linux. The encrypted store syncs between devices as ciphertext through a private git repo, unlocked everywhere by the same master password.

> **0.6.0 — macOS Keychain-free.** Earlier versions stored secrets in the macOS Keychain via the `security` CLI, which is bound to the GUI (Aqua) security session and returns empty over ssh / headless (`User interaction is not allowed`). The new backend is a session-independent encrypted file, so `secret get` works anywhere. See [Migrating](#migrating-from-the-keychain-backend).

## Install

```bash
# 1. Install hexa-lang (gives you `hexa` + `hx` package manager)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/main/install.sh)"

# 2. Install secret
hx install secret
```

`hx` wires the `secret` shim into `~/.hx/bin/` (must be on PATH).

Then set up the store location (one-time per device):

```
secret init github https://github.com/<owner>/<repo>.git  # store.enc inside a private git checkout
```

The **master password** is the sole decryption secret — use the SAME one on every device. It is never stored by the tool; supply it via (in priority order):

1. `$SECRET_MASTER` env var — headless / ssh / CI
2. `~/.config/secret/master` — a `0600` file (trailing newline stripped)
3. tty prompt — interactive

`argv` is **never** accepted for the master password.

## Use

```
secret set github_token ghp_xxxxxxxxxx
secret get github_token            # → ghp_xxxxxxxxxx (stdout, pipe-friendly)
secret rotate session_key          # generate random + store (value NEVER printed)
secret check github_token          # exit 0 if exists, 1 otherwise
secret list
secret delete github_token
```

Headless (ssh / CI) — pass the master password via env:

```
SECRET_MASTER="$PW" secret get github_token
```

Value omitted on a tty → hidden prompt. Value piped on stdin → the WHOLE stdin is read (multiline / ssh-key safe):

```
cat ~/.ssh/id_ed25519 | secret set ssh_key      # multiline value, stored intact
secret get ssh_key > id_ed25519                  # byte-identical roundtrip
```

Compose:

```
TOKEN=$(secret get github_token) gh repo view
SECRET_SERVICE=work secret list    # separate namespace
```

## High-value secret protection (`set` only)

Wallet-grade secrets are auto-detected on `secret set` and **refused by default**:

| Shape | Detected as |
|---|---|
| 12 / 15 / 18 / 21 / 24 lowercase a-z words (single-space) | BIP39 mnemonic |
| `xprv` / `xpub` / `yprv` / `ypub` / `zprv` / `zpub` + base58 (~111c) | extended key |
| `5` / `K` / `L` + 51-52 chars base58 | WIF private key |

Override requires BOTH:
1. `--allow-mnemonic` flag (explicit consent)
2. Value via **stdin or tty** (argv is refused — `ps aux` leak vector)

```
# tty prompt (hidden):
secret set hot_wallet --allow-mnemonic

# pipe:
cat words.txt | secret set hot_wallet --allow-mnemonic

# REFUSED — argv with --allow-mnemonic still rejected (ps aux):
secret set wallet --allow-mnemonic "abandon ability able …"
```

**BIP39 mnemonic detection** validates against the bundled canonical BIP39 English wordlist (`data/bip39_english.txt`, 2048 words); falls back to a lowercase-words heuristic if the file is missing. Bare 64-hex (SHA-256 / R2 key / HMAC / ETH privkey) → **WARN**, stored.

## Rotate (random + replace)

```
secret rotate <key> [--bytes N | --hex N]
```

- `--bytes N` (default 32) → N random bytes, base64-encoded.
- `--hex N` → N hex chars (N must be even).
- The new value is **never printed** — read it via `secret get <key>`.

## Check (existence, no value print)

```
secret check <key>          # exit 0 if exists, 1 otherwise
secret check github_token && echo present
```

## Storage

| | |
|---|---|
| Backend     | single openssl-encrypted file `store.enc` |
| Encryption  | `openssl enc -aes-256-cbc -pbkdf2 -salt -iter 200000`, password via fd (never argv) |
| Decryption  | in-memory only — plaintext is never written to disk |
| Store format | one line per entry: `<key><TAB>base64(value)` (multiline / binary-text safe) |
| Service     | `$SECRET_SERVICE` (default: `dancinlab.secret`) |
| Store path  | `$SECRET_GITHUB_PATH/store.enc` (default: `~/.local/share/secret/store.enc`) |
| Master pw   | `$SECRET_MASTER` → `~/.config/secret/master` (0600) → tty |

The plaintext store is **never** written to disk: `set` = decrypt-in-memory → modify → re-encrypt → atomic write of the ciphertext (`mktemp .store.enc.* → mv`). Values are base64-encoded so embedded newlines / tabs / binary-text (ssh keys, PEM, certs) stay line-safe.

## Sync — private git repo

### Store location
```
secret init github https://github.com/<owner>/<repo>.git
```
`store.enc` lives inside the checkout (default `~/.local/share/secret/`, `$SECRET_GITHUB_PATH` override). Every `set` / `rotate` / `delete` commits + pushes the encrypted store. Each device unlocks with the **same master password**. The repo MUST be private.

### Optional second mirror
```
secret backup enable https://github.com/<owner>/<mirror>.git [<local-path>]
secret backup                          # manual push
secret backup status                   # show config + state
secret backup disable                  # stop mirroring (clone kept)
```
Default local clone: `~/.local/share/secret-archive/`. The mirror is a byte-for-byte copy of the same `store.enc` — a second recovery channel.

**Auto-push is ON by default** once a git target is configured. Commit or push failures print a warning (a missing git identity is the usual culprit — `git config --global user.email/user.name`) but never block the local write — run `secret sync` later to catch up.
- Opt out for a single call: `SECRET_BACKUP_AUTO=0 secret set …`
- Permanent opt-out: `secret backup disable`

### Cross-device restore
On a new device, after `secret init github <url>`:
```
secret sync                            # git pull --rebase + push
```

## Migrating from the Keychain backend

Versions ≤ 0.5.0 stored secrets in the macOS Keychain. To import those entries into the new encrypted store, run **on the Mac, from Terminal.app** (NOT over ssh — keychain reads need a GUI security session):

```
secret migrate --from-keychain                 # import every entry (service=$SECRET_SERVICE)
secret migrate --from-keychain --purge-source  # import, then delete originals from the keychain
```

Each entry is read from `$SECRET_KEYCHAIN` (default `~/Library/Keychains/dancinlab.keychain-db`), written into `store.enc`, and round-trip-verified before reporting `ok`. The legacy keychain file is left in place as a rollback safety net (delete it manually once the migration is verified).

## Namespacing

`$SECRET_SERVICE` partitions entries by context. Note: each service maps to its own `store.enc` only insofar as `$SECRET_GITHUB_PATH` differs — within one store, keys are flat; use distinct stores (`$SECRET_GITHUB_PATH`) for hard isolation.

## Limitations

- **NUL bytes** in a value cannot survive (a bash variable cannot hold `\0`). Text secrets — tokens, ssh keys, PEM, certs, multiline configs — are safe; truly arbitrary binary blobs with embedded NUL are not.
- Requires `openssl` and `base64` (present on macOS and Linux).
