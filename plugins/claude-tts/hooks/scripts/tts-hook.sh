#!/usr/bin/env bash
# tts-hook.sh — Stop hook entry point for Claude TTS plugin.
# Reads the last assistant message and forks a background TTS worker.

set -uo pipefail

# Check toggle
if [[ ! -f "$HOME/.claude/tts-enabled" ]]; then
  exit 0
fi

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract last assistant message
MESSAGE=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)
if [[ -z "$MESSAGE" ]]; then
  exit 0
fi

# Write message to temp file for the worker
TEMP_FILE=$(mktemp "${TMPDIR:-/tmp}/claude_tts_msg.XXXXXX")
echo "$MESSAGE" > "$TEMP_FILE"

# Fork background worker and exit immediately
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"${SCRIPT_DIR}/tts-worker.sh" "$TEMP_FILE" &>/dev/null & disown

exit 0
