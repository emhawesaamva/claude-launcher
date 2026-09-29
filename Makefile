# Claude Launcher — build, install and maintain the two-profile Claude setup.
# Run `make` for the list of targets. Override locations for testing, e.g.
#   make install APP_DIR=/tmp/x/Applications BIN_DIR=/tmp/x/bin STATUSLINE=/tmp/x/statusline.sh

SHELL      := /bin/bash
APP_NAME   := Claude Launcher.app
BIN_DIR    ?= $(HOME)/.local/bin
APP_DIR    ?= $(HOME)/Applications
STATUSLINE ?= $(HOME)/.claude-statusline.sh
APP        := build/$(APP_NAME)

.DEFAULT_GOAL := help
.PHONY: help app install uninstall render-config check diff snapshot clean

help:  ## Show this help
	@awk 'BEGIN{FS=":.*## "} /^[a-z-]+:.*## /{printf "  make %-10s %s\n",$$1,$$2}' $(MAKEFILE_LIST)

app:  ## Build build/Claude Launcher.app (with the custom icon) from src/app + assets/icon.png
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	cp src/app/Info.plist "$(APP)/Contents/Info.plist"
	install -m 755 src/app/claude-launcher "$(APP)/Contents/MacOS/claude-launcher"
	osascript -l JavaScript scripts/set-icon.js "$(CURDIR)/$(APP)" "$(CURDIR)/assets/icon.png"

install: app  ## Install the picker, statusline and app (never touches ~/.zshrc or profile dirs)
	mkdir -p "$(BIN_DIR)" "$(APP_DIR)"
	install -m 755 src/claude-project-launcher.sh "$(BIN_DIR)/claude-project-launcher.sh"
	install -m 755 src/claude-statusline.sh "$(STATUSLINE)"
	rm -rf "$(APP_DIR)/$(APP_NAME)"
	ditto "$(APP)" "$(APP_DIR)/$(APP_NAME)"
	@echo "Installed. Shell aliases/function: see config/shell/zshrc (merge by hand)."

uninstall:  ## Remove the installed picker and app (keeps statusline, ~/.zshrc and profiles)
	rm -f "$(BIN_DIR)/claude-project-launcher.sh"
	rm -rf "$(APP_DIR)/$(APP_NAME)"

render-config:  ## Write ~/.claude-*/CLAUDE.md from the templates (prompts for the two account emails)
	@scripts/render-config.sh

check:  ## Syntax, plist, JSON and secret checks
	@scripts/check.sh

diff:  ## Compare installed files with the repo (repo is the source of truth for src/)
	@for p in "src/claude-project-launcher.sh:$(BIN_DIR)/claude-project-launcher.sh" \
	          "src/claude-statusline.sh:$(STATUSLINE)" \
	          "src/app/claude-launcher:$(APP_DIR)/$(APP_NAME)/Contents/MacOS/claude-launcher" \
	          "src/app/Info.plist:$(APP_DIR)/$(APP_NAME)/Contents/Info.plist" \
	          "config/shell/zshrc:$(HOME)/.zshrc"; do \
	    a=$${p%%:*}; b=$${p#*:}; \
	    if cmp -s "$$a" "$$b"; then echo "same   $$a"; else echo "DIFF   $$a  <->  $$b"; fi; \
	done

snapshot:  ## Pull live config (zshrc, profile settings, desktop launcher) into the repo; CLAUDE.md is template-only
	@scripts/snapshot-config.sh

clean:  ## Remove build output
	rm -rf build
