#!/usr/bin/env bats

load 'helpers/common'

setup() {
  setup_sandbox
  use_linux
}

@test "use restores the saved blob and splices the identity back" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com

  run "$CLSW" use alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to profile: alice"* ]]
  [ "$(cat "$CREDS_FILE")" = "$(oauth_blob A)" ]
  [ "$(jq -r '.oauthAccount.emailAddress' "$CLAUDE_JSON_PATH")" = "alice@example.com" ]
  [ "$(jq -r '.userID' "$CLAUDE_JSON_PATH")" = "uid-alice@example.com" ]
  [ "$(cat "$CLSW_ROOT/active")" = "alice" ]
}

@test "use snapshots a rotated token into the outgoing profile" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  run "$CLSW" use alice
  [ "$status" -eq 0 ]

  # Claude Code rotates alice's refresh token behind our back.
  write_creds_file "$(oauth_blob A2)"

  run "$CLSW" use bob
  [ "$status" -eq 0 ]
  [[ "$output" == *"snapshotted refreshed credentials into profile: alice"* ]]
  [ "$(jq -r '.blob' "$(profile_file alice)")" = "$(oauth_blob A2)" ]
  [ "$(cat "$CREDS_FILE")" = "$(oauth_blob B)" ]
}

@test "use refuses a missing profile" {
  run "$CLSW" use ghost
  [ "$status" -eq 1 ]
  [[ "$output" == *"no such profile: ghost"* ]]
}

@test "use refuses a profile whose blob has no Claude login" {
  mkdir -p "$CLSW_ROOT/profiles"
  jq -n '{blob: "{\"mcpOAuth\":{}}", email: "x@example.com", tier: "max", store: "file", identity: null}' \
    > "$(profile_file broken)"
  run "$CLSW" use broken
  [ "$status" -eq 1 ]
  [[ "$output" == *"has no Claude login"* ]]
}

@test "use without an identity snapshot clears the stale cached identity" {
  # alice was saved while ~/.claude.json had no identity.
  write_creds_file "$(oauth_blob A)"
  clear_identity
  run "$CLSW" save alice
  [ "$status" -eq 0 ]
  make_profile bob B bob@example.com

  run "$CLSW" use alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"no identity snapshot"* ]]
  [ "$(jq -r '.oauthAccount' "$CLAUDE_JSON_PATH")" = "null" ]
  [ "$(jq -r '.hasAvailableSubscription' "$CLAUDE_JSON_PATH")" = "false" ]
}

@test "rm deletes the profile and cleans up references" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  run "$CLSW" default alice
  [ "$status" -eq 0 ]
  mkdir -p "$HOME/repo"
  run "$CLSW" link alice "$HOME/repo"
  [ "$status" -eq 0 ]
  run "$CLSW" use alice
  [ "$status" -eq 0 ]

  run "$CLSW" rm alice
  [ "$status" -eq 0 ]
  [ ! -f "$(profile_file alice)" ]
  [ ! -f "$CLSW_ROOT/active" ]
  [ ! -f "$CLSW_ROOT/default" ]
  [ "$(jq -r 'length' "$CLSW_ROOT/repos.json")" = "0" ]
}

@test "rm refuses a missing profile" {
  run "$CLSW" rm ghost
  [ "$status" -eq 1 ]
  [[ "$output" == *"no such profile: ghost"* ]]
}
