# Claude Profiles & Launcher

One Mac, two Claude identities — **Work** and **Personal** — kept fully apart,
with a one-click launcher that starts Claude Code in the right one.

## The problem this solves

Claude Code is used here for two very different jobs on the same machine:

| | Work | Personal |
|---|---|---|
| Account | `m*****@aamva.org` (AAMVA organization) | `h*****@gmail.com` |
| Projects | AAMVA wiki, Jira/Confluence work | AudioLib-io, music, email, hobby projects |
| Tools | Atlassian `twg` CLI, org-synced skills | Supabase / Vercel / GitHub, personal connectors |

Out of the box Claude Code has **one** identity per user account. Sharing it means:

- **Constant re-logging** to switch accounts.
- **Mixed-up context** — work memory, history, permissions and skills leaking into personal sessions, and the reverse.
- **Wrong-account accidents** — starting in the wrong identity and only noticing after it touched the wrong data.
- **One set of settings** — work wants cautious defaults and an Atlassian-first rule; personal wants project-specific auto-approvals.
- **A silent default** — a plain `claude` falling back to some third, forgotten profile.

**The solution:** give each identity its own config directory, make choosing
between them a single, visible decision, and never let the choice be silent.

## How it works

Claude Code stores everything about an identity in one folder, chosen by the
`CLAUDE_CONFIG_DIR` environment variable. Point it elsewhere and you get a
completely separate identity: login, settings, `CLAUDE.md`, memory, history,
plugins, skills and MCP servers.

```
                        ┌─────────────────────────────┐
   Claude Launcher.app  │  claude-project-launcher.sh │  pick profile → pick project
   (Ghostty window) ───▶│  (fzf menus)                │
                        └──────────────┬──────────────┘
   claude-work  ──────────────┐        │ sets CLAUDE_CONFIG_DIR
   claude-personal ───────────┤        ▼
   claude  (reads .work /     │   ┌──────────────────┐      ┌──────────────────────┐
   .personal marker, else ────┴──▶│  ~/.claude-work  │  or  │  ~/.claude-personal  │
   asks — never guesses)          │  work account    │      │  personal account    │
                                  └────────┬─────────┘      └──────────┬───────────┘
                                           └───────────┬───────────────┘
                                                       ▼
                                    one shared `claude` binary (~/.local/bin)
                                    one shared statusline  → shows [WORK] / [PERSONAL]
```

1. **Two config directories** — `~/.claude-work` and `~/.claude-personal`, each with its own login (macOS Keychain), settings, memory and skills.
2. **Project markers** — an empty `.work` or `.personal` file in a project folder says which profile owns it. Untagged folders appear under both.
3. **Three ways in, one rule** — the **launcher app** (pick profile, then project), the **`claude-work` / `claude-personal`** aliases, and a **profile-aware `claude`** command that reads the marker and *asks* when unsure.

A colour-coded statusline (cyan `[WORK]`, magenta `[PERSONAL]`) shows the active identity at all times.

| Project | Profile |
|---|---|
| AAMVA-Wiki | Work |
| AudioLib-io, Email-Processing, Music, OCR Batman RPG, Personal-Assets-Inventory | Personal |
| Tools | Both (asks) |

## Requirements

