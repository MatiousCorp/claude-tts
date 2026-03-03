---
description: Disable text-to-speech for Claude responses
allowed-tools: [Bash]
---

Disable the Claude TTS plugin by running:

```bash
rm -f ~/.claude/tts-enabled
```

Also kill any running queue daemon:

```bash
QUEUE_DIR="${TMPDIR:-/tmp}/claude_tts_queue"
if [[ -f "$QUEUE_DIR/daemon.pid" ]]; then
  kill $(cat "$QUEUE_DIR/daemon.pid") 2>/dev/null || true
  rm -f "$QUEUE_DIR/daemon.pid"
fi
```

Then confirm to the user: "TTS disabled. Claude responses will no longer be spoken."
