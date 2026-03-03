---
description: Show current TTS plugin status
allowed-tools: [Bash]
---

Check the status of the Claude TTS plugin by running the following checks and reporting the results:

1. **Toggle**: Check if `~/.claude/tts-enabled` exists
2. **API Key**: Check if `ELEVENLABS_API_KEY` env var is set, or if `~/.claude/claude-tts.local.md` exists and contains an API key
3. **jq**: Check if `jq` is installed (`command -v jq`)
4. **Queue daemon**: Check if the daemon PID file exists at `${TMPDIR:-/tmp}/claude_tts_queue/daemon.pid` and if that process is alive
5. **Queued files**: Count any `.mp3` or `.aiff` files in `${TMPDIR:-/tmp}/claude_tts_queue/`

Run these as a single bash script:

```bash
echo "=== Claude TTS Status ==="
echo ""

# Toggle
if [[ -f "$HOME/.claude/tts-enabled" ]]; then
  echo "TTS:      ENABLED"
else
  echo "TTS:      DISABLED"
fi

# API Key
API_KEY="${ELEVENLABS_API_KEY:-}"
CONFIG="$HOME/.claude/claude-tts.local.md"
if [[ -n "$API_KEY" ]]; then
  echo "API Key:  Set (env var)"
elif [[ -f "$CONFIG" ]] && grep -q 'elevenlabs_api_key' "$CONFIG" 2>/dev/null; then
  echo "API Key:  Set (config file)"
else
  echo "API Key:  NOT SET (will use macOS say fallback)"
fi

# jq
if command -v jq &>/dev/null; then
  echo "jq:       Installed ($(jq --version 2>&1))"
else
  echo "jq:       NOT FOUND (required! run: brew install jq)"
fi

# Queue daemon
QUEUE_DIR="${TMPDIR:-/tmp}/claude_tts_queue"
PID_FILE="$QUEUE_DIR/daemon.pid"
if [[ -f "$PID_FILE" ]]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    echo "Daemon:   Running (PID $PID)"
  else
    echo "Daemon:   Stale PID file (not running)"
  fi
else
  echo "Daemon:   Not running (starts automatically)"
fi

# Queued files
QUEUED=$(ls -1 "$QUEUE_DIR"/*.mp3 "$QUEUE_DIR"/*.aiff 2>/dev/null | wc -l | tr -d ' ')
echo "Queued:   $QUEUED audio file(s)"
```

Report the results to the user in a clear format.
