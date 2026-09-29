# Claude profiles — how they work

Reference for the two-profile Claude setup on this Mac (Work and Personal).
For rebuilding from scratch see [REBUILD.md](REBUILD.md). Snapshot date: **2026-09-29**.

> Anything marked **(unverified)** was not confirmed when this was written.
> Secrets are deliberately **not** stored in this folder — see [Secrets](#secrets).

## 1. The idea

Claude Code keeps *everything* about an identity in one config directory:
login, settings, `CLAUDE.md`, memory, history, plugins, skills, MCP servers and
per-project permission approvals. Pointing the `CLAUDE_CONFIG_DIR` environment
variable at a different directory gives a completely separate identity. The
whole setup is just three such directories and the machinery that picks one.

| | **Work** | **Personal** |
|---|---|---|
| Config dir | `~/.claude-work` | `~/.claude-personal` |
| Account | `m*****@aamva.org` (organization: AAMVA) | `h*****@gmail.com` (own organization) |
| Project marker | `.work` | `.personal` |
| Shell alias | `claude-work` | `claude-personal` |
| Statusline tag | cyan `[WORK]` | magenta `[PERSONAL]` |
| Default model | `sonnet` | `sonnet` |
| Default permission mode | `acceptEdits` | Claude Code default |
| Full-screen TUI | yes | yes |

The old third profile, `~/.claude` (used by plain `claude` before 2026-09-29),
was retired — see [History](#7-history-of-this-setup).

## 2. What is shared and what is separate

**Shared by both profiles**

- The `claude` binary: `~/.local/bin/claude` → `~/.local/share/claude/versions/<version>` (native install, auto-update **off** in both profiles).
- `~/.zshrc` (aliases + the `claude` function), `~/.claude-statusline.sh`, the launcher app and script.
- The project folders in `~/Documents/Projects`.
- Homebrew tools: `fzf`, `jq`; Ghostty terminal.

**Separate per profile (all inside the config dir)**

| Item | Where |
|---|---|
| Login credentials | macOS Keychain, service `Claude Code-credentials-<hash>` (the suffix appears to be derived from the config dir — **unverified**). Not in the folder. |
| Settings | `settings.json` |
| Global instructions | `CLAUDE.md` |
| Memory | `projects/<path-with-dashes>/memory/` |
| Conversations / history | `projects/`, `history.jsonl`, `sessions/` |
| MCP servers, per-project approvals, onboarding state | `.claude.json` (**contains secrets**) |
| Plugins | `plugins/` |
| Skills | `skills/` (`synced/` comes from the claude.ai account) |
| Chrome integration | `chrome/` |

Because memory is per profile, a project tagged for both (e.g. `Tools`) has
**two independent memories** — one seen from each profile.

## 3. How a profile gets chosen

Three entry points, all of which end in `CLAUDE_CONFIG_DIR=<dir> claude --allow-dangerously-skip-permissions`
(that flag only makes "bypass permissions" *available* in the Shift+Tab cycle; it is not on by default).

1. **`claude-work` / `claude-personal`** (aliases in `~/.zshrc`) — explicit.
2. **Plain `claude`** — a shell function in `~/.zshrc` (`config/shell/zshrc`). Order of decision:
   1. `CLAUDE_CONFIG_DIR` already set → use it (this is how the launcher and nested runs work).
   2. Walk up from the current directory to `$HOME` looking for `.work` / `.personal`. Exactly one kind found → use that profile and print `→ claude (work|personal)`.
   3. Both kinds, or none → ask `[w]ork / [p]ersonal?` (any other key cancels).
   4. No terminal to ask on (script/pipe) → print an error and exit 1. It **never** silently falls back to a default profile.
3. **Claude Launcher.app** → Ghostty → `claude-project-launcher.sh` (section 4).

## 4. Claude Launcher

`Claude Launcher.app` (installed in `~/Applications`) is a 2-file bundle:
`Info.plist` and `Contents/MacOS/claude-launcher`, a bash script that runs

```bash
open -na "/Applications/Ghostty.app" --args -e "$HOME/.local/bin/claude-project-launcher.sh"
```

Bundle id `com.local.claude-launcher`. The bundle is not stored in the repo:
`make app` builds it from `src/app/Info.plist`, `src/app/claude-launcher` and the
icon `assets/icon.png` (applied as the bundle's custom Finder icon, which macOS
keeps in a resource fork — hence the build step and `ditto` in `make install`).

`claude-project-launcher.sh` flow:

1. Clears inherited `CLAUDE_CODE_*` session variables so a launcher started from inside Claude Code doesn't poison the new session's transcripts.
2. **fzf menu 1 — profile:** Work / Personal → sets `CONFIG_DIR` and `MARKER`.
3. **fzf menu 2 — project:** every folder in `~/Documents/Projects` whose marker matches the profile, **plus untagged folders** (they appear under both). Sorted by most recently modified file (ignoring `node_modules .git .next .nuxt dist build out target .venv venv __pycache__ .pytest_cache .cache .DS_Store .work .personal`). A separator line and a `Projects` entry (the root folder) sit at the bottom.
4. `cd`s into the project, exports `CLAUDE_CONFIG_DIR`, runs `claude --allow-dangerously-skip-permissions`; when Claude exits it drops to a shell.

Requires: Ghostty, `fzf` (`/opt/homebrew/bin`), `claude` on PATH.

## 5. Project markers

Empty files named `.work` / `.personal` in a project's root. Semantics:
tagged → shown only under that profile; untagged → shown under both; a
project carrying **both** files behaves like untagged in the launcher and makes
plain `claude` ask.

| Project | Tag |
|---|---|
| AAMVA-Wiki | `.work` |
| AudioLib-io | `.personal` |
| Email-Processing | `.personal` |
| Music | `.personal` |
| OCR Batman RPG | `.personal` |
| Personal-Assets-Inventory | `.personal` |
| Tools | `.work` **and** `.personal` |

Markers only affect the launcher and plain `claude`. They don't restrict
anything else — either profile can still be started anywhere via its alias.
Add a new project: `touch ~/Documents/Projects/<name>/.work` (or `.personal`).

## 6. Profile details

### Work — `~/.claude-work`

- **`settings.json`** (`config/work/settings.json`): `model: sonnet`, `defaultMode: acceptEdits`, `enableWorkflows`, `tui: fullscreen`, `editorMode: normal`, `verbose`, input-needed notifications off, agent push notifications on, `skipDangerousModePermissionPrompt`, theme auto, statusline → `~/.claude-statusline.sh`, plugin `vercel@claude-plugins-official` enabled, and a large **read-only allowlist of `twg` commands** (Jira / Confluence / Bitbucket / Rovo *reads* only — writes always prompt) plus the Chrome `tabs_context_mcp` tool.
- **`CLAUDE.md`** (template `config/work/CLAUDE.md.tmpl`, rendered by `make render-config`): the "About Em" block (name, the two account emails, they/them) followed by the rule "use `twg` skills before the Atlassian Rovo MCP connector; show the exact command before any write; never pass `--yes` without explicit confirmation".
- **`twg` (Atlassian CLI)**: binary `~/.local/bin/twg` (v1.3.3 when written). Its skills live in `~/.agents/skills/twg*` and are **symlinked** into `~/.claude-work/skills/` (`twg`, `twg-jira`, `twg-confluence`, …13 in total). `twg` updates re-create these links. Auth is `twg login`.
- **Synced skills:** `skills/synced/<uuid>/` — pushed from the AAMVA claude.ai organization (wiki-sync, jira-sync, focus-check, docx, pptx…). Managed remotely; don't hand-edit.
- **Plugins:** Vercel plugin 0.45.1 from the official marketplace (`anthropics/claude-plugins-official`). The `plugins/*.json` records must point at `~/.claude-work/plugins/…` (fixed 2026-09-29; they had pointed at the retired `~/.claude`). Reference copies in `config/work/plugins/`.
- **MCP servers** (in `.claude.json`): no user-scope servers; project-scope `wisprflow` in AAMVA-Wiki (HTTP `https://api.wisprflow.ai/connect/mcp`); project-scope `apple-music` in Music (`uvx applemusic-mcp serve`).
- **Chrome:** the Claude-Code native host is `~/.claude-work/chrome/chrome-native-host`, registered in `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json`.

### Personal — `~/.claude-personal`

- **`settings.json`** (`config/personal/settings.json`): `model: sonnet`, `tui: fullscreen`, notifications on, statusline, an explicit `env.PATH` (Homebrew, `~/.local/bin`, Ghostty), and an **`autoMode`** block whose `environment` text describes the AudioLib-io project (Supabase, Vercel, public GitHub repo, secrets in `.env*`) with extra `soft_deny` rules for `npm run db:reset` / `migrate`. It applies to *every* personal session, not only AudioLib-io.
- **`CLAUDE.md`** (template `config/personal/CLAUDE.md.tmpl`): the "About Em" block only.
- **Memory:** `projects/-Users-admin-Documents-Projects-AudioLib-io/memory/` — PR workflow, local dev seeded account, Supabase migrations notes (migrated from the retired `~/.claude` on 2026-09-29).
- **MCP servers:** no user-scope servers; project-scope `applemusic` in Music (`uvx --from "applemusic-mcp[browser]" applemusic-mcp serve`).
- **Synced skills:** from the personal claude.ai account (docs, gmail-inbox-triage, deep-research, browser skills, office-file skills…).
- No plugins installed beyond the official marketplace being registered; no `twg`.

### Shared statusline

`~/.claude-statusline.sh` (`src/claude-statusline.sh`) reads the session JSON
on stdin (needs `jq`) and prints `[WORK]`/`[PERSONAL]` (by the *basename* of
`CLAUDE_CONFIG_DIR` ending in `-work` / `-personal`, else `[DEFAULT]`), the model
name, and the current folder. Its header comments still mention the retired
`~/.claude` default — cosmetic only.

### Account-level things that come with the login

Not stored locally; they reappear after `/login`: claude.ai **connectors**
(Gmail, Calendar, Vercel, Supabase, Shopify, etc. — authorised in claude.ai
settings), org/account **synced skills**, and org policy limits.

## 7. History of this setup

- **2026-08-06/07** — Work desktop instance created (`Claude Work.app`); launcher app + picker script created; `~/.claude-work` and `~/.claude-personal` in use.
- **2026-09-29** — Consolidation:
  - Plain `claude` changed from a bare alias (→ third profile `~/.claude`) to the profile-aware function.
  - `~/.claude` retired to the Trash (`~/.Trash/.claude`, restorable until emptied). Its one valuable item (AudioLib Supabase memory) was copied to personal.
  - "About Em" `CLAUDE.md` block added to both profiles.
  - `Personal-Assets-Inventory` and `OCR Batman RPG` tagged `.personal`.
  - Default model set to Sonnet in both profiles.
  - Stale plugin paths in `~/.claude-work/plugins/*.json` repointed to the work profile.
- Backups from that day (delete when no longer wanted): `~/.zshrc.bak-2026-09-29`, `~/.claude-work/settings.json.bak-2026-09-29`, `~/.claude-work/CLAUDE.md.bak-2026-09-29`, `~/.claude-work/plugins/*.json.bak-2026-09-29`.

## 8. Desktop apps and browser

Separate from the terminal profiles but part of the same "work vs personal" split:

| App | What it is |
|---|---|
| `/Applications/Claude.app` | Normal Claude desktop app (default data dir `~/Library/Application Support/Claude`). |
| `/Applications/Claude Work.app` | A **duplicate** of Claude.app, run as a separate instance: `open -n "/Applications/Claude Work.app" --args --user-data-dir="$HOME/Library/Application Support/Claude-Work"`. |
| `/Applications/Claude for Work.app` | Automator wrapper (bundle `com.apple.automator.Claude-for-Work`) running that same `open -n …` command. |
| `~/Documents/Projects/launch-claude-work.command` | The same command as a double-clickable script (`desktop/launch-claude-work.command`). |

The Chrome native-messaging host `com.anthropic.claude_browser_extension`
points at `Claude Work.app`'s helper, so the browser extension is wired to the
**work** desktop instance. Which Anthropic account each desktop app is signed
into is **(unverified)** — check in each app's settings.

## 9. Known issues / notes

- **`twg` updates may re-create `~/.claude`** with its skills. Harmless; nothing reads it.
- **Keychain has many old `Claude Code-credentials-*` entries** from earlier config dirs. Harmless; remove stale ones in Keychain Access if desired.
- **Auto-update is off** in both profiles; update with `claude update`. Versions accumulate in `~/.local/share/claude/versions/`.
- The `~/Documents/Projects/.claude/settings.local.json` and `.wander/` folders in the Projects root are unrelated to profile selection.

## Secrets

Never copied into this folder:

- `~/.claude-*/.claude.json` — may contain MCP server credentials and account/user ids. Re-create MCP entries with `claude mcp add` instead (REBUILD step 9).
- macOS Keychain logins — re-created by `/login`.
- Conversation history, memory, `sessions/`.

`make snapshot` (`scripts/snapshot-config.sh`) refreshes `config/` and `desktop/`
from the live files and aborts if anything looks like a key; `make check` scans
for secrets too. **This folder lives only on this Mac unless you put it under
version control** — keep an off-machine copy (a private repo is fine; it is
secret-free) or it disappears with the machine.
