#!/usr/bin/env bash
# tts-worker.sh — Background worker: clean text, call TTS provider, queue audio.
# Supports: elevenlabs, openai, google, amazon, azure, say (macOS fallback)
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
  /^```/,/^```/d
  s/`[^`]+`//g
  s|https?://[^ ]*||g
  s|[[:space:]]/?[a-zA-Z0-9_./-]+\.[a-zA-Z]{1,10}||g
  s/^#{1,6}[[:space:]]+//
  s/\*{1,3}//g
  s/_{1,3}//g
  s/^[[:space:]]*[-*+][[:space:]]+//
  s/^[[:space:]]*[0-9]+\.[[:space:]]+//
  /^[[:space:]]*\|.*[-]{3,}/d
  s/\|/ /g
  s/\[([^]]*)\]\([^)]*\)/\1/g
  s/[[:space:]]+/ /g
')

CLEANED=$(echo "$CLEANED" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ +//; s/ +$//')
CLEANED="${CLEANED:0:5000}"

if [[ ${#CLEANED} -lt 5 ]]; then
  exit 0
fi

# --- Config ---
CONFIG_FILE="$HOME/.claude/claude-tts.local.md"

PROVIDER=""
API_KEY=""
VOICE_ID=""
MODEL_ID=""
REGION=""

# Parse config file
if [[ -f "$CONFIG_FILE" ]]; then
  PROVIDER=$(grep '^provider:' "$CONFIG_FILE" | head -1 | sed -E 's/^provider:[[:space:]]*"?([^"]*)"?/\1/')
  API_KEY=$(grep '^api_key:' "$CONFIG_FILE" | head -1 | sed -E 's/^api_key:[[:space:]]*"?([^"]*)"?/\1/')
  VOICE_ID=$(grep '^voice_id:' "$CONFIG_FILE" | head -1 | sed -E 's/^voice_id:[[:space:]]*"?([^"]*)"?/\1/')
  MODEL_ID=$(grep '^model_id:' "$CONFIG_FILE" | head -1 | sed -E 's/^model_id:[[:space:]]*"?([^"]*)"?/\1/')
  REGION=$(grep '^region:' "$CONFIG_FILE" | head -1 | sed -E 's/^region:[[:space:]]*"?([^"]*)"?/\1/')

  # Legacy migration: elevenlabs_api_key without provider → elevenlabs
  if [[ -z "$PROVIDER" ]]; then
    LEGACY_KEY=$(grep '^elevenlabs_api_key:' "$CONFIG_FILE" | head -1 | sed -E 's/^elevenlabs_api_key:[[:space:]]*"?([^"]*)"?/\1/')
    if [[ -n "$LEGACY_KEY" ]]; then
      PROVIDER="elevenlabs"
      API_KEY="$LEGACY_KEY"
    fi
  fi
fi

# Env var overrides: generic first, then legacy elevenlabs-specific
if [[ -n "${CLAUDE_TTS_API_KEY:-}" ]]; then
  API_KEY="$CLAUDE_TTS_API_KEY"
elif [[ -n "${ELEVENLABS_API_KEY:-}" && ("$PROVIDER" == "elevenlabs" || -z "$PROVIDER") ]]; then
  API_KEY="$ELEVENLABS_API_KEY"
  [[ -z "$PROVIDER" ]] && PROVIDER="elevenlabs"
fi

# Default to say if no provider configured
[[ -z "$PROVIDER" ]] && PROVIDER="say"

# --- Provider Defaults ---
case "$PROVIDER" in
  elevenlabs)
    [[ -z "$VOICE_ID" ]] && VOICE_ID="21m00Tcm4TlvDq8ikWAM"
    [[ -z "$MODEL_ID" ]] && MODEL_ID="eleven_flash_v2_5"
    ;;
  openai)
    [[ -z "$VOICE_ID" ]] && VOICE_ID="alloy"
    [[ -z "$MODEL_ID" ]] && MODEL_ID="tts-1"
    ;;
  google)
    [[ -z "$VOICE_ID" ]] && VOICE_ID="en-US-Neural2-F"
    ;;
  amazon)
    [[ -z "$VOICE_ID" ]] && VOICE_ID="Joanna"
    [[ -z "$MODEL_ID" ]] && MODEL_ID="neural"
    ;;
  azure)
    [[ -z "$VOICE_ID" ]] && VOICE_ID="en-US-JennyNeural"
    [[ -z "$REGION" ]] && REGION="eastus"
    ;;
  say) ;;
esac

# --- Queue Setup ---
QUEUE_DIR="${TMPDIR:-/tmp}/claude_tts_queue"
mkdir -p "$QUEUE_DIR"

LOCK_DIR="${QUEUE_DIR}/.lock"
SEQ_FILE="${QUEUE_DIR}/.seq"

acquire_lock() {
  local attempts=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [[ $attempts -ge 50 ]]; then
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

# --- Provider Functions ---

tts_elevenlabs() {
  AUDIO_FILE="${QUEUE_DIR}/${SEQ_PADDED}.mp3"
  local body
  body=$(jq -n --arg text "$CLEANED" --arg model "$MODEL_ID" '{
    text: $text,
    model_id: $model
  }')

  local http_code
  http_code=$(curl -s -w "%{http_code}" -o "$AUDIO_FILE" \
    --max-time 30 \
    -X POST "https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}" \
    -H "xi-api-key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$body" 2>/dev/null || echo "000")

  if [[ "$http_code" != "200" ]]; then
    rm -f "$AUDIO_FILE"
    return 1
  fi
  validate_audio "$AUDIO_FILE"
}

tts_openai() {
  AUDIO_FILE="${QUEUE_DIR}/${SEQ_PADDED}.mp3"
  local body
  body=$(jq -n --arg text "$CLEANED" --arg model "$MODEL_ID" --arg voice "$VOICE_ID" '{
    model: $model,
    input: $text,
    voice: $voice,
    response_format: "mp3"
  }')

  local http_code
  http_code=$(curl -s -w "%{http_code}" -o "$AUDIO_FILE" \
    --max-time 30 \
    -X POST "https://api.openai.com/v1/audio/speech" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$body" 2>/dev/null || echo "000")

  if [[ "$http_code" != "200" ]]; then
    rm -f "$AUDIO_FILE"
    return 1
  fi
  validate_audio "$AUDIO_FILE"
}

tts_google() {
  AUDIO_FILE="${QUEUE_DIR}/${SEQ_PADDED}.mp3"
  local body
  body=$(jq -n --arg text "$CLEANED" --arg voice "$VOICE_ID" '{
    input: { text: $text },
    voice: {
      languageCode: "en-US",
      name: $voice
    },
    audioConfig: { audioEncoding: "MP3" }
  }')

  local tmp_response
  tmp_response=$(mktemp "${TMPDIR:-/tmp}/claude_tts_gcloud.XXXXXX")

  local http_code
  http_code=$(curl -s -w "%{http_code}" -o "$tmp_response" \
    --max-time 30 \
    -X POST "https://texttospeech.googleapis.com/v1/text:synthesize" \
    -H "X-Goog-Api-Key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$body" 2>/dev/null || echo "000")

  if [[ "$http_code" != "200" ]]; then
    rm -f "$tmp_response" "$AUDIO_FILE"
    return 1
  fi

  # Google returns base64-encoded audio in JSON
  jq -r '.audioContent' "$tmp_response" 2>/dev/null | base64 -d > "$AUDIO_FILE" 2>/dev/null
  rm -f "$tmp_response"
  validate_audio "$AUDIO_FILE"
}

tts_amazon() {
  AUDIO_FILE="${QUEUE_DIR}/${SEQ_PADDED}.mp3"

  if ! command -v aws &>/dev/null; then
    return 1
  fi

  aws polly synthesize-speech \
    --output-format mp3 \
    --voice-id "$VOICE_ID" \
    --engine "$MODEL_ID" \
    --text "$CLEANED" \
    "$AUDIO_FILE" &>/dev/null

  validate_audio "$AUDIO_FILE"
}

tts_azure() {
  AUDIO_FILE="${QUEUE_DIR}/${SEQ_PADDED}.mp3"
  local ssml="<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>
  <voice name='${VOICE_ID}'>${CLEANED}</voice>
</speak>"

  local http_code
  http_code=$(curl -s -w "%{http_code}" -o "$AUDIO_FILE" \
    --max-time 30 \
    -X POST "https://${REGION}.tts.speech.microsoft.com/cognitiveservices/v1" \
    -H "Ocp-Apim-Subscription-Key: ${API_KEY}" \
    -H "Content-Type: application/ssml+xml" \
    -H "X-Microsoft-OutputFormat: audio-16khz-128kbitrate-mono-mp3" \
    -d "$ssml" 2>/dev/null || echo "000")

  if [[ "$http_code" != "200" && "$http_code" != "201" ]]; then
    rm -f "$AUDIO_FILE"
    return 1
  fi
  validate_audio "$AUDIO_FILE"
}

tts_say() {
  if ! command -v say &>/dev/null; then
    return 1
  fi
  AUDIO_FILE="${QUEUE_DIR}/${SEQ_PADDED}.aiff"
  local say_text="${CLEANED:0:2000}"
  say -o "$AUDIO_FILE" "$say_text" 2>/dev/null
  if [[ ! -f "$AUDIO_FILE" || $(stat -f%z "$AUDIO_FILE" 2>/dev/null || echo "0") -lt 100 ]]; then
    rm -f "$AUDIO_FILE"
    return 1
  fi
  return 0
}

validate_audio() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    return 1
  fi
  local size
  size=$(stat -f%z "$file" 2>/dev/null || echo "0")
  if [[ "$size" -lt 1024 ]]; then
    rm -f "$file"
    return 1
  fi
  return 0
}

# --- Provider Dispatch ---
if [[ "$PROVIDER" != "say" && -n "$API_KEY" ]]; then
  case "$PROVIDER" in
    elevenlabs) tts_elevenlabs || USE_FALLBACK=true ;;
    openai)     tts_openai     || USE_FALLBACK=true ;;
    google)     tts_google     || USE_FALLBACK=true ;;
    amazon)     tts_amazon     || USE_FALLBACK=true ;;
    azure)      tts_azure      || USE_FALLBACK=true ;;
    *)          USE_FALLBACK=true ;;
  esac
else
  USE_FALLBACK=true
fi

# --- macOS say Fallback ---
if [[ "$USE_FALLBACK" == true ]]; then
  if ! tts_say; then
    echo "[claude-tts] All TTS backends failed" >&2
    exit 1
  fi
fi

# --- Start Queue Daemon if Not Running ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
