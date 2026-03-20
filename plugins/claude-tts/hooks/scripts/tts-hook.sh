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

# Prevent duplicate execution (e.g., plugin registered in multiple locations)
HOOK_LOCK="${TMPDIR:-/tmp}/claude_tts_hook.lock"
if [[ -d "$HOOK_LOCK" ]]; then
  # Check if the lock holder is still alive
  LOCK_PID=$(cat "$HOOK_LOCK/pid" 2>/dev/null || echo "")
  if [[ -n "$LOCK_PID" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
    exit 0
  fi
  # Stale lock — remove it
  rm -rf "$HOOK_LOCK"
fi
if ! mkdir "$HOOK_LOCK" 2>/dev/null; then
  exit 0
fi
echo $$ > "$HOOK_LOCK/pid"
trap 'rm -rf "$HOOK_LOCK"' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Stop any currently playing TTS before starting new
"${SCRIPT_DIR}/tts-stop.sh" &>/dev/null || true

# Write message to temp file for the worker
TEMP_FILE=$(mktemp "${TMPDIR:-/tmp}/claude_tts_msg.XXXXXX")
echo "$MESSAGE" > "$TEMP_FILE"

# Fork background worker and exit immediately
"${SCRIPT_DIR}/tts-worker.sh" "$TEMP_FILE" &>/dev/null & disown

exit 0
