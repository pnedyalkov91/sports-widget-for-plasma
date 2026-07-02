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

import "../../../code/MatchNotifications.js" as MatchNotifications
import "../../../code/SportVisuals.js" as SportVisuals
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Kirigami.FormLayout {
    id: competitionsTab

    required property var configRoot

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
            competitionsTab.configRoot.cfg_notifyEntryInclusions = "[]";
            return;
        }
        competitionsTab.configRoot.cfg_notifyEntryInclusions = JSON.stringify(competitionsTab.savedEntries.map(entry => MatchNotifications.entryKey(entry)));
    }

    function setAllCalendarIncluded(included) {
        if (!included) {
            competitionsTab.configRoot.cfg_calendarEntryInclusions = "[]";
            return;
        }
        competitionsTab.configRoot.cfg_calendarEntryInclusions = JSON.stringify(competitionsTab.savedEntries.map(entry => MatchNotifications.entryKey(entry)));
    }

    // Matches the user enabled the one-click bell for, stored as a map of
    // stable match key -> details (legacy entries are just `true`; their teams
    // and league are recovered from the key "league|home|away|day").
    readonly property var perMatchNotifyEntries: {
        try {
            const parsed = JSON.parse(competitionsTab.configRoot.cfg_perMatchNotify || "{}");
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
                return [];
            return Object.keys(parsed).map(key => {
                const value = parsed[key];
                const detail = value && typeof value === "object" ? value : {};
                const parts = key.split("|");
                return {
                    "key": key,
                    "sport": String(detail.sport || ""),
                    "league": String(detail.league || parts[0] || ""),
                    "homeTeam": String(detail.homeTeam || parts[1] || ""),
                    "awayTeam": String(detail.awayTeam || parts[2] || ""),
                    "when": String(detail.startTime || parts[3] || "")
                };
            });
        } catch (error) {
            return [];
        }
    }

    function removePerMatchNotify(key) {
        try {
            const parsed = JSON.parse(competitionsTab.configRoot.cfg_perMatchNotify || "{}");
            if (!parsed || typeof parsed !== "object")
                return;
            delete parsed[key];
            competitionsTab.configRoot.cfg_perMatchNotify = JSON.stringify(parsed);
        } catch (error) {
        }
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
        visible: competitionsTab.savedEntries.length === 0
        text: i18nc("@info:placeholder", "No competitions or teams added yet. Add some from the Sport page.")
        wrapMode: Text.WordWrap
        color: Kirigami.Theme.disabledTextColor
    }

    RowLayout {
        Kirigami.FormData.label: i18nc("@label", "Global notifications and calendar:")
        spacing: Kirigami.Units.largeSpacing
        visible: competitionsTab.savedEntries.length > 0

        Switch {
            text: i18nc("@option:check", "Notify")
            enabled: competitionsTab.configRoot.cfg_notificationsEnabled
            checked: competitionsTab.savedEntries.length > 0 && competitionsTab.savedEntries.every(entry => competitionsTab.isIncluded(competitionsTab.configRoot.cfg_notifyEntryInclusions, MatchNotifications.entryKey(entry)))
            onToggled: competitionsTab.setAllIncluded(checked)
        }

        Switch {
            text: i18nc("@option:check", "Calendar")
            enabled: competitionsTab.configRoot.cfg_calendarSyncEnabled
            checked: competitionsTab.savedEntries.length > 0 && competitionsTab.savedEntries.every(entry => competitionsTab.isIncluded(competitionsTab.configRoot.cfg_calendarEntryInclusions, MatchNotifications.entryKey(entry)))
            onToggled: competitionsTab.setAllCalendarIncluded(checked)
        }
    }

    Repeater {
        model: competitionsTab.savedEntries

        delegate: RowLayout {
            id: entryRow

            required property var modelData

            readonly property string entryKey: MatchNotifications.entryKey(entryRow.modelData)

            Kirigami.FormData.label: SportVisuals.emoji(String(entryRow.modelData.sport || "")) + " " + competitionsTab.entryLabel(entryRow.modelData)
            spacing: Kirigami.Units.largeSpacing

            Switch {
                text: i18nc("@option:check", "Notify")
                enabled: competitionsTab.configRoot.cfg_notificationsEnabled
                checked: competitionsTab.isIncluded(competitionsTab.configRoot.cfg_notifyEntryInclusions, entryRow.entryKey)
                onToggled: competitionsTab.configRoot.cfg_notifyEntryInclusions = competitionsTab.withInclusion(competitionsTab.configRoot.cfg_notifyEntryInclusions, entryRow.entryKey, checked)
            }

            Switch {
                text: i18nc("@option:check", "Calendar")
                enabled: competitionsTab.configRoot.cfg_calendarSyncEnabled
                checked: competitionsTab.isIncluded(competitionsTab.configRoot.cfg_calendarEntryInclusions, entryRow.entryKey)
                onToggled: competitionsTab.configRoot.cfg_calendarEntryInclusions = competitionsTab.withInclusion(competitionsTab.configRoot.cfg_calendarEntryInclusions, entryRow.entryKey, checked)
            }
        }
    }

    Item {
        Kirigami.FormData.isSection: true
    }

    Item {
        Kirigami.FormData.label: i18nc("@title:group", "Individual match notifications")
        Kirigami.FormData.isSection: true
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: true
        showCloseButton: true
        type: Kirigami.MessageType.Information
        text: i18nc("@info", "Matches you enabled the bell icon for in the widget. They are notified even if their competition is not included above, and are cleaned up automatically once the match has finished.")
    }

    Label {
        Layout.fillWidth: true
        visible: competitionsTab.perMatchNotifyEntries.length === 0
        text: i18nc("@info:placeholder", "No individual matches yet. Click the bell icon on a match row in the widget to add one.")
        wrapMode: Text.WordWrap
        color: Kirigami.Theme.disabledTextColor
    }

    Repeater {
        model: competitionsTab.perMatchNotifyEntries

        delegate: RowLayout {
            id: matchNotifyRow

            required property var modelData

            Kirigami.FormData.label: SportVisuals.emoji(String(matchNotifyRow.modelData.sport || "")) + " "
                + i18nc("@label %1 and %2 are team names", "%1 vs %2", matchNotifyRow.modelData.homeTeam, matchNotifyRow.modelData.awayTeam)
            spacing: Kirigami.Units.smallSpacing

            Label {
                Layout.fillWidth: true
                text: [matchNotifyRow.modelData.league, matchNotifyRow.modelData.when].filter(part => String(part || "").length > 0).join(" · ")
                elide: Text.ElideRight
                color: Kirigami.Theme.disabledTextColor
            }

            ToolButton {
                icon.name: "edit-delete-remove"
                display: AbstractButton.IconOnly
                text: i18nc("@action:button", "Stop notifying about this match")
                ToolTip.visible: hovered
                ToolTip.text: text
                onClicked: competitionsTab.removePerMatchNotify(matchNotifyRow.modelData.key)
            }
        }
    }
}
