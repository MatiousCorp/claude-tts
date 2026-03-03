#!/usr/bin/env bash
# tts-hook.sh — Stop hook entry point for Claude TTS plugin
# Reads the last assistant message from the transcript and forks a background TTS worker.
# Exits 0 immediately so Claude Code is not blocked.

set -uo pipefail

DEBUG_LOG="${TMPDIR:-/tmp}/claude_tts_debug.log"

log() {
  echo "[$(date '+%H:%M:%S')] $*" >> "$DEBUG_LOG"
}

log "=== tts-hook.sh triggered ==="

# Check toggle — silent exit if TTS is disabled
if [[ ! -f "$HOME/.claude/tts-enabled" ]]; then
  log "TTS disabled, exiting"
  exit 0
fi

# Read hook input from stdin (JSON with transcript_path, etc.)
HOOK_INPUT=$(cat)
log "Hook input: $HOOK_INPUT"

# Extract last_assistant_message directly from hook input (most reliable)
MESSAGE=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)

if [[ -z "$MESSAGE" ]]; then
  log "No last_assistant_message in hook input, exiting"
  exit 0
fi

log "Message length: ${#MESSAGE}"
log "Message preview: ${MESSAGE:0:100}"

# Write message to temp file for the worker
TEMP_FILE=$(mktemp "${TMPDIR:-/tmp}/claude_tts_msg.XXXXXX")
echo "$MESSAGE" > "$TEMP_FILE"

# Fork background worker and exit immediately
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
log "Worker script: ${SCRIPT_DIR}/tts-worker.sh"
"${SCRIPT_DIR}/tts-worker.sh" "$TEMP_FILE" >> "$DEBUG_LOG" 2>&1 & disown
log "Worker forked, PID: $!"

exit 0
