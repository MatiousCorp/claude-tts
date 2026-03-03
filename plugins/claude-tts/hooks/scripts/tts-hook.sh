#!/usr/bin/env bash
# tts-hook.sh — Stop hook entry point for Claude TTS plugin
# Reads the last assistant message from the transcript and forks a background TTS worker.
# Exits 0 immediately so Claude Code is not blocked.

set -euo pipefail

# Check toggle — silent exit if TTS is disabled
[[ -f "$HOME/.claude/tts-enabled" ]] || exit 0

# Read hook input from stdin (JSON with transcript_path, etc.)
HOOK_INPUT=$(cat)

# Extract transcript path
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Get the last assistant message from JSONL transcript
LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1 || true)
if [[ -z "$LAST_LINE" ]]; then
  exit 0
fi

# Extract text content blocks and join them
MESSAGE=$(echo "$LAST_LINE" | jq -r '
  .message.content
  | if type == "array" then
      map(select(.type == "text")) | map(.text) | join("\n")
    elif type == "string" then
      .
    else
      empty
    end
' 2>/dev/null || true)

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
