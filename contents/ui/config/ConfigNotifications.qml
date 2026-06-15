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

KCM.SimpleKCM {
    id: root

    property alias cfg_notificationsEnabled: notificationsEnabled.checked
    property alias cfg_notifyKickoff: notifyKickoff.checked
    property alias cfg_notifyGoals: notifyGoals.checked
    property alias cfg_notifyFullTime: notifyFullTime.checked
    property alias cfg_notifyStartsSoon: notifyStartsSoon.checked
    property alias cfg_notifyStartsSoonMinutes: notifyStartsSoonMinutes.value
    property alias cfg_notifyFavoriteTeamsOnly: notifyFavoriteTeamsOnly.checked
    property alias cfg_calendarSyncEnabled: calendarSyncEnabled.checked
    property alias cfg_calendarReminderMinutes: calendarReminderMinutes.value
    property bool cfg_calendarResourceReady: Plasmoid.configuration.calendarResourceReady
    property string cfg_notifyEntryExclusions: Plasmoid.configuration.notifyEntryExclusions
    property string cfg_calendarEntryExclusions: Plasmoid.configuration.calendarEntryExclusions

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

    function isExcluded(exclusionsJson, key) {
        try {
            return JSON.parse(exclusionsJson || "[]").indexOf(key) >= 0;
        } catch (error) {
            return false;
        }
    }

    function withExclusion(exclusionsJson, key, excluded) {
        let list = [];
        try {
            const parsed = JSON.parse(exclusionsJson || "[]");
            list = Array.isArray(parsed) ? parsed.map(String) : [];
        } catch (error) {
            list = [];
        }
        list = list.filter(existing => existing !== key);
        if (excluded)
            list.push(key);
        return JSON.stringify(list);
    }

    property bool cfg_notificationsEnabledDefault: false
    property bool cfg_notifyKickoffDefault: true
    property bool cfg_notifyGoalsDefault: true
    property bool cfg_notifyFullTimeDefault: true
    property bool cfg_notifyStartsSoonDefault: true
    property int cfg_notifyStartsSoonMinutesDefault: 15
    property bool cfg_notifyFavoriteTeamsOnlyDefault: false
    property bool cfg_calendarSyncEnabledDefault: false
    property int cfg_calendarReminderMinutesDefault: 15
    property bool cfg_calendarResourceReadyDefault: false

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

        Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18nc("@info", "Show a notification for matches in the competitions and teams you follow.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
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
            id: notifyFullTime

            text: i18nc("@option:check", "Full-time result")
            enabled: notificationsEnabled.checked
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

        Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18nc("@info", "Upcoming fixtures from the competitions and teams you follow are added to a dedicated \"Sports\" calendar in KDE, kept in sync automatically. Remove it any time from your calendar settings.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
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
            Kirigami.FormData.label: i18nc("@title:group", "Per competition / team")
            Kirigami.FormData.isSection: true
        }

        Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18nc("@info", "Choose which of your followed competitions and teams trigger notifications and appear in the calendar.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        Label {
            Layout.fillWidth: true
            visible: root.savedEntries.length === 0
            text: i18nc("@info:placeholder", "No competitions or teams added yet. Add some from the Sport page.")
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
        }

        Repeater {
            model: root.savedEntries

            delegate: RowLayout {
                id: entryRow

                required property var modelData

                readonly property string entryKey: MatchNotifications.entryKey(entryRow.modelData)

                Kirigami.FormData.label: SportVisuals.emoji(String(entryRow.modelData.sport || "")) + " " + root.entryLabel(entryRow.modelData)
                spacing: Kirigami.Units.largeSpacing

                CheckBox {
                    text: i18nc("@option:check", "Notify")
                    enabled: notificationsEnabled.checked
                    checked: !root.isExcluded(root.cfg_notifyEntryExclusions, entryRow.entryKey)
                    onToggled: root.cfg_notifyEntryExclusions = root.withExclusion(root.cfg_notifyEntryExclusions, entryRow.entryKey, !checked)
                }

                CheckBox {
                    text: i18nc("@option:check", "Calendar")
                    enabled: calendarSyncEnabled.checked
                    checked: !root.isExcluded(root.cfg_calendarEntryExclusions, entryRow.entryKey)
                    onToggled: root.cfg_calendarEntryExclusions = root.withExclusion(root.cfg_calendarEntryExclusions, entryRow.entryKey, !checked)
                }
            }
        }
    }
}
