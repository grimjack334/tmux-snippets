# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`snippet-picker.sh` is a single Bash script that opens an fzf popup inside tmux, lets the user browse snippet files by category, previews them with `bat` (or `cat`), and pastes the selected snippet into the originating pane via the tmux paste buffer.

## Installation

```bash
cp snippet-picker.sh ~/.local/bin/snippet-picker.sh
chmod +x ~/.local/bin/snippet-picker.sh
mkdir -p ~/.config/snippets/git ~/.config/snippets/docker
```

Add to `~/.tmux.conf`:
```tmux
bind-key S run-shell "~/.local/bin/snippet-picker.sh"
```

Dependencies: `tmux ≥ 3.2`, `fzf`. Optional: `bat` for syntax-highlighted previews.

## How the script works

The script has two execution modes distinguished by an internal `--popup` flag:

**Outer call** (keybinding → `run-shell`):
1. Validates it's inside a tmux session
2. Captures the target pane ID before the popup steals focus
3. Creates a temp file, opens `tmux display-popup` that re-invokes the script with `--popup <tmpfile>`
4. After the popup closes, loads the temp file into a named tmux buffer (`_snippet`) and pastes it to the target pane
5. Deletes the named buffer and temp file

**Inner call** (inside the popup, `--popup`):
1. Finds all files under `SNIPPETS_DIR` recursively, strips the prefix for display
2. Runs `fzf` with a preview (`bat --color=always` or `cat`)
3. Writes the selected file's contents to the temp file and exits

## Snippet directory layout

Snippets are plain files under `~/.config/snippets/` (override with `SNIPPETS_DIR`). Subdirectories act as categories and appear in the display path:

```
~/.config/snippets/
├── git/
│   └── log-graph.sh        # displays as "git/log-graph.sh"
└── docker/
    └── prune-all.sh        # displays as "docker/prune-all.sh"
```

The full file contents are pasted verbatim — no interpolation.

## Key conventions

- **`SNIPPETS_DIR`** env var overrides the default `~/.config/snippets`
- **Paste target** is captured as `$TMUX_PANE` (or via `tmux display-message`) before the popup opens, so focus changes don't affect where the snippet lands
- **Named buffer** `_snippet` is used and immediately deleted to avoid polluting the buffer list
- **`set -euo pipefail`** throughout; fzf cancel (ESC) writes nothing to the temp file and the script exits cleanly
