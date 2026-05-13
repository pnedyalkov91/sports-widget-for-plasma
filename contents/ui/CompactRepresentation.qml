/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../code/SportVisuals.js" as SportVisuals
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Control {
    id: compact

    property int liveCount: 0
    property bool loading: false
    property string layoutMode: "singleLine"
    property string primaryText: ""
    property string secondaryText: ""
    property string sport: "sports"

    Layout.minimumWidth: layoutMode === "simple" ? Kirigami.Units.iconSizes.medium : Kirigami.Units.gridUnit * 7
    Layout.minimumHeight: Kirigami.Units.iconSizes.medium
    Layout.preferredWidth: layoutMode === "simple" ? Kirigami.Units.iconSizes.large : Kirigami.Units.gridUnit * 11
    Layout.preferredHeight: layoutMode === "multiline" ? Kirigami.Units.gridUnit * 2 : Kirigami.Units.iconSizes.large
    padding: 0

    MouseArea {
        anchors.fill: parent
        onClicked: root.expanded = !root.expanded
    }

    contentItem: Item {
        RowLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            visible: compact.layoutMode !== "multiline"

            SportGlyph {
                Layout.preferredWidth: Math.min(parent.height, Kirigami.Units.iconSizes.medium)
                Layout.preferredHeight: Layout.preferredWidth
                loading: compact.loading
                sport: compact.sport
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                visible: compact.layoutMode !== "simple"

                Label {
                    Layout.fillWidth: true
                    text: compact.primaryText
                    elide: Text.ElideRight
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                Label {
                    Layout.fillWidth: true
                    text: compact.secondaryText
                    elide: Text.ElideRight
                    opacity: 0.72
                    font.pixelSize: Math.max(8, Kirigami.Theme.smallFont.pixelSize - 1)
                }

            }

            CountBadge {
                count: compact.liveCount
                visible: compact.liveCount > 0 && compact.layoutMode === "simple"
            }

        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: 0
            visible: compact.layoutMode === "multiline"

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                SportGlyph {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                    loading: compact.loading
                    sport: compact.sport
                }

                Label {
                    Layout.fillWidth: true
                    text: compact.primaryText
                    elide: Text.ElideRight
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

            }

            Label {
                Layout.fillWidth: true
                text: compact.secondaryText
                elide: Text.ElideRight
                opacity: 0.72
                font.pixelSize: Math.max(8, Kirigami.Theme.smallFont.pixelSize - 1)
            }

        }

    }

    component SportGlyph: Item {
        property bool loading: false
        property string sport: "football"

        Kirigami.Icon {
            anchors.fill: parent
            source: "view-refresh"
            visible: parent.loading
        }

        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("../icons/sports/" + SportVisuals.iconName(parent.sport))
            visible: !parent.loading
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

    }

    component CountBadge: Rectangle {
        property int count: 0

        Layout.preferredWidth: Math.max(Kirigami.Units.iconSizes.smallMedium, countLabel.implicitWidth + Kirigami.Units.smallSpacing * 2)
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        radius: height / 2
        color: Kirigami.Theme.positiveTextColor

        Label {
            id: countLabel

            anchors.centerIn: parent
            text: parent.count > 99 ? "99+" : parent.count
            color: Kirigami.Theme.backgroundColor
            font.bold: true
            font.pixelSize: Math.max(8, Kirigami.Theme.smallFont.pixelSize)
        }

    }

}
