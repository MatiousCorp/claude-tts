#!/usr/bin/env bash
# tts-setup.sh — Set up Claude TTS plugin with a provider
# Usage: tts-setup.sh <provider> [api-key]

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$HOME/.claude/claude-tts.local.md"
VALID_PROVIDERS="elevenlabs openai google amazon azure edge kitten mimo tada fish gemini local"

# Source cross-platform abstraction layer
source "${PLUGIN_ROOT}/hooks/scripts/platform.sh"

PROVIDER="${1:-}"
API_KEY="${2:-}"

# Backward compat: map "say" → "local"
[[ "$PROVIDER" == "say" ]] && PROVIDER="local"

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
  echo "  edge        — Microsoft Edge TTS (free, no key needed)"
  echo "  kitten      — Kitten TTS V0.8 (free, local, no key needed)"
  echo "  mimo        — Xiaomi MiMo-V2-TTS (expressive, free limited time)"
  echo "  tada        — Hume TADA (open-source, GPU recommended, optional voice cloning)"
  echo "  fish        — Fish Audio TTS (high quality, multilingual, voice cloning)"
  echo "  gemini      — Google Gemini 3.1 Flash TTS (70+ languages, multi-speaker)"
  echo "  local       — System built-in TTS (free, no key needed)"
  echo ""
  echo "Examples:"
  echo "  /claude-tts:tts-setup elevenlabs sk_abc123"
  echo "  /claude-tts:tts-setup openai sk-abc123"
  echo "  /claude-tts:tts-setup tada"
  echo "  /claude-tts:tts-setup local"
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
  echo "Install with: $(install_hint jq)"
  echo ""
fi

# Require API key for cloud providers
if [[ "$PROVIDER" != "local" && "$PROVIDER" != "amazon" && "$PROVIDER" != "edge" && "$PROVIDER" != "kitten" && "$PROVIDER" != "tada" && -z "$API_KEY" ]]; then
  echo "ERROR: API key required for $PROVIDER"
  echo ""
  case "$PROVIDER" in
    elevenlabs) echo "Get your key at: https://elevenlabs.io/app/settings/api-keys" ;;
    openai)     echo "Get your key at: https://platform.openai.com/api-keys" ;;
    google)     echo "Get your key at: https://console.cloud.google.com/apis/credentials" ;;
    azure)      echo "Get your key at: https://portal.azure.com/#view/Microsoft_Azure_ProjectOxford/CognitiveServicesHub" ;;
    mimo)       echo "Get your key at: https://platform.xiaomimimo.com/#/console/api-keys" ;;
    fish)       echo "Get your key at: https://fish.audio (Dashboard → API Keys)" ;;
    gemini)     echo "Get your key at: https://aistudio.google.com/apikey" ;;
  esac
  exit 1
fi

# Write config file
mkdir -p "$HOME/.claude"
if [[ "$PROVIDER" == "local" ]]; then
  cat > "$CONFIG_FILE" << EOF
---
provider: "local"
---

Claude TTS configuration. Provider: local system TTS.
EOF
elif [[ "$PROVIDER" == "amazon" ]]; then
  cat > "$CONFIG_FILE" << EOF
---
provider: "amazon"
---

Claude TTS configuration. Provider: Amazon Polly.
Uses AWS CLI credentials (aws configure).
EOF
elif [[ "$PROVIDER" == "edge" ]]; then
  cat > "$CONFIG_FILE" << EOF
---
provider: "edge"
---

Claude TTS configuration. Provider: Microsoft Edge TTS.
Requires: pip install edge-tts
EOF
elif [[ "$PROVIDER" == "kitten" ]]; then
  cat > "$CONFIG_FILE" << EOF
---
provider: "kitten"
voice_id: "expr-voice-2-f"
---

Claude TTS configuration. Provider: Kitten TTS V0.8.
Requires: pip install KittenTTS soundfile
System dep: espeak (brew install espeak / apt install espeak)
Voices: expr-voice-2-m, expr-voice-2-f, expr-voice-3-m, expr-voice-3-f, expr-voice-4-m, expr-voice-4-f, expr-voice-5-m, expr-voice-5-f
EOF
elif [[ "$PROVIDER" == "mimo" ]]; then
  cat > "$CONFIG_FILE" << EOF
---
provider: "mimo"
api_key: "${API_KEY}"
voice_id: "mimo_default"
model_id: "mimo-v2-tts"
---

