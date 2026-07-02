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
import org.kde.plasma.components as PlasmaComponents

Kirigami.FormLayout {
    id: tooltipTab

    required property var configRoot

    Kirigami.Separator {
        Kirigami.FormData.label: i18nc("@title:group", "Tooltip")
        Kirigami.FormData.isSection: true
    }

    RowLayout {
        Kirigami.FormData.label: i18nc("@label:spinbox", "Live matches:")
        spacing: Kirigami.Units.smallSpacing

        SpinBox {
            id: liveMatchesLimit

            from: 1
            to: 30
            stepSize: 1
            editable: true
            value: Math.min(30, Math.max(1, tooltipTab.configRoot.cfg_tooltipLiveMatchesLimit || 5))
            onValueModified: tooltipTab.configRoot.cfg_tooltipLiveMatchesLimit = value
        }

        PlasmaComponents.Label {
            text: i18ncp("@label:spinbox", "match", "matches", liveMatchesLimit.value)
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18nc("@label:spinbox", "Schedules days ahead:")
        spacing: Kirigami.Units.smallSpacing

        SpinBox {
            id: scheduleDaysAhead

            from: 1
            to: 5
            stepSize: 1
            editable: true
            value: Math.min(5, Math.max(1, tooltipTab.configRoot.cfg_tooltipScheduleDaysAhead || 1))
            onValueModified: tooltipTab.configRoot.cfg_tooltipScheduleDaysAhead = value
        }

        PlasmaComponents.Label {
            text: i18ncp("@label:spinbox", "day", "days", scheduleDaysAhead.value)
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18nc("@label:spinbox", "Recent results days back:")
        spacing: Kirigami.Units.smallSpacing

        SpinBox {
            id: recentDaysBack

            from: 1
            to: 5
            stepSize: 1
            editable: true
            value: Math.min(5, Math.max(1, tooltipTab.configRoot.cfg_tooltipRecentDaysBack || 5))
            onValueModified: tooltipTab.configRoot.cfg_tooltipRecentDaysBack = value
        }

        PlasmaComponents.Label {
            text: i18ncp("@label:spinbox", "day", "days", recentDaysBack.value)
        }
    }

    Kirigami.InlineMessage {
        Kirigami.FormData.label: ""
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: true
        showCloseButton: true
        type: Kirigami.MessageType.Information
        text: i18nc("@info", "How many live matches to list, how many days ahead to look for upcoming fixtures, and how many days back to look for finished matches in the panel's hover tooltip.")
    }
}
