#!/bin/bash
# Interactive picker: choose Claude profile (work/personal) + project folder,
# then cd into it and launch Claude Code there.
# Uses fzf so both lists are navigable with arrow keys.

export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

# Prevent a stale/inherited Claude Code session marker (e.g. from testing
# this launcher inside a Claude Code terminal) from leaking into the new
# session and disabling transcript saving.
unset CLAUDE_CODE_CHILD_SESSION CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_SESSION_ID \
      CLAUDE_CODE_BRIDGE_SESSION_ID CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_EXECPATH \
      CLAUDE_CODE_FORCE_SESSION_PERSISTENCE

PROJECTS_DIR="$HOME/Documents/Projects"

ORANGE=$'\033[38;5;209m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

cols=$(tput cols 2>/dev/null || echo 60)

center() {
    local plain="$1" color="$2"
    local pad=$(( (cols - ${#plain}) / 2 ))
    (( pad < 0 )) && pad=0
    printf "%*s%s%s%s\n" "$pad" "" "$color" "$plain" "$RESET"
}

# Centers a multi-line block as a single unit (same left padding on every
# line) so the lines stay aligned to each other, unlike centering each
# line independently by its own length.
center_block() {
    local color="$1"; shift
    local lines=("$@") l maxlen=0
    for l in "${lines[@]}"; do
        (( ${#l} > maxlen )) && maxlen=${#l}
    done
    local pad=$(( (cols - maxlen) / 2 ))
    (( pad < 0 )) && pad=0
    for l in "${lines[@]}"; do
        printf "%*s%s%s%s\n" "$pad" "" "$color" "$l" "$RESET"
    done
}

clear
echo
center_block "$ORANGE" "       █████████" "      ██▄█████▄██" "       █████████" ".......█ █   █ █......."
echo
center "C L A U D E   C O D E" "$BOLD"
center "project launcher" "$DIM"
echo
echo

FZF_OPTS=(
    --height=~40% --layout=reverse --border=none --header-first
    --color=fg:245,fg+:255,bg+:236,hl:209,hl+:209,header:209,prompt:209,pointer:209,info:238
    --prompt="❯ "
)

profile=$(printf 'Work\nPersonal\n' | fzf "${FZF_OPTS[@]}" --header="Profile")
case "$profile" in
    Work) CONFIG_DIR="$HOME/.claude-work"; MARKER=".work" ;;
    Personal) CONFIG_DIR="$HOME/.claude-personal"; MARKER=".personal" ;;
    *) exit 0 ;;  # esc / ctrl-c
esac

ROOT_LABEL="Projects"

# Skipped when timestamping a project: dependency, build and VCS directories
# churn on installs and commits, and the marker files below would make freshly
# tagging a project look like work on it. Both would mask how long it has
# actually been since the project was touched by hand.
PRUNE_NAMES=( node_modules .git .next .nuxt dist build out target
              .venv venv __pycache__ .pytest_cache .cache .DS_Store
              .work .personal .bypass )

# Newest file mtime found anywhere in the project, so editing a deeply nested
# file floats it to the top of the list. Only files count: macOS rewrites
# .DS_Store behind your back, which bumps a directory's mtime without anything
# in the project having actually changed.
newest_mtime() {
    local dir="$1" prune=() n mtime
    for n in "${PRUNE_NAMES[@]}"; do
        [ ${#prune[@]} -gt 0 ] && prune+=( -o )
        prune+=( -name "$n" )
    done
    mtime=$(find "$dir" \( "${prune[@]}" \) -prune -o -type f -print0 2>/dev/null \
            | xargs -0 stat -f '%m' 2>/dev/null | sort -rn | head -1)
    # No files at all: fall back to when the folder was created, not its mtime.
    # A brand-new empty project still sorts first, while a long-abandoned one
    # sinks instead of riding the next .DS_Store write to the top.
    [ -n "$mtime" ] || mtime=$(stat -f '%B' "$dir" 2>/dev/null)
    [ -n "$mtime" ] || mtime=0
    printf '%s\n' "$mtime"
}

# A project belongs to a profile if it holds that profile's marker file.
# An untagged project belongs to both, so a folder never vanishes from the
# menu just because it has not been labelled yet.
matches_profile() {
    local dir="$1"
    [ -e "$dir/$MARKER" ] && return 0
    [ ! -e "$dir/.work" ] && [ ! -e "$dir/.personal" ]
}

projects=$(
    for dir in "$PROJECTS_DIR"/*/; do
        dir="${dir%/}"
        [ -d "$dir" ] || continue
        name="${dir##*/}"   # the glob already excludes dotfiles
        matches_profile "$dir" || continue
        printf '%s\t%s\n' "$(newest_mtime "$dir")" "$name"
    done | sort -rn | cut -f2-
)

# The Projects root sits at the bottom, below a rule, so the recency-sorted
# projects keep the top of the list where the cursor starts.
SEPARATOR="──────────────────────────────"

if [ -n "$projects" ]; then
    menu="$projects
$SEPARATOR
$ROOT_LABEL"
else
    menu="$ROOT_LABEL"
fi

# The rule is decoration, but fzf will happily return it, so re-prompt instead
# of treating it as a project.
while true; do
    project=$(printf '%s\n' "$menu" | fzf "${FZF_OPTS[@]}" --header="Project")

    if [ -z "$project" ]; then
        exit 0  # esc / ctrl-c
    fi

    [ "$project" = "$SEPARATOR" ] || break
done

if [ "$project" = "$ROOT_LABEL" ]; then
    target_dir="$PROJECTS_DIR"
else
    target_dir="$PROJECTS_DIR/$project"
fi

cd "$target_dir" || exec "$SHELL"

profile_lc=$(echo "$profile" | tr '[:upper:]' '[:lower:]')

clear
echo
center "██▄█▄██  launching claude — ${profile_lc}" "$ORANGE$BOLD"
center "$target_dir" "$DIM"
echo

export CLAUDE_CONFIG_DIR="$CONFIG_DIR"

if ! command -v claude >/dev/null 2>&1; then
    echo "error: 'claude' not found on PATH ($PATH)" >&2
    exec "$SHELL"
fi

# A project holding an empty .bypass file starts in bypassPermissions mode.
# This has to come from the command line: Claude Code ignores defaultMode
# "bypassPermissions" in project settings files (v2.1.257+), so a settings
# entry cannot do it. Everything else starts in the normal mode.
permission_args=(--allow-dangerously-skip-permissions)
if [ -e "$target_dir/.bypass" ]; then
    permission_args+=(--permission-mode bypassPermissions)
fi

claude "${permission_args[@]}"
echo
echo "(claude exited — press ctrl-d or type 'exit' to close this window)"
exec "$SHELL"
