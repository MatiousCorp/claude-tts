---
description: Stop TTS playback immediately
allowed-tools: [Bash]
---

Run this exact command:

```bash
QUEUE_DIR="${TMPDIR:-/tmp}/claude_tts_queue" && if [[ -f "$QUEUE_DIR/daemon.pid" ]]; then DAEMON_PID=$(cat "$QUEUE_DIR/daemon.pid" 2>/dev/null); if [[ -n "$DAEMON_PID" ]]; then pkill -P "$DAEMON_PID" 2>/dev/null || true; kill "$DAEMON_PID" 2>/dev/null || true; fi; rm -f "$QUEUE_DIR/daemon.pid"; fi; find "$QUEUE_DIR" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.wav" -o -name ".seq" \) -delete 2>/dev/null; echo "TTS playback stopped."
```
