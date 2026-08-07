# Shared helpers for the claudeswitch bats suite.
#
# Every test runs in a throwaway sandbox: HOME, XDG_CONFIG_HOME, and the
# fake keychain all live under $BATS_TEST_TMPDIR, and tests/fakebin is
# prepended to PATH so `uname` (platform forcing) and `security` (keychain)
# are shims. Nothing a test does can touch the real credential store.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
CLSW="$REPO_ROOT/claudeswitch"
FAKEBIN="$REPO_ROOT/tests/fakebin"

PLAIN_SERVICE="Claude Code-credentials"

setup_sandbox() {
  mkdir -p "$BATS_TEST_TMPDIR/home"
  # Resolve symlinks now (macOS /tmp -> /private/tmp) so paths written by
  # abs_dir/pwd -P match what tests compare against.
  HOME="$(cd "$BATS_TEST_TMPDIR/home" && pwd -P)"
  export HOME
  export XDG_CONFIG_HOME="$HOME/.config"
  export FAKE_KEYCHAIN="$BATS_TEST_TMPDIR/keychain"
  mkdir -p "$FAKE_KEYCHAIN"
  unset CLAUDE_CONFIG_DIR CLAUDE_JSON CLAUDE_SECURESTORAGE_CONFIG_DIR
  unset CLAUDESWITCH_CLAUDE_BIN CLAUDESWITCH_LOCK_TIMEOUT CLAUDE_SWITCH_BYPASS
  case ":$PATH:" in
    *":$FAKEBIN:"*) ;;
    *) export PATH="$FAKEBIN:$PATH" ;;
  esac

  CLSW_ROOT="$XDG_CONFIG_HOME/claudeswitch"
  CREDS_FILE="$HOME/.claude/.credentials.json"
  CLAUDE_JSON_PATH="$HOME/.claude.json"
}

use_linux() { export FAKE_UNAME=Linux; }
use_macos() { export FAKE_UNAME=Darwin; }

profile_file() { printf '%s/profiles/%s.json' "$CLSW_ROOT" "$1"; }

# --- assertions ------------------------------------------------------------
# bash 3.2 (macOS /bin/bash) has an errexit bug: a failing bare [[ ]] does
# NOT abort the test, so [[-based assertions silently pass. These helpers
# are plain commands - their failure always propagates - and they print
# the expectation and the actual text on mismatch.

assert_contains() {  # $1 = haystack, $2 = needle
  case "$1" in *"$2"*) return 0 ;; esac
  { echo "expected to contain: $2"; echo "actual:"; printf '%s\n' "$1"; } >&2
  return 1
}

assert_not_contains() {  # $1 = haystack, $2 = needle
  case "$1" in
    *"$2"*)
      { echo "expected NOT to contain: $2"; echo "actual:"; printf '%s\n' "$1"; } >&2
      return 1
      ;;
  esac
  return 0
}

assert_starts_with() {  # $1 = text, $2 = prefix
  case "$1" in "$2"*) return 0 ;; esac
  { echo "expected to start with: $2"; echo "actual:"; printf '%s\n' "$1"; } >&2
  return 1
}

assert_line_matches() {  # $1 = text, $2 = ERE matched against any line
  if printf '%s\n' "$1" | grep -qE "$2"; then return 0; fi
  { echo "expected a line matching: $2"; echo "actual:"; printf '%s\n' "$1"; } >&2
  return 1
}

assert_no_line_matches() {  # $1 = text, $2 = ERE
  if printf '%s\n' "$1" | grep -qE "$2"; then
    { echo "expected no line matching: $2"; echo "actual:"; printf '%s\n' "$1"; } >&2
    return 1
  fi
  return 0
}

# --- fixtures --------------------------------------------------------------

# A syntactically realistic OAuth credential blob; $1 seeds the tokens so
# distinct seeds produce distinct fingerprints.
oauth_blob() {
  jq -cn --arg t "$1" \
    '{claudeAiOauth: {accessToken: ("at-" + $t), refreshToken: ("rt-" + $t),
      expiresAt: 4102444800000, scopes: ["user:inference"], subscriptionType: "max"}}'
}

write_creds_file() {  # $1 = blob
  mkdir -p "$HOME/.claude"
  printf '%s' "$1" > "$CREDS_FILE"
  chmod 600 "$CREDS_FILE"
}

write_keychain() {  # $1 = blob, $2 = service (default: plain)
  local service="${2:-$PLAIN_SERVICE}"
  printf '%s' "$1" > "$FAKE_KEYCHAIN/$service.secret"
  printf '%s' "testuser" > "$FAKE_KEYCHAIN/$service.acct"
}

read_keychain() {  # $1 = service (default: plain)
  cat "$FAKE_KEYCHAIN/${1:-$PLAIN_SERVICE}.secret"
}

write_identity() {  # $1 = email, [$2 = userID], [$3 = path]
  local path="${3:-$CLAUDE_JSON_PATH}"
  mkdir -p "$(dirname "$path")"
  jq -n --arg e "$1" --arg u "${2:-uid-$1}" \
    '{userID: $u,
      oauthAccount: {emailAddress: $e, accountUuid: ("uuid-" + $u)},
      hasAvailableSubscription: true}' > "$path"
}

clear_identity() {
  printf '{}\n' > "$CLAUDE_JSON_PATH"
}

# Fabricate a saved profile end to end via the real `save` path (Linux
# file store): $1 = name, $2 = token seed, $3 = email.
make_profile() {
  write_creds_file "$(oauth_blob "$2")"
  write_identity "$3"
  run "$CLSW" save "$1"
  [ "$status" -eq 0 ] || { echo "make_profile $1 failed: $output" >&2; return 1; }
}

sha256_8() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-8
  else
    printf '%s' "$1" | sha256sum | cut -c1-8
  fi
}
