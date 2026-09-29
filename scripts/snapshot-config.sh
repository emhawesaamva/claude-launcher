#!/bin/bash
# Pull the LIVE, hand-edited config back into this repo:
#   ~/.zshrc, each profile's settings.json, the work plugin records,
#   and the desktop-app launchers.
#
# CLAUDE.md is NOT pulled back: it holds real email addresses, so the repo keeps
# only config/*/CLAUDE.md.tmpl (edit those; `make render-config` writes the live files).
#
# The launcher sources in src/ are the other direction: edit them here and
# `make install`. Use `make diff` to see whether the installed copies match.
#
# Copies ONLY files that hold no credentials. It deliberately skips:
#   ~/.claude-*/.claude.json   (may hold MCP credentials + account ids)
#   ~/.claude-*/history.jsonl, projects/, sessions/  (conversations)
#   Keychain entries          (the actual logins)
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
C="$HERE/config"
mkdir -p "$C/shell" "$C/work/plugins" "$C/personal" "$HERE/desktop"

cp -p ~/.zshrc "$C/shell/zshrc"

for p in work personal; do
    cp -p ~/.claude-$p/settings.json "$C/$p/settings.json"
done
cp -p ~/.claude-work/plugins/installed_plugins.json ~/.claude-work/plugins/known_marketplaces.json "$C/work/plugins/"

cp -p ~/Documents/Projects/launch-claude-work.command "$HERE/desktop/launch-claude-work.command"
ditto "/Applications/Claude for Work.app" "$HERE/desktop/Claude for Work.app.new" \
    && rm -rf "$HERE/desktop/Claude for Work.app" \
    && mv "$HERE/desktop/Claude for Work.app.new" "$HERE/desktop/Claude for Work.app"

# Safety net: refuse to leave anything that looks like a secret behind.
if grep -rInE '(sk-ant-|"?(api|secret)[_-]?key"?\s*[:=]\s*"[A-Za-z0-9]{16,})' "$C" "$HERE/desktop" >/dev/null 2>&1; then
    echo "WARNING: possible secret found under config/ or desktop/ — review before keeping." >&2
    exit 1
fi
echo "Snapshot refreshed in: $HERE"
