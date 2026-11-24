#!/bin/bash
set -euo pipefail

ARG="${1:-}"
if [ -z "$ARG" ]; then
  exit 0
fi

urlencode() {
  /usr/bin/python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

OPEN_FLAGS="-g"

case "$ARG" in
  save_interactive)
    QUERY="action=save"
    OPEN_FLAGS=""
    ;;
  save:*)
    NAME="${ARG#save:}"
    QUERY="action=save&name=$(urlencode "$NAME")"
    ;;
  restore_slot:*)
    SLOT="${ARG#restore_slot:}"
    QUERY="action=restore&slot=${SLOT}"
    ;;
  restore_name:*)
    NAME="${ARG#restore_name:}"
    QUERY="action=restore&name=$(urlencode "$NAME")"
    ;;
  delete:*)
    NAME="${ARG#delete:}"
    QUERY="action=delete&name=$(urlencode "$NAME")"
    ;;
  *)
    exit 0
    ;;
esac

URL="hammerspoon://deskLayout?${QUERY}"

if pgrep -x Hammerspoon >/dev/null 2>&1; then
  if [ -n "$OPEN_FLAGS" ]; then
    open "$OPEN_FLAGS" "$URL"
  else
    open "$URL"
  fi
else
  printf '%s\n' "$QUERY" > "$HOME/.hammerspoon/desk_action"
  if [ -n "$OPEN_FLAGS" ]; then
    open "$OPEN_FLAGS" -a Hammerspoon
  else
    open -a Hammerspoon
  fi
fi
