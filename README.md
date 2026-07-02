# Sports Widget for KDE Plasma 6

Sports widget for KDE Plasma desktop environment. Provides live scores, results, schedules and tables for various sports.

### Why this widget?
*   **Multi-Sport:** Follow 16 sports at the same time - Football, Basketball, Cricket, Tennis, American Football, Baseball, Ice Hockey, Golf, Racing, MMA, Rugby, Australian Football, Field Hockey, Lacrosse, Volleyball and Water Polo.
*   **Multi-Competition:** Track several leagues, cups, national teams and favorite clubs together.
*   **Modern UX:** A clean, native-feeling interface with a guided setup wizard, live score panel and informative tooltip.
*   **Stay Notified:** Optional desktop notifications and Plasma calendar sync for the matches you care about.
*   **Network Friendly:** Smart refresh keeps schedules up to date every 30 minutes and live scores every 60 seconds, without hammering the data providers' APIs.

## 📑 Table of Contents
- [📦 Installation](#-installation)
  - [🛍 Install from KDE Store](#-install-from-kde-store-recommended)
  - [🛠 Manual Installation](#-manual-installation-development)
- [🖼️ Screenshots](#-screenshots)
- [✨ Detailed Features](#-detailed-features)
- [🌐 Translation](#-translation)
- [📚 External Resources](#external-resources)
- [🐛 Bug Reports & Feedback](#-bug-reports--feedback)
- [❤️ Support](#-support-the-project)
- [📜 License](#-license)
- [™️ Trademark Notice](#-trademark-notice)

---

---

# 📦 Installation


## ⚠️ Prerequisites & Dependencies
For the full functionality of this widget, please ensure you have the following Qt6 modules installed for your distribution:

### 📡 Sports Details
*Required for the interactive Details tab (Chromium-based).*

| Distribution | Package Name |
|---|---|
| **Fedora / RHEL** | `qt6-qtwebengine` |
| **openSUSE** | `qt6-webengine` |
| **Arch Linux** | `qt6-webengine` |
| **Debian / Kubuntu / KDE Neon** | `qml6-module-qtwebengine` |

> **Note:** After installing these, restart your session or run `systemctl --user restart plasma-plasmashell`.

## 🛍 Install from KDE Store (Recommended)
1. Right-click your Panel or Desktop.
2. Select **Add Widgets...** -> **Get New Widgets** -> **Download New Plasma Widgets**.
3. Search for **Sports Widget**.
4. Click **Install**.

## 🛠 Manual Installation (Development)
If you prefer to install from source:
```bash
git clone https://github.com/pnedyalkov91/sports-widget-for-plasma.git && cd sports-widget-for-plasma
kpackagetool6 --type Plasma/Applet --install .
rm -rf ~/.cache/plasmashell/qmlcache
systemctl --user restart plasma-plasmashell
```

To update an existing installation, replace `--install` with `--upgrade`.

---

# 🖼️ Screenshots

<p align="center">
  <b>Live Matches</b><br>
  <img src="screenshots/live.png" width="260" alt="Live football match with details">
  <br>
  (Follow live matches with expandable details, lineups and tracker.)
</p>

<p align="center">
  <b>Schedules &amp; Recent Results</b><br>
  <img src="screenshots/schedules.png" width="260" alt="Schedules tab">
  <img src="screenshots/recent results.png" width="260" alt="Recent Results tab">
  <br>
  (Upcoming fixtures and recent results, with detailed stats per match.)
</p>

<p align="center">
  <b>Tables</b><br>
  <img src="screenshots/tables.png" width="260" alt="League tables">
  <br>
  (League standings/group tables for your selected competitions.)
</p>

<p align="center">
  <b>Multiple Sports</b><br>
  <img src="screenshots/basketball.png" width="260" alt="Basketball live match">
  <img src="screenshots/cricket.png" width="260" alt="Cricket live match">
  <img src="screenshots/tennis.png" width="260" alt="Tennis live match">
  <br>
  (Basketball, Cricket and Tennis are supported alongside Football, plus 12 more sports via ESPN.)
</p>

<p align="center">
  <b>Tooltip and panel</b><br>
  <img src="screenshots/tooltip.png" width="260" alt="Tooltip with upcoming and live matches">
  <br>
  (Tooltip with upcoming and live matches.)
</p>

# ✨ Detailed Features

### 🏆 Sports & Competitions
- **Supported sports:** Football, Basketball, Cricket, Tennis, American Football, Baseball, Ice Hockey, Golf, Racing, MMA, Rugby, Australian Football, Field Hockey, Lacrosse, Volleyball and Water Polo.
- **Guided setup wizard:** Add a sport, then pick a country/competition or an international tournament, and optionally a favorite club, national team or player.
- **Multiple selections:** Add as many sports, competitions, national teams and favorite teams as you like - they're all combined into one view, with duplicate detection so you don't add the same thing twice.
- **International tournaments:** Follow World Cups, continental championships and other international competitions without picking a specific country.
- **Favorite team highlighting:** Matches involving your favorite teams are prioritized and visually highlighted across all tabs.

### 📺 Live Scores & Match Details
- **Live tab:** See all live matches for your selected sports/competitions at a glance, grouped by competition.
- **Match details:** Click a live match to expand inline details (score progression, current period/set, etc.).
- **Schedules tab:** Upcoming fixtures for your selected competitions and teams.
- **Recent Results tab:** Latest finished matches and final scores.
- **Tables tab:** League standings/tables for your selected competitions, with season selection where available.
- **Quick actions:** Star, bell and pin icons on each match row let you favorite a team, get notified about that match, or pin it to the panel with one click.
- **Widget layout:** Choose between a Detailed view (featured match, tabs, standings, recent results) or a Simple view (a single scrolling list of live and upcoming matches), and pick which tabs are visible.

### 🔔 Notifications
- **Desktop notifications:** Get notified on kickoff, goals/score changes, half-time, full-time, and detailed events (scorer, cards, substitutions - football only).
- **"Starting soon" reminders:** A heads-up a configurable number of minutes before kickoff.
- **Per competition/team control:** Notifications are off by default and can be turned on individually for each followed competition or team, or limited to favorite teams only.
- **Per-match notifications:** Use the bell icon on any match to get notified just for that one game.

### 📅 Calendar Integration
- **Plasma calendar sync:** Upcoming fixtures from your followed competitions and teams appear directly in the Plasma calendar (the date/clock pop-up), via a native calendar plugin.
- **.ics export:** Optionally also export a standard iCalendar file you can import into any calendar app (Google Calendar, Thunderbird, GNOME, mobile, etc.).
- **Per competition/team control:** Like notifications, calendar sync is off by default and can be enabled per followed competition or team.

### 🔄 Smart Refresh
- **Smart mode (default):** Automatically checks for upcoming matches every 30 minutes and refreshes live scores every 60 seconds while a match is in progress - keeping data fresh while minimizing network requests.
- **Manual mode:** Turn off Smart refresh to set your own "Full refresh" (minutes) and "Live refresh" (seconds) intervals, or disable separate live updates entirely.

### 🖥 Panel Integration
- **Panel modes:** Detailed (shows the live/upcoming match) or Simple (a compact live/remaining match count, similar to GNOME's Colosseum).
- **Panel layouts:** Show emblems + teams + score, emblems + score only, or teams + score only.
- **Panel sizing:** Auto-fit, fill the panel, or set a manual size for team emblems.
- **Custom fonts:** Use the system font or pick your own family, size and weight for the panel text.
- **Match rotation:** Automatically rotate through multiple live/upcoming matches in the panel (and in the widget's hero area), with a configurable interval.

### 🛈 Tooltip
- Hovering the panel icon shows a quick tooltip with your live and upcoming matches, so you don't need to open the full widget.

### 🎛 Customization
- **National teams visuals:** Display national teams using emblems/flags.
- **Date & time formats:** Multiple built-in formats (e.g. `22.05`, `22.05.2026`, `2026-05-22`, `22 May`, region defaults, or 12/24-hour clock times) or fully custom Qt date/time patterns, with a live preview.

---

## 🌐 Translation

The widget follows your system language automatically. It currently ships with English and Bulgarian translations, and more are welcome - see the [translation guide](translate/readme.md) for how to contribute a new one.

## 🐛 Bug Reports & Feedback
If you encounter any issues or have suggestions, please open a [GitHub Issue](https://github.com/pnedyalkov91/sports-widget-for-plasma/issues). Please include your distribution, Plasma version, and the sport/competition you were viewing.

## External resources

- Football, Basketball, Cricket and Tennis data is sourced from [SportScore](https://sportscore.com/).
- All other sports (American Football, Baseball, Ice Hockey, Golf, Racing, MMA, Rugby, Australian Football, Field Hockey, Lacrosse, Volleyball, Water Polo) are sourced from ESPN's public (unofficial, undocumented) endpoints, in the same way as the [Public-ESPN-API](https://github.com/pseudo-r/Public-ESPN-API) reference project.

## ❤️ Support the project

Sports Widget for Plasma is developed in my free time.

If you enjoy using it, you can support the project:

- Liberapay: https://liberapay.com/pnedyalkov
- PayPal: https://paypal.me/pnedyalkov91
- Revolut: https://revolut.me/petarnedyalkov91

---

## 📜 License

This project is licensed under the **GNU General Public License v2.0 or later**.

---

## ™️ Trademark Notice

All product names, logos, trademarks and registered trademarks referenced in this project are the property of their respective owners and are used solely for identification purposes. Reasonable care has been taken to spell, capitalize and attribute these names accurately. Use of these names does not imply any affiliation with or endorsement by their respective owners. This project is not affiliated with, endorsed by, or sponsored by SportScore, ESPN, or any of the sports leagues, federations, clubs or organizations referenced within it.
