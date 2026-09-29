#!/bin/bash
# Static checks: script syntax, plist, JSON, and a secret scan. No side effects.
set -u
cd "$(dirname "$0")/.."
fail=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=1; }

echo "shell syntax"
for f in src/*.sh src/app/claude-launcher scripts/*.sh desktop/*.command; do
    bash -n "$f" 2>/dev/null && ok "$f" || bad "$f"
done
zsh -n config/shell/zshrc 2>/dev/null && ok config/shell/zshrc || bad config/shell/zshrc

echo "plist"
plutil -lint src/app/Info.plist >/dev/null && ok src/app/Info.plist || bad src/app/Info.plist

echo "json"
while IFS= read -r f; do
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null && ok "$f" || bad "$f"
done < <(find config -name '*.json')

echo "shellcheck"
if command -v shellcheck >/dev/null; then
    shellcheck -S warning src/*.sh scripts/*.sh >/dev/null 2>&1 && ok "shellcheck" || bad "shellcheck warnings (run: shellcheck src/*.sh scripts/*.sh)"
else
    echo "  skip  shellcheck not installed (brew install shellcheck)"
fi

echo "personal data"
if grep -rInE --exclude-dir=build --exclude-dir=.git --exclude=check.sh --exclude=icon.png --exclude-dir="Claude for Work.app" \
     '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' . | grep -v -E '@(work|personal)\.example|@example\.' >/dev/null; then
    bad "email address found (run: grep -rInE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' .)"
else
    ok "no email addresses"
fi
if grep -rIn --exclude-dir=.git --exclude=check.sh "com\.matthawes" . >/dev/null; then bad "personal bundle id found"; else ok "generic bundle id"; fi

echo "secrets"
if grep -rInE --exclude-dir=build --exclude-dir=.git --exclude=check.sh --exclude=snapshot-config.sh \
     '(sk-ant-[A-Za-z0-9]|eyJ[A-Za-z0-9_-]{20,}|"?(api|secret)[_-]?key"?\s*[:=]\s*"[A-Za-z0-9]{16,})' . >/dev/null; then
    bad "possible secret found (grep -rInE for sk-ant-/eyJ/api_key)"
else
    ok "none found"
fi

[ "$fail" -eq 0 ] && echo "all checks passed" || { echo "checks FAILED"; exit 1; }
