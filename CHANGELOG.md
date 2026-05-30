# Changelog

Chronological log of notable changes. One section per ship batch, date-keyed.

For the full audit trail, see `git log`.

---

## 2026-05-31

- **0.6.0 — macOS Keychain 의존 제거 (in-memory openssl 암호화 store)** — 백엔드를 macOS Keychain(`security` CLI)에서 단일 openssl 암호화 파일 `store.enc`로 교체. Keychain은 GUI(Aqua) 보안세션에 바인딩돼 ssh·헤드리스에서 `secret get`이 빈값을 반환했는데(`User interaction is not allowed`), 새 백엔드는 세션 무관 파일이라 Mac·mini(ssh)·linux 어디서나 동작.
  - **암호화**: `openssl enc -aes-256-cbc -pbkdf2 -salt -iter 200000`. 마스터 비밀번호는 fd(process substitution)로 전달 — argv 노출 없음.
  - **store 포맷**: 평문은 라인당 `key<TAB>base64(value)`. base64 인코딩으로 멀티라인·ssh키·텍스트 바이너리(PEM/cert) 안전.
  - **마스터 비밀번호 소스**: `$SECRET_MASTER`(env) → `~/.config/secret/master`(0600 파일) → tty 프롬프트. argv 절대 미허용. 헤드리스: `SECRET_MASTER=… secret get <key>`.
  - **평문 디스크 기록 0**: 복호화는 변수/stdout(in-memory)만. `set` = 복호화→수정→재암호화→원자적 write(ciphertext `mktemp .store.enc.* → mv`). 평문 임시파일 없음.
  - **keychain 제거**: get·set·rotate·check·list·delete hot-path의 `security find-generic-password`/`add-generic-password` 전부 제거. `security` 잔존은 `migrate --from-keychain` 1회용 reader에만.
  - **verb surface 유지**: get·set·rotate·check·delete·list·backup·sync·init·migrate (CLI 호환). high-value 보호(BIP39·xprv·WIF refuse), rotate(`openssl rand`), `SECRET_BACKUP_AUTO` 자동 백업, git backup/sync 로직 보존.
  - **migrate 재정의**: `secret migrate --from-keychain [--purge-source]` — 구 keychain 전 키를 store.enc로 1회 import + 라운드트립 검증. 키체인 read는 GUI 세션 필요 → Mac Terminal.app에서 실행. 기존 `dancinlab.keychain-db`는 롤백 안전망으로 보존.

---

## 2026-05-30

- **0.5.0 — iCloud Drive 채널 폐기 (github 단일 채널)** — `secret init icloud` 백엔드와 iCloud 관련 코드(`_do_init_icloud`·backend resolver의 iCloud 탐지·init github의 iCloud 마이그레이션 분기·help/README의 iCloud 서술)를 전부 제거. 동기화는 이제 **private git repo 단일 채널**: 키체인 암호화 blob을 git으로만 push/pull 한다. 동기 = Apple ID 불필요·헤드리스/ssh 가능(iCloud TCC·Files & Folders 권한 프롬프트 없음). `secret init icloud` 는 `unknown backend 'icloud' (expected: github)` 로 거부. 기존 git 백엔드·mirror(`backup enable`)·migrate 동작은 무변경. macOS Keychain 저장·마스터 비밀번호 모델도 그대로.

## 2026-05-25

- **0.4.1 — 64-hex 하드 거부 완화 (경고로 강등)** — `set`에서 모든 64자리 hex 값을 "지갑급 개인키"로 오인해 거부하던 false positive 수정. 64-hex는 SHA-256 다이제스트·R2 secret access key·HMAC 키 등 합법 시크릿이 훨씬 흔해 차단이 부적절했음. 자기식별 가능한 지갑 포맷(BIP39 니모닉·xprv/xpub·WIF)만 하드 거부를 유지하고, 64-hex는 한 줄 경고 후 그대로 저장(argv 허용). R2 secret access key(`sha256(token)` = 64-hex) 저장이 `--allow-mnemonic` 없이 가능해짐.

---

## 2026-05-22

- **0.4.0 — dual-channel sync** — keychain blob (encrypted at rest with the user-chosen master password) pushed/pulled via two independent channels: iCloud Drive file-level sync + an optional private GitHub mirror, each with its own on/off toggle. Auto-push is ON by default once a channel is enabled — `SECRET_BACKUP_AUTO` becomes an opt-out only.
- **iCloud-synced keychain** — dedicated keychain file synced across the user's Macs via iCloud Drive; `secret init` / `secret migrate` admin verbs added.
- **0.3.1** — accept piped values without a trailing newline.
- **0.3.0 — initial release** — macOS Keychain-backed credential CLI; single bash script, zero dependencies (system `security` CLI). Master password independent of Apple ID.
