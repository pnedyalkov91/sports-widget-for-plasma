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

ColumnLayout {
    id: root

    property string title: ""
    property string subtitle: ""
    property string filterText: ""
    property string filterPlaceholder: ""
    readonly property int cardMinimumWidth: Kirigami.Units.gridUnit * 10
    readonly property int contentColumns: cardGrid.columns
    property alias headerContent: headerExtra.data
    default property alias cards: cardGrid.data

    signal filterEdited(string text)

    spacing: Kirigami.Units.largeSpacing

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            text: root.title
            level: 2
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.subtitle.length > 0
            showCloseButton: true
            type: Kirigami.MessageType.Information
            text: root.subtitle
        }
    }

    TextField {
        Layout.fillWidth: true
        visible: root.filterPlaceholder.length > 0
        placeholderText: root.filterPlaceholder
        text: root.filterText
        leftPadding: Kirigami.Units.gridUnit * 1.8
        onTextEdited: root.filterEdited(text)

        Kirigami.Icon {
            anchors.left: parent.left
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.verticalCenter: parent.verticalCenter
            width: Kirigami.Units.iconSizes.small
            height: width
            source: "search"
            color: Kirigami.Theme.disabledTextColor
        }
    }

    ColumnLayout {
        id: headerExtra

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        visible: children.length > 0
    }

    ScrollView {
        id: cardScroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        GridLayout {
            id: cardGrid

            width: cardScroll.availableWidth
            columns: Math.max(1, Math.floor((width + columnSpacing) / (root.cardMinimumWidth + columnSpacing)))
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing
        }
    }
}
