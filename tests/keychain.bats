#!/usr/bin/env bats
# macOS code paths, exercised via the fake `security` shim on every host.

load 'helpers/common'

setup() {
  setup_sandbox
  use_macos
}

@test "save and use round-trip through the keychain" {
  write_keychain "$(oauth_blob A)"
  write_identity alice@example.com
  run "$CLSW" save alice
  [ "$status" -eq 0 ]
  [ "$(jq -r '.store' "$(profile_file alice)")" = "keychain" ]

  write_keychain "$(oauth_blob B)"
  write_identity bob@example.com
  run "$CLSW" save bob
  [ "$status" -eq 0 ]

  run "$CLSW" use alice
  [ "$status" -eq 0 ]
  [ "$(read_keychain)" = "$(oauth_blob A)" ]
  [ "$(jq -r '.oauthAccount.emailAddress' "$CLAUDE_JSON_PATH")" = "alice@example.com" ]
}

@test "a raw API key in the keychain is wrapped and restored raw" {
  printf '%s' "sk-ant-raw-key" > "$FAKE_KEYCHAIN/$PLAIN_SERVICE.secret"
  clear_identity
  run "$CLSW" save apiprof
  [ "$status" -eq 0 ]
  local f
  f="$(profile_file apiprof)"
  [ "$(jq -r '.store' "$f")" = "keychain-api-key" ]
  [ "$(jq -r '.tier' "$f")" = "api" ]
  [ "$(jq -r '.blob | fromjson | .primaryApiKey' "$f")" = "sk-ant-raw-key" ]

  # Overwrite with an OAuth login, then restore: the key must go back raw,
  # not wrapped in JSON.
  write_keychain "$(oauth_blob B)"
  write_identity bob@example.com
  run "$CLSW" save bob
  [ "$status" -eq 0 ]
  run "$CLSW" use apiprof
  [ "$status" -eq 0 ]
  [ "$(read_keychain)" = "sk-ant-raw-key" ]
}

@test "a managed API key in claude.json wins over the keychain" {
  write_keychain "$(oauth_blob A)"
  jq -n '{primaryApiKey: "sk-ant-managed"}' > "$CLAUDE_JSON_PATH"
  run "$CLSW" save carol
  [ "$status" -eq 0 ]
  local f
  f="$(profile_file carol)"
  [ "$(jq -r '.store' "$f")" = "state-api-key" ]
  [ "$(jq -r '.tier' "$f")" = "api" ]
  [ "$(jq -r '.blob | fromjson | .primaryApiKey' "$f")" = "sk-ant-managed" ]
}

@test "a credentials file wins over the keychain" {
  write_keychain "$(oauth_blob A)"
  write_creds_file "$(oauth_blob B)"
  write_identity bob@example.com
  run "$CLSW" save bob
  [ "$status" -eq 0 ]
  [ "$(jq -r '.store' "$(profile_file bob)")" = "file" ]
  [ "$(jq -r '.blob' "$(profile_file bob)")" = "$(oauth_blob B)" ]
}

@test "restoring a keychain profile clears the credentials file" {
  write_keychain "$(oauth_blob A)"
  write_identity alice@example.com
  run "$CLSW" save alice
  [ "$status" -eq 0 ]
  # A stray creds file would shadow the keychain on the next read.
  write_creds_file "$(oauth_blob C)"
  run bash -c "printf 'y\n' | '$CLSW' save other"
  [ "$status" -eq 0 ]
  run "$CLSW" use alice
  [ "$status" -eq 0 ]
  [ ! -f "$CREDS_FILE" ]
  [ "$(read_keychain)" = "$(oauth_blob A)" ]
}

@test "CLAUDE_CONFIG_DIR derives a suffixed keychain service" {
  export CLAUDE_CONFIG_DIR="$HOME/alt"
  local service
  service="$PLAIN_SERVICE-$(sha256_8 "$CLAUDE_CONFIG_DIR")"
  write_keychain "$(oauth_blob A)" "$service"
  write_identity alice@example.com "uid-a" "$CLAUDE_CONFIG_DIR/.claude.json"

  run "$CLSW" save alice
  [ "$status" -eq 0 ]
  [ "$(jq -r '.email' "$(profile_file alice)")" = "alice@example.com" ]
  # the plain-name service must not have been touched
  [ ! -f "$FAKE_KEYCHAIN/$PLAIN_SERVICE.secret" ]
}

@test "an empty CLAUDE_SECURESTORAGE_CONFIG_DIR forces the plain service" {
  export CLAUDE_CONFIG_DIR="$HOME/alt"
  export CLAUDE_SECURESTORAGE_CONFIG_DIR=""
  write_keychain "$(oauth_blob A)"
  write_identity alice@example.com "uid-a" "$CLAUDE_CONFIG_DIR/.claude.json"

  run "$CLSW" save alice
  [ "$status" -eq 0 ]
  [ "$(jq -r '.email' "$(profile_file alice)")" = "alice@example.com" ]
}
