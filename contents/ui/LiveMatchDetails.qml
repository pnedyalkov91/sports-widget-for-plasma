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
    property string sport: ""
    property int activeDetailsTab: 0
    readonly property var summaryRows: details && details.summaryRows ? details.summaryRows : []
    readonly property var statsRows: details && details.statsRows ? details.statsRows : []
    readonly property var eventsRows: details && details.events ? details.events : []
    readonly property var matchInfoRows: details && details.matchInfoRows ? details.matchInfoRows : []
    readonly property var lineups: details && details.lineups ? details.lineups : ({})
    readonly property string detailsSourceProvider: details && details.sourceProvider ? String(details.sourceProvider) : ""
    readonly property string competitionLogo: details && details.competitionLogo ? String(details.competitionLogo) : ""
    readonly property string competitionName: details && details.competition ? String(details.competition) : ""
    readonly property string statusText: details && details.statusText ? String(details.statusText) : ""
    readonly property string halfTimeScore: details && details.halfTimeScore ? String(details.halfTimeScore) : ""
    readonly property string homeFormation: lineups && lineups.homeFormation ? String(lineups.homeFormation) : ""
    readonly property string awayFormation: lineups && lineups.awayFormation ? String(lineups.awayFormation) : ""
    readonly property var homeStarting: lineups && lineups.homeStarting ? lineups.homeStarting : []
    readonly property var awayStarting: lineups && lineups.awayStarting ? lineups.awayStarting : []
    readonly property var homeSubstitutes: lineups && lineups.homeSubstitutes ? lineups.homeSubstitutes : []
    readonly property var awaySubstitutes: lineups && lineups.awaySubstitutes ? lineups.awaySubstitutes : []
    readonly property var possessionRow: statByLabel("Possession")
    readonly property var visibleStatsRows: orderedStatsRows()
    readonly property var homeEventsRows: orderedEventsRows(eventsRows.filter(row => String(row && row.side || "").toLowerCase() === "home"))
    readonly property var awayEventsRows: orderedEventsRows(eventsRows.filter(row => String(row && row.side || "").toLowerCase() === "away"))
    readonly property var neutralEventsRows: eventsRows.filter(row => {
        const side = String(row && row.side || "").toLowerCase();
        return side !== "home" && side !== "away";
    })
    readonly property bool hasSummary: summaryRows.some(row => Number(row.homeValue || 0) > 0 || Number(row.awayValue || 0) > 0)
    readonly property bool hasStats: statsRows.some(row => Number(row.homeRaw || 0) > 0 || Number(row.awayRaw || 0) > 0)
    readonly property bool hasEvents: eventsRows.length > 0
    readonly property bool hasLineups: homeStarting.length > 0 || awayStarting.length > 0 || homeSubstitutes.length > 0 || awaySubstitutes.length > 0
    readonly property bool hasInformation: matchInfoRows.length > 0 || competitionLogo.length > 0 || competitionName.length > 0 || homeFormation.length > 0 || awayFormation.length > 0 || hasLineups
    readonly property var tennisSets: details && details.tennisSets ? details.tennisSets : null
    readonly property var tennisPlayerComparison: details && details.tennisPlayerComparison ? details.tennisPlayerComparison : null
    readonly property bool hasTennisSets: tennisSets !== null && Array.isArray(tennisSets.rows) && tennisSets.rows.length > 0
    readonly property bool hasTennisComparison: tennisPlayerComparison !== null && Array.isArray(tennisPlayerComparison.rows) && tennisPlayerComparison.rows.length > 0
    // Tracker URL fallback cache, owned by the long-lived LiveMatchDelegate and
    // passed in here. `details` gets reset to {} while the card is collapsed
    // (periodic detail resets), so this component (recreated on every
    // expand/collapse) cannot rely on `details.trackerUrl` alone at creation time.
    property string cachedTrackerUrl: ""

    readonly property string trackerUrl: {
        const fresh = details && details.trackerUrl ? String(details.trackerUrl) : "";
        return fresh.length > 0 ? fresh : cachedTrackerUrl;
    }
    readonly property bool hasTracker: {
        const s = String(root.sport || "").toLowerCase();
        return trackerUrl.length > 0 && (s === "cricket" || s === "tennis" || s === "basketball");
    }
    readonly property bool hasStatisticsTab: {
        const s = String(root.sport || "").toLowerCase();
        return s !== "tennis" && s !== "basketball" && s !== "cricket";
    }
    // Temporary extra tab to preview the live tracker for football alongside
    // the existing Information/Details/Statistics tabs.
    readonly property bool hasFootballTracker: trackerUrl.length > 0 && String(root.sport || "").toLowerCase() === "football"
    readonly property bool hasAnyDetails: hasInformation || hasEvents || halfTimeScore.length > 0 || hasTennisSets || hasTracker || hasFootballTracker || (hasStatisticsTab && (hasStats || hasSummary || hasTennisComparison))

    property bool _autoSwitchedToTracker: hasTracker

    // Reset state when the user navigates to a different match.
    onHomeTeamChanged: { activeDetailsTab = 0; _autoSwitchedToTracker = false; }
    onAwayTeamChanged: { activeDetailsTab = 0; _autoSwitchedToTracker = false; }
    onSportChanged:    { activeDetailsTab = 0; _autoSwitchedToTracker = false; }

    onDetailsChanged: {
        // Do NOT reset activeDetailsTab here — details reload every few seconds for live
        // matches (detailsIdentity includes timestamp). Resetting here would continuously
        // kick the user back to the Information tab while they watch the tracker.
        // Auto-switch to Details tab the first time a usable tracker arrives.
        if (hasTracker && !_autoSwitchedToTracker) {
            _autoSwitchedToTracker = true
            activeDetailsTab = 1
        }
    }

    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    function statByLabel(label) {
        const normalized = String(label || "").toLowerCase();
        const rows = root.statsRows || [];
        for (let index = 0; index < rows.length; index += 1) {
            const row = rows[index] || {};
            if (String(row.kind || "").toLowerCase() === "possession" || String(row.label || "").toLowerCase() === normalized)
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

    function orderedStatsRows() {
        const rows = Array.isArray(root.statsRows) ? root.statsRows.slice() : [];
        function rank(row) {
            const kind = String(row && row.kind || "").toLowerCase();
            const label = String(row && row.label || "").toLowerCase();
            if (kind === "possession" || label.indexOf("possession") >= 0)
                return 0;
            if (kind === "attacks")
                return 1;
            if (label.indexOf("shots on target") >= 0)
                return 2;
            if (label.indexOf("dangerous") >= 0)
                return 3;
            if (label.indexOf("shots off") >= 0)
                return 4;
            return 5;
        }
        return rows.sort((left, right) => rank(left) - rank(right));
    }

    function orderedEventsRows(rows) {
        return (Array.isArray(rows) ? rows.slice() : []).sort((left, right) => {
            const leftMinute = Number(String(left && left.minute || "").replace(/[^\d.-]/g, ""));
            const rightMinute = Number(String(right && right.minute || "").replace(/[^\d.-]/g, ""));
            if (Number.isFinite(leftMinute) && Number.isFinite(rightMinute) && leftMinute !== rightMinute)
                return leftMinute - rightMinute;
            return String(left && left.minute || "").localeCompare(String(right && right.minute || ""));
        });
    }

    function stripTeamPrefix(text) {
        const value = String(text || "").trim();
        if (value.length === 0)
            return value;

        const colonIndex = value.indexOf(":");
        if (colonIndex <= 0)
            return value;

        const prefix = value.slice(0, colonIndex).trim().toLowerCase();
        const suffix = value.slice(colonIndex + 1).trim();
        if (!suffix.length)
            return value;

        const home = String(root.homeTeam || "").trim().toLowerCase();
        const away = String(root.awayTeam || "").trim().toLowerCase();
        if ((home.length > 0 && prefix === home) || (away.length > 0 && prefix === away))
            return suffix;

        return value;
    }

    function sourceProviderLabel(provider) {
        return String(provider || "");
    }

    function teamFormationLabel(team, formation) {
        const parts = [String(team || "").trim(), String(formation || "").trim()].filter(part => part.length > 0);
        return parts.join(" · ");
    }

    function statisticsUnavailableText() {
        const provider = root.sourceProviderLabel(root.detailsSourceProvider);
        return provider.length > 0
            ? i18nc("@info:placeholder", "%1 does not provide detailed match statistics for this match.", provider)
            : i18nc("@info:placeholder", "The provider does not provide detailed match statistics for this match.");
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
                    text: i18nc("@info:status", "Loading match statistics")
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

            PlasmaComponents.TabBar {
                Layout.fillWidth: true
                visible: !root.loading && root.errorText.length === 0 && root.hasAnyDetails
                currentIndex: root.activeDetailsTab
                onCurrentIndexChanged: root.activeDetailsTab = currentIndex

                PlasmaComponents.TabButton {
                    text: i18nc("@tab:match details", "Information")
                }

                PlasmaComponents.TabButton {
                    text: i18nc("@tab:match details", "Details")
                }

                Repeater {
                    model: root.hasStatisticsTab ? 1 : 0

                    PlasmaComponents.TabButton {
                        text: i18nc("@tab:match details", "Statistics")
                    }
                }

                Repeater {
                    model: root.hasFootballTracker ? 1 : 0

                    PlasmaComponents.TabButton {
                        text: i18nc("@tab:match details", "Tracker")
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                visible: !root.loading && root.errorText.length === 0 && root.hasAnyDetails
                currentIndex: root.activeDetailsTab

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.competitionLogo.length > 0 || root.competitionName.length > 0
                        spacing: Kirigami.Units.smallSpacing

                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Layout.preferredWidth
                            source: root.competitionLogo
                            visible: root.competitionLogo.length > 0
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: root.competitionName
                            color: Kirigami.Theme.disabledTextColor
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font: Kirigami.Theme.smallFont
                        }
                    }

                    Repeater {
                        model: root.matchInfoRows

                        delegate: InfoRow {
                            Layout.fillWidth: true
                            label: String(modelData.label || "")
                            value: String(modelData.value || "")
                        }
                    }

                    LineupSection {
                        Layout.fillWidth: true
                        visible: root.homeStarting.length > 0 || root.awayStarting.length > 0
                        title: i18nc("@label:football lineups", "Starting lineups")
                        homePlayers: root.homeStarting
                        awayPlayers: root.awayStarting
                        homeFormation: root.homeFormation
                        awayFormation: root.awayFormation
                    }

                    LineupSection {
                        Layout.fillWidth: true
                        visible: root.homeSubstitutes.length > 0 || root.awaySubstitutes.length > 0
                        title: i18nc("@label:football lineups", "Substitutes")
                        homePlayers: root.homeSubstitutes
                        awayPlayers: root.awaySubstitutes
                    }

                    EmptyTabPlaceholder {
                        Layout.fillWidth: true
                        visible: !root.hasInformation
                        text: i18nc("@info:placeholder", "No match information available")
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    // Cricket / Tennis live tracker
                    Loader {
                        id: trackerLoader
                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 26
                        active: root.hasTracker
                        visible: active
                        source: active ? Qt.resolvedUrl("TrackerView.qml") : ""

                        Binding {
                            target: trackerLoader.item
                            property: "trackerUrl"
                            value: root.trackerUrl
                            when: trackerLoader.status === Loader.Ready
                        }
                    }

                    // Tennis set-by-set scoreboard
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.hasTennisSets && !root.hasTracker
                        spacing: 2

                        Repeater {
                            model: root.tennisSets ? root.tennisSets.rows : []

                            delegate: TennisSetRow {
                                Layout.fillWidth: true
                                badge: String(modelData.badge || "")
                                playerName: String(modelData.playerName || "")
                                setScores: modelData.setScores || []
                                totalSets: String(modelData.totalSets || "")
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        visible: root.hasEvents
                        columns: 2
                        columnSpacing: Kirigami.Units.largeSpacing
                        rowSpacing: Kirigami.Units.smallSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                            spacing: Kirigami.Units.smallSpacing

                            Repeater {
                                model: root.homeEventsRows

                                delegate: EventRow {
                                    Layout.fillWidth: true
                                    minute: String(modelData.minute || "")
                                    kind: String(modelData.kind || "")
                                    label: String(modelData.label || "")
                                    player: String(modelData.player || "")
                                    side: String(modelData.side || "")
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignRight | Qt.AlignTop
                            spacing: Kirigami.Units.smallSpacing

                            Repeater {
                                model: root.awayEventsRows

                                delegate: EventRow {
                                    Layout.fillWidth: true
                                    minute: String(modelData.minute || "")
                                    kind: String(modelData.kind || "")
                                    label: String(modelData.label || "")
                                    player: String(modelData.player || "")
                                    side: String(modelData.side || "")
                                    alignRight: true
                                }
                            }
                        }
                    }

                    EmptyTabPlaceholder {
                        Layout.fillWidth: true
                        visible: !root.hasEvents && !root.hasTennisSets && !root.hasTracker
                        text: i18nc("@info:placeholder", "No match events available")
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    // Tennis player comparison
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.hasTennisComparison
                        spacing: 2

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: root.tennisPlayerComparison ? root.tennisPlayerComparison.title : ""
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Repeater {
                            model: root.tennisPlayerComparison ? root.tennisPlayerComparison.rows : []

                            delegate: PlayerCompRow {
                                Layout.fillWidth: true
                                label: String(modelData.label || "")
                                homeValue: String(modelData.homeValue || "")
                                awayValue: String(modelData.awayValue || "")
                            }
                        }
                    }

                    SummaryStrip {
                        Layout.fillWidth: true
                        visible: root.hasSummary
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

                    EmptyTabPlaceholder {
                        Layout.fillWidth: true
                        visible: !root.hasStats && !root.hasSummary && !root.hasTennisComparison
                        text: root.statisticsUnavailableText()
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: !root.hasStats && root.hasSummary && !root.hasTennisComparison
                        text: root.statisticsUnavailableText()
                        color: Kirigami.Theme.disabledTextColor
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font: Kirigami.Theme.smallFont
                    }
                }

                Repeater {
                    model: root.hasFootballTracker ? 1 : 0

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        // Temporary: football live tracker preview
                        Loader {
                            id: footballTrackerLoader
                            Layout.fillWidth: true
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 26
                            active: root.hasFootballTracker
                            visible: active
                            source: active ? Qt.resolvedUrl("TrackerView.qml") : ""

                            Binding {
                                target: footballTrackerLoader.item
                                property: "trackerUrl"
                                value: root.trackerUrl
                                when: footballTrackerLoader.status === Loader.Ready
                            }
                        }
                    }
                }
            }

            EmptyTabPlaceholder {
                Layout.fillWidth: true
                visible: !root.loading && root.errorText.length === 0 && !root.hasAnyDetails
                text: i18nc("@info:placeholder", "No match details available")
            }
        }
    }

    component InfoRow: RowLayout {
        id: infoRow

        property string label: ""
        property string value: ""

        spacing: Kirigami.Units.smallSpacing
        implicitHeight: Math.max(Kirigami.Units.gridUnit * 1.35, valueLabel.implicitHeight + Kirigami.Units.smallSpacing)

        Item {
            Layout.fillWidth: true
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignVCenter
            text: infoRow.label + ":"
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
        }

        PlasmaComponents.Label {
            id: valueLabel

            Layout.alignment: Qt.AlignVCenter
            text: infoRow.value
            color: Kirigami.Theme.textColor
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
        }

        Item {
            Layout.fillWidth: true
        }
    }

    component LineupSection: ColumnLayout {
        id: section

        property string title: ""
        property var homePlayers: []
        property var awayPlayers: []
        property string homeFormation: ""
        property string awayFormation: ""

        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: section.title
            color: Kirigami.Theme.textColor
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.max(1, Kirigami.Units.smallSpacing / 2)

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.teamFormationLabel(root.homeTeam, section.homeFormation)
                    visible: text.length > 0
                    color: Kirigami.Theme.disabledTextColor
                    font.bold: true
                    elide: Text.ElideRight
                }

                Repeater {
                    model: section.homePlayers

                    delegate: LineupPlayerRow {
                        Layout.fillWidth: true
                        number: String(modelData.number || "")
                        name: String(modelData.name || "")
                        position: String(modelData.position || "")
                        rating: String(modelData.rating || "")
                        captain: modelData.captain === true
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.max(1, Kirigami.Units.smallSpacing / 2)

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.teamFormationLabel(root.awayTeam, section.awayFormation)
                    visible: text.length > 0
                    color: Kirigami.Theme.disabledTextColor
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                Repeater {
                    model: section.awayPlayers

                    delegate: LineupPlayerRow {
                        Layout.fillWidth: true
                        number: String(modelData.number || "")
                        name: String(modelData.name || "")
                        position: String(modelData.position || "")
                        rating: String(modelData.rating || "")
                        captain: modelData.captain === true
                        alignRight: true
                    }
                }
            }
        }
    }

    component LineupPlayerRow: RowLayout {
        id: playerRow

        property string number: ""
        property string name: ""
        property string position: ""
        property string rating: ""
        property bool captain: false
        property bool alignRight: false

        spacing: Kirigami.Units.smallSpacing
        layoutDirection: alignRight ? Qt.RightToLeft : Qt.LeftToRight
        implicitHeight: Kirigami.Units.gridUnit * 1.4

        function playerLabel() {
            const parts = [playerRow.name];
            if (playerRow.position.length > 0)
                parts[0] += " (" + playerRow.position + ")";
            if (playerRow.captain)
                parts[0] += " (C)";
            return parts[0];
        }

        PlasmaComponents.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.7
            text: playerRow.number.length > 0 ? playerRow.number : "—"
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: playerRow.playerLabel()
            color: Kirigami.Theme.textColor
            horizontalAlignment: playerRow.alignRight ? Text.AlignRight : Text.AlignLeft
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
        }
    }

    component EmptyTabPlaceholder: ColumnLayout {
        id: emptyPlaceholder

        property string text: ""

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
            text: emptyPlaceholder.text
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    component SummaryStrip: Item {
        id: summary

        property string homeCorners: "0"
        property string awayCorners: "0"
        property string homeYellow: "0"
        property string awayYellow: "0"
        property string homeRed: "0"
        property string awayRed: "0"

        implicitHeight: Kirigami.Units.gridUnit * 1.4

        GridLayout {
            anchors.fill: parent
            columns: 2
            columnSpacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
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

            RowLayout {
                Layout.fillWidth: true
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
            width: parent.ratio > 0 ? Math.max(2, parent.width * Math.min(1, Math.max(0, parent.ratio))) : 0
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
        readonly property string normalizedKind: String(kind || "").toLowerCase()
        readonly property bool isCard: normalizedKind.indexOf("yellow") >= 0 || normalizedKind.indexOf("red") >= 0
        readonly property bool isTextIcon: normalizedKind.indexOf("goal") >= 0 || normalizedKind.indexOf("substitution") >= 0 || normalizedKind.indexOf("penalty") >= 0

        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Layout.preferredWidth
        implicitWidth: Kirigami.Units.iconSizes.small
        implicitHeight: implicitWidth

        Rectangle {
            anchors.fill: parent
            visible: parent.isCard
            radius: 2
            color: parent.normalizedKind.indexOf("yellow") >= 0 ? "#f9c440" : "#ed333b"
        }

        PlasmaComponents.Label {
            anchors.centerIn: parent
            visible: parent.isTextIcon
            text: parent.normalizedKind.indexOf("substitution") >= 0 ? "\u21c4" : "\u26bd"
            color: Kirigami.Theme.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.bold: true
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        PlasmaComponents.Label {
            anchors.centerIn: parent
            visible: !parent.isCard && !parent.isTextIcon
            text: parent.normalizedKind.indexOf("corner") >= 0 ? "🚩" : "⚽"
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
    }

    component EventRow: RowLayout {
        id: eventRow

        property string minute: ""
        property string kind: ""
        property string label: ""
        property string player: ""
        property string side: ""
        property bool alignRight: false

        spacing: Kirigami.Units.smallSpacing
        layoutDirection: alignRight ? Qt.RightToLeft : Qt.LeftToRight

        implicitHeight: Math.max(Kirigami.Units.gridUnit * 1.45, eventText.implicitHeight + Kirigami.Units.smallSpacing)

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
            text: eventRow.minute.length > 0 ? eventRow.minute + "'" : "—"
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: eventRow.alignRight ? Text.AlignRight : Text.AlignLeft
            font.bold: true
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        MatchStatIcon {
            Layout.alignment: Qt.AlignVCenter
            kind: eventRow.kind
        }

        PlasmaComponents.Label {
            id: eventText

            Layout.fillWidth: true
            text: eventLabel()
            color: Kirigami.Theme.textColor
            horizontalAlignment: eventRow.alignRight ? Text.AlignRight : Text.AlignLeft
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        function eventLabel() {
            const detail = eventDescription();
            return detail;
        }

        function eventDescription() {
            const label = root.stripTeamPrefix(String(eventRow.label || "").trim());
            const player = root.stripTeamPrefix(String(eventRow.player || "").trim());
            const kind = String(eventRow.kind || "").toLowerCase();
            if ((kind.indexOf("yellow") >= 0 || kind.indexOf("red") >= 0) && player.length > 0)
                return player;

            const lowerLabel = label.toLowerCase();
            const lowerPlayer = player.toLowerCase();
            if (player.length > 0 && label.length > 0 && lowerLabel !== lowerPlayer && lowerLabel.indexOf(lowerPlayer) < 0)
                return player + " (" + label + ")";

            if (label.length > 0)
                return label;

            return player;
        }
    }

    component TennisSetRow: RowLayout {
        id: tennisSetRow

        property string badge: ""
        property string playerName: ""
        property var setScores: []
        property string totalSets: ""

        spacing: Kirigami.Units.smallSpacing

        Image {
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            source: tennisSetRow.badge
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            visible: tennisSetRow.badge.length > 0
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: tennisSetRow.playerName
            elide: Text.ElideRight
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
        }

        Repeater {
            model: tennisSetRow.setScores

            PlasmaComponents.Label {
                required property var modelData
                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.8
                text: modelData.score
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                font.bold: modelData.winner
                color: modelData.winner ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
            }
        }

        PlasmaComponents.Label {
            text: "·"
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
        }

        PlasmaComponents.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.8
            text: tennisSetRow.totalSets
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }
    }

    component PlayerCompRow: RowLayout {
        id: playerCompRow

        property string label: ""
        property string homeValue: ""
        property string awayValue: ""

        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: playerCompRow.homeValue
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        PlasmaComponents.Label {
            text: playerCompRow.label
            color: Kirigami.Theme.disabledTextColor
            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: playerCompRow.awayValue
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        }
    }
}
