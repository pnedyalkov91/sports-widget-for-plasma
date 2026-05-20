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
    property string panelText: ""
    property string liveText: ""
    property bool isLive: false
    property string sport: "sports"
    readonly property color liveColor: Qt.rgba(1, 0.32, 0.32, 1)

    function displayText() {
        const text = compact.panelText.trim();
        return text.length > 0 ? text : compact.primaryText;
    }

    function displayLiveText() {
        const value = compact.liveText.trim();
        if (value.length === 0)
            return i18nc("@info:live match status", "Live");

        return value;
    }

    Layout.minimumWidth: layoutMode === "simple" ? Kirigami.Units.iconSizes.medium : Kirigami.Units.gridUnit * 7
    Layout.minimumHeight: Kirigami.Units.iconSizes.medium
    Layout.preferredWidth: layoutMode === "simple" ? Kirigami.Units.iconSizes.large : Kirigami.Units.gridUnit * 11
    Layout.preferredHeight: Kirigami.Units.iconSizes.large
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
            visible: true

            SportGlyph {
                Layout.preferredWidth: compact.layoutMode === "simple" ? Math.min(parent.height, Kirigami.Units.iconSizes.medium) : 0
                Layout.preferredHeight: Layout.preferredWidth
                loading: compact.loading
                sport: compact.sport
                visible: compact.layoutMode === "simple"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: compact.layoutMode !== "simple"

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: compact.liveColor
                    visible: compact.isLive

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: compact.isLive

                        NumberAnimation {
                            from: 1
                            to: 0.35
                            duration: 650
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            from: 0.35
                            to: 1
                            duration: 650
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignVCenter
                    text: compact.displayLiveText()
                    color: compact.liveColor
                    elide: Text.ElideRight
                    visible: compact.isLive
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                Label {
                    Layout.fillWidth: true
                    text: compact.displayText()
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
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
            visible: false

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

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: compact.liveCount > 0

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: compact.liveColor
                }

                Label {
                    Layout.fillWidth: true
                    text: compact.displayLiveText()
                    color: compact.liveColor
                    elide: Text.ElideRight
                    font.bold: true
                    font.pixelSize: Math.max(8, Kirigami.Theme.smallFont.pixelSize - 1)
                }
            }

            Label {
                Layout.fillWidth: true
                text: compact.secondaryText
                elide: Text.ElideRight
                opacity: 0.72
                visible: compact.liveCount === 0
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

        Kirigami.Icon {
            anchors.fill: parent
            source: Qt.resolvedUrl("../icons/sports/" + SportVisuals.iconName(parent.sport))
            visible: !parent.loading
            isMask: true
            color: Kirigami.Theme.textColor
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
