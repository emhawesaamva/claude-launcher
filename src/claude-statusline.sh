#!/bin/bash
# Shared Claude Code status line script.
# Referenced by ~/.claude/settings.json, ~/.claude-work/settings.json,
# and ~/.claude-personal/settings.json.
#
# Shows which identity launched the session (Work / Personal / Default),
# based on the CLAUDE_CONFIG_DIR env var set by the shell aliases:
#   alias claude-work='CLAUDE_CONFIG_DIR=~/.claude-work claude'
#   alias claude-personal='CLAUDE_CONFIG_DIR=~/.claude-personal claude'
#   plain `claude` (no override) -> default ~/.claude
#
# Also shows the current model name and current directory.

input=$(cat)

# Determine identity by matching the basename of CLAUDE_CONFIG_DIR,
# not an exact full-path string, so this works regardless of where
# the config dirs actually live on disk.
config_base=$(basename "${CLAUDE_CONFIG_DIR:-}" 2>/dev/null)

case "$config_base" in
  *-work)
    identity="WORK"
    color="36" # cyan
    ;;
  *-personal)
    identity="PERSONAL"
    color="35" # magenta
    ;;
  *)
    identity="DEFAULT"
    color="90" # dim gray
    ;;
esac

model=$(printf '%s' "$input" | jq -r '.model.display_name // "unknown"')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir_display=$(basename "${cwd:-/}" 2>/dev/null)

# Bold, colored [IDENTITY] tag + dim model name + cyan current dir.
printf '\033[1;%sm[%s]\033[0m \033[2m%s\033[0m \033[36m%s\033[0m' \
  "$color" "$identity" "$model" "$dir_display"
