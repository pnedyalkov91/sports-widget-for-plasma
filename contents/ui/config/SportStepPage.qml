/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
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

        Label {
            Layout.fillWidth: true
            text: root.subtitle
            opacity: 0.72
            wrapMode: Text.WordWrap
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
