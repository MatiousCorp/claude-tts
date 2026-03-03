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

# Extract transcript path
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
log "Transcript path: $TRANSCRIPT_PATH"

if [[ -z "$TRANSCRIPT_PATH" ]]; then
  log "No transcript_path in input, exiting"
  exit 0
fi

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  log "Transcript file not found: $TRANSCRIPT_PATH, exiting"
  exit 0
fi

# Get the last assistant message from JSONL transcript
LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1 || true)
if [[ -z "$LAST_LINE" ]]; then
  log "No assistant messages found in transcript, exiting"
  exit 0
fi

log "Last assistant line length: ${#LAST_LINE}"

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
  log "No text content extracted, exiting"
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
