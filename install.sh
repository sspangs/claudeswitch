#!/usr/bin/env bash
# install.sh - set up claudeswitch on this machine.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_MAIN="$SCRIPT_DIR/claudeswitch"

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
ASSUME_YES=0
ACTION=install
SHELL_CHOICE=""

MARKER_START="# >>> claudeswitch >>>"
MARKER_END="# <<< claudeswitch <<<"

die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '[install] %s\n' "$*" >&2; }
ok()   { printf '[install] OK: %s\n' "$*" >&2; }

usage() {
  cat <<EOF
install.sh - set up claudeswitch on this machine.

Usage: ./install.sh [flags]

Flags:
  -y, --yes            non-interactive: accept all defaults
  --uninstall          remove symlinks and shell wrapper
  --bin-dir <dir>      install to <dir> instead of ~/.local/bin
  --shell <name>       fish|bash|zsh|none (default: auto-detect from \$SHELL)
  -h, --help           show this message

What it does:
  1. Verifies macOS and installs jq if missing (via Homebrew).
  2. Symlinks 'claudeswitch' and 'clsw' into ~/.local/bin.
  3. Optionally installs the 'claude' shell wrapper for fish/bash/zsh.
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -y|--yes)    ASSUME_YES=1 ;;
      --uninstall) ACTION=uninstall ;;
      --bin-dir)   [ $# -ge 2 ] || die "--bin-dir requires a directory"; BIN_DIR="$2"; shift ;;
      --shell)     [ $# -ge 2 ] || die "--shell requires a name"; SHELL_CHOICE="$2"; shift ;;
      -h|--help)   usage; exit 0 ;;
      *) die "unknown flag: $1 (try --help)" ;;
    esac
    shift
  done
}

confirm() {
  local prompt="$1" default="${2:-n}" yn
  if [ "$ASSUME_YES" -eq 1 ]; then
    [ "$default" = "y" ]; return
  fi
  if [ "$default" = "y" ]; then
    printf '%s [Y/n] ' "$prompt" >&2
  else
    printf '%s [y/N] ' "$prompt" >&2
  fi
  IFS= read -r yn </dev/tty || return 1
  yn="${yn:-$default}"
  [[ "$yn" =~ ^[Yy]$ ]]
}

require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "claudeswitch only supports macOS (uses the Keychain)"
}

detect_shell() {
  if [ -n "$SHELL_CHOICE" ]; then
    echo "$SHELL_CHOICE"; return
  fi
  case "$(basename "${SHELL:-}")" in
    fish) echo fish ;;
    bash) echo bash ;;
    zsh)  echo zsh  ;;
    *)    echo ""   ;;
  esac
}

ensure_jq() {
  if command -v jq >/dev/null 2>&1; then
    ok "jq is installed"
    return
  fi
  if ! command -v brew >/dev/null 2>&1; then
    die "jq is required. Install Homebrew (https://brew.sh), then run: brew install jq"
  fi
  if confirm "jq is not installed. Install it via Homebrew now?" y; then
    brew install jq
    ok "jq installed"
  else
    die "jq is required; aborting"
  fi
}

install_symlinks() {
  [ -f "$REPO_MAIN" ] || die "can't find claudeswitch at $REPO_MAIN"
  chmod +x "$REPO_MAIN"
  mkdir -p "$BIN_DIR"
  ln -sf "$REPO_MAIN" "$BIN_DIR/claudeswitch"
  ln -sf "$REPO_MAIN" "$BIN_DIR/clsw"
  ok "linked claudeswitch and clsw into $BIN_DIR"
}

remove_symlinks() {
  local f target
  for f in "$BIN_DIR/claudeswitch" "$BIN_DIR/clsw"; do
    if [ -L "$f" ]; then
      target="$(readlink "$f")"
      if [ "$target" = "$REPO_MAIN" ]; then
        rm -f "$f"
        ok "removed $f"
      else
        info "skipping $f (not pointing at this repo: $target)"
      fi
    fi
  done
}

