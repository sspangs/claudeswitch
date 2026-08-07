#!/usr/bin/env bats

load 'helpers/common'

setup() {
  setup_sandbox
  use_linux
}

@test "save refuses when no login exists" {
  run "$CLSW" save alice
  [ "$status" -eq 1 ]
  [[ "$output" == *"no active Claude Code login"* ]]
}

@test "save rejects invalid profile names" {
  run "$CLSW" save 'bad/name'
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid profile name"* ]]
}

@test "save captures blob, email, tier, store, and identity" {
  local blob
  blob="$(oauth_blob A)"
  write_creds_file "$blob"
  write_identity alice@example.com

  run "$CLSW" save alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"saved profile: alice (alice@example.com)"* ]]

  local f
  f="$(profile_file alice)"
  [ -f "$f" ]
  [ "$(jq -r '.blob' "$f")" = "$blob" ]
  [ "$(jq -r '.email' "$f")" = "alice@example.com" ]
  [ "$(jq -r '.tier' "$f")" = "max" ]
  [ "$(jq -r '.store' "$f")" = "file" ]
  [ "$(jq -r '.identity.oauthAccount.emailAddress' "$f")" = "alice@example.com" ]
  [ "$(jq -r '.identity.userID' "$f")" = "uid-alice@example.com" ]
}

@test "save records the profile as the active record" {
  make_profile alice A alice@example.com
  [ "$(cat "$CLSW_ROOT/active")" = "alice" ]
}

@test "save refuses a credential-less blob (logged-out store)" {
  write_creds_file '{"mcpOAuth":{"someServer":{"accessToken":"x"}}}'
  write_identity alice@example.com
  run "$CLSW" save alice
  [ "$status" -eq 1 ]
  [[ "$output" == *"no Claude login"* ]]
  [ ! -f "$(profile_file alice)" ]
}

@test "save with no identity in claude.json records a null identity" {
  write_creds_file "$(oauth_blob A)"
  clear_identity
  run "$CLSW" save alice
  [ "$status" -eq 0 ]
  [ "$(jq -r '.identity' "$(profile_file alice)")" = "null" ]
}

@test "re-saving the same account skips the overwrite prompt" {
  make_profile alice A alice@example.com
  # stdin closed: if save prompted, the read would fail and abort.
  run bash -c "'$CLSW' save alice </dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"saved profile: alice"* ]]
}

@test "overwriting with a different account prompts, and 'n' aborts" {
  make_profile alice A alice@example.com
  write_creds_file "$(oauth_blob B)"
  write_identity bob@example.com
  run bash -c "printf 'n\n' | '$CLSW' save alice"
  [ "$status" -eq 1 ]
  [[ "$output" == *"aborted"* ]]
  [ "$(jq -r '.email' "$(profile_file alice)")" = "alice@example.com" ]
}

@test "overwriting with a different account proceeds on 'y'" {
  make_profile alice A alice@example.com
  write_creds_file "$(oauth_blob B)"
  write_identity bob@example.com
  run bash -c "printf 'y\n' | '$CLSW' save alice"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.email' "$(profile_file alice)")" = "bob@example.com" ]
}
