/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../code/providers/ProviderCatalog.js" as ProviderCatalog
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
    property bool tableLoading: false
    property string league: ""
    property string leagueLabel: ""
    property string sport: "football"
    property string favoriteTeam: ""
    property bool followTeamMode: false
    property var tableOptions: []
    property string selectedTableSlug: ""
    readonly property int rowCount: tableRows ? tableRows.length : 0
    readonly property var displayRows: groupedRows()

    signal tableSelected(string slug)

    function groupedRows() {
        const rows = root.tableRows || [];
        if (!rows.some(row => String(row.group || "").trim().length > 0))
            return rows;

        let result = [];
        let currentGroup = "";
        rows.forEach(row => {
            const group = String(row.group || "").trim();
            if (group.length > 0 && group !== currentGroup) {
                currentGroup = group;
                result.push({
                    "isGroupHeader": true,
                    "group": group
                });
            }
            result.push(row);
        });
        return result;
    }

    function isFavoriteTeam(teamName) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(teamName || "").toLowerCase().indexOf(favorite) >= 0;
    }

    function leagueTitle() {
        const label = root.leagueLabel.length > 0 ? root.leagueLabel : ProviderCatalog.leagueLabel(root.league);
        return label.length > 0 ? i18nc("@label", "%1 Table", label) : i18nc("@label", "League Table");
    }

    function selectedTableLabel() {
        const selected = ProviderCatalog.sportScoreSlug(root.selectedTableSlug);
        const options = Array.isArray(root.tableOptions) ? root.tableOptions : [];
        for (let index = 0; index < options.length; index += 1) {
            const option = options[index] || {};
            if (ProviderCatalog.sportScoreSlug(option.slug) === selected)
                return String(option.label || "").trim();
        }

        return root.leagueLabel.length > 0 ? root.leagueLabel : root.leagueTitle().replace(/\s+Table$/, "");
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: tableList

                anchors.fill: parent
                clip: true
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                model: root.displayRows
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                readonly property int contentColumnWidth: Math.max(0, width - Kirigami.Units.gridUnit)

                header: TableHeader {
                    width: tableList.contentColumnWidth
                    title: root.leagueTitle()
                }

                delegate: Loader {
                    id: rowLoader

                    width: tableList.contentColumnWidth
                    height: item ? item.height : 0
                    sourceComponent: modelData.isGroupHeader ? groupHeaderComponent : tableRowComponent

                    readonly property var rowData: modelData

                    onLoaded: item.rowData = rowData
                    onRowDataChanged: {
                        if (item)
                            item.rowData = rowData;
                    }
                }
            }

            EmptyState {
                anchors.fill: parent
                visible: root.rowCount === 0
                text: root.tableLoading ? i18nc("@info:status", "Updating table") : root.tableErrorMessage.length > 0 ? root.tableErrorMessage : i18nc("@info:placeholder", "No table data")
            }
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

    Component {
        id: groupHeaderComponent

        Rectangle {
            property var rowData: ({})

            width: tableList.contentColumnWidth
            height: Kirigami.Units.gridUnit * 1.9
            color: "transparent"

            PlasmaComponents.Label {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                text: parent.rowData.group || ""
                color: "#ff9f1a"
                font.bold: true
                elide: Text.ElideRight
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Qt.rgba(1, 0.62, 0.10, 0.28)
            }
        }
    }

    Component {
        id: tableRowComponent

        TableRow {
            property var rowData: ({})

            width: tableList.contentColumnWidth
            position: rowData.position || 0
            team: rowData.team || ""
            played: rowData.played || 0
            won: rowData.won || 0
            draw: rowData.draw || 0
            lost: rowData.lost || 0
            goalsFor: rowData.goalsFor || 0
            goalsAgainst: rowData.goalsAgainst || 0
            points: rowData.points || 0
            goalDifference: rowData.goalDifference || 0
            form: rowData.form || ""
            formDetails: rowData.formDetails || []
            crest: rowData.crest || ""
            favorite: root.isFavoriteTeam(rowData.team || "")
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
        property var formDetails: []
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
                details: parent.parent.formDetails
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
        property var details: []

        function results() {
            const text = String(form || "").trim();
            if (text.length === 0)
                return [];

            if (/^[WDL]+$/i.test(text))
                return text.split("").slice(-5);

            return text.replace(/[^A-Za-z]+/g, ",").split(",").filter(item => item.length > 0).slice(-5);
        }

        function tooltipFor(index) {
            if (!details || index < 0 || index >= details.length)
                return "";

            return String(details[index] || "");
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
                    ToolTip.text: parent.parent.tooltipFor(index)
                    ToolTip.visible: badgeHover.hovered && ToolTip.text.length > 0

                    HoverHandler {
                        id: badgeHover
                    }

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
