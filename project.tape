@V := "tape" :: spec [active]
  version = "1.2"

@I := "secret" :: identity [active]
  kind     = "macOS Keychain-backed credential CLI (bash · zero deps · dual-channel sync · 🔐)"
  brief    = "Keychain credential CLI · service-namespaced · dual sync (iCloud Drive file + private GitHub mirror)"
  parent   = "dancinlab"
  ssot     = "github.com/dancinlab/secret"
  siblings = "hexa-lang"

@D s1 := "Keychain is the SSOT — no plaintext secret files" :: governance [required active]
  do   = "all secret storage via `security add/find-generic-password` · `$SECRET_SERVICE`-namespaced · dedicated `$SECRET_KEYCHAIN`"
  dont = "write secrets to repo / local files · echo into shell history · cache plaintext outside Keychain · co-mingle with login keychain"

@D s2 := "macOS-only — fail fast on other OS" :: governance [required active]
  do   = "rely on the macOS `security` CLI · sync via iCloud Drive file-level + GitHub encrypted-blob mirror"
  dont = "Linux / Windows fallback paths in this CLI · degrade to file storage on non-mac · set kSecAttrSynchronizable (needs entitlement)"

@D s3 := "high-value secrets — refuse by default" :: governance [required active]
  do   = "auto-detect wallet-grade secrets on `set` (BIP39 · xprv / WIF · 64-hex) and REFUSE — override = `--allow-mnemonic` + stdin/tty"
  dont = "accept a high-value value via argv (`ps aux` leak) · auto-promote argv · store wallet seeds without override + stdin/tty"

@D s4 := "rotate emits a sentinel only" :: governance [required active]
  do   = "`secret rotate` generates via /dev/urandom, stores via `security`, emits a sentinel line only"
  dont = "print the rotated value to stdout / stderr / log · pass it as downstream argv · skip the sentinel"

@D s5 := "master password is the trust root" :: governance [required active]
  do   = "master password = SOLE decryption secret · strong + unique, independent of Apple ID · enable ADP for defense-in-depth"
  dont = "store the master password in any synced location · reuse the login password · add an Apple-ID-derived fallback unlock"

@D s6 := "migration tools pin explicit keychain paths" :: governance [required active]
  do   = "`secret migrate` / copy helpers pin explicit source + dest keychain paths · assert source ≠ dest · log both in the banner"
  dont = "use the implicit default keychain / user search list in a copy loop — enumerates source + dest → purges both → data loss"

@D s7 := "GitHub mirror = same encrypted blob, auto-push ON" :: governance [required active]
  do   = "`backup` / `sync` push the encrypted blob AS-IS to a PRIVATE git repo · auto-push ON by default · disable keychain auto-lock at init"
  dont = "public mirror repo · parallel plaintext-export path · gate auto-push behind an opt-in env var · leave keychain auto-lock at defaults"
