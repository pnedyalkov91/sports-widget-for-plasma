#!/bin/sh
# Uninstalls the Sports Widget Plasma calendar plugin.
#
# Removes the plugin binary and its config QML from both the system and per-user
# Qt6 plugin paths, and removes "sportsmatchesevents" from the Plasma calendar's
# enabled-plugins list. Safe to run repeatedly; only touches our own files.
set -eu

name="sportsmatchesevents"

# Candidate plugin dirs (system + per-user, lib64 and lib variants).
dirs="
/usr/lib64/qt6/plugins/plasmacalendarplugins
/usr/lib/qt6/plugins/plasmacalendarplugins
$HOME/.local/lib64/qt6/plugins/plasmacalendarplugins
$HOME/.local/lib/qt6/plugins/plasmacalendarplugins
"

removed=0
for d in $dirs; do
    so="$d/$name.so"
    cfg="$d/$name"   # config-QML subdir
    [ -e "$so" ] || [ -d "$cfg" ] || continue

    if [ -w "$d" ]; then
        rm -f "$so"
        rm -rf "$cfg"
    else
        echo "removing from $d (needs sudo)"
        sudo rm -f "$so"
        sudo rm -rf "$cfg"
    fi
    echo "removed: $so"
    removed=1
done

[ "$removed" = "1" ] || echo "No installed plugin found."

# Drop the plugin from the calendar's enabled list so Plasma stops trying to
# load it. Done with python3 if available (safe, comma-aware), else skipped.
cfgfile="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
if [ -f "$cfgfile" ] && command -v python3 >/dev/null 2>&1; then
    python3 - "$cfgfile" "$name" <<'PY'
import sys, re
path, name = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
changed = 0
for i, l in enumerate(lines):
    m = re.match(r"^enabledCalendarPlugins=(.*)$", l)
    if not m:
        continue
    vals = [v for v in m.group(1).split(",") if v.strip() and v.strip() != name]
    new = "enabledCalendarPlugins=" + ",".join(vals)
    if new != l:
        lines[i] = new
        changed += 1
if changed:
    open(path, "w", encoding="utf-8").write("\n".join(lines))
    print(f"disabled '{name}' in {changed} calendar config line(s)")
PY
fi

echo
echo "Done. Restart Plasma to apply:  kquitapp6 plasmashell; kstart plasmashell"
echo "The widget's own data files in ~/.local/share/sports-widget-for-plasma/ are left untouched."
