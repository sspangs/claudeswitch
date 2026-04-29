# claudeswitch

A tiny CLI for juggling multiple Claude Code logins - e.g. a personal
Claude Max account and a work one - without having to `/logout` and
re-authenticate every time. Works on macOS, Linux, and Windows (via Git
Bash or WSL).

Save each login once, then swap between them in a single command. Optionally
set up a shell wrapper so each repo auto-picks the right account the first
time you run `claude` there.

Primary command: `claudeswitch`. Short alias: `clsw`.

```sh
clsw save personal
clsw save work
clsw use work        # now `claude` runs as your work account
clsw current         # -> work
```

## Requirements

- A POSIX shell: macOS, Linux, or Windows via Git Bash / WSL
- `bash` 3.2+
- [`jq`](https://jqlang.github.io/jq/)

Credentials live wherever Claude Code keeps them on your platform: the
macOS Keychain on macOS, or `~/.claude/.credentials.json` on Linux and
Windows. See [How it works](#how-it-works) for details.

## Install

```sh
./install.sh
```

That checks for `jq` (offers to `brew install` it on macOS, prints a
package-manager hint elsewhere), symlinks `claudeswitch` and `clsw` into
`~/.local/bin`, and offers to install the `claude` shell wrapper for your
shell. Re-running it is safe - the shell-rc block is replaced in place,
not duplicated.

Flags:

```
-y, --yes            non-interactive: accept all defaults
--uninstall          remove symlinks and shell wrapper
--bin-dir <dir>      install to <dir> instead of ~/.local/bin
--shell <name>       fish|bash|zsh|none (default: auto-detect from $SHELL)
```

### Manual install

If you'd rather wire it up yourself:

```sh
chmod +x claudeswitch
ln -s "$PWD/claudeswitch" ~/.local/bin/claudeswitch
ln -s "$PWD/claudeswitch" ~/.local/bin/clsw
# then set up the shell wrapper (see "Auto-switch per directory" below)
```

## Usage

### Profile management

```
clsw save <name>            snapshot the current login as <name>
clsw add  <name>            log in as a new account, then save it as <name>
clsw use  <name>            make <name> the active login
clsw list                   list saved profiles (marks active with *)
clsw current                print the name of the active profile
clsw rm <name>              delete a saved profile
```

### Per-directory auto-switching

```
clsw link [<profile> [dir]]   link current (or given) dir to a profile
clsw unlink [<dir>]           remove mapping for current (or given) dir
clsw which [<dir>]            show the effective profile for a dir
clsw default [<name>]         show / set the fallback profile
clsw default --clear          clear the fallback profile
clsw ensure                   internal: used by the shell wrapper
clsw init-shell <fish|bash|zsh>
                              print a 'claude' shell wrapper to eval
```

### A full walkthrough

```sh
# 1. Sign in as yourself in Claude Code, then snapshot it.
claude                          # /login, complete OAuth, quit
clsw save personal
# -> saved profile: personal (you@personal.example)

# 2. Add a second account. `clsw add` launches claude under a bypass
#    so the shell wrapper (if installed) won't intercept.
clsw add work
# follow the /logout + /login prompts, quit claude when done
# -> saved profile: work (you@company.example)

# 3. List them.
clsw list
#     NAME        EMAIL                      TIER      FLAGS
#   * work        you@company.example        max
#     personal    you@personal.example       max

# 4. Switch manually whenever you want.
clsw use personal
clsw current        # -> personal
```

### Auto-switch per directory (the shell wrapper)

Install the wrapper once so `claude` picks the right account based on the
directory you run it in.

```sh
# fish:
clsw init-shell fish | source
# and to persist it:
clsw init-shell fish > ~/.config/fish/functions/claude.fish

# bash:
eval "$(clsw init-shell bash)"
# and to persist it, append the same into ~/.bashrc

# zsh:
eval "$(clsw init-shell zsh)"
# and to persist it, append the same into ~/.zshrc
```

The first time you run `claude` in an unmanaged directory you'll get a
prompt:

```
[claudeswitch] no Claude profile set for: /Users/you/src/acme-api

  1) use personal  (you@personal.example)
  2) use work      (you@company.example)
  3) add a new profile (log in as another account)
  4) do not manage this directory
  5) set a default profile for all unmanaged dirs
choose [1-5, or q to cancel]:
```

Your choice is remembered for that directory (and its subdirectories) in
`~/.config/claudeswitch/repos.json`. Subsequent `claude` invocations inside
that tree switch accounts silently.

### Default fallback

If most of your repos should use the same account, set a default and skip
the prompt:

```sh
clsw default personal      # make 'personal' the fallback for unmanaged dirs
clsw default               # -> personal
clsw default --clear       # stop falling back; resume prompting
```

Resolution order when you run `claude`:

1. Explicit mapping for the cwd (or any ancestor) - use it.
2. No mapping, but a default is set - use the default silently.
3. No mapping and no default - prompt.

### Managing mappings

```sh
clsw link work               # link the cwd to 'work'
clsw link work ~/src/acme    # link a specific directory
clsw unlink                  # remove the mapping for cwd
clsw which                   # show what would be used here, and why
# -> work (inherited from /Users/you/src)
# -> personal (default)
# -> (unmanaged - mapped at /Users/you/throwaway)
```

Explicit links beat the default, so linking a repo pins it even if the
default already routes there today. Useful when a repo must always use a
specific account regardless of how you change the fallback later.

### Bypassing the wrapper

Set `CLAUDE_SWITCH_BYPASS=1` to skip `clsw ensure` for a single command:

```sh
CLAUDE_SWITCH_BYPASS=1 claude
```

`clsw add` sets this automatically when it launches `claude` for you to log
in, so you can safely `add` a new profile from inside any managed
directory.

## How it works

Claude Code stores its OAuth credentials as a single JSON blob. That blob -
not a config file - is what defines "who you're signed in as." Where the
blob lives depends on your platform, and `claudeswitch` reads and writes
from the same place Claude Code does:

- **macOS:** the system Keychain, service `Claude Code-credentials`
- **Linux / Windows:** `~/.claude/.credentials.json` (mode `0600`)

What each command does:

- `save <name>` reads the live blob and writes it to
  `~/.config/claudeswitch/profiles/<name>.json` (mode `0600`), along with
  an identity snapshot from `~/.claude.json` (`userID`, `oauthAccount`,
  `hasAvailableSubscription`). The snapshot is needed because Claude Code
  caches "who am I" in `~/.claude.json` and trusts that cache over the
  credential store for things like the displayed email and subscription
  state.
- `use <name>` writes the saved blob into the credential store and splices
  the saved identity subtree back into `~/.claude.json` so the UI matches
  the token.
- `current` / `list` identify the active profile by hashing the refresh
  token and matching against saved profiles.
- `ensure` (called by the shell wrapper) walks up from the cwd looking for
  a mapping in `~/.config/claudeswitch/repos.json`, falls back to the
  default, then prompts if neither exists.

State lives in `~/.config/claudeswitch/`:

```
profiles/<name>.json   # per-profile snapshot (mode 0600)
repos.json             # { "/abs/repo/path": "profile_name_or_-" }
default                # single line: default profile name
```

Nothing else is touched - no symlink swapping, no daemons, no background
state.

## Caveats

- **Restart `claude` after switching.** A running session holds its tokens
  in memory and won't notice the credential change until it's restarted.
- **Profile files contain live OAuth tokens.** They're written with mode
  `0600`, but treat `~/.config/claudeswitch/` the same way you'd treat
  `~/.ssh/` - don't commit it, don't sync it to places you don't trust.
- **Refresh tokens rotate.** After enough time, a saved profile's
  fingerprint may stop matching the live credential store, so `list` won't
  show a `*`. If that happens, just `clsw save <name>` again while that
  account is active - it's cheap and re-snaps the fingerprint.
- **macOS may prompt for Keychain access** the first time the script reads
  or writes the entry from a new terminal. Click "Always Allow" to skip
  future prompts.
- **Mappings are central, not in-repo.** `repos.json` lives in your home
  config dir so cloning a shared repo on a new machine won't silently pull
  in someone else's work/personal labels. The tradeoff: you re-link on a
  fresh machine.
- **First `save` requires you to be signed in.** If the credential store
  is empty, `save` fails with a clear message - sign in with `claude`
  first.
- **Only save right after `/login`.** `save` captures whatever is
  currently in the credential store AND whatever identity is currently
  cached in `~/.claude.json`. Those are only guaranteed to match right
  after a `/login`. If you've been switching back and forth manually, do
  a `/logout` + `/login` first to resync before saving.

## Uninstall

```sh
./install.sh --uninstall           # removes symlinks and the shell wrapper
rm -rf ~/.config/claudeswitch      # (optional) also remove saved profiles + mappings
```

This doesn't touch your stored credentials or `~/.claude.json`, so your
current Claude Code login remains intact.
