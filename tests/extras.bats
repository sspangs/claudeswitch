#!/usr/bin/env bats
# links, rename, show, version, doctor, completions, --json output.

load 'helpers/common'

setup() {
  setup_sandbox
  use_linux
}

@test "version prints the version" {
  run "$CLSW" version
  [ "$status" -eq 0 ]
  assert_starts_with "$output" "claudeswitch "
  run "$CLSW" --version
  [ "$status" -eq 0 ]
}

@test "links lists all mappings with markers" {
  make_profile alice A alice@example.com
  mkdir -p "$HOME/repo1" "$HOME/repo2" "$HOME/repo3"
  run "$CLSW" link alice "$HOME/repo1"
  jq --arg a "$HOME/repo2" --arg b "$HOME/repo3" \
    '.[$a] = "-" | .[$b] = "ghost"' "$CLSW_ROOT/repos.json" \
    > "$CLSW_ROOT/repos.json.tmp"
  mv "$CLSW_ROOT/repos.json.tmp" "$CLSW_ROOT/repos.json"

  run "$CLSW" links
  [ "$status" -eq 0 ]
  assert_contains "$output" "$HOME/repo1 -> alice"
  assert_contains "$output" "$HOME/repo2 -> (unmanaged)"
  assert_contains "$output" "$HOME/repo3 -> ghost  (missing profile)"
}

@test "links with no mappings says so" {
  run "$CLSW" links
  [ "$status" -eq 0 ]
  [ "$output" = "no mappings." ]
  run "$CLSW" links --json
  [ "$output" = "[]" ]
}

@test "links --json emits structured mappings" {
  make_profile alice A alice@example.com
  mkdir -p "$HOME/repo1"
  run "$CLSW" link alice "$HOME/repo1"
  run "$CLSW" links --json
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.[0].dir')" = "$HOME/repo1" ]
  [ "$(printf '%s' "$output" | jq -r '.[0].profile')" = "alice" ]
  [ "$(printf '%s' "$output" | jq -r '.[0].missing')" = "false" ]
}

@test "rename moves the profile and updates every reference" {
  make_profile alice A alice@example.com
  mkdir -p "$HOME/repo"
  run "$CLSW" link alice "$HOME/repo"
  run "$CLSW" default alice

  run "$CLSW" rename alice work
  [ "$status" -eq 0 ]
  [ ! -f "$(profile_file alice)" ]
  [ -f "$(profile_file work)" ]
  [ "$(cat "$CLSW_ROOT/active")" = "work" ]
  [ "$(cat "$CLSW_ROOT/default")" = "work" ]
  [ "$(jq -r --arg k "$HOME/repo" '.[$k]' "$CLSW_ROOT/repos.json")" = "work" ]
}

@test "rename refuses collisions and missing profiles" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  run "$CLSW" rename alice bob
  [ "$status" -eq 1 ]
  assert_contains "$output" "already exists"
  run "$CLSW" rename ghost new
  [ "$status" -eq 1 ]
  assert_contains "$output" "no such profile"
}

@test "show prints metadata but never the tokens" {
  make_profile alice A alice@example.com
  run "$CLSW" show alice
  [ "$status" -eq 0 ]
  assert_contains "$output" "alice@example.com"
  assert_contains "$output" "store:             file"
  assert_contains "$output" "identity snapshot: yes"
  assert_not_contains "$output" "rt-A"
  assert_not_contains "$output" "at-A"
}

@test "show --json emits metadata without the blob" {
  make_profile alice A alice@example.com
  run "$CLSW" show --json alice
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.name')" = "alice" ]
  [ "$(printf '%s' "$output" | jq -r '.email')" = "alice@example.com" ]
  [ "$(printf '%s' "$output" | jq -r '.identity_snapshot')" = "true" ]
  [ "$(printf '%s' "$output" | jq -r 'has("blob")')" = "false" ]
  assert_not_contains "$output" "rt-A"
}

@test "current --json covers active, unsaved, and none" {
  run "$CLSW" current --json
  [ "$(printf '%s' "$output" | jq -r '.status')" = "none" ]

  write_creds_file "$(oauth_blob A)"
  write_identity alice@example.com
  run "$CLSW" current --json
  [ "$(printf '%s' "$output" | jq -r '.status')" = "unsaved" ]
  [ "$(printf '%s' "$output" | jq -r '.email')" = "alice@example.com" ]

  run "$CLSW" save alice
  run "$CLSW" current --json
  [ "$(printf '%s' "$output" | jq -r '.status')" = "active" ]
  [ "$(printf '%s' "$output" | jq -r '.profile')" = "alice" ]
  [ "$(printf '%s' "$output" | jq -r '.tier')" = "max" ]
}

