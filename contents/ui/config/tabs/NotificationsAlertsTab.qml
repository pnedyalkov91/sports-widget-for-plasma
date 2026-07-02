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

Kirigami.FormLayout {
    id: alertsTab

    required property var configRoot

    Switch {
        id: notificationsEnabled

        Kirigami.FormData.label: i18nc("@label:chooser", "Desktop notifications:")
        text: i18nc("@option:check", "Enabled")
        checked: alertsTab.configRoot.cfg_notificationsEnabled
        onToggled: alertsTab.configRoot.cfg_notificationsEnabled = checked
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: true
        showCloseButton: true
        type: Kirigami.MessageType.Information
        text: i18nc("@info", "Show a notification for matches in the competitions and teams you follow.")
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: true
        showCloseButton: true
        type: Kirigami.MessageType.Information
        text: i18nc("@info", "Notifications are off by default for each saved competition/team to avoid spam. Enable them per entry in the \"Competitions & teams\" tab.")
    }

    CheckBox {
        id: notifyKickoff

        Kirigami.FormData.label: i18nc("@label:chooser", "Notify on:")
        text: i18nc("@option:check", "Kickoff (match goes live)")
        enabled: notificationsEnabled.checked
        checked: alertsTab.configRoot.cfg_notifyKickoff
        onToggled: alertsTab.configRoot.cfg_notifyKickoff = checked
    }

    CheckBox {
        id: notifyGoals

        text: i18nc("@option:check", "Goals and score changes")
        enabled: notificationsEnabled.checked
        checked: alertsTab.configRoot.cfg_notifyGoals
        onToggled: alertsTab.configRoot.cfg_notifyGoals = checked
    }

    CheckBox {
        id: notifyHalfTime

        text: i18nc("@option:check", "Half-time and second half")
        enabled: notificationsEnabled.checked
        checked: alertsTab.configRoot.cfg_notifyHalfTime
        onToggled: alertsTab.configRoot.cfg_notifyHalfTime = checked
    }

    CheckBox {
        id: notifyFullTime

        text: i18nc("@option:check", "Full-time result")
        enabled: notificationsEnabled.checked
        checked: alertsTab.configRoot.cfg_notifyFullTime
        onToggled: alertsTab.configRoot.cfg_notifyFullTime = checked
    }

    CheckBox {
        id: notifyDetailedEvents

        text: i18nc("@option:check", "Detailed events (scorer, cards, substitutions, extra time, penalties) - football only")
        enabled: notificationsEnabled.checked
        checked: alertsTab.configRoot.cfg_notifyDetailedEvents
        onToggled: alertsTab.configRoot.cfg_notifyDetailedEvents = checked
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
        checked: alertsTab.configRoot.cfg_notifyStartsSoon
        onToggled: alertsTab.configRoot.cfg_notifyStartsSoon = checked
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
            value: alertsTab.configRoot.cfg_notifyStartsSoonMinutes
            onValueModified: alertsTab.configRoot.cfg_notifyStartsSoonMinutes = value
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
        checked: alertsTab.configRoot.cfg_notifyFavoriteTeamsOnly
        onToggled: alertsTab.configRoot.cfg_notifyFavoriteTeamsOnly = checked
    }
}
