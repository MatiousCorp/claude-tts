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

# Content-based deduplication: hash the message and use atomic mkdir to
# prevent the same text from being spoken twice (e.g., if Stop fires twice
# for the same turn, or the plugin is registered in multiple locations).
MSG_HASH=$(printf '%s' "$MESSAGE" | md5 2>/dev/null || printf '%s' "$MESSAGE" | md5sum 2>/dev/null | cut -d' ' -f1)
DEDUP_DIR="${TMPDIR:-/tmp}/claude_tts_dedup_${MSG_HASH}"
if ! mkdir "$DEDUP_DIR" 2>/dev/null; then
  # Another invocation already claimed this exact message
  exit 0
fi
# Clean up previous dedup markers (keep only current)
find "${TMPDIR:-/tmp}" -maxdepth 1 -name "claude_tts_dedup_*" -not -name "claude_tts_dedup_${MSG_HASH}" -exec rm -rf {} + 2>/dev/null || true

# Process-level lock to serialize hook execution
HOOK_LOCK="${TMPDIR:-/tmp}/claude_tts_hook.lock"
if [[ -d "$HOOK_LOCK" ]]; then
  LOCK_PID=$(cat "$HOOK_LOCK/pid" 2>/dev/null || echo "")
  if [[ -n "$LOCK_PID" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
    exit 0
  fi
  rm -rf "$HOOK_LOCK"
fi
if ! mkdir "$HOOK_LOCK" 2>/dev/null; then
  exit 0
fi
echo $$ > "$HOOK_LOCK/pid"
trap - EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Stop any currently playing TTS before starting new
"${SCRIPT_DIR}/tts-stop.sh" &>/dev/null || true

# Write message to temp file for the worker
TEMP_FILE=$(mktemp "${TMPDIR:-/tmp}/claude_tts_msg.XXXXXX")
echo "$MESSAGE" > "$TEMP_FILE"

# Fork background worker and exit immediately
"${SCRIPT_DIR}/tts-worker.sh" "$TEMP_FILE" &>/dev/null & disown
WORKER_PID=$!

# Update lock with worker PID so concurrent invocations see the worker is alive
echo "$WORKER_PID" > "$HOOK_LOCK/pid"

exit 0
