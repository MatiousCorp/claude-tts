#!/usr/bin/env bash
# tts-stop.sh — Stop all TTS playback immediately and clear the queue.
# Can be called from hooks, commands, or directly.

set -uo pipefail

QUEUE_DIR="${TMPDIR:-/tmp}/claude_tts_queue"

# Kill any running TTS workers (API calls in progress)
pkill -f "tts-worker.sh" 2>/dev/null || true

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

# Remove daemon lock so a new daemon can start
rm -rf "${QUEUE_DIR}/.daemon_lock" 2>/dev/null || true

# Kill audio player and TTS generator processes directly.
# pkill -P only kills direct children; grandchild/orphan processes survive.
# For example, say (child of killed worker) or afplay (grandchild of daemon
# via backgrounded subshell) would keep running without this.
case "$(uname -s)" in
  Darwin*)
    pkill -x afplay 2>/dev/null || true
    pkill -x say 2>/dev/null || true
    ;;
  Linux*)
    for p in mpv ffplay paplay aplay espeak-ng espeak piper; do
      pkill -x "$p" 2>/dev/null || true
    done
    ;;
esac

# Clear remaining queued audio files and reset sequence counter
# Use find instead of glob to avoid zsh nomatch errors
find "${QUEUE_DIR}" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.wav" -o -name ".seq" \) -delete 2>/dev/null || true

# Release hook lock since we killed the worker
rm -rf "${TMPDIR:-/tmp}/claude_tts_hook.lock" 2>/dev/null || true

exit 0
