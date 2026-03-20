#!/usr/bin/env bash
# tts-queue-daemon.sh — Persistent audio queue player.
# Plays queued audio files sequentially, exits after 30s idle.

set -uo pipefail

# Source cross-platform abstraction layer
source "$(cd "$(dirname "$0")" && pwd)/platform.sh"

QUEUE_DIR="${TMPDIR:-/tmp}/claude_tts_queue"
mkdir -p "$QUEUE_DIR"

# Ensure only one daemon instance runs at a time (atomic lock)
DAEMON_LOCK="${QUEUE_DIR}/.daemon_lock"
if ! mkdir "$DAEMON_LOCK" 2>/dev/null; then
  exit 0
fi

PID_FILE="${QUEUE_DIR}/daemon.pid"
echo $$ > "$PID_FILE"

cleanup() {
  # Kill all child processes (audio players like afplay, mpv, etc.)
  pkill -P $$ 2>/dev/null || true
  rm -f "$PID_FILE"
  rm -rf "$DAEMON_LOCK"
  # Clear remaining queued audio files (use find to avoid zsh glob issues)
  find "${QUEUE_DIR}" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.wav" \) -delete 2>/dev/null || true
}
trap cleanup EXIT TERM INT

IDLE=0

while true; do
  # Find the next audio file (mp3 or wav, sorted by name for sequence order)
  NEXT=$(ls -1 "${QUEUE_DIR}/"*.mp3 "${QUEUE_DIR}/"*.wav 2>/dev/null | sort | head -1 || true)

  if [[ -n "$NEXT" && -f "$NEXT" ]]; then
    IDLE=0
    # Play audio in background so signals can interrupt it
    play_audio "$NEXT" 2>/dev/null &
    wait $! 2>/dev/null || true
    # Remove after playing
    rm -f "$NEXT"
  else
    IDLE=$((IDLE + 1))
    sleep 1
    # Exit after 30 seconds idle
    if [[ $IDLE -ge 30 ]]; then
      exit 0
    fi
  fi
done
