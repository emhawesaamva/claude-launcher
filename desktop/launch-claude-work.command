#!/bin/bash
# Launches a second, isolated Claude Desktop instance ("Claude Work")
# Make sure you've duplicated Claude.app to "Claude Work.app" in /Applications first.

open -n "/Applications/Claude Work.app" --args --user-data-dir="$HOME/Library/Application Support/Claude-Work"