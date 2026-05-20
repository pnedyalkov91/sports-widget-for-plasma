/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: root

    property string sport: ""
    property string league: ""
    property string homeTeam: ""
    property string awayTeam: ""
    property string homeScore: ""
    property string awayScore: ""
    property string status: ""
    property string minute: ""
    property string startTime: ""
    property string matchday: ""
    property string stadium: ""
    property string homeBadge: ""
    property string awayBadge: ""
    property string poster: ""
    property bool popular: false
    property bool favorite: false
    property bool selected: false
    readonly property color liveColor: Qt.rgba(1, 0.32, 0.32, 1)

    signal clicked()

    function scoreText() {
        if (root.homeScore.length === 0 && root.awayScore.length === 0)
            return "-";

        return root.homeScore + " - " + root.awayScore;
    }

    function centerTimeText() {
        if (root.minute.length > 0)
            return root.minute;

        const timeText = root.startTime.length > 0 ? root.startTime : root.status === "Live" ? root.status : "";

        if (root.matchday.length > 0 && timeText.length > 0)
            return root.matchday + " · " + timeText;

        return root.matchday.length > 0 ? root.matchday : timeText;
    }

    function isLiveMatch() {
        return root.status === "Live";
    }

    function liveMinuteText() {
        const value = root.minute.trim();
        if (value.length === 0)
            return "";

        return /^\d+\+?$/.test(value) ? value + "'" : value;
    }

    function withAlpha(color, alpha) {
        try {
            if (!color || color.r === undefined || color.g === undefined || color.b === undefined)
                return Qt.rgba(0, 0, 0, 0);

            return Qt.rgba(color.r, color.g, color.b, alpha);
        } catch (error) {
            return Qt.rgba(0, 0, 0, 0);
        }
    }

    height: Kirigami.Units.gridUnit * 4.2
    color: selected ? withAlpha(Kirigami.Theme.highlightColor, 0.5) : favorite || hoverHandler.hovered ? withAlpha(Kirigami.Theme.alternateBackgroundColor, 0.5) : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Kirigami.Units.shortDuration
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        visible: root.selected
        color: withAlpha(Kirigami.Theme.highlightedTextColor, 0.5)
    }

    TapHandler {
        onTapped: root.clicked()
    }

    HoverHandler {
        id: hoverHandler
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: withAlpha(Kirigami.Theme.separatorColor, 0.5)
    }

    Item {
        id: rowContent

        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing

        ColumnLayout {
            id: scoreColumn

            width: Kirigami.Units.gridUnit * 7.8
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: scoreText()
                color: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                font.bold: true
                font.pixelSize: Kirigami.Units.gridUnit
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: scoreColumn.width
                spacing: Kirigami.Units.smallSpacing
                visible: root.isLiveMatch()

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Math.max(6, Math.round(Kirigami.Units.smallSpacing * 1.25))
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: root.liveColor

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.isLiveMatch()

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

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.liveMinuteText().length > 0 ? i18nc("@info:live match status", "Live %1", root.liveMinuteText()) : i18nc("@info:live match status", "Live")
                    color: root.liveColor
                    elide: Text.ElideRight
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: centerTimeText()
                color: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: !root.isLiveMatch()
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: scoreColumn.width
                Layout.topMargin: 1
                visible: root.stadium.length > 0
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Math.round(Kirigami.Units.iconSizes.smallMedium * 0.85)
                    Layout.preferredHeight: Layout.preferredWidth
                    source: Qt.resolvedUrl("../icons/sports/stadium.svg")
                    isMask: true
                    color: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.disabledTextColor
                }

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.maximumWidth: scoreColumn.width - Math.round(Kirigami.Units.iconSizes.smallMedium * 0.85) - Kirigami.Units.smallSpacing
                    text: root.stadium
                    color: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.disabledTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }
            }

        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: scoreColumn.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            TeamLogo {
                sourceUrl: root.homeBadge
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.homeTeam
                    color: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    elide: Text.ElideRight
                    font.bold: true
                }

            }
        }

        RowLayout {
            anchors.left: scoreColumn.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Kirigami.Units.smallSpacing
            spacing: 0

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.awayTeam
                    color: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    font.bold: true
                }

            }

            TeamLogo {
                sourceUrl: root.awayBadge
            }

        }

    }

    component TeamLogo: Item {
        property string sourceUrl: ""
        readonly property int backingSize: Math.ceil(Math.max(width, height, Kirigami.Units.iconSizes.huge) * Math.max(1, Screen.devicePixelRatio) * 2)

        Layout.preferredWidth: Kirigami.Units.iconSizes.large
        Layout.preferredHeight: Layout.preferredWidth

        Image {
            anchors.fill: parent
            source: sourceUrl
            visible: sourceUrl.length > 0
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            smooth: true
            sourceSize.width: parent.backingSize
            sourceSize.height: parent.backingSize
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: "emblem-favorite"
            visible: sourceUrl.length === 0
            color: Kirigami.Theme.disabledTextColor
            opacity: 0.5
        }

    }

}
