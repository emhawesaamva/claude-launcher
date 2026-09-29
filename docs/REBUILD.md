# Rebuilding the two-profile Claude setup from scratch

Runbook for recreating everything if the machine or the config directories are
wiped. Read [PROFILES.md](PROFILES.md) first for what each piece does.
All files referenced as `config/…` are in this folder.

> **Testing status:** the file contents, paths and settings below come from the live setup on 2026-09-29. The install/login/`claude mcp add` commands were assembled from it but **not run end-to-end** — expect to adjust a flag or two the first time.

Set a variable for this folder so the commands below work (adjust if it moved):

```bash
K="$HOME/Documents/Projects/Tools/claude-launcher"
```

**If the whole Mac was lost, this folder is lost too** unless you kept a copy
off-machine. Restore the folder first (backup / private repo), then continue.

## What you will need on hand

- Work login: `m*****@aamva.org` (AAMVA organization, SSO/email link)
- Personal login: `h*****@gmail.com`
- Atlassian access for `twg` (work).

## 1. Prerequisites

```bash
# Homebrew: https://brew.sh
brew install fzf jq uv            # picker menus, statusline JSON parsing, uvx for Music MCP
brew install --cask ghostty       # terminal the launcher opens
# nvm/Node are sourced by .zshrc but Claude Code itself does not need them
```

## 2. Install Claude Code (native)

```bash
curl -fsSL https://claude.ai/install.sh | bash     # installs ~/.local/bin/claude
claude --version
```

`~/.local/bin` must be on `PATH` (the `.zshrc` in step 4 does this). Auto-update
was turned **off** in both profiles; update manually with `claude update`.

## 3. Restore the launcher

```bash
cd "$K"
make check        # optional: sanity-check the sources
make install      # builds the app (with icon) and installs the picker, statusline and app
xattr -dr com.apple.quarantine ~/Applications/"Claude Launcher.app" 2>/dev/null || true
```

`make install` puts `claude-project-launcher.sh` in `~/.local/bin`, the
statusline at `~/.claude-statusline.sh` and `Claude Launcher.app` in
`~/Applications`. It never touches `~/.zshrc` or the profile folders (steps 4–5).
The app is rebuilt from `src/app/` + `assets/icon.png`, so no prebuilt bundle is
needed.

## 4. Restore the shell setup

```bash
cp ~/.zshrc ~/.zshrc.pre-restore 2>/dev/null || true
cp "$K/config/shell/zshrc" ~/.zshrc                    # aliases + profile-aware claude() function
# (~/.claude-statusline.sh was already installed by `make install` in step 3)
exec zsh
```

Check: `type claude` says "claude is a shell function"; `alias | grep claude-`
shows `claude-work` and `claude-personal`.

## 5. Recreate the profile directories and static config

```bash
mkdir -p ~/.claude-work ~/.claude-personal
cp "$K/config/work/settings.json"     ~/.claude-work/settings.json
cp "$K/config/personal/settings.json" ~/.claude-personal/settings.json
# CLAUDE.md holds your real account emails, so the repo stores templates only.
# This prompts for the two addresses (or reads config/local.env, or $WORK_EMAIL / $PERSONAL_EMAIL):
(cd "$K" && make render-config)
```

Do **not** copy `config/work/plugins/*.json` — they hold absolute install paths
and are written by Claude Code when you install the plugin in step 8. They are a
reference only.

## 6. Log in to each profile

```bash
claude-work        # /login  → m*****@aamva.org (AAMVA)
# exit, then:
claude-personal    # /login  → h*****@gmail.com
```

Inside each, `/status` should show the right account. Logins land in the macOS
Keychain (`Claude Code-credentials-…`). After login the claude.ai **connectors**
(Gmail, Calendar, Vercel, Supabase, …) and account **synced skills** appear on
their own — authorise connectors in claude.ai → Settings → Connectors if asked.

## 7. Tag the projects

```bash
cd ~/Documents/Projects
touch AAMVA-Wiki/.work
touch AudioLib-io/.personal Email-Processing/.personal Music/.personal \
      "OCR Batman RPG/.personal" Personal-Assets-Inventory/.personal
touch Tools/.work Tools/.personal
```

Restore the project folders themselves from their own backups / git remotes
(AudioLib-io: `github.com/emhawesaamva/audiobook-library`).

