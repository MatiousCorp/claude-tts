#!/usr/bin/env bash
# tts-stop.sh — Stop all TTS playback immediately and clear the queue.
# Can be called from hooks, commands, or directly.

set -uo pipefail

QUEUE_DIR="${TMPDIR:-/tmp}/claude_tts_queue"

# Kill the queue daemon and its child audio players
if [[ -f "${QUEUE_DIR}/daemon.pid" ]]; then
  DAEMON_PID=$(cat "${QUEUE_DIR}/daemon.pid" 2>/dev/null || echo "")
  if [[ -n "$DAEMON_PID" ]] && kill -0 "$DAEMON_PID" 2>/dev/null; then
    # Kill children first (audio players: afplay, mpv, ffplay, etc.)
    pkill -P "$DAEMON_PID" 2>/dev/null || true
    # Then kill the daemon itself
    kill "$DAEMON_PID" 2>/dev/null || true
  fi
  rm -f "${QUEUE_DIR}/daemon.pid"
fi

# Clear remaining queued audio files
rm -f "${QUEUE_DIR}/"*.mp3 "${QUEUE_DIR}/"*.wav 2>/dev/null || true

# Reset sequence counter so next TTS starts fresh
rm -f "${QUEUE_DIR}/.seq" 2>/dev/null || true

exit 0
