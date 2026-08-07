#!/usr/bin/env bats
# Isolated profiles: per-profile CLAUDE_CONFIG_DIR homes.

load 'helpers/common'

setup() {
  setup_sandbox
  use_linux
  HOMES="$CLSW_ROOT/homes"
}

@test "isolate converts a blob profile into a home" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  # give the primary claude.json a comfort field to inherit
  jq '.theme = "dark"' "$CLAUDE_JSON_PATH" > "$CLAUDE_JSON_PATH.tmp"
  mv "$CLAUDE_JSON_PATH.tmp" "$CLAUDE_JSON_PATH"

  run "$CLSW" isolate alice
  [ "$status" -eq 0 ]
  assert_contains "$output" "isolated profile: alice"

  local home="$HOMES/alice" f
  [ -d "$home" ]
  # credentials moved into the home's own store
  [ "$(cat "$home/.credentials.json")" = "$(oauth_blob A)" ]
  # identity and comfort fields seeded into the home's .claude.json
  [ "$(jq -r '.oauthAccount.emailAddress' "$home/.claude.json")" = "alice@example.com" ]
  [ "$(jq -r '.theme' "$home/.claude.json")" = "dark" ]
  # envelope rewritten: isolated, no blob
  f="$(profile_file alice)"
  [ "$(jq -r '.mode' "$f")" = "isolated" ]
  [ "$(jq -r '.home' "$f")" = "$home" ]
  [ "$(jq -r 'has("blob")' "$f")" = "false" ]
}

@test "isolating the active profile clears the global login" {
  make_profile alice A alice@example.com
  run "$CLSW" isolate alice
  [ "$status" -eq 0 ]
  assert_contains "$output" "cleared the global login"
  [ ! -f "$CREDS_FILE" ]
  [ "$(jq -r '.oauthAccount' "$CLAUDE_JSON_PATH")" = "null" ]
  [ ! -f "$CLSW_ROOT/active" ]
}

@test "isolating a non-active profile leaves the global login alone" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  run "$CLSW" isolate alice
  [ "$status" -eq 0 ]
  assert_not_contains "$output" "cleared the global login"
  [ "$(cat "$CREDS_FILE")" = "$(oauth_blob B)" ]
}

@test "isolate refuses an already-isolated or empty profile" {
  make_profile alice A alice@example.com
  run "$CLSW" isolate alice
  [ "$status" -eq 0 ]
  run "$CLSW" isolate alice
  [ "$status" -eq 1 ]
  assert_contains "$output" "already isolated"
  run "$CLSW" isolate ghost
  [ "$status" -eq 1 ]
  assert_contains "$output" "no such profile: ghost"
}

@test "use refuses an isolated profile with guidance" {
  make_profile alice A alice@example.com
  run "$CLSW" isolate alice
  run "$CLSW" use alice
  [ "$status" -eq 1 ]
  assert_contains "$output" "is isolated"
  assert_contains "$output" "env alice"
}

@test "save refuses an isolated profile" {
  make_profile alice A alice@example.com
  run "$CLSW" isolate alice
  write_creds_file "$(oauth_blob B)"
  run "$CLSW" save alice
  [ "$status" -eq 1 ]
  assert_contains "$output" "never needs saving"
}

@test "env prints export lines for bash and fish" {
  make_profile alice A alice@example.com
  run "$CLSW" isolate alice
  run "$CLSW" env --shell bash alice
  [ "$status" -eq 0 ]
  assert_contains "$output" "export CLAUDE_CONFIG_DIR='$HOMES/alice'"
  assert_contains "$output" "export CLAUDE_SECURESTORAGE_CONFIG_DIR='$HOMES/alice'"
  run "$CLSW" env --shell fish alice
  [ "$status" -eq 0 ]
  assert_contains "$output" "set -gx CLAUDE_CONFIG_DIR '$HOMES/alice'"
  run "$CLSW" env --shell bash ghost
  [ "$status" -eq 1 ]
}

@test "env refuses a blob profile" {
  make_profile alice A alice@example.com
  run "$CLSW" env --shell bash alice
  [ "$status" -eq 1 ]
  assert_contains "$output" "not isolated"
}

@test "ensure prints the home dir for an isolated mapping" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  run "$CLSW" isolate alice
  mkdir -p "$HOME/repo"
  run "$CLSW" link alice "$HOME/repo"

  run "$CLSW" ensure "$HOME/repo"
  [ "$status" -eq 0 ]
  # stdout carries exactly the home dir; the global store stays bob's
  [ "${lines[${#lines[@]}-1]}" = "$HOMES/alice" ]
  [ "$(cat "$CREDS_FILE")" = "$(oauth_blob B)" ]
}

@test "ensure stays silent on stdout for blob profiles" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  mkdir -p "$HOME/repo"
  run "$CLSW" link alice "$HOME/repo"
  run bash -c "'$CLSW' ensure '$HOME/repo' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the bash wrapper launches claude inside the isolated home" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  run "$CLSW" isolate alice
  mkdir -p "$HOME/repo" "$HOME/bin"
  run "$CLSW" link alice "$HOME/repo"

  # fake claude that reports which config dir it was launched with
  cat > "$HOME/bin/claude" <<'EOF'
