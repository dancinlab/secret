@V := "tape" :: spec [active]
  version = "1.2"

@I := "secret" :: identity [active]
  kind   = "macOS Keychain-backed credential CLI (single bash script · zero deps · 🔐)"
  brief  = "secret get/set/delete/list via `security` CLI · service-namespaced · iCloud Keychain syncs entries across the user's Apple devices."
  parent = "dancinlab"
  ssot   = "github.com/dancinlab/secret (`hx install secret`)"

@D s1 := "Keychain is the SSOT — never write secrets to plaintext files" :: governance [required active]
  do   = "all secret storage flows through `security add-generic-password` / `find-generic-password` · `$SECRET_SERVICE` namespaces the entries (default `dancinlab.secret`)"
  dont = "write secrets to local files / repo files (cards.json · *.token · .env in repo) · echo a fetched secret into shell history · cache plaintext outside the user's Keychain"

@D s2 := "macOS-only — fail fast on other OS" :: governance [required active]
  do   = "rely on the macOS-built-in `security` CLI; iCloud Keychain handles multi-device sync per the user's Apple ID"
  dont = "add Linux/Windows fallback paths inside this CLI (cross-platform users should use 1Password CLI `op` or Bitwarden CLI `bw`) · silently degrade to file storage on non-mac"

@D s3 := "high-value secrets — refuse by default, require explicit override + stdin/tty" :: governance [required active]
  do   = "auto-detect wallet-grade secrets on `set` (BIP39 12/15/18/21/24-word validated against bundled wordlist · xprv/xpub/yprv/ypub/zprv/zpub · WIF · 64-hex privkey) and REFUSE by default; override requires BOTH `--allow-mnemonic` flag AND stdin/tty input (pipe or hidden prompt)"
  dont = "accept high-value value via argv even with `--allow-mnemonic` (process-listing `ps aux` leak) · auto-promote argv input · silently store wallet seeds without the explicit-override + stdin/tty combo"

@D s4 := "rotate emits sentinel only — never echo the generated value" :: governance [required active]
  do   = "`secret rotate <key>` generates `/dev/urandom` (base64 / hex), stores via `security`, emits only a sentinel line (`rotated: <key> (mode=..., n=...)`) — the new value is read separately via `secret get <key>` (process-lifetime ephemeral)"
  dont = "print the rotated value to stdout / stderr / log · pass it as argv to a downstream command · skip the sentinel (silent rotate masks operator intent)"
