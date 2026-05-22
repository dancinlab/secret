# 🔐 secret

macOS Keychain-backed credential CLI. Single bash script, zero dependencies (uses the system `security` CLI).

## Install

```
hx install secret
```

Or clone + symlink:

```
git clone https://github.com/dancinlab/secret ~/core/secret
ln -s ~/core/secret/bin/secret ~/.local/bin/secret    # ensure ~/.local/bin is on PATH
```

## Use

```
secret set github_token ghp_xxxxxxxxxx
secret get github_token            # → ghp_xxxxxxxxxx (stdout, pipe-friendly)
secret rotate session_key          # generate random + store (value NEVER printed)
secret check github_token          # exit 0 if exists, 1 otherwise
secret list
secret delete github_token
```

Value omitted → hidden prompt:

```
$ secret set openai_key
value for openai_key: ******
stored: openai_key (service=dancinlab.secret)
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
| `(0x)?` + 64 hex | Ethereum-style private key |

Override requires BOTH:
1. `--allow-mnemonic` flag (explicit consent)
2. Value via **stdin or tty** (argv is refused — `ps aux` leak vector)

```
# tty prompt (hidden):
secret set hot_wallet --allow-mnemonic
value for hot_wallet: …

# pipe:
cat words.txt | secret set hot_wallet --allow-mnemonic

# REFUSED — argv with --allow-mnemonic still rejected (ps aux):
secret set wallet --allow-mnemonic "abandon ability able …"
```

**BIP39 mnemonic detection** — validates against the bundled canonical BIP39 English wordlist (`data/bip39_english.txt`, 2048 words). A random 12-word English sentence (words NOT in the wordlist) is NOT flagged. If the wordlist file is missing, falls back to the lowercase-words heuristic.

## Rotate (random + replace)

```
secret rotate <key> [--bytes N | --hex N]
```

- `--bytes N` (default 32) → N random bytes from `/dev/urandom`, base64-encoded.
- `--hex N` → N hex chars (N must be even).
- The new value is **never printed** — only a sentinel (`rotated: <key> …`) is emitted. Read via `secret get <key>`.

```
$ secret rotate session_key --bytes 64
rotated: session_key (service=dancinlab.secret, mode=bytes, n=64) — read via `secret get session_key`
```

## Check (existence, no value print)

```
secret check <key>          # exit 0 if exists, 1 otherwise
```

```
secret check github_token && echo present
```

## TTY guard

A trap restores `stty echo` on `EXIT`, `INT`, `TERM` — interrupting a hidden prompt won't leave the terminal in `-echo` state.

## Storage

| | |
|---|---|
| Backend | **macOS Keychain** via `security` CLI |
| Service | `$SECRET_SERVICE` (default: `dancinlab.secret`) |
| Item key | the `<key>` argument |
| Multi-device | **iCloud Keychain** syncs entries across the user's Apple devices automatically |
| Encryption | system Keychain (per-user, AES-256, hardware-bound on Apple Silicon) |

## Why Keychain over files

- Encrypted at rest (Keychain is system-managed, not plaintext on disk)
- iCloud Keychain = automatic multi-device sync without extra setup
- `security` CLI is built into macOS — no extra install
- Per-user namespace (each operator has their own Keychain)

## Namespacing

`$SECRET_SERVICE` partitions the entries. Use it to separate contexts:

```
SECRET_SERVICE=personal secret set ...
SECRET_SERVICE=work     secret set ...
SECRET_SERVICE=ci-bot   secret set ...
```

`secret list` shows only the active service's entries.

## Limitations

- **macOS-only** (uses `security` CLI). For cross-platform, consider 1Password CLI (`op`) / Bitwarden CLI (`bw`).
- The `list` verb relies on `security dump-keychain` (slow on huge keychains) — fine for typical secret counts.
