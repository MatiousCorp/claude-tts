#!/usr/bin/env bash
# tts-worker.sh — Background worker: clean text, call ElevenLabs API (or macOS say fallback), queue audio.
# Usage: tts-worker.sh <temp-message-file>

set -uo pipefail

TEMP_FILE="${1:-}"
if [[ -z "$TEMP_FILE" || ! -f "$TEMP_FILE" ]]; then
  exit 1
fi

RAW_TEXT=$(cat "$TEMP_FILE")
rm -f "$TEMP_FILE"

# --- Text Cleaning ---
CLEANED=$(echo "$RAW_TEXT" | sed -E '
  # Remove fenced code blocks (``` ... ```)
  /^```/,/^```/d
  # Remove inline code
  s/`[^`]+`//g
  # Remove URLs
  s|https?://[^ ]*||g
  # Remove file paths like /foo/bar.ext or ./foo/bar
  s|[[:space:]]/?[a-zA-Z0-9_./-]+\.[a-zA-Z]{1,10}||g
  # Remove markdown headings
  s/^#{1,6}[[:space:]]+//
  # Remove bold/italic markers
  s/\*{1,3}//g
  s/_{1,3}//g
  # Remove markdown list markers
  s/^[[:space:]]*[-*+][[:space:]]+//
  s/^[[:space:]]*[0-9]+\.[[:space:]]+//
  # Remove markdown table separators
  /^[[:space:]]*\|.*[-]{3,}/d
  # Remove pipe characters (table cells)
  s/\|/ /g
  # Remove markdown link syntax [text](url)
  s/\[([^]]*)\]\([^)]*\)/\1/g
  # Collapse multiple spaces
  s/[[:space:]]+/ /g
')

# Join lines, collapse whitespace, trim
CLEANED=$(echo "$CLEANED" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ +//; s/ +$//')

# Truncate to 5000 chars for cost control
CLEANED="${CLEANED:0:5000}"

# Skip if too short
if [[ ${#CLEANED} -lt 5 ]]; then
  exit 0
fi

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="$HOME/.claude/claude-tts.local.md"

# Read API key: env var takes precedence, then config file frontmatter
API_KEY="${ELEVENLABS_API_KEY:-}"
VOICE_ID="21m00Tcm4TlvDq8ikWAM"
MODEL_ID="eleven_flash_v2_5"

if [[ -z "$API_KEY" && -f "$CONFIG_FILE" ]]; then
  API_KEY=$(sed -n '/^---$/,/^---$/{ /^elevenlabs_api_key:/{ s/^elevenlabs_api_key:[[:space:]]*"*\([^"]*\)"*/\1/p; } }' "$CONFIG_FILE" | head -1)
  # Read optional voice_id override
  _VID=$(sed -n '/^---$/,/^---$/{ /^voice_id:/{ s/^voice_id:[[:space:]]*"*\([^"]*\)"*/\1/p; } }' "$CONFIG_FILE" | head -1)
  [[ -n "$_VID" ]] && VOICE_ID="$_VID"
  # Read optional model_id override
  _MID=$(sed -n '/^---$/,/^---$/{ /^model_id:/{ s/^model_id:[[:space:]]*"*\([^"]*\)"*/\1/p; } }' "$CONFIG_FILE" | head -1)
  [[ -n "$_MID" ]] && MODEL_ID="$_MID"
fi

# --- Queue Setup ---
QUEUE_DIR="${TMPDIR:-/tmp}/claude_tts_queue"
mkdir -p "$QUEUE_DIR"

# Atomic sequence number via mkdir-based lock
LOCK_DIR="${QUEUE_DIR}/.lock"
SEQ_FILE="${QUEUE_DIR}/.seq"

acquire_lock() {
  local attempts=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [[ $attempts -ge 50 ]]; then
      # Stale lock — force remove
      rm -rf "$LOCK_DIR"
    fi
    sleep 0.1
  done
}

release_lock() {
  rm -rf "$LOCK_DIR"
}

acquire_lock
SEQ=$(cat "$SEQ_FILE" 2>/dev/null || echo "0")
SEQ=$((SEQ + 1))
printf "%d" "$SEQ" > "$SEQ_FILE"
release_lock

SEQ_PADDED=$(printf "%06d" "$SEQ")
AUDIO_FILE=""
USE_FALLBACK=false

# --- ElevenLabs API ---
if [[ -n "$API_KEY" ]]; then
  AUDIO_FILE="${QUEUE_DIR}/${SEQ_PADDED}.mp3"
  BODY=$(jq -n --arg text "$CLEANED" --arg model "$MODEL_ID" '{
    text: $text,
    model_id: $model
  }')

  HTTP_CODE=$(curl -s -w "%{http_code}" -o "$AUDIO_FILE" \
    --max-time 30 \
    -X POST "https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}" \
    -H "xi-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$BODY" 2>/dev/null || echo "000")

  # Validate response: HTTP 200 and file > 1KB
  if [[ "$HTTP_CODE" != "200" ]]; then
    rm -f "$AUDIO_FILE"
    USE_FALLBACK=true
  elif [[ ! -f "$AUDIO_FILE" ]]; then
    USE_FALLBACK=true
  else
    FILE_SIZE=$(stat -f%z "$AUDIO_FILE" 2>/dev/null || echo "0")
    if [[ "$FILE_SIZE" -lt 1024 ]]; then
      rm -f "$AUDIO_FILE"
      USE_FALLBACK=true
    fi
  fi
else
  USE_FALLBACK=true
fi

# --- macOS say Fallback ---
if [[ "$USE_FALLBACK" == true ]]; then
  if command -v say &>/dev/null; then
    AUDIO_FILE="${QUEUE_DIR}/${SEQ_PADDED}.aiff"
    # Truncate for say (it handles long text but let's be reasonable)
    SAY_TEXT="${CLEANED:0:2000}"
    say -o "$AUDIO_FILE" "$SAY_TEXT" 2>/dev/null
    if [[ ! -f "$AUDIO_FILE" || $(stat -f%z "$AUDIO_FILE" 2>/dev/null || echo "0") -lt 100 ]]; then
      rm -f "$AUDIO_FILE"
      echo "[claude-tts] Both ElevenLabs and macOS say failed" >&2
      exit 1
    fi
  else
    echo "[claude-tts] No TTS backend available (no API key and no macOS say)" >&2
    exit 1
  fi
fi

# --- Start Queue Daemon if Not Running ---
DAEMON_PID_FILE="${QUEUE_DIR}/daemon.pid"
DAEMON_RUNNING=false

if [[ -f "$DAEMON_PID_FILE" ]]; then
  DAEMON_PID=$(cat "$DAEMON_PID_FILE" 2>/dev/null || echo "0")
  if kill -0 "$DAEMON_PID" 2>/dev/null; then
    DAEMON_RUNNING=true
  else
    rm -f "$DAEMON_PID_FILE"
  fi
fi

if [[ "$DAEMON_RUNNING" == false ]]; then
  "${SCRIPT_DIR}/tts-queue-daemon.sh" &>/dev/null & disown
fi

exit 0
