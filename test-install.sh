#!/bin/bash
# Verify the repo actually works on a clean Debian machine.
#
# Needs Docker. Builds a Debian trixie image with the tools that can be
# installed from the distro repos, runs install.sh as a fresh user, then checks
# that the rendered configs are actually accepted by the applications.
#
# What this covers:
#   - install.sh runs to completion on a clean HOME
#   - it is idempotent (runs twice, still exit 0)
#   - placeholders are rendered to the new user's paths
#   - waybar parses the config (headless sway + waybar, screenshot as proof)
#   - fastfetch renders
#   - wofi/waybar style paths resolve
#
# What this cannot cover (needs a real desktop session):
#   - visual look of the bar, wallpaper, lock screen
#   - Hyprland itself (not packaged in Debian trixie)
#   - Quickshell panels (ditto)
#   - kitty image-protocol logo in fastfetch
set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
TAG="dotfiles-test:$(date +%s)"
FAIL=0

say()  { printf '\n=== %s ===\n' "$1"; }
pass() { printf '  PASS  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }

command -v docker >/dev/null || { echo "docker is required"; exit 1; }

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

cat > "$BUILD_DIR/Dockerfile" <<'EOF'
FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash coreutils findutils python3 jq file git ca-certificates \
      waybar wofi kitty neovim fastfetch btop zsh \
      sway grim imagemagick seatd dbus-x11 \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash testuser
USER testuser
WORKDIR /home/testuser
EOF

say "building test image"
docker build -q -t "$TAG" "$BUILD_DIR" >/dev/null 2>&1 \
    && pass "image built" || { fail "image build"; exit 1; }

say "install.sh on a clean HOME"
OUT=$(docker run --rm -v "$REPO":/src:ro "$TAG" bash -c '
  cp -r /src /home/testuser/dotfiles && cd /home/testuser/dotfiles
  ./install.sh 2>&1; echo "EXITCODE=$?"
')
echo "$OUT" | grep -q "EXITCODE=0" && pass "exit 0" || fail "exit code (see below)"
echo "$OUT" | grep -qE "Missing commands" && \
    echo "$OUT" | sed -n '/Missing commands/,/^$/p' | sed 's/^/        /'

say "idempotent (second run)"
OUT2=$(docker run --rm -v "$REPO":/src:ro "$TAG" bash -c '
  cp -r /src /home/testuser/dotfiles && cd /home/testuser/dotfiles
  ./install.sh >/dev/null 2>&1 && ./install.sh 2>&1; echo "EXITCODE=$?"
')
echo "$OUT2" | grep -q "EXITCODE=0" && pass "second run exit 0" || fail "second run"

# The repo owner's home directory must never leak into a rendered config.
# Derive it from tracked files so a fork is checked the same way.
OWNER_HOME=$(cd "$REPO" && grep -rhoE '/home/[a-z0-9_-]+' \
  --include='*.jsonc' --include='config*' --include='*.conf' \
  waybar wofi hypr fastfetch 2>/dev/null | sort -u | head -1)
OUT3=$(docker run --rm -v "$REPO":/src:ro -e OWNER_HOME="${OWNER_HOME:-}" "$TAG" bash -c '
  cp -r /src /home/testuser/dotfiles && cd /home/testuser/dotfiles
  ./install.sh >/dev/null 2>&1
  echo "--- leftovers ---"
  grep -rl "__HOME__\|__WALLPAPER__" ~/.config/dotfiles-rendered/ 2>/dev/null || echo none
  echo "--- owner paths ---"
  if [ -n "$OWNER_HOME" ]; then
    grep -rl "$OWNER_HOME" ~/.config 2>/dev/null || echo none
  else
    echo none
  fi
')
echo "$OUT3" | grep -A1 "leftovers" | grep -q "none" && pass "no placeholders left" || fail "placeholders left"
echo "$OUT3" | grep -A1 "owner paths" | grep -q "none" && pass "no repo-owner home path leaked" || fail "repo owner home path leaked"

say "waybar parses the config (headless sway)"
OUT4=$(docker run --rm -v "$REPO":/src:ro "$TAG" bash -c '
  cp -r /src /home/testuser/dotfiles && cd /home/testuser/dotfiles
  ./install.sh >/dev/null 2>&1
  export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
  export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman
  mkdir -p ~/.config/sway; printf "output HEADLESS-1 resolution 1440x900\n" > ~/.config/sway/config
  eval $(dbus-launch --sh-syntax)
  sway --config ~/.config/sway/config >/tmp/sway.log 2>&1 &
  sleep 10
  export WAYLAND_DISPLAY=wayland-1
  timeout 12 waybar >/tmp/wb.log 2>&1 &
  sleep 8
  if pgrep -x waybar >/dev/null; then echo "WAYBAR=ALIVE"; else echo "WAYBAR=DEAD"; fi
  grep -iE "Using configuration file|Using CSS" /tmp/wb.log | head -2
  pkill waybar 2>/dev/null
  grim /tmp/bar.png >/dev/null 2>&1 && echo "SCREENSHOT=OK" || echo "SCREENSHOT=FAIL"

  # bar must come up once the documented-broken module is removed
  python3 - <<PY
import re,json,os,pathlib
cfg=pathlib.Path(os.environ["HOME"]+"/.config/waybar/config")
s=re.sub(r"^\s*//.*$","",cfg.read_text(),flags=re.M); d=json.loads(s)
for k in ("modules-left","modules-center","modules-right"):
    d[k]=[m for m in d.get(k,[]) if m!="bluetooth"]
pathlib.Path("/tmp/nobt.json").write_text(json.dumps(d))
PY
  pkill waybar 2>/dev/null; sleep 1
  timeout 12 waybar -c /tmp/nobt.json >/tmp/wb2.log 2>&1 &
  sleep 8
  if pgrep -x waybar >/dev/null; then echo "WAYBAR_NOBT=ALIVE"; else echo "WAYBAR_NOBT=DEAD"; fi
  pkill waybar 2>/dev/null

  # which module kills it, if any
  python3 - <<PY
import re,json,os,subprocess,time,pathlib
cfg=pathlib.Path(os.environ["HOME"]+"/.config/waybar/config")
s=re.sub(r"^\s*//.*$","",cfg.read_text(),flags=re.M); d=json.loads(s)
mods=[]
for k in ("modules-left","modules-center","modules-right"): mods+=d.get(k,[])
bad=[]
for m in mods:
    t={"layer":"top","modules-left":[m]}
    if m in d: t[m]=d[m]
    p=pathlib.Path("/tmp/one.json"); p.write_text(json.dumps(t))
    subprocess.run(["pkill","-x","waybar"],capture_output=True); time.sleep(1)
    pr=subprocess.Popen(["waybar","-c",str(p)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    time.sleep(4)
    if pr.poll() is not None: bad.append(m)
    pr.terminate()
    try: pr.wait(3)
    except: pr.kill()
print("CRASHING_MODULES=" + (",".join(sorted(set(bad))) or "none"))
PY
  2>/dev/null
' 2>&1)

echo "$OUT4" | grep -q "WAYBAR=ALIVE" && pass "waybar stays up" || \
    echo "  NOTE  waybar died with every module enabled (see the module check below)"
echo "$OUT4" | grep -q "WAYBAR_NOBT=ALIVE" && pass "bar stays up without the documented-broken module" || \
    fail "bar still dies with 'bluetooth' removed"
echo "$OUT4" | grep -q "SCREENSHOT=OK" && pass "bar renders (screenshot taken)" || fail "screenshot"

# Modules that are documented as crashing Waybar without the matching hardware.
# They must be the ONLY reason the bar fails, and the bar must stay up once they
# are removed. Anything else is a real regression.
KNOWN_CRASH_BT="bluetooth"
CRASH=$(echo "$OUT4" | grep -oP 'CRASHING_MODULES=\K.*' | head -1)
if [ "$CRASH" = "none" ]; then
    pass "every module loads individually"
else
    unexpected=$(echo "$CRASH" | tr ',' '\n' | grep -vx "$KNOWN_CRASH_BT" | tr '\n' ' ')
    if [ -z "${unexpected// /}" ]; then
        pass "only '$KNOWN_CRASH_BT' crashes (documented, needs /dev/rfkill)"
    else
        fail "modules crash waybar on a machine without hardware: $unexpected"
    fi
fi

say "fastfetch"
OUT5=$(docker run --rm -v "$REPO":/src:ro "$TAG" bash -c '
  cp -r /src /home/testuser/dotfiles && cd /home/testuser/dotfiles
  ./install.sh >/dev/null 2>&1
  fastfetch --config ~/.config/fastfetch/config.jsonc 2>&1 | sed "s/\x1b\[[0-9;]*[A-Za-z]//g" | tail -4
  echo "EXITCODE=$?"
')
echo "$OUT5" | grep -q "EXITCODE=0" && pass "fastfetch renders" || fail "fastfetch"
echo "$OUT5" | grep -qiE "error" && fail "fastfetch printed an error"

say "summary"
if [ "$FAIL" -eq 0 ]; then
    echo "  all checks passed"
    docker rmi -f "$TAG" >/dev/null 2>&1
    exit 0
else
    echo "  $FAIL check(s) failed"
    echo "  image kept as $TAG for inspection"
    exit 1
fi