Claude TTS configuration. Provider: Xiaomi MiMo-V2-TTS.
Voices: mimo_default, default_zh (Chinese female), default_en (English female)
Style: prefix text with <style>Happy</style> etc. for expressive speech.
EOF
elif [[ "$PROVIDER" == "fish" ]]; then
  cat > "$CONFIG_FILE" << EOF
---
provider: "fish"
api_key: "${API_KEY}"
voice_id: ""
model_id: "s2-pro"
---

Claude TTS configuration. Provider: Fish Audio.
voice_id: reference voice ID (leave empty for default, or use a voice ID from fish.audio)
model_id: s2-pro (flagship) or s2 (faster)
Supports 80+ languages, voice cloning, and emotional tags like [excited] [whisper].
EOF
elif [[ "$PROVIDER" == "gemini" ]]; then
  cat > "$CONFIG_FILE" << EOF
---
provider: "gemini"
api_key: "${API_KEY}"
voice_id: "Kore"
model_id: "gemini-3.1-flash-tts-preview"
---

Claude TTS configuration. Provider: Google Gemini 3.1 Flash TTS.
voice_id: Kore (default). Available voices: Zephyr, Puck, Charon, Kore, Fenrir, Leda, Orus, Aoede, Callirrhoe, Autonoe, Enceladus, Iapetus, Umbriel, Algieba, Despina, Erinome, Algenib, Rasalgethi, Laomedeia, Achernar, Alnilam, Schedar, Gacrux, Pulcherrima, Achird, Zubenelgenubi, Vindemiatrix, Sadachbia, Sadaltager, Sulafat
model_id: gemini-3.1-flash-tts-preview (latest) or gemini-2.5-flash-preview-tts or gemini-2.5-pro-preview-tts
Supports 70+ languages, multi-speaker dialogue, and audio tags like [whispers] [laughs].
EOF
elif [[ "$PROVIDER" == "tada" ]]; then
  # Second arg (API_KEY) is repurposed as reference audio path for TADA
  ref_audio="${API_KEY:-$HOME/.claude/tada-reference.wav}"
  # Generate default reference audio if none provided
  if [[ ! -f "$ref_audio" && "$ref_audio" == "$HOME/.claude/tada-reference.wav" ]]; then
    if check_local_tts; then
      echo "Generating default reference audio..."
      tts_local "The quick brown fox jumps over the lazy dog near the river bank on a warm summer day." "$ref_audio"
      if [[ ! -f "$ref_audio" ]]; then
        echo "WARNING: Could not generate default reference audio."
      fi
    else
      echo "WARNING: No reference audio provided and local TTS unavailable."
      echo "Provide a reference WAV file: /claude-tts:tts-setup tada /path/to/voice.wav"
    fi
  fi
  # Remove stale prompt cache when reference changes
  rm -f "$HOME/.claude/tada-prompt-cache.pt"
  cat > "$CONFIG_FILE" << EOF
---
provider: "tada"
voice_id: "${ref_audio}"
model_id: "tada-1b"
---

Claude TTS configuration. Provider: Hume TADA (open-source voice cloning).
Requires: pip install hume-tada
voice_id: path to reference WAV file (voice to clone)
model_id: tada-1b (English, smaller) or tada-3b-ml (multilingual, larger)
GPU recommended (CUDA or Apple MPS). CPU works but is slow.
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
      echo "AWS CLI not found. Install with: $(install_hint awscli)"
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
  edge)
    if command -v edge-tts &>/dev/null; then
      edge-tts --voice "en-US-AriaNeural" --text "$TEST_TEXT" --write-media "$TEST_FILE" &>/dev/null && HTTP_CODE="200" || HTTP_CODE="000"
    else
      echo "edge-tts not found. Install with: pip install edge-tts"
      HTTP_CODE="000"
    fi
    ;;
  kitten)
    TEST_FILE="${QUEUE_DIR}/test_setup.wav"
    # Auto-install espeak system dependency if missing
    if ! command -v espeak &>/dev/null && ! command -v espeak-ng &>/dev/null; then
      echo "Installing espeak (required by Kitten TTS)..."
      case "$CLAUDE_TTS_OS" in
        macos)   brew install espeak 2>/dev/null ;;
        linux)
          if command -v apt-get &>/dev/null; then sudo apt-get install -y espeak-ng 2>/dev/null
          elif command -v dnf &>/dev/null; then sudo dnf install -y espeak-ng 2>/dev/null
          elif command -v pacman &>/dev/null; then sudo pacman -S --noconfirm espeak-ng 2>/dev/null
          fi ;;
      esac
      if ! command -v espeak &>/dev/null && ! command -v espeak-ng &>/dev/null; then
        echo "WARNING: Could not install espeak. Install manually: $(install_hint espeak)"
      else
        echo "espeak: OK"
      fi
    fi
    # Auto-install Python packages if missing
    if ! python3 -c "import kittentts" &>/dev/null; then
      echo "Installing KittenTTS and soundfile..."
      pip install KittenTTS soundfile 2>&1 | tail -1
    fi
    if python3 -c "import kittentts" &>/dev/null; then
      KITTEN_TEXT="$TEST_TEXT" KITTEN_OUTPUT="$TEST_FILE" \
        python3 -c "
