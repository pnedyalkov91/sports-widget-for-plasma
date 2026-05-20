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

    property var details: ({})
    property bool loading: false
    property string errorText: ""
    property string homeTeam: ""
    property string awayTeam: ""
    readonly property var summaryRows: details && details.summaryRows ? details.summaryRows : []
    readonly property var statsRows: details && details.statsRows ? details.statsRows : []
    readonly property var possessionRow: statByLabel("Possession")
    readonly property var visibleStatsRows: statsRows.filter(row => String(row.label || "") !== "Possession")
    readonly property bool hasSummary: summaryRows.some(row => Number(row.homeValue || 0) > 0 || Number(row.awayValue || 0) > 0)
    readonly property bool hasStats: statsRows.some(row => Number(row.homeRaw || 0) > 0 || Number(row.awayRaw || 0) > 0)

    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    function statByLabel(label) {
        const normalized = String(label || "").toLowerCase();
        const rows = root.statsRows || [];
        for (let index = 0; index < rows.length; index += 1) {
            if (String(rows[index].label || "").toLowerCase() === normalized)
                return rows[index];
        }

        return {
            label,
            homeValue: "0%",
            awayValue: "0%",
            homeRatio: 0,
            awayRatio: 0,
            homeRaw: 0,
            awayRaw: 0
        };
    }

    function summaryValue(kind, side) {
        const rows = root.summaryRows || [];
        for (let index = 0; index < rows.length; index += 1) {
            if (String(rows[index].kind || "") === kind)
                return String(rows[index][side + "Value"] || "0");
        }

        return "0";
    }

    implicitHeight: visible ? detailsFrame.height : 0

    Rectangle {
        id: detailsFrame

        width: root.width
        height: detailsColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: 0
        color: root.withAlpha(Kirigami.Theme.backgroundColor, 0.45)

        ColumnLayout {
            id: detailsColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                visible: root.loading
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.BusyIndicator {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                    running: root.loading
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: i18nc("@info:status", "Loading live statistics")
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: !root.loading && root.errorText.length > 0
                type: Kirigami.MessageType.Information
                text: root.errorText
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.loading && root.errorText.length === 0 && (root.hasStats || root.hasSummary)
                spacing: Kirigami.Units.smallSpacing

                PossessionSummary {
                    Layout.fillWidth: true
                    rowData: root.possessionRow
                    homeCorners: root.summaryValue("corners", "home")
                    awayCorners: root.summaryValue("corners", "away")
                    homeYellow: root.summaryValue("yellow", "home")
                    awayYellow: root.summaryValue("yellow", "away")
                    homeRed: root.summaryValue("red", "home")
                    awayRed: root.summaryValue("red", "away")
                }

                Repeater {
                    model: root.visibleStatsRows

                    delegate: StatStripRow {
                        Layout.fillWidth: true
                        label: modelData.label || ""
                        homeValue: modelData.homeValue || "0"
                        awayValue: modelData.awayValue || "0"
                        homeRatio: Number(modelData.homeRatio || 0)
                        awayRatio: Number(modelData.awayRatio || 0)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.loading && root.errorText.length === 0 && !root.hasStats && !root.hasSummary
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Layout.preferredWidth
                    source: "view-statistics"
                    color: Kirigami.Theme.disabledTextColor
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: i18nc("@info:placeholder", "No live statistics available yet")
                    color: Kirigami.Theme.disabledTextColor
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component PossessionSummary: Item {
        id: summary

        property var rowData: ({})
        property string homeCorners: "0"
        property string awayCorners: "0"
        property string homeYellow: "0"
        property string awayYellow: "0"
        property string homeRed: "0"
        property string awayRed: "0"

        implicitHeight: Kirigami.Units.gridUnit * 2.1

        GridLayout {
            anchors.fill: parent
            columns: 3
            columnSpacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                spacing: Kirigami.Units.smallSpacing

                SummaryChip {
                    kind: "corners"
                    value: summary.homeCorners
                }

                SummaryChip {
                    kind: "red"
                    value: summary.homeRed
                }

                SummaryChip {
                    kind: "yellow"
                    value: summary.homeYellow
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit

                    PlasmaComponents.Label {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: summary.rowData.homeValue || "0%"
                        color: Kirigami.Theme.highlightColor
                        font.bold: true
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 5)
                        text: i18nc("@label:match statistic", "POSSESSION")
                        color: Kirigami.Theme.disabledTextColor
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font.bold: true
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }

                    PlasmaComponents.Label {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: summary.rowData.awayValue || "0%"
                        color: Kirigami.Theme.negativeTextColor
                        font.bold: true
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.smallSpacing
                    spacing: 0

                    StatFill {
                        Layout.fillWidth: true
                        ratio: Number(summary.rowData.homeRatio || 0)
                        fillColor: Kirigami.Theme.highlightColor
                        mirrored: false
                    }

                    StatFill {
                        Layout.fillWidth: true
                        ratio: Number(summary.rowData.awayRatio || 0)
                        fillColor: Kirigami.Theme.negativeTextColor
                        mirrored: true
                    }
                }
            }

            RowLayout {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                spacing: Kirigami.Units.smallSpacing

                SummaryChip {
                    kind: "yellow"
                    value: summary.awayYellow
                }

                SummaryChip {
                    kind: "red"
                    value: summary.awayRed
                }

                SummaryChip {
                    kind: "corners"
                    value: summary.awayCorners
                }
            }
        }
    }

    component StatStripRow: Item {
        id: statRow

        property string label: ""
        property string homeValue: "0"
        property string awayValue: "0"
        property real homeRatio: 0
        property real awayRatio: 0

        implicitHeight: Kirigami.Units.gridUnit * 1.45

        GridLayout {
            anchors.fill: parent
            columns: 5
            columnSpacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
                Layout.alignment: Qt.AlignVCenter
                text: statRow.homeValue
                color: Kirigami.Theme.textColor
                horizontalAlignment: Text.AlignRight
                font.bold: true
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }

            StatFill {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.smallSpacing
                Layout.alignment: Qt.AlignVCenter
                ratio: statRow.homeRatio
                fillColor: Kirigami.Theme.highlightColor
                mirrored: true
            }

            PlasmaComponents.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                Layout.alignment: Qt.AlignVCenter
                text: statRow.label.toUpperCase()
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.bold: true
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }

            StatFill {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.smallSpacing
                Layout.alignment: Qt.AlignVCenter
                ratio: statRow.awayRatio
                fillColor: Kirigami.Theme.negativeTextColor
                mirrored: false
            }

            PlasmaComponents.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
                Layout.alignment: Qt.AlignVCenter
                text: statRow.awayValue
                color: Kirigami.Theme.textColor
                font.bold: true
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }
    }

    component StatFill: Rectangle {
        property real ratio: 0
        property bool mirrored: false
        property color fillColor: Kirigami.Theme.highlightColor

        radius: height / 2
        color: root.withAlpha(Kirigami.Theme.alternateBackgroundColor, 0.65)

        Rectangle {
            height: parent.height
            width: Math.max(0, parent.width * Math.min(1, Math.max(0, parent.ratio)))
            x: parent.mirrored ? parent.width - width : 0
            radius: parent.radius
            color: parent.fillColor
        }
    }

    component SummaryChip: RowLayout {
        property string kind: ""
        property string value: "0"

        spacing: Math.max(2, Kirigami.Units.smallSpacing / 2)

        MatchStatIcon {
            Layout.alignment: Qt.AlignVCenter
            kind: parent.kind
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignVCenter
            text: parent.value
            color: Kirigami.Theme.textColor
            font.bold: true
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
    }

    component MatchStatIcon: Item {
        property string kind: ""

        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Layout.preferredWidth
        implicitWidth: Kirigami.Units.iconSizes.small
        implicitHeight: implicitWidth

        Rectangle {
            anchors.fill: parent
            visible: kind === "yellow" || kind === "red"
            radius: 2
            color: kind === "yellow" ? "#f9c440" : "#ed333b"
        }

        Kirigami.Icon {
            anchors.fill: parent
            visible: kind !== "yellow" && kind !== "red"
            source: kind === "corners" ? "flag" : Qt.resolvedUrl("../icons/sports/football.svg")
            isMask: true
            color: Kirigami.Theme.disabledTextColor
        }
    }
}
