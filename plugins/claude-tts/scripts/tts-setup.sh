#!/usr/bin/env bash
# tts-setup.sh — Set up Claude TTS plugin with a provider
# Usage: tts-setup.sh <provider> [api-key]

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$HOME/.claude/claude-tts.local.md"
VALID_PROVIDERS="elevenlabs openai google amazon azure say"

PROVIDER="${1:-}"
API_KEY="${2:-}"

if [[ -z "$PROVIDER" ]]; then
  echo "=== Claude TTS Setup ==="
  echo ""
  echo "Usage: tts-setup <provider> [api-key]"
  echo ""
  echo "Providers:"
  echo "  elevenlabs  — ElevenLabs TTS (high quality)"
  echo "  openai      — OpenAI TTS"
  echo "  google      — Google Cloud Text-to-Speech"
  echo "  amazon      — Amazon Polly (uses AWS CLI creds)"
  echo "  azure       — Azure Cognitive Services Speech"
  echo "  say         — macOS built-in (free, no key needed)"
  echo ""
  echo "Examples:"
  echo "  /claude-tts:tts-setup elevenlabs sk_abc123"
  echo "  /claude-tts:tts-setup openai sk-abc123"
  echo "  /claude-tts:tts-setup say"
  exit 1
fi

# Validate provider
PROVIDER_VALID=false
for p in $VALID_PROVIDERS; do
  if [[ "$PROVIDER" == "$p" ]]; then
    PROVIDER_VALID=true
    break
  fi
done

if [[ "$PROVIDER_VALID" == false ]]; then
  echo "ERROR: Unknown provider '$PROVIDER'"
  echo "Valid providers: $VALID_PROVIDERS"
  exit 1
fi

# Check jq
if ! command -v jq &>/dev/null; then
  echo "WARNING: jq is not installed. It is required for the TTS hook."
  echo "Install with: brew install jq"
  echo ""
fi

# Require API key for cloud providers
if [[ "$PROVIDER" != "say" && "$PROVIDER" != "amazon" && -z "$API_KEY" ]]; then
  echo "ERROR: API key required for $PROVIDER"
  echo ""
  case "$PROVIDER" in
    elevenlabs) echo "Get your key at: https://elevenlabs.io/app/settings/api-keys" ;;
    openai)     echo "Get your key at: https://platform.openai.com/api-keys" ;;
    google)     echo "Get your key at: https://console.cloud.google.com/apis/credentials" ;;
    azure)      echo "Get your key at: https://portal.azure.com/#view/Microsoft_Azure_ProjectOxford/CognitiveServicesHub" ;;
  esac
  exit 1
fi

# Write config file
mkdir -p "$HOME/.claude"
if [[ "$PROVIDER" == "say" ]]; then
  cat > "$CONFIG_FILE" << EOF
---
provider: "say"
---

Claude TTS configuration. Provider: macOS say (built-in).
EOF
elif [[ "$PROVIDER" == "amazon" ]]; then
  cat > "$CONFIG_FILE" << EOF
---
provider: "amazon"
---

Claude TTS configuration. Provider: Amazon Polly.
Uses AWS CLI credentials (aws configure).
EOF
else
  cat > "$CONFIG_FILE" << EOF
---
provider: "${PROVIDER}"
api_key: "${API_KEY}"
---

Claude TTS configuration. Provider: ${PROVIDER}.
Edit voice_id and model_id above to customize.
EOF
fi

echo "Config written to: $CONFIG_FILE"

# Enable TTS
touch "$HOME/.claude/tts-enabled"
echo "TTS enabled with provider: $PROVIDER"

# Make scripts executable
chmod +x "${PLUGIN_ROOT}/hooks/scripts/"*.sh
chmod +x "${PLUGIN_ROOT}/scripts/"*.sh

# Test with sample phrase
echo ""
echo "Testing TTS pipeline..."

QUEUE_DIR="${TMPDIR:-/tmp}/claude_tts_queue"
mkdir -p "$QUEUE_DIR"
TEST_TEXT="Claude TTS is now set up and working."
TEST_FILE="${QUEUE_DIR}/test_setup.mp3"

test_passed=false

