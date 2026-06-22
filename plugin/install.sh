#!/bin/sh
# Builds and installs the Plasma calendar-events plugin that shows the Sports
# widget's followed matches directly in the Plasma calendar (date-menu dropdown).
# (Run plugin/uninstall.sh to remove it again.)
#
# The plugin reads an inert JSON snapshot written by the widget and feeds events
# to Plasma's calendar in memory. It never touches Akonadi, an .ics resource or
# the PIM indexer, so it cannot hang plasmashell.
#
# No KF6CalendarEvents CMake config ships on this distro, so we compile directly
# with g++ + moc against libKF6CalendarEvents and install into the user's Qt6
# plugin path that plasmashell scans.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
build="$here/build"
mkdir -p "$build"

MOC="${MOC:-/usr/lib64/qt6/libexec/moc}"
[ -x "$MOC" ] || MOC="$(command -v moc-qt6 || command -v moc)"

CXX="${CXX:-g++}"

# Qt6 Core + Gui (EventData uses QDateTime/QString; Gui pulls QColor-free here but
# the export header needs QtGui's moc predefs on some setups). Core is sufficient.
QT_CFLAGS="$(pkg-config --cflags Qt6Core)"
QT_LIBS="$(pkg-config --libs Qt6Core)"

# CalendarEvents lives in KF6 headers; link the shipped .so directly.
KF_CFLAGS="-I/usr/include/KF6/KDeclarative"
KF_LIBS="-lKF6CalendarEvents"

echo "moc: $MOC"
# moc needs the KF6 include path to resolve the CalendarEventsPlugin interface
# declared via Q_DECLARE_INTERFACE in the KF6 header.
"$MOC" $KF_CFLAGS -I/usr/include/qt6 "$here/sportsmatchesevents.h" -o "$build/moc_sportsmatchesevents.cpp"

# Silence a harmless GCC 16 warning emitted from inside the Qt 6 headers (QChar
# SFINAE), not from our code. Only pass the flag if this compiler understands it,
# so older GCC/Clang don't complain about an unknown option.
EXTRA_WARN=""
if echo 'int main(){}' | $CXX -Wno-sfinae-incomplete -x c++ - -o /dev/null >/dev/null 2>&1; then
    EXTRA_WARN="-Wno-sfinae-incomplete"
fi

echo "compiling plugin..."
# -fPIC shared plugin; -DQT_NO_KEYWORDS off (we use Q_SLOTS/Q_EMIT which are fine).
$CXX -shared -fPIC -std=c++20 $EXTRA_WARN \
    $QT_CFLAGS $KF_CFLAGS \
    -I"$here" -I"$build" \
    "$here/sportsmatchesevents.cpp" \
    -o "$build/sportsmatchesevents.so" \
    $QT_LIBS $KF_LIBS

# Install location. Plasma discovers calendar plugins from Qt's plugin paths.
# By default Qt only scans the SYSTEM path (e.g. /usr/lib64/qt6/plugins), so the
# system dir is the reliable target. Pass a first arg to override, or set
# SYSTEM_INSTALL=0 to force the per-user path (only works if QT_PLUGIN_PATH
# includes ~/.local/lib64/qt6/plugins).
sysdest="/usr/lib64/qt6/plugins/plasmacalendarplugins"
userdest="$HOME/.local/lib64/qt6/plugins/plasmacalendarplugins"

if [ "${1:-}" != "" ]; then
    dest="$1"
elif [ "${SYSTEM_INSTALL:-1}" = "1" ]; then
    dest="$sysdest"
else
    dest="$userdest"
fi

# The .so plus its config QML (in a subdir matching the .so name, per the
# X-KDE-PlasmaCalendar-ConfigUi metadata) so the calendar config page can render
# a settings page for the plugin instead of crashing on a missing one.
if [ -w "$(dirname "$dest")" ] || [ -w "$dest" ] 2>/dev/null; then
    mkdir -p "$dest/sportsmatchesevents"
    cp -f "$build/sportsmatchesevents.so" "$dest/sportsmatchesevents.so"
    cp -f "$here/SportsMatchesEventsConfig.qml" "$dest/sportsmatchesevents/SportsMatchesEventsConfig.qml"
else
    echo "installing to $dest (needs sudo)"
    sudo mkdir -p "$dest/sportsmatchesevents"
    sudo cp -f "$build/sportsmatchesevents.so" "$dest/sportsmatchesevents.so"
    sudo cp -f "$here/SportsMatchesEventsConfig.qml" "$dest/sportsmatchesevents/SportsMatchesEventsConfig.qml"
fi

echo "installed: $dest/sportsmatchesevents.so (+ config QML)"
echo
echo "Installation completed."
echo "Restart plasmashell with the following command: systemctl --user restart plasma-plasmashell"
echo "Enable the plugin in Plasma's calendar (right-click clock -> Configure ->"
echo "Calendar -> 'Sports Widget matches')"