rc_file_for_shell() {
  case "$1" in
    bash) echo "$HOME/.bashrc" ;;
    zsh)  echo "$HOME/.zshrc"  ;;
  esac
}

write_fish_wrapper() {
  local dir="$HOME/.config/fish/functions"
  local file="$dir/claude.fish"
  mkdir -p "$dir"
  "$REPO_MAIN" init-shell fish > "$file"
  ok "wrote fish wrapper to $file"
}

remove_fish_wrapper() {
  local file="$HOME/.config/fish/functions/claude.fish"
  if [ -f "$file" ] && grep -q 'claudeswitch' "$file"; then
    rm -f "$file"
    ok "removed $file"
  fi
}

strip_rc_block() {
  local rc="$1"
  [ -f "$rc" ] || return 0
  if grep -qF "$MARKER_START" "$rc"; then
    local tmp
    tmp="$(mktemp)"
    awk -v s="$MARKER_START" -v e="$MARKER_END" '
      $0 == s { skip=1; next }
      $0 == e { skip=0; next }
      !skip
    ' "$rc" > "$tmp"
    mv "$tmp" "$rc"
    ok "removed wrapper block from $rc"
  fi
}

write_rc_wrapper() {
  local shell="$1" rc wrapper
  rc="$(rc_file_for_shell "$shell")"
  [ -n "$rc" ] || return 0
  touch "$rc"
  strip_rc_block "$rc"
  # Ensure the rc ends with a newline so our block starts cleanly.
  if [ -s "$rc" ] && [ "$(tail -c1 "$rc" | wc -l)" -eq 0 ]; then
    printf '\n' >> "$rc"
  fi
  wrapper="$("$REPO_MAIN" init-shell "$shell")"
  {
    printf '%s\n' "$MARKER_START"
    printf '# Managed by install.sh. Run ./install.sh --uninstall to remove.\n'
    printf '%s\n' "$wrapper"
    printf '%s\n' "$MARKER_END"
  } >> "$rc"
  ok "added wrapper block to $rc"
}

maybe_install_wrapper() {
  local shell
  shell="$(detect_shell)"
  if [ -z "$shell" ] || [ "$shell" = "none" ]; then
    info "no shell wrapper installed (run 'claudeswitch init-shell <shell>' manually)"
    return
  fi
  if ! confirm "Install the '$shell' wrapper so 'claude' auto-switches per repo?" y; then
    info "skipping shell wrapper; you can install it later with 'claudeswitch init-shell $shell'"
    return
  fi
  case "$shell" in
    fish)     write_fish_wrapper ;;
    bash|zsh) write_rc_wrapper "$shell" ;;
    *) info "unknown shell: $shell; skipping" ;;
  esac
}

remove_wrapper() {
  remove_fish_wrapper
  strip_rc_block "$HOME/.bashrc"
  strip_rc_block "$HOME/.zshrc"
}

path_notice() {
  case ":$PATH:" in
    *":$BIN_DIR:"*) return ;;
  esac
  info ""
  info "NOTE: $BIN_DIR is not on your PATH. Add it with:"
  info "  fish:  fish_add_path $BIN_DIR"
  info "  bash:  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc"
  info "  zsh:   echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc"
}

do_install() {
  require_macos
  ensure_jq
  install_symlinks
  maybe_install_wrapper
  path_notice
  info ""
  info "Done. Try: clsw help"
  info "Open a new shell to pick up the wrapper."
}

do_uninstall() {
  remove_symlinks
  remove_wrapper
  info ""
  info "Uninstalled. Saved profiles at ~/.config/claudeswitch/ were left in place."
  info "Your Keychain entry and ~/.claude.json were not touched."
}

main() {
  parse_args "$@"
  case "$ACTION" in
    install)   do_install ;;
    uninstall) do_uninstall ;;
  esac
}

main "$@"
