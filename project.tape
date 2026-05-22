@V := "tape" :: spec [active]
  version = "1.2"

@I := "secret" :: identity [active]
  kind   = "macOS Keychain-backed credential CLI (bash · zero deps · iCloud-Drive-synced · 🔐)"
  brief  = "secret get/set/delete/list via `security` CLI · service-namespaced · the dedicated keychain file lives in iCloud Drive via a symlink, so iCloud Drive does file-level sync between Macs; each device unlocks with the SAME user-chosen master password (independent of Apple ID / login password)."
  parent = "dancinlab"
  ssot   = "github.com/dancinlab/secret"
  scripts = "bin/secret — single CLI entry point with verbs: get/set/rotate/check/list/delete/service + admin verbs init (one-time per-device setup) and migrate (one-time migration from login keychain)"

@D s1 := "Keychain is the SSOT — never write secrets to plaintext files" :: governance [required active]
  do   = "all secret storage flows through `security add-generic-password` / `find-generic-password` · `$SECRET_SERVICE` namespaces the entries (default `dancinlab.secret`) · entries live in the dedicated keychain at `$SECRET_KEYCHAIN` (default `~/Library/Keychains/dancinlab.keychain-db`, a symlink to `~/Library/Mobile Documents/com~apple~CloudDocs/Keychains/dancinlab.keychain-db`)"
  dont = "write secrets to local files / repo files (cards.json · *.token · .env in repo) · echo a fetched secret into shell history · cache plaintext outside the user's Keychain · co-mingle with the login keychain (the dedicated keychain is isolated by design — login keychain unlock ≠ secret keychain unlock)"

@D s2 := "macOS-only — fail fast on other OS" :: governance [required active]
  do   = "rely on the macOS-built-in `security` CLI; iCloud Drive (per Apple ID) handles file-level sync of the dedicated keychain between Macs — sync mechanism is file-level, not iCloud-Keychain item-level (the latter requires Apple Developer entitlements unavailable to a bash CLI)"
  dont = "add Linux/Windows fallback paths inside this CLI (cross-platform users should use 1Password CLI `op` or Bitwarden CLI `bw`) · silently degrade to file storage on non-mac · try to set `kSecAttrSynchronizable=true` from this CLI (it returns errSecMissingEntitlement -34018 without a provisioning profile — keep using the iCloud Drive symlink path instead)"

@D s3 := "high-value secrets — refuse by default, require explicit override + stdin/tty" :: governance [required active]
  do   = "auto-detect wallet-grade secrets on `set` (BIP39 12/15/18/21/24-word validated against bundled wordlist · xprv/xpub/yprv/ypub/zprv/zpub · WIF · 64-hex privkey) and REFUSE by default; override requires BOTH `--allow-mnemonic` flag AND stdin/tty input (pipe or hidden prompt)"
  dont = "accept high-value value via argv even with `--allow-mnemonic` (process-listing `ps aux` leak) · auto-promote argv input · silently store wallet seeds without the explicit-override + stdin/tty combo"

@D s4 := "rotate emits sentinel only — never echo the generated value" :: governance [required active]
  do   = "`secret rotate <key>` generates `/dev/urandom` (base64 / hex), stores via `security`, emits only a sentinel line (`rotated: <key> (mode=..., n=...)`) — the new value is read separately via `secret get <key>` (process-lifetime ephemeral)"
  dont = "print the rotated value to stdout / stderr / log · pass it as argv to a downstream command · skip the sentinel (silent rotate masks operator intent)"

@D s5 := "master password is the trust root — Apple ID compromise alone does NOT expose secrets" :: governance [required active]
  do   = "treat the user-chosen master password as the SOLE decryption secret · choose a strong unique master password independent of Apple ID / login passwords · enable Apple Advanced Data Protection (ADP) if available for defense in depth (encrypts the file blob in iCloud as well) · document that losing the master password means losing all entries (no Apple-side recovery)"
  dont = "store the master password in any synced location (iCloud Drive · iCloud Keychain · Notes) · reuse the macOS login password as the master password (defeats the iCloud-Drive-vs-Apple-ID-only-compromise separation) · add an Apple-ID-derived fallback unlock path (would re-couple the trust root to Apple ID)"

@D s6 := "migration / cross-keychain tools MUST pin source AND destination via explicit keychain paths — never the default user search list" :: governance [required active]
  do   = "every `security <verb> ... <keychain-path>` invocation inside `secret migrate` (and any future copy/sync helper) MUST pass the explicit source path (`~/Library/Keychains/login.keychain-db`) for enumerate / read / purge, and `$SECRET_KEYCHAIN` for dest write / verify · add a pre-flight assertion that resolved-source ≠ resolved-destination · log both paths in the migrate banner so the operator can sanity-check before --apply"
  dont = "rely on the implicit default keychain or user search list (`security dump-keychain`, `security delete-generic-password -a … -s …` with no trailing path) inside a copy loop — once `secret init` adds the destination keychain to the user search list, the same loop will enumerate BOTH source and destination, purge source on pass-1, then purge destination on pass-2 → total data loss"
  why  = "2026-05-22 incident: `secret migrate --apply --purge-source` after `secret init` had added the iCloud-Drive keychain to the user search list. dump-keychain saw 126 entries (63 × 2), the purge loop's pathless `delete-generic-password` removed login on its first sweep over each key and the iCloud destination on the second sweep. Both keychains ended empty. Recovered from the orthogonal TOML backup at `~/core/self-secret/credentials` (which held the same 63 keys 1:1). Without that backup BIP39 wallet seeds and YubiKey PIV credentials would have been irrecoverable."
