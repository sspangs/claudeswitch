#!/usr/bin/env bats

load 'helpers/common'

setup() {
  setup_sandbox
  use_linux
  write_creds_file "$(oauth_blob A)"
  write_identity alice@example.com
  mkdir -p "$CLSW_ROOT"
  LOCK_DIR="$CLSW_ROOT/.lock"
}

@test "a stale lock from a dead process is stolen" {
  mkdir -p "$LOCK_DIR"
  # A shell that has already exited: its pid is (almost certainly) dead.
  local dead_pid
  dead_pid="$(bash -c 'echo $$')"
  printf '%s' "$dead_pid" > "$LOCK_DIR/pid"

  run "$CLSW" save alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"saved profile: alice"* ]]
  [ ! -d "$LOCK_DIR" ]
}

@test "a lock held by a live process times out with a helpful error" {
  mkdir -p "$LOCK_DIR"
  printf '%s' "$$" > "$LOCK_DIR/pid"  # this bats process: alive

  CLAUDESWITCH_LOCK_TIMEOUT=1 run "$CLSW" save alice
  [ "$status" -eq 1 ]
  [[ "$output" == *"timed out waiting for lock"* ]]
  [[ "$output" == *"$LOCK_DIR"* ]]
  rm -rf "$LOCK_DIR"
}

@test "a lock with no pid file is not stolen" {
  mkdir -p "$LOCK_DIR"

  CLAUDESWITCH_LOCK_TIMEOUT=1 run "$CLSW" save alice
  [ "$status" -eq 1 ]
  [[ "$output" == *"timed out waiting for lock"* ]]
  rm -rf "$LOCK_DIR"
}

@test "the lock is released after a successful mutation" {
  run "$CLSW" save alice
  [ "$status" -eq 0 ]
  [ ! -d "$LOCK_DIR" ]
}
