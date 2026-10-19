#!/usr/bin/env python3
"""Todoist tasks for waybar (custom module, return-type json, streaming).

Shows only tasks due TODAY. Behaviour:
  * 0 tasks  -> muted "no tasks" state.
  * 1 task   -> the task stays on screen, no animation.
  * N tasks  -> one line at a time, fading out -> in between tasks.

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
    """Return today's tasks, highest priority first."""
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

    due_today = []
    for t in items or []:
        due = t.get("due") or {}
        raw = due.get("date") or ""
        if raw[:10] != today:  # also covers tasks with no due date
            continue
        due_today.append(t)

    due_today.sort(key=lambda t: (-int(t.get("priority", 1)), t.get("id", "")))
    return due_today, None


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
                "Nothing due today",
                "empty",
            )
            time.sleep(REFRESH)
            continue

        names = []
        for t in tasks:
            name = escape(truncate(t.get("content", ""), limit))
            due = (t.get("due") or {}).get("string") or "today"
            tip = t.get("content", "")
            if len(tasks) > 1:
                tip += "\nDue: %s\n\n%d tasks due today (rotating)" % (due, len(tasks))
            else:
                tip += "\nDue: %s" % due
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