## 8. Work-only extras

**Vercel plugin** (inside `claude-work`):

```
/plugin marketplace add anthropics/claude-plugins-official
/plugin install vercel@claude-plugins-official
```

`enabledPlugins` in the restored `settings.json` already lists it.

**`twg` (Atlassian CLI)** — the binary lives at `~/.local/bin/twg`; the original
install source is **not recorded here** (obtain from Atlassian's internal docs).
Then:

```bash
twg login
twg help skills            # `twg skills install` puts skills in ~/.agents/skills
ls -l ~/.claude-work/skills   # each twg* entry should be a symlink to ~/.agents/skills/twg*
```

If the symlinks are missing after installing skills, create them:
`for s in ~/.agents/skills/twg*; do ln -s "$s" ~/.claude-work/skills/; done`.
The read-only command allowlist is already in the restored `settings.json`.

## 9. MCP servers

Run each with the right `CLAUDE_CONFIG_DIR`. Project-scoped ones must be run
from that project's folder (default `local` scope is stored per project).

```bash
# Work
cd ~/Documents/Projects/AAMVA-Wiki
CLAUDE_CONFIG_DIR="$HOME/.claude-work" command claude mcp add --transport http wisprflow https://api.wisprflow.ai/connect/mcp
cd ~/Documents/Projects/Music
CLAUDE_CONFIG_DIR="$HOME/.claude-work" command claude mcp add apple-music -- uvx applemusic-mcp serve

# Personal
cd ~/Documents/Projects/Music
CLAUDE_CONFIG_DIR="$HOME/.claude-personal" command claude mcp add applemusic -- uvx --from "applemusic-mcp[browser]" applemusic-mcp serve
```

Check with `claude-work mcp list` / `claude-personal mcp list` (or `/mcp` inside a session).

## 10. Desktop apps and Chrome (optional)

1. Install **Claude.app** from claude.ai/download.
2. Make the work instance: `ditto /Applications/Claude.app "/Applications/Claude Work.app"`.
3. Launch it as its own instance: `cp "$K/desktop/launch-claude-work.command" ~/Documents/Projects/ && chmod +x ~/Documents/Projects/launch-claude-work.command`, then run it.
4. Optional: restore the Automator app with `ditto "$K/desktop/Claude for Work.app" "/Applications/Claude for Work.app"`, or recreate **Claude for Work.app** with one "Run Shell Script" action containing
   `open -n "/Applications/Claude Work.app" --args --user-data-dir="$HOME/Library/Application Support/Claude-Work"`.
5. Install the Claude Chrome extension and sign in. The native-messaging manifests in
   `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/` are written by the apps/Claude Code
   (`claude-work` → `~/.claude-work/chrome/chrome-native-host`); re-run `/chrome` inside `claude-work` if they're missing.

## 11. Verify

| Check | Expected |
|---|---|
| `type claude` | shell function |
| In `~/Documents/Projects/AAMVA-Wiki`: `claude` | prints `→ claude (work)`, statusline `[WORK]` |
| In `~/Documents/Projects/Music`: `claude` | prints `→ claude (personal)`, statusline `[PERSONAL]` |
| In `~/Documents/Projects/Tools`: `claude` | asks `[w]ork / [p]ersonal?` |
| `open ~/Applications/"Claude Launcher.app"` | Ghostty window with the ORANGE logo, then Profile → Project menus |
| Launcher, Work | lists AAMVA-Wiki, Tools (and any untagged folders); not AudioLib-io |
| Launcher, Personal | lists AudioLib-io, Email-Processing, Music, OCR Batman RPG, Personal-Assets-Inventory, Tools |
| `/status` in each profile | correct account; model shows Sonnet |
| `claude-work` then ask a Jira question | uses `twg` skills (work only) |

## What cannot be restored from this folder

- Conversation history, per-profile memory (`projects/*/memory`), per-project permission approvals — unless you back up `~/.claude-work` / `~/.claude-personal` separately (they can contain secrets and client data; keep those backups private).
- The Keychain logins (re-created in step 6) and any MCP credentials.
- The original `twg` install source and the Claude Work.app duplicate (step 8 / step 10).

Keep this folder current: edit launcher code in `src/` and run `make install`;
after changing live config (`~/.zshrc`, profile settings) run `make snapshot`.
`make diff` shows whether the installed files match the repo.
