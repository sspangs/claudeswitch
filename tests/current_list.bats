#!/usr/bin/env bats

load 'helpers/common'

setup() {
  setup_sandbox
  use_linux
}

@test "current with no login" {
  run "$CLSW" current
  [ "$status" -eq 0 ]
  [ "$output" = "no active login" ]
}

@test "current reports an unsaved login with its email" {
  write_creds_file "$(oauth_blob A)"
  write_identity alice@example.com
  run "$CLSW" current
  [ "$status" -eq 0 ]
  [[ "$output" == *"(unsaved - alice@example.com)"* ]]
}

@test "current matches the active profile by fingerprint" {
  make_profile alice A alice@example.com
  run "$CLSW" current
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice"* ]]
  [[ "$output" == *"alice@example.com"* ]]
  [[ "$output" == *"[max]"* ]]
}

@test "current falls back to the cached email when the token rotated" {
  make_profile alice A alice@example.com
  write_creds_file "$(oauth_blob A2)"
  run "$CLSW" current
  [ "$status" -eq 0 ]
  [[ "$output" == alice* ]]
}

@test "current treats conflicting email and active record as unknown" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  # Live store now holds a rotated token; the cached email says alice but
  # the active record says bob. Guessing either way could corrupt a
  # profile on the next snapshot, so the answer must be "unsaved".
  write_creds_file "$(oauth_blob C)"
  write_identity alice@example.com
  run "$CLSW" current
  [ "$status" -eq 0 ]
  [[ "$output" == *"(unsaved - alice@example.com)"* ]]
}

@test "ambiguous email is resolved by the active record" {
  make_profile work A shared@example.com
  make_profile personal B shared@example.com
  # Rotated token, and two profiles share the cached email; the active
  # record (personal, saved last) breaks the tie.
  write_creds_file "$(oauth_blob C)"
  write_identity shared@example.com
  run "$CLSW" current
  [ "$status" -eq 0 ]
  [[ "$output" == personal* ]]
}

@test "a credential-less live blob matches no profile" {
  make_profile alice A alice@example.com
  write_creds_file '{"mcpOAuth":{}}'
  run "$CLSW" current
  [ "$status" -eq 0 ]
  [[ "$output" == *"(unsaved"* ]]
}

@test "list shows all profiles, marks active and default" {
  make_profile alice A alice@example.com
  make_profile bob B bob@example.com
  run "$CLSW" default alice
  [ "$status" -eq 0 ]
  run "$CLSW" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
  [[ "$output" == *"* bob"* ]]
  local alice_line
  alice_line="$(printf '%s\n' "$output" | grep ' alice ')"
  [[ "$alice_line" == *"default"* ]]
  [[ "$alice_line" != "*"* ]]
}

@test "list with no profiles prints a hint" {
  run "$CLSW" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"no saved profiles"* ]]
}