#!/usr/bin/env bash
echo "CFG=${CLAUDE_CONFIG_DIR:-none}"
EOF
  chmod +x "$HOME/bin/claude"
  ln -s "$CLSW" "$HOME/bin/claudeswitch"

  run bash -c "
    export PATH='$HOME/bin':\$PATH
    eval \"\$(claudeswitch init-shell bash)\"
    cd '$HOME/repo' && claude
  "
  [ "$status" -eq 0 ]
  assert_contains "$output" "CFG=$HOMES/alice"

  # in an unmanaged-with-default dir, the blob profile keeps global mode
  run "$CLSW" default bob
  run bash -c "
    export PATH='$HOME/bin':\$PATH
    eval \"\$(claudeswitch init-shell bash)\"
    cd '$HOME' && claude
  "
  [ "$status" -eq 0 ]
  assert_contains "$output" "CFG=none"
}

@test "current identifies an isolated session via CLAUDE_CONFIG_DIR" {
  make_profile alice A alice@example.com
  run "$CLSW" isolate alice
  run bash -c "CLAUDE_CONFIG_DIR='$HOMES/alice' '$CLSW' current"
  [ "$status" -eq 0 ]
  assert_contains "$output" "alice"
  assert_contains "$output" "(isolated)"
  run bash -c "CLAUDE_CONFIG_DIR='$HOMES/alice' '$CLSW' current --json"
  [ "$(printf '%s' "$output" | jq -r '.profile')" = "alice" ]
  [ "$(printf '%s' "$output" | jq -r '.isolated')" = "true" ]
}

@test "an isolated profile is never claimed by the email fallback" {
  make_profile alice A alice@example.com
  run "$CLSW" isolate alice
  # A global login shows up with alice's cached email but an unknown
  # token. Claiming the isolated profile would corrupt it on snapshot.
  write_creds_file "$(oauth_blob X)"
  write_identity alice@example.com
  run "$CLSW" current
  [ "$status" -eq 0 ]
  assert_contains "$output" "(unsaved - alice@example.com)"
}

@test "list flags isolated profiles and reads live email from the home" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  run "$CLSW" isolate alice
  # the home's identity changes; list should show the live value
  jq '.oauthAccount.emailAddress = "new@example.com"' \
    "$HOMES/alice/.claude.json" > "$HOMES/alice/.claude.json.tmp"
  mv "$HOMES/alice/.claude.json.tmp" "$HOMES/alice/.claude.json"

  run "$CLSW" list
  [ "$status" -eq 0 ]
  assert_line_matches "$output" '^ +alice +new@example.com .* isolated'
  run "$CLSW" list --json
  [ "$(printf '%s' "$output" | jq -r '.[] | select(.name == "alice") | .mode')" = "isolated" ]
  [ "$(printf '%s' "$output" | jq -r '.[] | select(.name == "bob") | .mode')" = "blob" ]
}

@test "show reports mode and home for an isolated profile, no tokens" {
  make_profile alice A alice@example.com
  run "$CLSW" isolate alice
  run "$CLSW" show alice
  [ "$status" -eq 0 ]
  assert_contains "$output" "mode:        isolated"
  assert_contains "$output" "home:        $HOMES/alice"
  assert_not_contains "$output" "rt-A"
  run "$CLSW" show --json alice
  [ "$(printf '%s' "$output" | jq -r '.mode')" = "isolated" ]
  [ "$(printf '%s' "$output" | jq -r 'has("blob")')" = "false" ]
}

@test "rm on an isolated profile prompts and deletes the home" {
  make_profile alice A alice@example.com
  run "$CLSW" isolate alice
  run bash -c "printf 'n\n' | '$CLSW' rm alice"
  [ "$status" -eq 1 ]
  [ -d "$HOMES/alice" ]
  run bash -c "printf 'y\n' | '$CLSW' rm alice"
  [ "$status" -eq 0 ]
  [ ! -d "$HOMES/alice" ]
  [ ! -f "$(profile_file alice)" ]
}

@test "doctor checks isolated homes" {
  make_profile alice A alice@example.com
  run "$CLSW" isolate alice
  run "$CLSW" doctor
  [ "$status" -eq 0 ]
  assert_contains "$output" "isolated profile 'alice' looks healthy"

  rm -rf "$HOMES/alice"
  run "$CLSW" doctor
  [ "$status" -eq 1 ]
  assert_contains "$output" "missing its home"
}

@test "on macOS, isolate writes to the home's derived keychain service" {
  use_macos
  write_keychain "$(oauth_blob A)"
  write_identity alice@example.com
  run "$CLSW" save alice
  [ "$status" -eq 0 ]
  run "$CLSW" isolate alice
  [ "$status" -eq 0 ]

  local home service
  home="$HOMES/alice"
  service="$PLAIN_SERVICE-$(sha256_8 "$home")"
  [ "$(read_keychain "$service")" = "$(oauth_blob A)" ]
  # active profile: the global keychain entry must be gone
  [ ! -f "$FAKE_KEYCHAIN/$PLAIN_SERVICE.secret" ]
}
