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
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property string text: ""
    property bool collapsible: false
    property bool collapsed: false
    property bool loading: false
    // Optional trailing summary (e.g. "3 matches") and a live-match count shown
    // as a small red pill, used by the Leagues tab.
    property string badgeText: ""
    property int liveCount: 0

    signal toggled()

    function withAlpha(color, alpha) {
        try {
            if (!color || color.r === undefined || color.g === undefined || color.b === undefined)
                return Qt.rgba(0, 0, 0, 0);

            return Qt.rgba(color.r, color.g, color.b, alpha);
        } catch (error) {
            return Qt.rgba(0, 0, 0, 0);
        }
    }

    visible: text.length > 0
    height: visible ? Kirigami.Units.gridUnit * 1.8 : 0

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        visible: root.visible

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Layout.preferredWidth
            visible: root.collapsible
            source: root.collapsed ? "go-next-symbolic" : "go-down-symbolic"
            isMask: true
            color: Kirigami.Theme.disabledTextColor
        }

        PlasmaComponents.Label {
            text: root.text
            color: Kirigami.Theme.textColor
            opacity: 0.82
            font.bold: true
            elide: Text.ElideRight
        }

        PlasmaComponents.BusyIndicator {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Layout.preferredWidth
            visible: root.loading
            running: root.loading
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.withAlpha(Kirigami.Theme.separatorColor, 0.5)
        }

        Rectangle {
            Layout.preferredWidth: liveCountLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
            Layout.preferredHeight: Kirigami.Units.iconSizes.small + 2
            radius: height / 2
            visible: root.liveCount > 0
            color: Kirigami.Theme.negativeTextColor

            PlasmaComponents.Label {
                id: liveCountLabel

                anchors.centerIn: parent
                text: i18ncp("@label number of live matches", "%1 live", "%1 live", root.liveCount)
                color: Kirigami.Theme.backgroundColor
                font.bold: true
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }

        PlasmaComponents.Label {
            text: root.badgeText
            visible: root.badgeText.length > 0
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.collapsible
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
