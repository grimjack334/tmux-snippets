#!/usr/bin/env bash
# snippet-picker.sh — browse code snippets in a tmux popup, paste selected to current pane
#
# Snippets are plain files under SNIPPETS_DIR. Subdirectories act as categories.
# The selected snippet is loaded into the tmux paste buffer and pasted to the
# pane that invoked the picker.
#
# Setup:
#   mkdir -p ~/.config/snippets/git ~/.config/snippets/docker
#   echo 'git log --oneline --graph --all' > ~/.config/snippets/git/log-graph.sh
#
#   # tmux.conf keybinding:
#   bind-key S run-shell "~/.local/bin/snippet-picker.sh"
#
# Environment:
#   SNIPPETS_DIR   Override snippet directory (default: ~/.config/snippets)

set -euo pipefail

SNIPPETS_DIR="${SNIPPETS_DIR:-$HOME/.config/snippets}"

# ── Internal popup mode ────────────────────────────────────────────────────────
# Invoked by tmux display-popup; writes the selected snippet path to $1.

if [[ "${1:-}" == "--popup" ]]; then
    tmpfile="$2"

    if [[ ! -d "$SNIPPETS_DIR" ]]; then
        printf 'No snippets directory: %s\n\nCreate it and add files to get started.\n' \
            "$SNIPPETS_DIR" >&2
        read -r -t 5 || true
        exit 1
    fi

    mapfile -t files < <(find "$SNIPPETS_DIR" -type f | sort)
    if [[ ${#files[@]} -eq 0 ]]; then
        printf 'No snippets found in %s\n' "$SNIPPETS_DIR" >&2
        read -r -t 5 || true
        exit 1
    fi

    # Strip the snippets dir prefix for display
    display_names=()
    for f in "${files[@]}"; do
        display_names+=("${f#"$SNIPPETS_DIR"/}")
    done

    if command -v bat &>/dev/null; then
        preview_cmd="bat --color=always --style=numbers,grid '$SNIPPETS_DIR/{}'"
    else
        preview_cmd="cat '$SNIPPETS_DIR/{}'"
    fi

    selected=$(printf '%s\n' "${display_names[@]}" | \
        fzf \
            --prompt='  Snippet > ' \
            --header='ENTER = paste   ESC = cancel' \
            --header-first \
            --preview "$preview_cmd" \
            --preview-window='right:60%:wrap' \
            --layout=reverse \
            --height=100% \
            --bind='ctrl-/:toggle-preview') || true

    if [[ -n "$selected" ]]; then
        cat "$SNIPPETS_DIR/$selected" > "$tmpfile"
    fi
    exit 0
fi

# ── Main mode ──────────────────────────────────────────────────────────────────

if [[ -z "${TMUX:-}" ]]; then
    printf 'Error: must be run inside a tmux session\n' >&2
    exit 1
fi

mkdir -p "$SNIPPETS_DIR"

# Capture the pane to paste into before the popup steals focus
target_pane="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}')}"

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

tmux display-popup \
    -E \
    -w 80% \
    -h 80% \
    "bash \"$(realpath "$0")\" --popup \"$tmpfile\""

if [[ -s "$tmpfile" ]]; then
    tmux load-buffer -b _snippet "$tmpfile"
    tmux paste-buffer -b _snippet -t "$target_pane"
    tmux delete-buffer -b _snippet
fi
