/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var tableModel
    property var tableRows: []
    property int tableCount: 0
    property string tableErrorMessage: ""
    property string league: "PL"
    property string sport: "football"
    property string favoriteTeam: ""
    readonly property int rowCount: tableRows ? tableRows.length : 0

    function isFavoriteTeam(teamName) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(teamName || "").toLowerCase().indexOf(favorite) >= 0;
    }

    function leagueTitle() {
        const names = {
            "BL1": i18nc("@label", "Bundesliga Table"),
            "BSA": i18nc("@label", "Brasileirao Serie A Table"),
            "CL": i18nc("@label", "UEFA Champions League Table"),
            "DED": i18nc("@label", "Eredivisie Table"),
            "EC": i18nc("@label", "European Championship Table"),
            "ELC": i18nc("@label", "Championship Table"),
            "FL1": i18nc("@label", "Ligue 1 Table"),
            "PD": i18nc("@label", "La Liga Table"),
            "PL": i18nc("@label", "Premier League Table"),
            "PPL": i18nc("@label", "Primeira Liga Table"),
            "SA": i18nc("@label", "Serie A Table"),
            "WC": i18nc("@label", "World Cup Table")
        };
        return names[String(root.league || "PL").toUpperCase()] || i18nc("@label", "League Table");
    }

    ListView {
        id: tableList

        anchors.fill: parent
        clip: true
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds
        model: root.tableRows
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        readonly property int contentColumnWidth: Math.max(0, width - Kirigami.Units.gridUnit)

        header: TableHeader {
            width: tableList.contentColumnWidth
            title: root.leagueTitle()
        }

        delegate: TableRow {
            width: tableList.contentColumnWidth
            position: modelData.position || 0
            team: modelData.team || ""
            played: modelData.played || 0
            won: modelData.won || 0
            draw: modelData.draw || 0
            lost: modelData.lost || 0
            goalsFor: modelData.goalsFor || 0
            goalsAgainst: modelData.goalsAgainst || 0
            points: modelData.points || 0
            goalDifference: modelData.goalDifference || 0
            form: modelData.form || ""
            crest: modelData.crest || ""
            favorite: root.isFavoriteTeam(modelData.team || "")
        }
    }

    EmptyState {
        anchors.fill: parent
        visible: root.rowCount === 0
        text: root.tableErrorMessage.length > 0 ? root.tableErrorMessage : i18nc("@info:placeholder", "No table data")
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

    component TableHeader: Rectangle {
        property string title: ""

        height: Kirigami.Units.gridUnit * 4.2
        color: "transparent"

        Column {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                width: parent.width
                text: parent.parent.title
                color: "#ffffff"
                elide: Text.ElideRight
                font.bold: true
                font.pixelSize: Kirigami.Units.gridUnit * 1.1
            }

            RowLayout {
                width: parent.width
                height: Kirigami.Units.gridUnit * 1.8
                spacing: Kirigami.Units.smallSpacing

                HeaderLabel {
                    text: "#"
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.35
                }

                HeaderLabel {
                    text: i18nc("@label", "Team")
                    Layout.fillWidth: true
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation games played", "Pl")
                    tooltip: i18nc("@label", "Played")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.4
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation games won", "W")
                    tooltip: i18nc("@label", "Won")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation games drawn", "D")
                    tooltip: i18nc("@label", "Drawn")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation games lost", "L")
                    tooltip: i18nc("@label", "Lost")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation goals for", "F")
                    tooltip: i18nc("@label", "Goals For")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation goals against", "A")
                    tooltip: i18nc("@label", "Goals Against")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.4
                }

                HeaderLabel {
                    text: i18nc("@label", "GD")
                    tooltip: i18nc("@label", "Goal Difference")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation points", "Pts")
                    tooltip: i18nc("@label", "Points")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.8
                }

                HeaderLabel {
                    text: i18nc("@label", "Form")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 6.6
                }
            }
        }
    }

    component HeaderLabel: PlasmaComponents.Label {
        property string tooltip: ""

        color: "#9db7be"
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        ToolTip.text: tooltip
        ToolTip.visible: tooltip.length > 0 && hoverHandler.hovered

        HoverHandler {
            id: hoverHandler
        }
    }

    component TableRow: Rectangle {
        property int position: 0
        property string team: ""
        property int played: 0
        property int won: 0
        property int draw: 0
        property int lost: 0
        property int goalsFor: 0
        property int goalsAgainst: 0
        property int points: 0
        property int goalDifference: 0
        property string form: ""
        property string crest: ""
        property bool favorite: false

        height: Kirigami.Units.gridUnit * 2.7
        color: favorite ? Qt.rgba(1, 0.59, 0.31, 0.14) : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Qt.rgba(1, 1, 1, 0.09)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: position
                color: "#e7fbff"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.35
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Kirigami.Units.gridUnit
            }

            Image {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Layout.preferredWidth
                source: crest
                visible: crest.length > 0
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            PlasmaComponents.Label {
                text: team
                color: "#e7fbff"
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.bold: true
            }

            RowValue {
                text: played
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.4
            }

            RowValue {
                text: won
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }

            RowValue {
                text: draw
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
            }

            RowValue {
                text: lost
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }

            RowValue {
                text: goalsFor
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }

            RowValue {
                text: goalsAgainst
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.4
            }

            RowValue {
                text: goalDifference
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }

            RowValue {
                text: points
                color: "#ffffff"
                font.bold: true
                font.pixelSize: Kirigami.Units.gridUnit * 1.25
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.8
            }

            FormBadges {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6.6
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.3
                form: parent.parent.form
            }
        }
    }

    component RowValue: PlasmaComponents.Label {
        color: "#d7eef2"
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    component FormBadges: Item {
        property string form: ""

        function results() {
            return String(form || "").replace(/[^A-Za-z]+/g, ",").split(",").filter(item => item.length > 0).slice(-6);
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            spacing: 3
            visible: parent.results().length > 0

            Repeater {
                model: parent.parent.results()

                Rectangle {
                    width: Kirigami.Units.gridUnit * 1.1
                    height: width
                    radius: 2
                    color: {
                        const result = String(modelData).toUpperCase();
                        if (result === "W")
                            return "#0b8f08";
                        if (result === "L")
                            return "#e91e63";
                        return "#5f6368";
                    }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: String(modelData).charAt(0).toUpperCase()
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: Math.max(8, Kirigami.Theme.smallFont.pixelSize - 1)
                    }
                }
            }
        }

        PlasmaComponents.Label {
            anchors.centerIn: parent
            visible: parent.results().length === 0
            text: "-"
            color: "#9db7be"
        }
    }
}
