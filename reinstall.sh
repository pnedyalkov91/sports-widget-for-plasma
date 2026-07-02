#!/bin/sh
# Reinstall the Sports widget applet and restart Plasma, for the dev loop.
# Use this after changing widget QML/JS. (The separate C++ calendar plugin under
# plugin/ only needs plugin/install.sh when its .cpp/.h change.)
set -eu

here="$(cd "$(dirname "$0")" && pwd)"

# --upgrade if already installed, --install otherwise - so the first run also works.
if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "org.kde.plasma.sports-widget-for-plasma"; then
    kpackagetool6 --type Plasma/Applet --upgrade "$here"
else
    kpackagetool6 --type Plasma/Applet --install "$here"
fi

# Drop the stale QML cache so the new code is actually picked up.
rm -rf "$HOME/.cache/plasmashell/qmlcache"

# Restart the shell so the running applet reloads.
systemctl --user restart plasma-plasmashell

echo "Reinstalled and Plasma restarted."
