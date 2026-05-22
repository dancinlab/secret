# Changelog

Chronological log of notable changes. One section per ship batch, date-keyed.

For the full audit trail, see `git log`.

---

## 2026-05-22

- **0.4.0 — dual-channel sync** — keychain blob (encrypted at rest with the user-chosen master password) pushed/pulled via two independent channels: iCloud Drive file-level sync + an optional private GitHub mirror, each with its own on/off toggle. Auto-push is ON by default once a channel is enabled — `SECRET_BACKUP_AUTO` becomes an opt-out only.
- **iCloud-synced keychain** — dedicated keychain file synced across the user's Macs via iCloud Drive; `secret init` / `secret migrate` admin verbs added.
- **0.3.1** — accept piped values without a trailing newline.
- **0.3.0 — initial release** — macOS Keychain-backed credential CLI; single bash script, zero dependencies (system `security` CLI). Master password independent of Apple ID.