macOS, [Homebrew](https://brew.sh), [Ghostty](https://ghostty.org), `fzf`, `jq`,
and Claude Code (`~/.local/bin/claude`). Optional: `shellcheck` for `make check`.

## Install

Full runbook: [docs/REBUILD.md](docs/REBUILD.md). The short version, from this folder:

1. **Tools:** `brew install fzf jq` · `brew install --cask ghostty` · `curl -fsSL https://claude.ai/install.sh | bash`
2. **Launcher:** `make install` — builds the app (with icon) and installs the picker, statusline and app. Never touches `~/.zshrc` or profile folders.
3. **Shell:** merge [`config/shell/zshrc`](config/shell/zshrc) into `~/.zshrc` (aliases + profile-aware `claude()`), then open a new terminal.
4. **Profile folders:** `mkdir -p ~/.claude-work ~/.claude-personal`, copy `config/work/settings.json` and `config/personal/settings.json` into them, then run `make render-config` (asks for your two account emails and writes each profile's `CLAUDE.md`).
5. **Log in once per profile:** `claude-work` → `/login` (work account); exit; `claude-personal` → `/login` (personal account).
6. **Tag projects:** `touch <project>/.work` or `touch <project>/.personal`.
7. **Verify:** open the launcher — Work lists AAMVA-Wiki, Personal lists AudioLib-io; in a tagged project, plain `claude` prints `→ claude (work|personal)`.

## Usage

```bash
open ~/Applications/"Claude Launcher.app"   # pick profile → pick project (new Ghostty window)
claude-project-launcher.sh                  # same picker in the current terminal
claude-work / claude-personal               # explicit profile, current folder
claude                                      # profile from the project's marker, else asks
```

## Repository layout

```
.
├── README.md
├── Makefile                          # build / install / check / diff / snapshot
├── src/                              # source — edit here, then `make install`
│   ├── claude-project-launcher.sh    #   the picker (fzf menus, launches claude)
│   ├── claude-statusline.sh          #   [WORK]/[PERSONAL] statusline
│   └── app/
│       ├── Info.plist                #   app bundle metadata
│       └── claude-launcher           #   app entry point → opens Ghostty with the picker
├── assets/
│   └── icon.png                      # custom app icon (applied by `make app`)
├── config/                           # snapshots of live config (secret-free)
│   ├── shell/zshrc                   #   → ~/.zshrc
│   ├── local.env.example             #   account emails for `make render-config` (real one is git-ignored)
│   ├── work/                         #   → ~/.claude-work/   (settings.json, CLAUDE.md.tmpl, plugin records)
│   └── personal/                     #   → ~/.claude-personal/ (settings.json, CLAUDE.md.tmpl)
├── desktop/                          # separate "Claude Work" desktop-app instance
│   ├── launch-claude-work.command
│   └── Claude for Work.app           #   Automator wrapper (copy with `ditto`)
├── scripts/
│   ├── check.sh                      # syntax / plist / JSON / secret checks
│   ├── snapshot-config.sh            # live config → repo (not CLAUDE.md — that stays a template)
│   ├── render-config.sh              # templates → live CLAUDE.md files (fills in the emails)
│   └── set-icon.js                   # applies assets/icon.png to a bundle
├── docs/
│   ├── PROFILES.md                   # full reference: how the profiles work
│   └── REBUILD.md                    # complete rebuild runbook
└── build/                            # generated by `make app` (git-ignored)
```

## Development

Source of truth: `src/` is edited **here** and pushed to the machine with
`make install`; `config/` and `desktop/` are the other way round — the live files
are edited in place and pulled back with `make snapshot`.

| Command | What it does |
|---|---|
| `make` | List targets |
| `make check` | Shell syntax, plist, JSON validity, no email addresses / personal bundle id, secret scan |
| `make app` | Build `build/Claude Launcher.app` from `src/app` + `assets/icon.png` |
| `make install` | Build, then install picker + statusline + app |
| `make uninstall` | Remove the installed picker and app (keeps statusline, `.zshrc`, profiles) |
| `make diff` | Show whether installed files match the repo |
| `make render-config` | Write each profile's `CLAUDE.md` from its template (prompts for the two emails) |
| `make snapshot` | Pull live `~/.zshrc`, profile settings and desktop launchers into the repo |
| `make clean` | Remove `build/` |

Install locations can be overridden for testing:
`make install APP_DIR=/tmp/x/Applications BIN_DIR=/tmp/x/bin STATUSLINE=/tmp/x/statusline.sh`.

**Never committed:** logins (macOS Keychain), `.claude.json` (may hold MCP
credentials and account ids), conversations and memory — see `.gitignore`.
This folder is not yet under version control; keep an off-machine copy or run
`git init` (it is secret-free, so a private remote is fine).
