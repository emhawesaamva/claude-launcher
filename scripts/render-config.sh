#!/bin/bash
# Render config/*/CLAUDE.md.tmpl into the live profile folders, filling in the
# {{WORK_EMAIL}} / {{PERSONAL_EMAIL}} placeholders so real addresses never live in the repo.
#
# Values come from (first found): environment variables, config/local.env
# (git-ignored), or an interactive prompt.
#
# Destinations (override for testing):
#   CLAUDE_WORK_DIR      default ~/.claude-work
#   CLAUDE_PERSONAL_DIR  default ~/.claude-personal
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$HERE/config/local.env" ] && . "$HERE/config/local.env"

ask() {  # ask VAR "prompt"
    local var="$1"
    [ -n "${!var:-}" ] && return
    if [ -t 0 ]; then
        read -r -p "$2: " "$var"
    else
        echo "error: $var not set (export it or create config/local.env)" >&2; exit 1
    fi
    [ -n "${!var}" ] || { echo "error: $var is empty" >&2; exit 1; }
}
ask WORK_EMAIL "Work account email"
ask PERSONAL_EMAIL "Personal account email"

render() {  # render <template> <dest-dir>
    local tmpl="$1" dir="$2"
    mkdir -p "$dir"
    [ -e "$dir/CLAUDE.md" ] && cp -p "$dir/CLAUDE.md" "$dir/CLAUDE.md.bak-$(date +%Y%m%d-%H%M%S)"
    WORK_EMAIL="$WORK_EMAIL" PERSONAL_EMAIL="$PERSONAL_EMAIL" python3 - "$tmpl" "$dir/CLAUDE.md" <<'PY'
import os, sys
s = open(sys.argv[1]).read()
s = s.replace("{{WORK_EMAIL}}", os.environ["WORK_EMAIL"]).replace("{{PERSONAL_EMAIL}}", os.environ["PERSONAL_EMAIL"])
open(sys.argv[2], "w").write(s)
PY
    echo "wrote $dir/CLAUDE.md"
}
render "$HERE/config/work/CLAUDE.md.tmpl"     "${CLAUDE_WORK_DIR:-$HOME/.claude-work}"
render "$HERE/config/personal/CLAUDE.md.tmpl" "${CLAUDE_PERSONAL_DIR:-$HOME/.claude-personal}"
