#!/usr/bin/env bash
# tts-setup.sh — First-time setup for Claude TTS plugin
# Usage: tts-setup.sh [api-key]

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$HOME/.claude/claude-tts.local.md"

echo "=== Claude TTS Setup ==="
echo ""

# 1. Check jq
if ! command -v jq &>/dev/null; then
  echo "WARNING: jq is not installed. It is required for the TTS hook."
  echo "Install with: brew install jq"
  echo ""
fi

# 2. Get API key
API_KEY="${1:-}"
if [[ -z "$API_KEY" ]]; then
  echo "No API key provided."
  echo "Usage: tts-setup.sh <elevenlabs-api-key>"
  echo ""
  echo "Get your API key at: https://elevenlabs.io/app/settings/api-keys"
  echo ""
  echo "You can also set it as an environment variable:"
  echo "  export ELEVENLABS_API_KEY=sk_..."
  exit 1
fi

# 3. Write config file
mkdir -p "$HOME/.claude"
cat > "$CONFIG_FILE" << EOF
---
elevenlabs_api_key: "${API_KEY}"
voice_id: "21m00Tcm4TlvDq8ikWAM"
model_id: "eleven_flash_v2_5"
---

Claude TTS plugin configuration. Edit voice_id and model_id above to customize.
See https://elevenlabs.io/docs/api-reference/get-voices for voice options.
EOF

echo "Config written to: $CONFIG_FILE"

# 4. Enable TTS
touch "$HOME/.claude/tts-enabled"
echo "TTS enabled."

# 5. Make scripts executable
chmod +x "${PLUGIN_ROOT}/hooks/scripts/"*.sh
chmod +x "${PLUGIN_ROOT}/scripts/"*.sh
echo "Scripts marked executable."

# 6. Test with sample phrase
echo ""
echo "Testing TTS pipeline..."

QUEUE_DIR="${TMPDIR:-/tmp}/claude_tts_queue"
mkdir -p "$QUEUE_DIR"

TEST_TEXT="Claude TTS is now set up and working."

# Try ElevenLabs
VOICE_ID="21m00Tcm4TlvDq8ikWAM"
MODEL_ID="eleven_flash_v2_5"
TEST_FILE="${QUEUE_DIR}/test_setup.mp3"

BODY=$(jq -n --arg text "$TEST_TEXT" --arg model "$MODEL_ID" '{
  text: $text,
  model_id: $model
}')

HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TEST_FILE" \
  --max-time 15 \
  -X POST "https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}" \
  -H "xi-api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" == "200" && -f "$TEST_FILE" ]]; then
  FILE_SIZE=$(stat -f%z "$TEST_FILE" 2>/dev/null || echo "0")
  if [[ "$FILE_SIZE" -gt 1024 ]]; then
    echo "ElevenLabs API: OK (${FILE_SIZE} bytes)"
    echo "Playing test audio..."
    afplay "$TEST_FILE" 2>/dev/null || true
    rm -f "$TEST_FILE"
    echo ""
    echo "Setup complete! TTS is ready."
    exit 0
  fi
fi

rm -f "$TEST_FILE"
echo "ElevenLabs API: FAILED (HTTP $HTTP_CODE)"
echo "Check your API key and try again."
echo ""

# Try macOS say fallback
if command -v say &>/dev/null; then
  echo "Falling back to macOS say..."
  say "$TEST_TEXT" 2>/dev/null && echo "macOS say: OK" || echo "macOS say: FAILED"
fi

echo ""
echo "Setup complete (with warnings). Check your API key if ElevenLabs didn't work."
exit 0
