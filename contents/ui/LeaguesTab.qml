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
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Compact, GNOME-Colosseum-style overview: every league with a live match is a
// row; click it to reveal its live matches with scores. Upcoming fixtures live
// on the Schedules tab only (they used to be mixed in here, duplicating it).
// Leagues are ordered by the user's configured priority (done upstream when the
// model is built). Each match row carries the one-click bell / star / pin
// actions.
Item {
    id: root

    property var leaguesModel
    property string favoriteTeam: ""
    property bool loading: false
    // Groups start collapsed here; the host keeps the expand/collapse state so it
    // survives model rebuilds and tab switches.
    property var collapsedGroups: ({})
    property bool defaultCollapsed: true
    property bool showMatchActions: false
    property int matchActionsTick: 0
    property var matchNotifyState: function(match) { return false; }
    property var matchPinnedState: function(match) { return false; }
    property var matchFavoriteState: function(match) { return false; }
    property var teamFavoriteState: function(teamName) { return false; }
    // Maps a leagueGroup -> { total, live } so the header can show counts. The
    // host supplies this so the tab doesn't have to scan the whole model itself.
    property var groupSummaries: ({})

    signal groupToggled(string group)
    signal matchNotifyToggled(var match)
    signal matchFavoriteToggled(string teamName, var match)
    signal matchPanelPinToggled(var match)

    function isGroupCollapsed(group) {
        const key = String(group || "");
        // An explicit user choice always wins.
        if (root.collapsedGroups[key] !== undefined)
            return Boolean(root.collapsedGroups[key]);
        // Otherwise leagues with a live match start expanded (so live scores are
        // visible at a glance); leagues with only upcoming fixtures start collapsed.
        if (root.groupSummary(key).live > 0)
            return false;
        return root.defaultCollapsed;
    }

    function groupSummary(group) {
        const summary = root.groupSummaries[String(group || "")];
        return summary || { "total": 0, "live": 0 };
    }

    function isFavoriteTeam(teamName) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(teamName || "").toLowerCase().indexOf(favorite) >= 0;
    }

    function modelMatch(model) {
        return {
            "sport": model.sport || "",
            "league": model.league || "",
            "homeTeam": model.homeTeam || "",
            "awayTeam": model.awayTeam || "",
            "homeBadge": model.homeBadge || "",
            "awayBadge": model.awayBadge || "",
            "startTime": model.startTime || "",
            "timestamp": Number(model.timestamp || 0)
        };
    }

    PlasmaComponents.BusyIndicator {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.smallSpacing
        z: 1
        width: Kirigami.Units.iconSizes.small
        height: width
        visible: root.loading && leaguesList.count > 0
        running: visible
    }

    ListView {
        id: leaguesList

        anchors.fill: parent
        clip: true
        spacing: 0
        model: root.leaguesModel
        boundsBehavior: Flickable.StopAtBounds
        readonly property int contentColumnWidth: Math.max(0, width - Kirigami.Units.gridUnit)

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        section.property: "leagueGroup"
        section.criteria: ViewSection.FullString
        section.delegate: RoundSectionHeader {
            width: leaguesList.contentColumnWidth
            text: section
            collapsible: true
            collapsed: root.isGroupCollapsed(section)
            liveCount: root.groupSummary(section).live
            onToggled: root.groupToggled(section)
        }

        EmptyState {
            anchors.fill: parent
            visible: leaguesList.count === 0 && !root.loading
            text: i18nc("@info:placeholder", "No live matches")
        }

        delegate: Item {
            id: leagueRow

            required property var model
            required property int index

            readonly property bool isRacing: String(leagueRow.model.sport || "").toLowerCase() === "racing"
            readonly property real racingRowHeight: Kirigami.Units.gridUnit * (String(leagueRow.model.racingTop || "[]").length > 2 ? 5.0 : 4.2)

            width: leaguesList.contentColumnWidth
            visible: !root.isGroupCollapsed(leagueRow.model.leagueGroup)
            height: visible ? (rowLoader.item ? rowLoader.item.implicitHeight : Kirigami.Units.gridUnit * 5.2) : 0
            enabled: visible

            Component {
                id: matchComponent

                LiveMatchDelegate {
                    width: leagueRow.width
                    sport: leagueRow.model.sport || ""
                    league: leagueRow.model.league || ""
                    homeTeam: leagueRow.model.homeTeam || ""
                    awayTeam: leagueRow.model.awayTeam || ""
                    homeScore: leagueRow.model.homeScore || ""
                    awayScore: leagueRow.model.awayScore || ""
                    homeGames: leagueRow.model.homeGames || ""
                    awayGames: leagueRow.model.awayGames || ""
                    homePenaltyScore: leagueRow.model.homePenaltyScore || ""
                    awayPenaltyScore: leagueRow.model.awayPenaltyScore || ""
                    status: leagueRow.model.status || ""
                    minute: leagueRow.model.minute || ""
                    startTime: leagueRow.model.startTime || ""
                    splitLeagueAndTimeLines: true
                    scoreRowHeight: Kirigami.Units.gridUnit * 5.2
                    timestamp: Number(leagueRow.model.timestamp || 0)
                    stadium: leagueRow.model.stadium || ""
                    homeBadge: leagueRow.model.homeBadge || ""
                    awayBadge: leagueRow.model.awayBadge || ""
                    poster: leagueRow.model.poster || ""
                    popular: Boolean(leagueRow.model.popular)
                    showScore: leagueRow.model.showScore !== false
                    favorite: root.isFavoriteTeam(leagueRow.model.homeTeam) || root.isFavoriteTeam(leagueRow.model.awayTeam) || (root.matchActionsTick, root.matchFavoriteState(root.modelMatch(leagueRow.model)))
                    expanded: leagueRow.visible && leagueRow.index === leaguesList.expandedIndex
                    matchPath: leagueRow.model.matchPath || ""
                    liveUrl: leagueRow.model.liveUrl || ""
                    detailsProvider: leagueRow.model.detailsProvider || ""
                    espnEventId: leagueRow.model.espnEventId || ""
                    espnSport: leagueRow.model.espnSport || ""
                    espnLeague: leagueRow.model.espnLeague || ""
                    showMatchActions: root.showMatchActions
                    matchNotifyOn: (root.matchActionsTick, root.matchNotifyState(root.modelMatch(leagueRow.model)))
                    matchPinnedToPanel: (root.matchActionsTick, root.matchPinnedState(root.modelMatch(leagueRow.model)))
                    homeIsFavorite: (root.matchActionsTick, root.teamFavoriteState(leagueRow.model.homeTeam || ""))
                    awayIsFavorite: (root.matchActionsTick, root.teamFavoriteState(leagueRow.model.awayTeam || ""))
                    activeDetailsTab: leaguesList.expandedDetailsTab
                    onActiveDetailsTabChanged: leaguesList.expandedDetailsTab = activeDetailsTab
                    onClicked: leaguesList.expandedIndex = leaguesList.expandedIndex === leagueRow.index ? -1 : leagueRow.index
                    onRequestExpand: leaguesList.expandedIndex = leagueRow.index
                    onNotifyToggled: root.matchNotifyToggled(root.modelMatch(leagueRow.model))
                    onFavoriteToggled: (teamName) => root.matchFavoriteToggled(teamName, root.modelMatch(leagueRow.model))
                    onPanelPinToggled: root.matchPanelPinToggled(root.modelMatch(leagueRow.model))
                }
            }

            // Racing weekends: the live session's running order (top three plus the
            // full classification when expanded) instead of a two-sided score row.
            Component {
                id: raceComponent

                RaceDelegate {
                    width: leagueRow.width
                    league: leagueRow.model.league || ""
                    status: leagueRow.model.status || ""
                    minute: leagueRow.model.minute || ""
                    statusText: leagueRow.model.statusText || ""
                    startTime: leagueRow.model.startTime || ""
                    timestamp: Number(leagueRow.model.timestamp || 0)
                    eventName: leagueRow.model.racingEvent || ""
                    circuit: leagueRow.model.racingCircuit || ""
                    location: leagueRow.model.racingLocation || ""
                    sessionLabel: leagueRow.model.racingSession || ""
                    racingTop: leagueRow.model.racingTop || "[]"
                    racingData: leagueRow.model.racingData || ""
                    espnEventId: leagueRow.model.espnEventId || ""
                    espnLeague: leagueRow.model.espnLeague || ""
                    headerHeight: leagueRow.racingRowHeight
                    favorite: root.isFavoriteTeam(leagueRow.model.homeTeam) || root.isFavoriteTeam(leagueRow.model.awayTeam) || (root.matchActionsTick, root.matchFavoriteState(root.modelMatch(leagueRow.model)))
                    expanded: leagueRow.visible && leagueRow.index === leaguesList.expandedIndex
                    selectedSession: leaguesList.expandedSession
                    showMatchActions: root.showMatchActions
                    matchNotifyOn: (root.matchActionsTick, root.matchNotifyState(root.modelMatch(leagueRow.model)))
                    matchPinnedToPanel: (root.matchActionsTick, root.matchPinnedState(root.modelMatch(leagueRow.model)))
                    onSessionPicked: key => leaguesList.expandedSession = key
                    onNotifyToggled: root.matchNotifyToggled(root.modelMatch(leagueRow.model))
                    onPanelPinToggled: root.matchPanelPinToggled(root.modelMatch(leagueRow.model))
                    onClicked: leaguesList.expandedIndex = leaguesList.expandedIndex === leagueRow.index ? -1 : leagueRow.index
                }
            }

            Loader {
                id: rowLoader

                width: parent.width
                sourceComponent: leagueRow.isRacing ? raceComponent : matchComponent
            }
        }

        property int expandedIndex: -1
        property int expandedDetailsTab: 0
        property string expandedSession: ""
        onExpandedIndexChanged: {
            expandedDetailsTab = 0;
            expandedSession = "";
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
        visible: root.loading && leaguesList.count === 0
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Layout.preferredWidth
            running: root.loading
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: i18nc("@info:status", "Loading matches")
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
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
                source: "view-calendar-list"
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: parent.parent.text
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