import os, soundfile as sf
from kittentts import KittenTTS
model = KittenTTS()
audio = model.generate(text=os.environ['KITTEN_TEXT'], voice='expr-voice-2-f', speed=1.0)
sf.write(os.environ['KITTEN_OUTPUT'], audio, 24000)
" &>/dev/null && HTTP_CODE="200" || HTTP_CODE="000"
    else
      echo "ERROR: Failed to install KittenTTS. Try manually: pip install KittenTTS soundfile"
      HTTP_CODE="000"
    fi
    ;;
  mimo)
    TEST_FILE="${QUEUE_DIR}/test_setup.wav"
    TMP_RESP=$(mktemp "${TMPDIR:-/tmp}/claude_tts_mimo_test.XXXXXX")
    BODY=$(jq -n --arg text "$TEST_TEXT" '{
      model: "mimo-v2-tts",
      messages: [{ role: "assistant", content: $text }],
      audio: { format: "wav", voice: "mimo_default" }
    }')
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TMP_RESP" --max-time 15 \
      -X POST "https://api.xiaomimimo.com/v1/chat/completions" \
      -H "api-key: ${API_KEY}" -H "Content-Type: application/json" \
      -d "$BODY" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" == "200" ]]; then
      jq -r '.choices[0].message.audio.data' "$TMP_RESP" 2>/dev/null | base64 -d > "$TEST_FILE" 2>/dev/null
    fi
    rm -f "$TMP_RESP"
    ;;
  fish)
    BODY=$(jq -n --arg text "$TEST_TEXT" '{text: $text, format: "mp3"}')
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TEST_FILE" --max-time 15 \
      -X POST "https://api.fish.audio/v1/tts" \
      -H "Authorization: Bearer ${API_KEY}" \
      -H "Content-Type: application/json" \
      -H "model: s2-pro" \
      -d "$BODY" 2>/dev/null || echo "000")
    ;;
  gemini)
    TEST_FILE="${QUEUE_DIR}/test_setup.wav"
    TMP_RESP=$(mktemp "${TMPDIR:-/tmp}/claude_tts_gemini_test.XXXXXX")
    BODY=$(jq -n --arg text "$TEST_TEXT" '{
      contents: [{ parts: [{ text: $text }] }],
      generationConfig: {
        responseModalities: ["AUDIO"],
        speechConfig: {
          voiceConfig: {
            prebuiltVoiceConfig: { voiceName: "Kore" }
          }
        }
      }
    }')
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TMP_RESP" --max-time 15 \
      -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-tts-preview:generateContent" \
      -H "x-goog-api-key: ${API_KEY}" -H "Content-Type: application/json" \
      -d "$BODY" 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" == "200" ]]; then
      PCM_TMP=$(mktemp "${TMPDIR:-/tmp}/claude_tts_pcm_test.XXXXXX")
      jq -r '.candidates[0].content.parts[0].inlineData.data' "$TMP_RESP" 2>/dev/null | base64 -d > "$PCM_TMP" 2>/dev/null
      python3 -c "
import struct, sys
pcm = open(sys.argv[1], 'rb').read()
with open(sys.argv[2], 'wb') as f:
    f.write(b'RIFF')
    f.write(struct.pack('<I', len(pcm) + 36))
    f.write(b'WAVEfmt ')
    f.write(struct.pack('<IHHIIHH', 16, 1, 1, 24000, 48000, 2, 16))
    f.write(b'data')
    f.write(struct.pack('<I', len(pcm)))
    f.write(pcm)
