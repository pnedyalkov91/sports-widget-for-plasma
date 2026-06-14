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

import "../code/SportsApi.js" as SportsApi
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
    property string homePenaltyScore: ""
    property string awayPenaltyScore: ""
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
    property bool showScore: true
    property bool splitLeagueAndTimeLines: false
    property bool splitDateAndTimeLines: false
    readonly property color liveColor: Kirigami.Theme.negativeTextColor

    signal clicked()
    signal doubleClicked()
    signal scoreInfoClicked()

    readonly property bool showScoreInfo: {
        if (!root.showScore || root.status === "Upcoming")
            return false;

        const s = String(root.sport || "").toLowerCase();
        if (s === "tennis")
            return true;
        if (s === "cricket" || s === "basketball")
            return root.homeScore.length > 0;
        return false;
    }

    function scoreText() {
        if (!root.showScore)
            return "-";

        if (root.homeScore.length === 0 && root.awayScore.length === 0) {
            // Tennis live/finished scores are unreliable from the API; show a
            // placeholder "0 - 0" with the info icon instead of a bare dash.
            if (String(root.sport || "").toLowerCase() === "tennis" && root.status !== "Upcoming")
                return "0 - 0";
            return "-";
        }
        let value = root.homeScore + " - " + root.awayScore;
        if (root.homePenaltyScore.length > 0 && root.awayPenaltyScore.length > 0)
            value += " (" + i18nc("@label:penalty shoot-out short", "Pens") + " " + root.homePenaltyScore + "-" + root.awayPenaltyScore + ")";
        return value;
    }

    function centerTimeText() {
        if (root.minute.length > 0 && !root.isLiveMatch())
            return root.minute;

        const timeText = root.startTime.length > 0 ? root.startTime : root.status === "Live" ? root.status : "";
        const competitionText = root.league.trim();

        if (root.matchday.length > 0 && competitionText.length > 0 && timeText.length > 0)
            return root.matchday + " · " + competitionText + " · " + timeText;

        if (root.matchday.length > 0 && timeText.length > 0)
            return root.matchday + " · " + timeText;

        if (competitionText.length > 0 && timeText.length > 0)
            return competitionText + " · " + timeText;

        if (root.matchday.length > 0 && competitionText.length > 0)
            return root.matchday + " · " + competitionText;

        if (root.matchday.length > 0)
            return root.matchday;

        return competitionText.length > 0 ? competitionText : timeText;
    }

    function leagueMetaText() {
        const competitionText = root.league.trim();
        if (root.matchday.length > 0 && competitionText.length > 0)
            return root.matchday + " · " + competitionText;
        if (root.matchday.length > 0)
            return root.matchday;
        return competitionText;
    }

    function dateTimeMetaText() {
        if (root.minute.length > 0 && !root.isLiveMatch())
            return root.minute;
        if (root.startTime.length > 0)
            return root.startTime;
        return root.status === "Live" ? root.status : "";
    }

    function dateTimeDisplayText() {
        const value = root.dateTimeMetaText();
        if (!root.splitDateAndTimeLines)
            return value;

        const match = /^(.+\S)\s+(\d{1,2}:\d{2}(?::\d{2})?)$/.exec(value);
        return match ? match[1] + "\n" + match[2] : value;
    }

    function isLiveMatch() {
        return root.status === "Live";
    }

    function liveMinuteText() {
        if (String(root.sport || "").toLowerCase() === "basketball")
            return SportsApi.liveStatusText(root.sport, root.minute);

        const value = SportsApi.normalizedLiveMinute(root.minute);
        if (value.length === 0)
            return root.minute.trim();

        const minuteMatch = /^(\d+)(?:\+(\d*))?$/.exec(value);
        if (!minuteMatch)
            return value;

        if (minuteMatch[2] === undefined)
            return minuteMatch[1] + "'";
        return minuteMatch[2].length > 0 ? minuteMatch[1] + "' + " + minuteMatch[2] + "'" : minuteMatch[1] + "' +";
    }

    function stoppageMinutePart(index) {
        const match = /^(\d+)\+(\d*)$/.exec(SportsApi.normalizedLiveMinute(root.minute));
        return match && match[index].length > 0 ? match[index] + "'" : "";
    }

    function hasStoppageTime() {
        return /^\d+\+\d*$/.test(SportsApi.normalizedLiveMinute(root.minute));
    }

    function isTennisMatch() {
        return String(root.sport || "").toLowerCase() === "tennis";
    }

    function liveStatusLabelText() {
        if (root.isTennisMatch() && root.minute.trim().length > 0)
            return root.minute.trim();
        return i18nc("@info:live match status", "Live");
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

    implicitHeight: Kirigami.Units.gridUnit * 4.2
    height: implicitHeight
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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked()
        onDoubleClicked: root.doubleClicked()
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

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(scoreLabel.implicitHeight, infoIconContainer.height)

                PlasmaComponents.Label {
                    id: scoreLabel
                    anchors.centerIn: parent
                    text: scoreText()
                    color: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                    font.pixelSize: Kirigami.Units.gridUnit
                }

                Item {
                    id: infoIconContainer
                    visible: root.showScoreInfo
                    anchors.left: scoreLabel.right
                    anchors.leftMargin: Kirigami.Units.smallSpacing / 2
                    anchors.verticalCenter: scoreLabel.verticalCenter
                    width: infoIcon.width
                    height: infoIcon.height

                    Kirigami.Icon {
                        id: infoIcon
                        width: Kirigami.Units.iconSizes.small
                        height: width
                        source: "dialog-information"
                        isMask: true
                        color: infoMouseArea.containsMouse
                            ? (root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor)
                            : (root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.disabledTextColor)

                        Behavior on color {
                            ColorAnimation { duration: Kirigami.Units.shortDuration }
                        }
                    }

                    MouseArea {
                        id: infoMouseArea
                        anchors.fill: parent
                        anchors.margins: -Kirigami.Units.smallSpacing
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: function(mouse) {
                            mouse.accepted = true;
                            root.scoreInfoClicked();
                        }

                        PlasmaComponents.ToolTip.text: i18nc("@info:tooltip", "Score may be inaccurate. Click to view match details.")
                        PlasmaComponents.ToolTip.visible: containsMouse
                        PlasmaComponents.ToolTip.delay: 600
                    }
                }
            }

            Item {
                id: liveStatusContainer

                readonly property int dotSize: Math.max(6, Math.round(Kirigami.Units.smallSpacing * 1.25))

                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Theme.smallFont.pixelSize + Kirigami.Units.smallSpacing
                visible: root.isLiveMatch()

                Row {
                    id: liveStatusRow

                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, liveStatusContainer.width)
                    height: implicitHeight
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: liveStatusContainer.dotSize
                        height: width
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
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.liveStatusLabelText()
                        color: root.liveColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.bold: true
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }

                    PlasmaComponents.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.isTennisMatch() && !root.hasStoppageTime() && root.liveMinuteText().length > 0
                        text: root.liveMinuteText()
                        color: root.liveColor
                        font.bold: true
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }

                    MinuteBadge {
                        visible: root.hasStoppageTime()
                        text: root.stoppageMinutePart(1)
                    }

                    PlasmaComponents.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.hasStoppageTime()
                        text: "+"
                        color: root.liveColor
                        font.bold: true
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }

                    MinuteBadge {
                        visible: root.hasStoppageTime() && root.stoppageMinutePart(2).length > 0
                        text: root.stoppageMinutePart(2)
                    }
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: centerTimeText()
                color: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                visible: (!root.isLiveMatch() || root.league.length > 0) && !root.splitLeagueAndTimeLines
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.leagueMetaText()
                color: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                visible: root.splitLeagueAndTimeLines && root.leagueMetaText().length > 0
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                maximumLineCount: 2
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.dateTimeDisplayText()
                color: root.selected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                visible: root.splitLeagueAndTimeLines && root.dateTimeMetaText().length > 0
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                maximumLineCount: 2
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: scoreColumn.width
                Layout.topMargin: 1
                visible: root.stadium.length > 0
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Math.round(Kirigami.Units.iconSizes.smallMedium * 0.85)
                    Layout.preferredHeight: Layout.preferredWidth
                    text: "🏟️"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Math.round(Kirigami.Units.iconSizes.smallMedium * 0.85 * 0.8)
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
            spacing: Kirigami.Units.smallSpacing

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

        readonly property bool isTennis: String(root.sport || "").toLowerCase() === "tennis"

        Layout.preferredWidth: Kirigami.Units.iconSizes.large
        Layout.preferredHeight: Layout.preferredWidth

        TeamBadgeImage {
            anchors.fill: parent
            sourceUrl: parent.sourceUrl
            fallbackIcon: "emblem-favorite"
            fillMode: parent.isTennis ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        }

    }

    component MinuteBadge: Rectangle {
        property string text: ""

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: Math.max(height, minuteLabel.implicitWidth + Kirigami.Units.smallSpacing)
        height: Kirigami.Theme.smallFont.pixelSize + Kirigami.Units.smallSpacing
        radius: 3
        color: root.withAlpha(root.liveColor, 0.16)
        border.width: 1
        border.color: root.withAlpha(root.liveColor, 0.65)

        PlasmaComponents.Label {
            id: minuteLabel

            anchors.centerIn: parent
            text: parent.text
            color: root.liveColor
            font.bold: true
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
    }

}
