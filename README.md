# claudeswitch

[![ci](https://github.com/sspangs/claudeswitch/actions/workflows/ci.yml/badge.svg)](https://github.com/sspangs/claudeswitch/actions/workflows/ci.yml)

A tiny CLI for juggling multiple Claude Code logins - e.g. a personal
Claude Max account and a work one - without having to `/logout` and
re-authenticate every time. Works on macOS, Linux, and Windows (Git
Bash or WSL).

```sh
clsw save personal   # snapshot the login you're using right now
clsw add work        # log in as the second account, saved as 'work'
clsw use work        # now `claude` runs as your work account
clsw current         # -> work  you@company.example  [max]
```

## Install

Requires `bash` 3.2+ and [`jq`](https://jqlang.github.io/jq/).

```sh
./install.sh
```

Symlinks `claudeswitch` and `clsw` into `~/.local/bin` and offers the
shell wrapper + tab completions. Re-running is safe; `--help` lists
flags (`-y`, `--uninstall`, `--bin-dir`, `--shell`). Manual install:
symlink `claudeswitch` (and `clsw`) anywhere on your `PATH`.

## Commands

```
save <name>               snapshot the current login
add [--isolated] <name>   log in as a new account and save it
use <name>                make <name> the active login
isolate <name>            give <name> its own Claude config dir (see below)
env [--shell <s>] <name>  print env exports for an isolated profile
list / current / show     inspect profiles (tokens are never printed)
rename <old> <new>        rename a profile (updates links and default)
rm <name>                 delete a profile
link / unlink / links     map directories to profiles
which [<dir>]             what would be used in a dir, and why
default [<name>]          fallback profile for unmanaged dirs
doctor                    read-only health check with fix hints
paths / version / init-shell <shell> / completions <shell>
```

`list`, `current`, `show`, `links`, and `which` accept `--json` for
scripting. When something seems off, run `clsw doctor`.

## Auto-switch per directory

Install the wrapper once (`install.sh` offers this):

```sh
clsw init-shell fish > ~/.config/fish/functions/claude.fish  # fish
eval "$(clsw init-shell bash)"       # bash/zsh: persist in your rc file
```

The first `claude` in a new directory prompts you to pick a profile;
the choice is remembered for that directory tree. Resolution order:
explicit `link` beats `default` beats prompting. Bypass once with
`CLAUDE_SWITCH_BYPASS=1 claude`.

```sh
clsw link work            # link the cwd to 'work' and switch now
clsw default personal     # fallback for all unmanaged dirs
```

## Isolated profiles

A normal profile swaps credentials in and out of Claude Code's single
global login. Running sessions keep their account in memory, so
different tabs can already be on different accounts - but they all
share one credential store: every background token refresh writes to
the same slot, so concurrent sessions overwrite each other's rotated
tokens, and claudeswitch has to patch up the drift on every switch.

An **isolated** profile removes the sharing. It owns its own Claude
config dir under `~/.config/claudeswitch/homes/<name>`, and the wrapper
launches `claude` with `CLAUDE_CONFIG_DIR` pointing there - each
account refreshes into its own store, nothing fights, and switching
never touches a running session.

```sh
clsw isolate work         # convert an existing profile
clsw add --isolated ops   # or start one fresh
eval "$(clsw env work)"   # use without the wrapper (fish: ... | source)
```

Recommended setup: leave your main account global (so IDE extensions,
scripts, and plain `claude` all see it) and isolate the secondary ones.
The accounts then share nothing, and the main login keeps working from
every entry point, wrapper or not.

Tradeoffs: the home is a separate Claude Code world (its own history,
settings, MCP logins). Isolating the account you're currently logged in
as also logs out the global store - two copies of one refresh token
invalidate each other. `rm` on an isolated profile asks first, since it
deletes the only copy of that login. Wrappers installed before v0.3.0
must be reinstalled.

## How it works

Claude Code stores auth as one credential blob (macOS: Keychain service
`Claude Code-credentials`; elsewhere `~/.claude/.credentials.json`)
plus a "who am I" cache in `~/.claude.json`. `save` snapshots both into
`~/.config/claudeswitch/profiles/<name>.json` (mode `0600`). `use`
first re-snapshots the outgoing profile (refresh tokens rotate), then
writes the saved blob back and splices the identity cache so the UI
matches the token. `current`/`list` match by token fingerprint, falling
back to the cached email and the last profile activated - and report
"unsaved" instead of guessing when those disagree. Every mutation takes
a lock, so parallel shells can't corrupt a profile. All state lives in
`~/.config/claudeswitch/` - no daemons, no symlink games.

## Caveats

- Restart `claude` after switching a non-isolated profile - running
  sessions hold their tokens in memory.
- Profile files and homes hold live OAuth tokens. Treat
  `~/.config/claudeswitch/` like `~/.ssh/`.
- macOS: `security` briefly exposes the blob in `ps` output during
  writes, and may ask for Keychain access once per terminal (choose
  "Always Allow").
- `save` right after a `/login` (or a `clsw use`), when the credential
  store and the identity cache are guaranteed to agree.
- Directory mappings are per-machine, not stored in the repo.

## Development

`make check` runs shellcheck plus the bats suite (needs
[bats-core](https://github.com/bats-core/bats-core) >= 1.4). Tests run
in a per-test sandbox with fake `uname`/`security` shims, so both the
Keychain and file-store paths run on any host and your real credentials
are never touched. CI covers Ubuntu and macOS. Use the `assert_*`
helpers instead of bare `[[ ]]` - `make lint` enforces this, and
`tests/helpers/common.bash` explains why.

## Uninstall

```sh
./install.sh --uninstall        # removes symlinks and the shell wrapper
rm -rf ~/.config/claudeswitch   # optional: also remove profiles + mappings
```

Your current Claude Code login stays intact.
