---
description: Show current TTS plugin status
allowed-tools: [Bash]
---

Run this exact command:

```bash
echo "=== Claude TTS Status ===" && echo "" && if [[ -f "$HOME/.claude/tts-enabled" ]]; then echo "TTS:      ENABLED"; else echo "TTS:      DISABLED"; fi && CONFIG="$HOME/.claude/claude-tts.local.md" && PROVIDER="(not configured)" && if [[ -f "$CONFIG" ]]; then P=$(grep '^provider:' "$CONFIG" | head -1 | sed -E 's/^provider:[[:space:]]*"?([^"]*)"?/\1/'); if [[ -n "$P" ]]; then PROVIDER="$P"; elif grep -q 'elevenlabs_api_key' "$CONFIG" 2>/dev/null; then PROVIDER="elevenlabs (legacy config)"; fi; fi && echo "Provider: $PROVIDER" && API_KEY="" && if [[ -n "${CLAUDE_TTS_API_KEY:-}" ]]; then echo "API Key:  Set (CLAUDE_TTS_API_KEY env var)"; elif [[ -n "${ELEVENLABS_API_KEY:-}" ]]; then echo "API Key:  Set (ELEVENLABS_API_KEY env var)"; elif [[ -f "$CONFIG" ]] && grep -q 'api_key:' "$CONFIG" 2>/dev/null; then echo "API Key:  Set (config file)"; elif [[ -f "$CONFIG" ]] && grep -q 'elevenlabs_api_key:' "$CONFIG" 2>/dev/null; then echo "API Key:  Set (config file, legacy)"; elif [[ "$PROVIDER" == "say" || "$PROVIDER" == "amazon" ]]; then echo "API Key:  Not needed"; else echo "API Key:  NOT SET"; fi && if command -v jq &>/dev/null; then echo "jq:       Installed ($(jq --version 2>&1))"; else echo "jq:       NOT FOUND (required! run: brew install jq)"; fi && QUEUE_DIR="${TMPDIR:-/tmp}/claude_tts_queue" && PID_FILE="$QUEUE_DIR/daemon.pid" && if [[ -f "$PID_FILE" ]]; then PID=$(cat "$PID_FILE"); if kill -0 "$PID" 2>/dev/null; then echo "Daemon:   Running (PID $PID)"; else echo "Daemon:   Stale PID file (not running)"; fi; else echo "Daemon:   Not running (starts automatically)"; fi && QUEUED=$(ls -1 "$QUEUE_DIR"/*.mp3 "$QUEUE_DIR"/*.aiff 2>/dev/null | wc -l | tr -d ' ') && echo "Queued:   $QUEUED audio file(s)"
```

Report the output to the user.
