#!/usr/bin/env python3
"""Todoist tasks for waybar (custom module, return-type json, streaming).

Shows tasks due TODAY plus anything OVERDUE (past due, still open).
Behaviour:
  * 0 tasks  -> muted "no tasks" state.
  * 1 task   -> the task stays on screen, no animation.
  * N tasks  -> one line at a time, fading out -> in between tasks.
Overdue tasks are marked in the tooltip.

The module is a long-running stream: waybar reads one JSON object per line and
redraws. Fading is done with pango <span alpha="..."> frames (verified to
render in waybar).

Env:
  TODOIST_API_KEY   from ~/.config/opencode/.env
  TODOIST_MAXLEN    max characters per task name (default 24)
  TODOIST_TEST_FILE read tasks from this JSON file instead of the API
"""
import datetime
import json
import os
import sys
import time
import urllib.request

API = "https://api.todoist.com/api/v1/tasks"
ENV_FILE = os.path.expanduser("~/.config/opencode/.env")

ICON = "\U000f0132"  # nf-md-checkbox_marked_circle
HOLD = 4.0           # seconds a task stays fully visible
FRAME = 0.06         # seconds per fade frame
FADE_STEPS = 6
REFRESH = 20.0       # seconds between API refreshes when nothing is due


def load_env():
    if os.environ.get("TODOIST_API_KEY"):
        return
    try:
        with open(ENV_FILE) as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("TODOIST_API_KEY="):
                    os.environ["TODOIST_API_KEY"] = line.split("=", 1)[1].strip().strip("'\"")
                    return
    except OSError:
        pass


def maxlen():
    try:
        return max(6, int(os.environ.get("TODOIST_MAXLEN", "24")))
    except ValueError:
        return 24


def truncate(text, limit):
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    return text[: limit - 1].rstrip() + "\u2026"


def emit(text, tooltip, cls):
    print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}), flush=True)


def fetch_tasks():
    """Return tasks due today or overdue, highest priority first.

    Each entry is (task, overdue_bool).
    """
    test_file = os.environ.get("TODOIST_TEST_FILE")
    try:
        if test_file:
            with open(test_file) as fh:
                payload = json.load(fh)
        else:
            key = os.environ.get("TODOIST_API_KEY", "")
            if not key:
                return None, "TODOIST_API_KEY not found"
            req = urllib.request.Request(API, headers={"Authorization": "Bearer " + key})
            with urllib.request.urlopen(req, timeout=8) as resp:
                payload = json.load(resp)
    except Exception as exc:  # network / auth / bad json
        return None, str(exc)[:60]

    items = payload.get("results", payload) if isinstance(payload, dict) else payload
    today = datetime.date.today().isoformat()

    picked = []
    for t in items or []:
        due = t.get("due") or {}
        raw = (due.get("date") or "")[:10]
        if not raw:  # no due date at all
            continue
        if raw > today:  # future task, skip
            continue
        picked.append((t, raw < today))  # raw < today == overdue

    picked.sort(key=lambda p: (-int(p[0].get("priority", 1)), p[0].get("id", "")))
    return picked, None


def render(name, alpha=None):
    label = name if alpha is None else '<span alpha="%d%%">%s</span>' % (alpha, name)
    return ICON + " " + label


def escape(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def main():
    load_env()
    limit = maxlen()

    while True:
        tasks, err = fetch_tasks()

        if err is not None:
            emit(ICON + " !", "Todoist: " + err, "err")
            time.sleep(REFRESH)
            continue

        if not tasks:
            emit(
                '<span alpha="70%%">%s no tasks</span>' % ICON,
                "Nothing due today and nothing overdue",
                "empty",
            )
            time.sleep(REFRESH)
            continue

        n_overdue = sum(1 for _, od in tasks if od)
        names = []
        for t, od in tasks:
            name = escape(truncate(t.get("content", ""), limit))
            due = (t.get("due") or {}).get("string") or "today"
            tip = t.get("content", "")
            if od:
                tip += "\nOVERDUE (was: %s)" % due
            else:
                tip += "\nDue: %s" % due
            if len(tasks) > 1:
                tip += "\n\n%d task(s) due/overdue" % len(tasks)
                if n_overdue:
                    tip += " (%d overdue)" % n_overdue
                tip += ", rotating"
            names.append((name, tip))

        # Single task: steady, no animation.
        if len(names) == 1:
            name, tip = names[0]
            emit(render(name), tip, "ok")
            time.sleep(HOLD + REFRESH)
            continue

        for idx, (name, tip) in enumerate(names):
            # fade in
            for step in range(1, FADE_STEPS + 1):
                emit(render(name, int(step * 100 / FADE_STEPS)), tip, "ok")
                time.sleep(FRAME)
            # hold
            emit(render(name), tip, "ok")
            time.sleep(HOLD)
            # fade out
            for step in range(FADE_STEPS - 1, -1, -1):
                emit(render(name, int(step * 100 / FADE_STEPS)), tip, "ok")
                time.sleep(FRAME)

        # loop back to the top: refetch so newly added tasks show up
        time.sleep(0.5)


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        sys.exit(0)