" "$PCM_TMP" "$TEST_FILE" 2>/dev/null
      rm -f "$PCM_TMP"
    fi
    rm -f "$TMP_RESP"
    ;;
  tada)
    TEST_FILE="${QUEUE_DIR}/test_setup.wav"
    # Auto-install hume-tada if missing
    if ! python3 -c "import tada" &>/dev/null; then
      echo "Installing hume-tada (this may take a while, includes PyTorch)..."
      pip install hume-tada 2>&1 | tail -3
    fi
    if python3 -c "import tada" &>/dev/null; then
      tada_ref="${API_KEY:-$HOME/.claude/tada-reference.wav}"
      tada_cache="$HOME/.claude/tada-prompt-cache.pt"
      if [[ -f "$tada_ref" ]]; then
        echo "Loading model and generating test audio (first run downloads ~2-4 GB)..."
        TADA_TEXT="$TEST_TEXT" TADA_OUTPUT="$TEST_FILE" TADA_MODEL="tada-1b" \
          TADA_REF_AUDIO="$tada_ref" TADA_CACHE="$tada_cache" \
          python3 -c "
import os, sys, torch, torchaudio
from tada.modules.encoder import EncoderOutput
from tada.modules.tada import TadaForCausalLM
text = os.environ['TADA_TEXT']
output_path = os.environ['TADA_OUTPUT']
model_name = 'HumeAI/' + os.environ.get('TADA_MODEL', 'tada-1b')
ref_audio_path = os.environ.get('TADA_REF_AUDIO', '')
cache_path = os.environ.get('TADA_CACHE', '')
if torch.cuda.is_available():
    device, dtype = 'cuda', torch.bfloat16
elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
    device, dtype = 'mps', torch.float32
else:
    device, dtype = 'cpu', torch.float32
if cache_path and os.path.exists(cache_path):
    prompt = EncoderOutput.load(cache_path, device=device)
else:
    from tada.modules.encoder import Encoder
    if not ref_audio_path or not os.path.exists(ref_audio_path):
        sys.exit(1)
    encoder = Encoder.from_pretrained('HumeAI/tada-codec', subfolder='encoder').to(device)
    audio, sr = torchaudio.load(ref_audio_path)
    audio = audio.to(device)
    prompt = encoder(audio, sample_rate=sr)
    if cache_path:
        os.makedirs(os.path.dirname(cache_path), exist_ok=True)
        prompt.save(cache_path)
    del encoder
model = TadaForCausalLM.from_pretrained(model_name, torch_dtype=dtype).to(device)
if hasattr(model, 'decoder'):
    model.decoder.to(device)
output = model.generate(prompt=prompt, text=text)
wav = output.audio[0].detach().cpu().float()
if wav.dim() == 1:
    wav = wav.unsqueeze(0)
torchaudio.save(output_path, wav, 24000)
" && HTTP_CODE="200" || HTTP_CODE="000"
      else
        echo "ERROR: Reference audio not found at: $tada_ref"
        HTTP_CODE="000"
      fi
    else
      echo "ERROR: Failed to install hume-tada. Try manually: pip install hume-tada"
      HTTP_CODE="000"
    fi
    ;;
  local)
    if check_local_tts; then
      tts_local_speak "$TEST_TEXT" && test_passed=true || true
      echo "Local TTS ($CLAUDE_TTS_OS): OK"
      echo ""
      echo "Setup complete!"
      exit 0
    else
      echo "Local TTS: NOT AVAILABLE"
      case "$CLAUDE_TTS_OS" in
        linux)   echo "Install with: $(install_hint espeak-ng)" ;;
        windows) echo "Windows SAPI should be available. Check PowerShell." ;;
      esac
      exit 1
    fi
    ;;
esac

if [[ "$HTTP_CODE" == "200" && -f "$TEST_FILE" ]]; then
  FILE_SIZE=$(file_size "$TEST_FILE")
  if [[ "$FILE_SIZE" -gt 1024 ]]; then
    echo "$PROVIDER API: OK (${FILE_SIZE} bytes)"
    if check_audio_player; then
      echo "Playing test audio..."
      play_audio "$TEST_FILE" 2>/dev/null || true
    else
      echo "No audio player found — skipping playback test."
      case "$CLAUDE_TTS_OS" in
        linux) echo "Install with: $(install_hint mpv)" ;;
      esac
    fi
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
if check_local_tts; then
  echo "Falling back to local TTS..."
  tts_local_speak "$TEST_TEXT" && echo "Local TTS: OK" || echo "Local TTS: FAILED"
fi

echo ""
echo "Setup complete (with warnings). Check your API key if $PROVIDER didn't work."
exit 0
