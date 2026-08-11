#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/secret-get-output.XXXXXX")
STORE_DIR="$TEST_ROOT/store"

cleanup() {
  [ ! -f "$STORE_DIR/store.enc" ] || unlink "$STORE_DIR/store.enc"
  [ ! -d "$STORE_DIR" ] || rmdir "$STORE_DIR"
  [ ! -d "$TEST_ROOT" ] || rmdir "$TEST_ROOT"
}
trap cleanup EXIT

secret() {
  env SECRET_MASTER=test-master \
    SECRET_GITHUB_PATH="$STORE_DIR" \
    SECRET_BACKUP_AUTO=0 \
    "$ROOT_DIR/bin/secret" "$@"
}

assert_hex() {
  local key="$1" expected="$2" actual
  actual=$(secret get "$key" | od -An -tx1 | tr -d ' \n')
  [ "$actual" = "$expected" ] || {
    printf 'get output mismatch for %s: expected %s, got %s\n' \
      "$key" "$expected" "$actual" >&2
    exit 1
  }
}

secret set token alpha >/dev/null 2>&1
assert_hex token 616c7068610a

printf 'first\nsecond' | secret set multiline >/dev/null 2>&1
assert_hex multiline 66697273740a7365636f6e640a

printf 'line\n' | secret set terminated >/dev/null 2>&1
assert_hex terminated 6c696e650a0a

captured=$(secret get token)
[ "$captured" = alpha ]

if secret get absent >/dev/null 2>&1; then
  printf 'missing key unexpectedly succeeded\n' >&2
  exit 1
fi

printf 'get output: ok\n'
