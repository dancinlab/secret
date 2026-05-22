# 🔐 secret

macOS Keychain-backed credential CLI. Bash, zero dependencies (uses the system `security` CLI). Entries live in a dedicated keychain file synced between Macs via **iCloud Drive** (file-level sync), unlocked by a user-chosen master password independent of Apple ID.

## Install

Clone + symlink:

```
git clone https://github.com/dancinlab/secret ~/core/secret
ln -s ~/core/secret/bin/secret ~/.local/bin/secret    # ensure ~/.local/bin is on PATH
```

Then pick a sync channel (one-time per device):

```
secret init icloud                                      # primary in iCloud Drive (easy default)
# or
secret init github https://github.com/<owner>/<repo>.git  # primary inside a private git checkout
# (prompts TWICE for the master password — use the SAME one on every device)
```

Optionally layer a GitHub mirror on top of the iCloud-primary setup:

```
secret backup enable https://github.com/<owner>/<repo>.git
secret backup                                  # initial push
SECRET_BACKUP_AUTO=1                            # export in shell rc for auto-push
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
| Backend       | **macOS Keychain** via `security` CLI |
| Service       | `$SECRET_SERVICE` (default: `dancinlab.secret`) |
| Item key      | the `<key>` argument |
| Keychain file | `$SECRET_KEYCHAIN` (default: `~/Library/Keychains/dancinlab.keychain-db`, a symlink to the actual file) |
| Encryption    | macOS Keychain format — file is encrypted at rest with the user-chosen master password |

The keychain file is **encrypted at rest**. Both sync channels below push/pull that encrypted blob as-is — no second crypto layer required.

## Sync channels (independent, on/off any time)

Either, both, or neither can be active:

### iCloud Drive — primary location in iCloud Drive
```
secret init icloud
```
File lives at `~/Library/Mobile Documents/com~apple~CloudDocs/Keychains/dancinlab.keychain-db`. iCloud Drive does file-level sync between your Macs. Each device unlocks with the **same master password**.

### GitHub mirror — encrypted blob in a private git repo
```
secret backup enable https://github.com/<owner>/<repo>.git [<local-path>]
secret backup                          # manual push
secret backup status                   # show config + state
secret backup disable                  # stop mirroring (clone kept)

SECRET_BACKUP_AUTO=1 secret set …      # auto commit + push after every modify
```
Default local clone: `~/.local/share/secret-archive/`. The mirror file is a byte-for-byte copy of the same encrypted blob — same master password unlocks it. Use the mirror as a recovery channel if iCloud Drive deletion / corruption / sync conflict happens. The repo MUST be private.

### Cross-device restore via mirror
On a new Mac, after `secret init icloud` (or `init github`) doesn't have the file yet:
```
secret backup enable <url>
secret sync                            # git pull --rebase + restore primary
```

### Why not iCloud Keychain item-sync (`kSecAttrSynchronizable=true`)?
Apple blocks programmatic iCloud Keychain access from unsigned CLI tools — `SecItemAdd` with `kSecAttrSynchronizable=true` returns `errSecMissingEntitlement` (`-34018`) without a provisioning profile. File-level sync (iCloud Drive OR git) sidesteps that constraint entirely.

## Why Keychain over files

- Encrypted at rest (`security` CLI manages it; the file is an encrypted blob)
- One self-contained file = a single artifact to sync via any file-transport channel
- `security` CLI is built into macOS — no extra install
- Master password independent of Apple ID — neither Apple ID nor GitHub compromise alone exposes secrets

## Migrating from a previous install

If you used `secret` before the iCloud-Drive-synced layout (entries lived in the default login keychain), copy them into the dedicated keychain with:

```
secret migrate                             # dry-run (read-only — shows what would copy)
secret migrate --apply                     # actually copy
secret migrate --apply --purge-source      # then delete originals from login keychain
```

`secret migrate` reads each entry from the default keychain, writes it to `$SECRET_KEYCHAIN`, and verifies the round-trip before reporting `ok`. Use `--purge-source` only after the verified copies look correct.

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
