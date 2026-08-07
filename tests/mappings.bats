#!/usr/bin/env bats

load 'helpers/common'

setup() {
  setup_sandbox
  use_linux
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  REPO="$HOME/repo"
  mkdir -p "$REPO/sub"
}

@test "link cwd records the mapping and activates the profile" {
  cd "$REPO"
  run "$CLSW" link alice
  [ "$status" -eq 0 ]
  [ "$(jq -r --arg k "$REPO" '.[$k]' "$CLSW_ROOT/repos.json")" = "alice" ]
  # live creds switched to alice right away
  [ "$(cat "$CREDS_FILE")" = "$(oauth_blob A)" ]
}

@test "link a different dir records the mapping without switching" {
  run "$CLSW" link alice "$REPO"
  [ "$status" -eq 0 ]
  [ "$(jq -r --arg k "$REPO" '.[$k]' "$CLSW_ROOT/repos.json")" = "alice" ]
  # still bob (the last profile saved)
  [ "$(cat "$CREDS_FILE")" = "$(oauth_blob B)" ]
}

@test "link refuses a missing profile" {
  run "$CLSW" link ghost "$REPO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no such profile: ghost"* ]]
}

@test "unlink removes the mapping" {
  run "$CLSW" link alice "$REPO"
  run "$CLSW" unlink "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unlinked"* ]]
  [ "$(jq -r --arg k "$REPO" 'has($k)' "$CLSW_ROOT/repos.json")" = "false" ]
}

@test "unlink without a mapping says so" {
  run "$CLSW" unlink "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no mapping"* ]]
}

@test "which reports linked, inherited, default, and none" {
  run "$CLSW" which "$REPO"
  [[ "$output" == *"no mapping, no default"* ]]

  run "$CLSW" link alice "$REPO"
  run "$CLSW" which "$REPO"
  [ "$output" = "alice (linked)" ]

  run "$CLSW" which "$REPO/sub"
  [ "$output" = "alice (inherited from $REPO)" ]

  run "$CLSW" default bob
  run "$CLSW" which "$HOME"
  [ "$output" = "bob (default)" ]
}

@test "which reports an unmanaged dir" {
  printf '%s\n' "{\"$REPO\": \"-\"}" > "$CLSW_ROOT/repos.json"
  run "$CLSW" which "$REPO/sub"
  [ "$output" = "(unmanaged - mapped at $REPO)" ]
}

@test "default set, show, and clear" {
  run "$CLSW" default
  [ "$output" = "(no default set)" ]
  run "$CLSW" default alice
  [ "$status" -eq 0 ]
  run "$CLSW" default
  [ "$output" = "alice" ]
  run "$CLSW" default --clear
  [ "$status" -eq 0 ]
  run "$CLSW" default
  [ "$output" = "(no default set)" ]
}

@test "default refuses a missing profile" {
  run "$CLSW" default ghost
  [ "$status" -eq 1 ]
  [[ "$output" == *"no such profile: ghost"* ]]
}

@test "ensure switches to the mapped profile" {
  run "$CLSW" link alice "$REPO"
  run "$CLSW" ensure "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to profile: alice"* ]]
  [ "$(cat "$CREDS_FILE")" = "$(oauth_blob A)" ]
}

@test "ensure is silent when the mapped profile is already active" {
  run "$CLSW" link alice "$REPO"
  run "$CLSW" ensure "$REPO"
  run "$CLSW" ensure "$REPO"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ensure leaves an unmanaged dir alone" {
  printf '%s\n' "{\"$REPO\": \"-\"}" > "$CLSW_ROOT/repos.json"
  run "$CLSW" ensure "$REPO"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "$CREDS_FILE")" = "$(oauth_blob B)" ]
}

@test "ensure falls back to the default when the mapped profile is missing" {
  printf '%s\n' "{\"$REPO\": \"ghost\"}" > "$CLSW_ROOT/repos.json"
  run "$CLSW" default alice
  run "$CLSW" ensure "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"missing profile 'ghost'"* ]]
  [[ "$output" == *"switched to profile: alice"* ]]
}

@test "ensure uses the default for unmapped dirs" {
  run "$CLSW" default alice
  run "$CLSW" ensure "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to profile: alice"* ]]
}

@test "ensure warns when a linked profile file disappeared" {
  run "$CLSW" link alice "$REPO"
  rm "$(profile_file alice)"
  run "$CLSW" default bob
  run "$CLSW" ensure "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"falling through"* ]]
}