case "$PROVIDER" in
  elevenlabs)
    BODY=$(jq -n --arg text "$TEST_TEXT" '{text: $text, model_id: "eleven_flash_v2_5"}')
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TEST_FILE" --max-time 15 \
      -X POST "https://api.elevenlabs.io/v1/text-to-speech/21m00Tcm4TlvDq8ikWAM" \
      -H "xi-api-key: ${API_KEY}" -H "Content-Type: application/json" \
      -d "$BODY" 2>/dev/null || echo "000")
    ;;
  openai)
    BODY=$(jq -n --arg text "$TEST_TEXT" '{model: "tts-1", input: $text, voice: "alloy", response_format: "mp3"}')
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TEST_FILE" --max-time 15 \
      -X POST "https://api.openai.com/v1/audio/speech" \
      -H "Authorization: Bearer ${API_KEY}" -H "Content-Type: application/json" \
      -d "$BODY" 2>/dev/null || echo "000")
    ;;
  google)
    TMP_RESP=$(mktemp "${TMPDIR:-/tmp}/claude_tts_test.XXXXXX")
    BODY=$(jq -n --arg text "$TEST_TEXT" '{input:{text:$text},voice:{languageCode:"en-US",name:"en-US-Neural2-F"},audioConfig:{audioEncoding:"MP3"}}')
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TMP_RESP" --max-time 15 \
      -X POST "https://texttospeech.googleapis.com/v1/text:synthesize" \
      -H "X-Goog-Api-Key: ${API_KEY}" -H "Content-Type: application/json" \
      -d "$BODY" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" == "200" ]]; then
      jq -r '.audioContent' "$TMP_RESP" 2>/dev/null | base64 -d > "$TEST_FILE" 2>/dev/null
    fi
    rm -f "$TMP_RESP"
    ;;
  amazon)
    if command -v aws &>/dev/null; then
      aws polly synthesize-speech --output-format mp3 --voice-id Joanna --engine neural \
        --text "$TEST_TEXT" "$TEST_FILE" &>/dev/null && HTTP_CODE="200" || HTTP_CODE="000"
    else
      echo "AWS CLI not found. Install with: brew install awscli"
      HTTP_CODE="000"
    fi
    ;;
  azure)
    SSML="<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><voice name='en-US-JennyNeural'>${TEST_TEXT}</voice></speak>"
    REGION_VAL=$(grep '^region:' "$CONFIG_FILE" 2>/dev/null | head -1 | sed -E 's/^region:[[:space:]]*"?([^"]*)"?/\1/')
    [[ -z "$REGION_VAL" ]] && REGION_VAL="eastus"
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TEST_FILE" --max-time 15 \
      -X POST "https://${REGION_VAL}.tts.speech.microsoft.com/cognitiveservices/v1" \
      -H "Ocp-Apim-Subscription-Key: ${API_KEY}" \
      -H "Content-Type: application/ssml+xml" \
      -H "X-Microsoft-OutputFormat: audio-16khz-128kbitrate-mono-mp3" \
      -d "$SSML" 2>/dev/null || echo "000")
    ;;
  say)
    if command -v say &>/dev/null; then
      say "$TEST_TEXT" 2>/dev/null && test_passed=true || true
      echo "macOS say: OK"
      echo ""
      echo "Setup complete!"
      exit 0
    else
      echo "macOS say: NOT AVAILABLE"
      exit 1
    fi
    ;;
esac

if [[ "$HTTP_CODE" == "200" && -f "$TEST_FILE" ]]; then
  FILE_SIZE=$(stat -f%z "$TEST_FILE" 2>/dev/null || echo "0")
  if [[ "$FILE_SIZE" -gt 1024 ]]; then
    echo "$PROVIDER API: OK (${FILE_SIZE} bytes)"
    echo "Playing test audio..."
    afplay "$TEST_FILE" 2>/dev/null || true
    rm -f "$TEST_FILE"
    echo ""
    echo "Setup complete! TTS is ready."
    exit 0
  fi
fi

rm -f "$TEST_FILE"
echo "$PROVIDER API: FAILED (HTTP ${HTTP_CODE:-000})"
echo "Check your API key and try again."
echo ""

# Fallback test
if command -v say &>/dev/null; then
  echo "Falling back to macOS say..."
  say "$TEST_TEXT" 2>/dev/null && echo "macOS say: OK" || echo "macOS say: FAILED"
fi

echo ""
echo "Setup complete (with warnings). Check your API key if $PROVIDER didn't work."
exit 0
