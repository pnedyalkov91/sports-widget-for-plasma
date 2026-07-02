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

import "../../code/MatchNotifications.js" as MatchNotifications
import "../../code/SportVisuals.js" as SportVisuals
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

KCM.SimpleKCM {
    id: root

    property alias cfg_notificationsEnabled: notificationsEnabled.checked
    property alias cfg_notifyKickoff: notifyKickoff.checked
    property alias cfg_notifyGoals: notifyGoals.checked
    property alias cfg_notifyHalfTime: notifyHalfTime.checked
    property alias cfg_notifyFullTime: notifyFullTime.checked
    property alias cfg_notifyDetailedEvents: notifyDetailedEvents.checked
    property alias cfg_notifyStartsSoon: notifyStartsSoon.checked
    property alias cfg_notifyStartsSoonMinutes: notifyStartsSoonMinutes.value
    property alias cfg_notifyFavoriteTeamsOnly: notifyFavoriteTeamsOnly.checked
    property alias cfg_calendarSyncEnabled: calendarSyncEnabled.checked
    property alias cfg_calendarIcsExportEnabled: calendarIcsExportEnabled.checked
    property alias cfg_calendarAkonadiEnabled: calendarAkonadiEnabled.checked
    property alias cfg_calendarReminderMinutes: calendarReminderMinutes.value

    readonly property string calendarIcsFileHint: "~/.local/share/sports-widget-for-plasma/sports-matches.ics"
    property string cfg_notifyEntryInclusions: Plasmoid.configuration.notifyEntryInclusions
    property string cfg_calendarEntryInclusions: Plasmoid.configuration.calendarEntryInclusions

    // Detect whether the native Plasma calendar plugin is installed, by checking
    // the Qt plugin paths plasmashell scans. "unknown" until the check returns.
    property string calendarPluginState: "unknown" // "unknown" | "installed" | "missing"

    function checkCalendarPlugin() {
        root.calendarPluginState = "unknown";
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
            root.calendarPluginState = out.indexOf("INSTALLED") >= 0 ? "installed" : "missing";
            pluginCheck.disconnectSource(source);
        }
    }

    Component.onCompleted: root.checkCalendarPlugin()

    readonly property var savedEntries: {
        try {
            const parsed = JSON.parse(Plasmoid.configuration.savedLeagues || "[]");
            return Array.isArray(parsed) ? parsed : [];
        } catch (error) {
            return [];
        }
    }

    function entryLabel(entry) {
        entry = entry || {};
        const team = String(entry.favoriteTeam || "").trim();
        if (team.length > 0)
            return team;

        const league = String(entry.customLeagueLabel || entry.leagueLabel || entry.league || entry.country || "").trim();
        return league.length > 0 ? league : i18nc("@item", "Competition");
    }

    // Per-entry Notify/Calendar are off by default, so a saved entry counts as
    // "included" only once its key is explicitly listed here.
    function isIncluded(inclusionsJson, key) {
        try {
            return JSON.parse(inclusionsJson || "[]").indexOf(key) >= 0;
        } catch (error) {
            return false;
        }
    }

    function withInclusion(inclusionsJson, key, included) {
        let list = [];
        try {
            const parsed = JSON.parse(inclusionsJson || "[]");
            list = Array.isArray(parsed) ? parsed.map(String) : [];
        } catch (error) {
            list = [];
        }
        list = list.filter(existing => existing !== key);
        if (included)
            list.push(key);
        return JSON.stringify(list);
    }

    function setAllIncluded(included) {
        if (!included) {
            root.cfg_notifyEntryInclusions = "[]";
            return;
        }
        root.cfg_notifyEntryInclusions = JSON.stringify(root.savedEntries.map(entry => MatchNotifications.entryKey(entry)));
    }

    function setAllCalendarIncluded(included) {
        if (!included) {
            root.cfg_calendarEntryInclusions = "[]";
            return;
        }
        root.cfg_calendarEntryInclusions = JSON.stringify(root.savedEntries.map(entry => MatchNotifications.entryKey(entry)));
    }

    property bool cfg_notificationsEnabledDefault: false
    property bool cfg_notifyKickoffDefault: true
    property bool cfg_notifyGoalsDefault: true
    property bool cfg_notifyHalfTimeDefault: true
    property bool cfg_notifyFullTimeDefault: true
    property bool cfg_notifyDetailedEventsDefault: false
    property bool cfg_notifyStartsSoonDefault: true
    property int cfg_notifyStartsSoonMinutesDefault: 15
    property bool cfg_notifyFavoriteTeamsOnlyDefault: false
    property bool cfg_calendarSyncEnabledDefault: false
    property bool cfg_calendarIcsExportEnabledDefault: false
    property bool cfg_calendarAkonadiEnabledDefault: false
    property int cfg_calendarReminderMinutesDefault: 15
    property string cfg_notifyEntryInclusionsDefault: "[]"
    property string cfg_calendarEntryInclusionsDefault: "[]"

    Kirigami.FormLayout {
        anchors.fill: parent

        Item {
            Kirigami.FormData.label: i18nc("@title:group", "Notifications")
            Kirigami.FormData.isSection: true
        }

        Switch {
            id: notificationsEnabled

            Kirigami.FormData.label: i18nc("@label:chooser", "Desktop notifications:")
            text: i18nc("@option:check", "Enabled")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 25
            visible: true
            showCloseButton: true
            type: Kirigami.MessageType.Information
            text: i18nc("@info", "Show a notification for matches in the competitions and teams you follow.")
        }

        CheckBox {
            id: notifyKickoff

            Kirigami.FormData.label: i18nc("@label:chooser", "Notify on:")
            text: i18nc("@option:check", "Kickoff (match goes live)")
            enabled: notificationsEnabled.checked
        }

        CheckBox {
            id: notifyGoals

            text: i18nc("@option:check", "Goals and score changes")
            enabled: notificationsEnabled.checked
        }

        CheckBox {
            id: notifyHalfTime

            text: i18nc("@option:check", "Half-time and second half")
            enabled: notificationsEnabled.checked
        }

        CheckBox {
            id: notifyFullTime

            text: i18nc("@option:check", "Full-time result")
            enabled: notificationsEnabled.checked
        }

        CheckBox {
            id: notifyDetailedEvents

            text: i18nc("@option:check", "Detailed events (scorer, cards, substitutions, extra time, penalties) - football only")
            enabled: notificationsEnabled.checked
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 25
            visible: notifyDetailedEvents.checked
            showCloseButton: true
            type: Kirigami.MessageType.Information
            text: i18nc("@info", "Polls each live football match for its scorer/cards/substitutions/extra time/penalty shootout on a separate, slower timer (every 90s). This means extra network requests per live match you follow, on top of the regular score refresh - leave this off if you'd rather minimize requests.")
        }

        CheckBox {
            id: notifyStartsSoon

            text: i18nc("@option:check", "Match starts soon")
            enabled: notificationsEnabled.checked
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label:spinbox", "Remind before kickoff:")
            spacing: Kirigami.Units.smallSpacing

            SpinBox {
                id: notifyStartsSoonMinutes

                from: 1
                to: 180
                stepSize: 5
                editable: true
                enabled: notificationsEnabled.checked && notifyStartsSoon.checked
            }

            Label {
                text: i18ncp("@label:spinbox", "minute", "minutes", notifyStartsSoonMinutes.value)
            }
        }

        Switch {
            id: notifyFavoriteTeamsOnly

            Kirigami.FormData.label: i18nc("@label:chooser", "Limit to:")
            text: i18nc("@option:check", "Favorite teams only")
            enabled: notificationsEnabled.checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        Item {
            Kirigami.FormData.label: i18nc("@title:group", "Calendar")
            Kirigami.FormData.isSection: true
        }

        Switch {
            id: calendarSyncEnabled

            Kirigami.FormData.label: i18nc("@label:chooser", "Add matches to calendar:")
            text: i18nc("@option:check", "Enabled")
        }

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
            visible: root.calendarPluginState === "installed"
            showCloseButton: true
            type: Kirigami.MessageType.Positive
            text: i18nc("@info", "Calendar plugin detected. If matches still don't appear, make sure the \"Sports Widget matches\" plugin is enabled in the Plasma calendar settings.")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 25
            visible: root.calendarPluginState === "missing"
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

        Switch {
            id: calendarIcsExportEnabled

            Kirigami.FormData.label: i18nc("@label:chooser", "Export iCal file:")
            text: i18nc("@option:check", "Also save an .ics file")
            enabled: calendarSyncEnabled.checked
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 25
            visible: calendarIcsExportEnabled.checked
            showCloseButton: true
            type: Kirigami.MessageType.Information
            text: i18nc("@info", "Also writes a standard iCalendar (.ics) file you can import into or subscribe to from any calendar app (Google Calendar, Thunderbird, GNOME, mobile…). It is only a file - it is never registered with Akonadi, so it cannot affect Plasma. File:\n%1", root.calendarIcsFileHint)
        }

        Switch {
            id: calendarAkonadiEnabled

            Kirigami.FormData.label: i18nc("@label:chooser", "KDE (Akonadi) calendar:")
            text: i18nc("@option:check", "Register as a live KDE calendar")
            enabled: calendarSyncEnabled.checked
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 25
            visible: calendarAkonadiEnabled.checked
            showCloseButton: true
            type: Kirigami.MessageType.Warning
            text: i18nc("@info", "Unstable - not recommended. This registers the .ics as a live Akonadi (KDE PIM) calendar. On some systems Akonadi re-indexes every match on each update and can freeze Plasma for several seconds. Prefer the native calendar plugin above; only enable this if you specifically need an Akonadi calendar and accept the risk.")
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label:spinbox", "Event reminder:")
            spacing: Kirigami.Units.smallSpacing

            SpinBox {
                id: calendarReminderMinutes

                from: 0
                to: 1440
                stepSize: 15
                editable: true
                enabled: calendarSyncEnabled.checked
            }

            Label {
                text: calendarReminderMinutes.value === 0
                    ? i18nc("@label", "no reminder")
                    : i18ncp("@label:spinbox", "minute before", "minutes before", calendarReminderMinutes.value)
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        Item {
            Kirigami.FormData.label: i18nc("@title:group", "Competition / team notifications")
            Kirigami.FormData.isSection: true
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 25
            visible: true
            showCloseButton: true
            type: Kirigami.MessageType.Information
            text: i18nc("@info", "Choose which of your followed competitions and teams trigger notifications and appear in the calendar. Off by default for new entries.")
        }

        Label {
            Layout.fillWidth: true
            visible: root.savedEntries.length === 0
            text: i18nc("@info:placeholder", "No competitions or teams added yet. Add some from the Sport page.")
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label", "Global notifications and calendar:")
            spacing: Kirigami.Units.largeSpacing
            visible: root.savedEntries.length > 0

            Switch {
                text: i18nc("@option:check", "Notify")
                enabled: notificationsEnabled.checked
                checked: root.savedEntries.length > 0 && root.savedEntries.every(entry => root.isIncluded(root.cfg_notifyEntryInclusions, MatchNotifications.entryKey(entry)))
                onToggled: root.setAllIncluded(checked)
            }

            Switch {
                text: i18nc("@option:check", "Calendar")
                enabled: calendarSyncEnabled.checked
                checked: root.savedEntries.length > 0 && root.savedEntries.every(entry => root.isIncluded(root.cfg_calendarEntryInclusions, MatchNotifications.entryKey(entry)))
                onToggled: root.setAllCalendarIncluded(checked)
            }
        }

        Repeater {
            model: root.savedEntries

            delegate: RowLayout {
                id: entryRow

                required property var modelData

                readonly property string entryKey: MatchNotifications.entryKey(entryRow.modelData)

                Kirigami.FormData.label: SportVisuals.emoji(String(entryRow.modelData.sport || "")) + " " + root.entryLabel(entryRow.modelData)
                spacing: Kirigami.Units.largeSpacing

                Switch {
                    text: i18nc("@option:check", "Notify")
                    enabled: notificationsEnabled.checked
                    checked: root.isIncluded(root.cfg_notifyEntryInclusions, entryRow.entryKey)
                    onToggled: root.cfg_notifyEntryInclusions = root.withInclusion(root.cfg_notifyEntryInclusions, entryRow.entryKey, checked)
                }

                Switch {
                    text: i18nc("@option:check", "Calendar")
                    enabled: calendarSyncEnabled.checked
                    checked: root.isIncluded(root.cfg_calendarEntryInclusions, entryRow.entryKey)
                    onToggled: root.cfg_calendarEntryInclusions = root.withInclusion(root.cfg_calendarEntryInclusions, entryRow.entryKey, checked)
                }
            }
        }
    }
}
