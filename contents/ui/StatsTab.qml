/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var statsModel

    ListView {
        id: statsList

        anchors.fill: parent
        clip: true
        spacing: Kirigami.Units.smallSpacing
        model: root.statsModel

        EmptyState {
            anchors.fill: parent
            visible: statsList.count === 0
            text: i18nc("@info:placeholder", "No match stats available")
        }

        delegate: StatsRow {
            width: statsList.width
            label: model.label
            homeValue: model.homeValue
            awayValue: model.awayValue
            homeRatio: model.homeRatio
            awayRatio: model.awayRatio
            homeHighlight: model.homeHighlight
            awayHighlight: model.awayHighlight
        }
    }

    component EmptyState: Item {
        property string text: ""

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Layout.preferredWidth
                source: "view-calendar-day"
                color: "#9db7be"
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: parent.parent.text
                color: "#9db7be"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    component StatsRow: Item {
        id: statsRow

        property string label: ""
        property string homeValue: ""
        property string awayValue: ""
        property real homeRatio: 0
        property real awayRatio: 0
        property bool homeHighlight: false
        property bool awayHighlight: false

        height: Kirigami.Units.gridUnit * 2.6

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: 3

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit

                PlasmaComponents.Label {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: statsRow.homeValue
                    color: "#d9d9d9"
                    font.bold: statsRow.homeHighlight
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 5)
                    text: statsRow.label
                    color: "#a8a8a8"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                PlasmaComponents.Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: statsRow.awayValue
                    color: "#d9d9d9"
                    font.bold: statsRow.awayHighlight
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                spacing: Kirigami.Units.smallSpacing

                StatHalfBar {
                    Layout.fillWidth: true
                    ratio: statsRow.homeRatio
                    highlight: statsRow.homeHighlight
                    mirrored: true
                }

                StatHalfBar {
                    Layout.fillWidth: true
                    ratio: statsRow.awayRatio
                    highlight: statsRow.awayHighlight
                    mirrored: false
                }
            }
        }
    }

    component StatHalfBar: Rectangle {
        property real ratio: 0
        property bool highlight: false
        property bool mirrored: false

        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.1)

        Rectangle {
            height: parent.height
            width: Math.max(0, parent.width * Math.min(1, Math.max(0, ratio)))
            x: mirrored ? parent.width - width : 0
            radius: parent.radius
            color: highlight ? "#ff7a00" : Qt.rgba(1, 1, 1, 0.62)
        }
    }
}