@test "list --json marks active and default" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  run "$CLSW" default alice
  run "$CLSW" list --json
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r 'length')" = "2" ]
  [ "$(printf '%s' "$output" | jq -r '.[] | select(.name == "bob") | .active')" = "true" ]
  [ "$(printf '%s' "$output" | jq -r '.[] | select(.name == "alice") | .default')" = "true" ]
  run "$CLSW" list --json
  [ "$(printf '%s' "$output" | jq -r '.[] | select(.name == "alice") | .active')" = "false" ]
}

@test "which --json reports source and profile" {
  make_profile alice A alice@example.com
  mkdir -p "$HOME/repo/sub"
  run "$CLSW" link alice "$HOME/repo"
  run "$CLSW" which --json "$HOME/repo/sub"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.source')" = "inherited" ]
  [ "$(printf '%s' "$output" | jq -r '.profile')" = "alice" ]
  [ "$(printf '%s' "$output" | jq -r '.mapped_at')" = "$HOME/repo" ]

  run "$CLSW" which --json "$HOME"
  [ "$(printf '%s' "$output" | jq -r '.source')" = "none" ]
  [ "$(printf '%s' "$output" | jq -r '.profile')" = "null" ]
}

@test "doctor is healthy on a good setup" {
  make_profile alice A alice@example.com
  run "$CLSW" doctor
  [ "$status" -eq 0 ]
  assert_contains "$output" "live login present"
  assert_contains "$output" "live login matches profile: alice"
  assert_contains "$output" "profile 'alice' looks healthy"
  assert_contains "$output" "0 problems"
}

@test "doctor fails on a corrupt profile" {
  make_profile alice A alice@example.com
  mkdir -p "$CLSW_ROOT/profiles"
  echo 'not json' > "$(profile_file broken)"
  run "$CLSW" doctor
  [ "$status" -eq 1 ]
  assert_contains "$output" "FAIL: profile 'broken' is not valid JSON"
  assert_contains "$output" "1 problem(s)"
}

@test "doctor flags a credential-less profile" {
  jq -n '{blob: "{\"mcpOAuth\":{}}", email: "", tier: "max", store: "file", identity: null}' \
    > "$(mkdir -p "$CLSW_ROOT/profiles" && profile_file empty)"
  run "$CLSW" doctor
  [ "$status" -eq 1 ]
  assert_contains "$output" "FAIL: profile 'empty' holds no Claude login"
}

@test "doctor warns about broken mappings, missing default, stale lock" {
  make_profile alice A alice@example.com
  printf '%s\n' "{\"$HOME/gone\": \"ghost\"}" > "$CLSW_ROOT/repos.json"
  printf '%s\n' "ghost" > "$CLSW_ROOT/default"
  mkdir -p "$CLSW_ROOT/.lock"
  run "$CLSW" doctor
  [ "$status" -eq 0 ]
  assert_contains "$output" "points at a missing profile"
  assert_contains "$output" "mapped directory no longer exists"
  assert_contains "$output" "default profile 'ghost' does not exist"
  assert_contains "$output" "stale lock"
  rm -rf "$CLSW_ROOT/.lock"
}

@test "completions emit for each shell and reject others" {
  run "$CLSW" completions fish
  [ "$status" -eq 0 ]
  assert_contains "$output" "complete -c clsw"
  assert_contains "$output" "__fish_seen_subcommand_from"
  run "$CLSW" completions bash
  [ "$status" -eq 0 ]
  assert_contains "$output" "complete -F _claudeswitch claudeswitch clsw"
  run "$CLSW" completions zsh
  [ "$status" -eq 0 ]
  assert_contains "$output" "bashcompinit"
  run "$CLSW" completions
  [ "$status" -eq 1 ]
}

@test "bash completions actually complete subcommands and profiles" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  run bash -c "
    eval \"\$('$CLSW' completions bash)\"
    COMP_WORDS=(clsw us); COMP_CWORD=1; COMPREPLY=()
    _claudeswitch; echo \"\${COMPREPLY[@]}\"
    COMP_WORDS=(clsw use al); COMP_CWORD=2; COMPREPLY=()
    PATH='$(dirname "$CLSW")':\$PATH _claudeswitch; echo \"\${COMPREPLY[@]}\"
  "
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "use" ]
  [ "${lines[1]}" = "alice" ]
}

@test "_profiles lists profile names for completion scripts" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  run "$CLSW" _profiles
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "alice" ]
  [ "${lines[1]}" = "bob" ]
}
