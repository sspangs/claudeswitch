#!/usr/bin/env bats
# /login-managed API key profiles (stored in ~/.claude.json), Linux store.

load 'helpers/common'

setup() {
  setup_sandbox
  use_linux
}

@test "save captures a managed API key profile" {
  jq -n '{primaryApiKey: "sk-ant-test"}' > "$CLAUDE_JSON_PATH"
  run "$CLSW" save api1
  [ "$status" -eq 0 ]
  local f
  f="$(profile_file api1)"
  [ "$(jq -r '.store' "$f")" = "state-api-key" ]
  [ "$(jq -r '.tier' "$f")" = "api" ]
  [ "$(jq -r '.blob | fromjson | .primaryApiKey' "$f")" = "sk-ant-test" ]
}

@test "switching between an API key profile and an OAuth profile" {
  make_profile alice A alice@example.com
  jq -n '{primaryApiKey: "sk-ant-test"}' > "$CLAUDE_JSON_PATH"
  run "$CLSW" save api1
  [ "$status" -eq 0 ]

  run "$CLSW" use alice
  [ "$status" -eq 0 ]
  [ "$(cat "$CREDS_FILE")" = "$(oauth_blob A)" ]
  # switching to OAuth must remove the managed key or Claude Code sees
  # two identities at once
  [ "$(jq -r 'has("primaryApiKey")' "$CLAUDE_JSON_PATH")" = "false" ]
  [ "$(jq -r '.oauthAccount.emailAddress' "$CLAUDE_JSON_PATH")" = "alice@example.com" ]

  run "$CLSW" use api1
  [ "$status" -eq 0 ]
  [ "$(jq -r '.primaryApiKey' "$CLAUDE_JSON_PATH")" = "sk-ant-test" ]
  # and the reverse: OAuth identity and creds file must be gone
  [ "$(jq -r '.oauthAccount' "$CLAUDE_JSON_PATH")" = "null" ]
  [ ! -f "$CREDS_FILE" ]
}

@test "a drifted fingerprint never matches an API key profile" {
  jq -n '{primaryApiKey: "sk-ant-test"}' > "$CLAUDE_JSON_PATH"
  run "$CLSW" save api1
  [ "$status" -eq 0 ]
  # The managed key disappears and an unknown OAuth login shows up with no
  # cached email. The active record still says api1, but API keys do not
  # rotate, so api1 must be ruled out.
  printf '{}\n' > "$CLAUDE_JSON_PATH"
  write_creds_file "$(oauth_blob X)"
  run "$CLSW" current
  [ "$status" -eq 0 ]
  assert_contains "$output" "(unsaved"
}
