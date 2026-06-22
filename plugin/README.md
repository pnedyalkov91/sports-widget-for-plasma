# Sports Widget — Plasma calendar plugin

This is a small native **Plasma calendar-events plugin** that shows the matches you
follow in the Sports widget directly in the Plasma calendar (the date/clock pop-up),
exactly like the [GnomeFootball](https://github.com/carlosjdelgado/GnomeFootball)
extension does for GNOME.

## Why it exists

The widget used to write an iCalendar (`.ics`) file and register it as an Akonadi
resource so matches would appear in the Plasma calendar. On some systems that made
plasmashell's PIM/Akonadi stack reconcile and re-index every event on each update,
which **froze Plasma for 25–30 s (sometimes permanently)**.

This plugin avoids that completely:

- The widget writes a small, **inert JSON snapshot** of upcoming matches
  (`~/.local/share/sports-widget-for-plasma/sports-matches.json`). Nothing parses,
  reconciles or indexes it.
- This plugin reads that JSON and feeds the matches to the Plasma calendar
  **in memory**, via `CalendarEvents::CalendarEventsPlugin::dataReady()`.
- **No `.ics`, no Akonadi resource, no PIM indexer** — so it cannot hang plasmashell.

## Build & install

Requires the KF6 `CalendarEvents` development headers
(`/usr/include/KF6/KDeclarative/CalendarEvents`), Qt 6 and a C++ compiler.

```sh
cd plugin
sh install.sh
# installs to ~/.local/lib64/qt6/plugins/plasmacalendarplugins/sportsmatchesevents.so
```

### Make it discoverable (two requirements)

Plasma only loads a calendar plugin if **(a)** the `.so` is on Qt's plugin path and
**(b)** it's listed in `enabledCalendarPlugins`.

1. **Plugin path.** `install.sh` installs to the system path
   (`/usr/lib64/qt6/plugins/plasmacalendarplugins`, via sudo) by default, which Qt
   always scans. To install per-user instead (`SYSTEM_INSTALL=0 sh install.sh`), Qt
   must also scan `~/.local/lib64/qt6/plugins`, so export `QT_PLUGIN_PATH` for the
   session — e.g. drop a line in `~/.config/plasma-workspace/env/qt-plugin-path.sh`:

   ```sh
   export QT_PLUGIN_PATH="$HOME/.local/lib64/qt6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
   ```

2. **Enable it.** Right-click the clock → Configure → Calendar → tick
   **"Sports Widget matches"**. (This adds `sportsmatchesevents` to
   `enabledCalendarPlugins` in `plasma-org.kde.plasma.desktop-appletsrc`.)

Then reload plasmashell:

```sh
kquitapp6 plasmashell; kstart plasmashell
```

Finally enable the calendar option in the widget settings (Notifications → Calendar).
That page also shows whether this plugin is detected.

## Uninstall

```sh
sh uninstall.sh
kquitapp6 plasmashell; kstart plasmashell
```

It removes the `.so` and its config QML from the system and per-user Qt plugin
paths and removes `sportsmatchesevents` from `enabledCalendarPlugins`. Widget data
is left untouched.

## Akonadi (optional, unstable)

The widget also has an opt-in switch to register the exported `.ics` as a live
Akonadi/KDE PIM calendar. It is **not recommended** — on some systems Akonadi
re-indexes every event on each update and can freeze Plasma — which is exactly why
this in-memory plugin exists and is the default. The Akonadi path lives in the
widget (`CalendarSync.resourceEnsureScript` / `resourceOfflineScript`), not in this
plugin.

## Files

- `sportsmatchesevents.h` / `.cpp` — the plugin implementation.
- `SportsMatchesEventsConfig.qml` — the config page shown in Plasma calendar settings.
- `metadata.json` — plugin metadata (embedded into the `.so`).
- `install.sh` — compiles with `g++` + `moc` and installs the plugin + config QML.
- `uninstall.sh` — removes the installed plugin and disables it.
