/*
 * Copyright 2026  Petar Nedyalkov
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

Kirigami.FormLayout {
    id: calendarTab

    required property var configRoot

    readonly property string calendarIcsFileHint: "~/.local/share/sports-widget-for-plasma/sports-matches.ics"

    // Detect whether the native Plasma calendar plugin is installed, by checking
    // the Qt plugin paths plasmashell scans. "unknown" until the check returns.
    property string calendarPluginState: "unknown" // "unknown" | "installed" | "missing"

    function checkCalendarPlugin() {
        calendarTab.calendarPluginState = "unknown";
        // Look in both the system and per-user Qt6 plugin dirs.
        const cmd = "for d in /usr/lib64/qt6/plugins /usr/lib/qt6/plugins \"$HOME/.local/lib64/qt6/plugins\" \"$HOME/.local/lib/qt6/plugins\"; do"
            + " [ -f \"$d/plasmacalendarplugins/sportsmatchesevents.so\" ] && { echo INSTALLED; exit 0; }; done; echo MISSING";
        pluginCheck.connectSource(cmd);
    }

    Plasma5Support.DataSource {
        id: pluginCheck

        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const out = String((data && data["stdout"]) || "").trim();
            calendarTab.calendarPluginState = out.indexOf("INSTALLED") >= 0 ? "installed" : "missing";
            pluginCheck.disconnectSource(source);
        }
    }

    Component.onCompleted: calendarTab.checkCalendarPlugin()

    // Single mode dropdown mapped onto the three underlying booleans, avoiding
    // invalid combinations (e.g. Akonadi without the sync being enabled).
    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: true
        showCloseButton: true
        type: Kirigami.MessageType.Information
        text: i18nc("@info", "Upcoming fixtures from the competitions and teams you follow are shown directly in the Plasma calendar (the date/clock pop-up), kept in sync automatically. This runs entirely in memory and never uses Akonadi, so it cannot slow down or freeze Plasma.")
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: true
        showCloseButton: true
        type: Kirigami.MessageType.Information
        text: i18nc("@info", "Calendar sync is off by default for each saved competition/team to avoid spam. Enable it per entry in the \"Competitions & teams\" tab.")
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: calendarTab.calendarPluginState === "installed"
        showCloseButton: true
        type: Kirigami.MessageType.Positive
        text: i18nc("@info", "Calendar plugin detected. If matches still don't appear, make sure the \"Sports Widget matches\" plugin is enabled in the Plasma calendar settings.")
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: calendarTab.calendarPluginState === "missing"
        showCloseButton: true
        type: Kirigami.MessageType.Warning
        text: i18nc("@info", "The native calendar plugin is not installed, so matches won't appear in the Plasma calendar yet. Build and install it from the widget's plugin/ folder, then restart Plasma.")
        actions: [
            Kirigami.Action {
                text: i18nc("@action:button", "View README") // qmllint disable unqualified
                icon.name: "internet-web-browser"
                onTriggered: Qt.openUrlExternally("https://github.com/pnedyalkov91/sports-widget-for-plasma/blob/main/plugin/README.md")
            }
        ]
    }

    ComboBox {
        id: calendarModeCombo

        Kirigami.FormData.label: i18nc("@label:listbox", "Add matches to calendar:")
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        textRole: "label"
        valueRole: "value"
        model: [
            {
                "label": i18nc("@item:inlistbox", "Off"),
                "value": "off"
            },
            {
                "label": i18nc("@item:inlistbox", "Native plugin"),
                "value": "native"
            },
            {
                "label": i18nc("@item:inlistbox", "Native plugin + export .ics file"),
                "value": "ics"
            },
            {
                "label": i18nc("@item:inlistbox", "Akonadi (unstable, not recommended)"),
                "value": "akonadi"
            }
        ]

        readonly property string currentMode: {
            if (calendarTab.configRoot.cfg_calendarAkonadiEnabled)
                return "akonadi";
            if (!calendarTab.configRoot.cfg_calendarSyncEnabled)
                return "off";
            return calendarTab.configRoot.cfg_calendarIcsExportEnabled ? "ics" : "native";
        }

        function indexForMode(mode) {
            for (let index = 0; index < model.length; index += 1) {
                if (model[index].value === mode)
                    return index;
            }
            return 0;
        }

        currentIndex: indexForMode(currentMode)

        onActivated: {
            const mode = model[currentIndex].value;
            calendarTab.configRoot.cfg_calendarSyncEnabled = mode !== "off";
            calendarTab.configRoot.cfg_calendarIcsExportEnabled = mode === "ics" || mode === "akonadi";
            calendarTab.configRoot.cfg_calendarAkonadiEnabled = mode === "akonadi";
        }
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: calendarModeCombo.currentMode === "ics"
        showCloseButton: true
        type: Kirigami.MessageType.Information
        text: i18nc("@info", "Also writes a standard iCalendar (.ics) file you can import into or subscribe to from any calendar app (Google Calendar, Thunderbird, GNOME, mobile…). It is only a file - it is never registered with Akonadi, so it cannot affect Plasma. File:\n%1", calendarTab.calendarIcsFileHint)
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: calendarModeCombo.currentMode === "akonadi"
        showCloseButton: true
        type: Kirigami.MessageType.Warning
        text: i18nc("@info", "Unstable - not recommended. This registers the .ics as a live Akonadi (KDE PIM) calendar. On some systems Akonadi re-indexes every match on each update and can freeze Plasma for several seconds. Prefer the native calendar plugin above; only enable this if you specifically need an Akonadi calendar and accept the risk.")
    }
}
