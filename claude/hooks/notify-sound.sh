#!/bin/bash
# Claude Code audio notification hook
# Plays meme sounds for various Claude Code events.
# Usage: notify-sound.sh <permission|done|session-start|session-end|compact>

SOUND_DIR="$HOME/.claude/hooks/sounds"
MARKER="/tmp/claude-sound-session-end"

case "$1" in
  notification)
    # Read JSON from stdin; only play sound for permission_prompt notifications
    INPUT=$(cat)
    # Log for debugging (remove once confirmed working)
    echo "$INPUT" >> /tmp/claude-notification-debug.log
    ;;
  done)
    DONE_SOUNDS=("done.mp3" "done-wow.mp3" "done-navi.mp3" "done-myman.mp3" "done-omg.mp3" "done-weredone.mp3")
    afplay "$SOUND_DIR/${DONE_SOUNDS[$((RANDOM % ${#DONE_SOUNDS[@]}))]}" &
    ;;
  session-start)
    # If session-end fired within last 3s, this is a /clear — consume the marker so
    # the delayed session-end check finds it gone and stays silent.
    if [[ -f "$MARKER" ]]; then
      end_ts=$(cat "$MARKER")
      now=$(date +%s)
      if (( now - end_ts <= 3 )); then
        rm -f "$MARKER"
        afplay "$SOUND_DIR/clear.mp3" &
        exit 0
      fi
    fi
    rm -f "$MARKER"
    afplay "$SOUND_DIR/session-start.mp3" &
    ;;
  session-end)
    date +%s > "$MARKER"
    # Wait 1s, then check if session-start consumed the marker (meaning /clear).
    # If marker still exists, it was a real session end — play the sound.
    (sleep 1 && [[ -f "$MARKER" ]] && rm -f "$MARKER" && afplay "$SOUND_DIR/session-end.mp3") &
    ;;
  compact)        afplay "$SOUND_DIR/compact.mp3" &;;
esac
