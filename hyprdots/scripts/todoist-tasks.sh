#!/usr/bin/env bash
# Todoist tasks for waybar (custom module, return-type json).
#
# Rotates through the active tasks: one task per refresh interval. With a
# single task it just shows that task; with several it cycles task 1 -> task 2
# -> ... and wraps around. The rotate index lives in a state file so each
# waybar interval advances by one.
#
# Env: TODOIST_API_KEY (loaded from ~/.config/opencode/.env).
set -euo pipefail

ENV_FILE="$HOME/.config/opencode/.env"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-todoist.idx"
MAXLEN="${TODOIST_MAXLEN:-40}"
API="https://api.todoist.com/api/v1/tasks"

emit() { # $1=text $2=tooltip $3=class
    python3 -c '
import json,sys
print(json.dumps({"text": sys.argv[1], "tooltip": sys.argv[2], "class": sys.argv[3]}))
' "$1" "$2" "$3"
}

if [ -z "${TODOIST_API_KEY:-}" ] && [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    set -a; . "$ENV_FILE"; set +a
fi

if [ -z "${TODOIST_API_KEY:-}" ]; then
    emit "󰄲 ?" "TODOIST_API_KEY not found" "none"
    exit 0
fi

payload="$(curl -fsS --max-time 5 "$API" -H "Authorization: Bearer $TODOIST_API_KEY" 2>/dev/null || true)"
if [ -z "$payload" ]; then
    emit "󰄲 !" "Todoist API unreachable" "err"
    exit 0
fi

# Build "priority<TAB>content<TAB>due" lines, sorted by priority desc then id.
mapfile -t rows < <(printf '%s' "$payload" | python3 -c '
import json,sys
d = json.load(sys.stdin)
items = d.get("results", d) if isinstance(d, dict) else d
items.sort(key=lambda t: (-int(t.get("priority", 1)), t.get("id", "")))
for t in items:
    due = (t.get("due") or {}).get("string") or ""
    print("%d\t%s\t%s" % (int(t.get("priority", 1)), t.get("content", ""), due))
')

n="${#rows[@]}"
if [ "$n" -eq 0 ]; then
    emit "󰄲" "No active tasks" "empty"
    # nothing to rotate through
    rm -f "$STATE_FILE" 2>/dev/null || true
    exit 0
fi

# Advance the rotate index (persisted between waybar refreshes).
idx=0
if [ -f "$STATE_FILE" ]; then
    idx="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
    case "$idx" in *[!0-9]*|'') idx=0 ;; esac
fi
idx=$(( idx % n ))
printf '%s' "$(( (idx + 1) % n ))" > "$STATE_FILE"

IFS=$'\t' read -r prio name due <<< "${rows[$idx]}"

# Truncate long names for the pill.
if [ "${#name}" -gt "$MAXLEN" ]; then
    name="${name:0:$((MAXLEN - 1))}…"
fi

tooltip="$name"
[ -n "$due" ] && tooltip="$tooltip
Due: $due"
[ "$n" -gt 1 ] && tooltip="$tooltip

Task $((idx + 1)) of $n (rotating)"

emit "󰄲 $name" "$tooltip" "ok"