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

Item {
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
    property real timestamp: 0
    property string stadium: ""
    property string homeBadge: ""
    property string awayBadge: ""
    property string poster: ""
    property string matchPath: ""
    property string liveUrl: ""
    property string detailsProvider: ""
    // ESPN-sourced matches have no matchPath/liveUrl; these identify the match
    // for fetching its incident feed (goals/cards/subs) instead.
    property string espnEventId: ""
    property string espnSport: ""
    property string espnLeague: ""
    // Public ESPN gamecast URL for this match (ESPN-sourced matches only), shown
    // as a "Visit on ESPN" link in the expanded details. Soccer uses
    // ".../match/_/gameId/", other sports ".../game/_/gameId/".
    readonly property string espnMatchUrl: {
        if (root.detailsProvider !== "espn" || root.espnEventId.length === 0)
            return "";
        const sportPath = root.espnSport.length > 0 ? root.espnSport.toLowerCase() : "soccer";
        const verb = sportPath === "soccer" ? "match" : "game";
        return "https://www.espn.com/" + sportPath + "/" + verb + "/_/gameId/" + root.espnEventId;
    }
    property bool popular: false
    property bool favorite: false
    property bool selected: false
    property bool showScore: true
    property bool showMatchActions: false
    property bool matchNotifyOn: false
    property bool matchPinnedToPanel: false
    property bool homeIsFavorite: false
    property bool awayIsFavorite: false
    property bool splitLeagueAndTimeLines: false
    property bool splitDateAndTimeLines: false
    property real scoreRowHeight: 0
    property bool expanded: false
    property bool detailsLoading: false
    property bool detailsLoaded: false
    property string detailsError: ""
    property var details: ({})
    property int requestGeneration: 0

    // Persists across detailsLoader recreations (collapse/expand, periodic
    // detail resets) since `details` itself gets reset to {} while collapsed.
    property string cachedTrackerUrl: ""
    // Selected details sub-tab, kept on the long-lived delegate so it survives the
    // detailsLoader being torn down and rebuilt (e.g. when the row is scrolled out
    // of and back into view), instead of snapping back to the first tab.
    property int activeDetailsTab: 0

    onDetailsChanged: {
        const fresh = root.details && root.details.trackerUrl ? String(root.details.trackerUrl) : "";
        if (fresh.length > 0)
            root.cachedTrackerUrl = fresh;
    }

    readonly property string detailsIdentity: [
        root.detailsProvider,
        root.matchPath,
        root.liveUrl,
        root.espnEventId,
        root.homeTeam,
        root.awayTeam,
        root.homeScore,
        root.awayScore,
        root.startTime,
        root.timestamp
    ].join("|")

    signal clicked()
    signal doubleClicked()
    signal requestExpand()
    signal notifyToggled()
    signal favoriteToggled(string teamName)
    signal panelPinToggled()

    // Finished matches are immutable, so their details are cached on disk and
    // re-opened without another network request.
    readonly property bool isFinishedMatch: root.status !== "Live"
        && root.status.toLowerCase() !== "upcoming"
        && root.homeScore.length > 0 && root.awayScore.length > 0

    MatchDataCache {
        id: detailsCache
    }

    function loadDetails(force) {
        if (!root.expanded)
            return;

        if (root.detailsLoading)
            return;

        if (root.detailsLoaded && !force)
            return;

        if (root.liveUrl.length === 0 && root.matchPath.length === 0 && root.espnEventId.length === 0) {
            root.details = {};
            root.detailsLoaded = true;
            root.detailsError = i18nc("@info:status", "Detailed match information is not available for this match.");
            return;
        }

        const detailsCacheKey = "matchdetails|" + root.detailsIdentity;
        if (root.isFinishedMatch && !force) {
            const cached = detailsCache.read(detailsCacheKey);
            if (cached && cached.value && typeof cached.value === "object") {
                root.details = cached.value;
                root.detailsLoaded = true;
                root.detailsLoading = false;
                root.detailsError = "";
                return;
            }
        }

        const generation = root.requestGeneration + 1;
        root.requestGeneration = generation;
        root.detailsLoading = true;
        root.detailsError = "";

        SportsApi.fetchLiveMatchDetails({
            "sport": root.sport,
            "sports": root.sport,
            "league": root.league,
            "liveUrl": root.liveUrl,
            "matchPath": root.matchPath,
            "detailsProvider": root.detailsProvider,
            "espnEventId": root.espnEventId,
            "espnSport": root.espnSport,
            "espnLeague": root.espnLeague,
            "homeTeam": root.homeTeam,
            "awayTeam": root.awayTeam,
            "homeScore": root.homeScore,
            "awayScore": root.awayScore,
            "startTime": root.startTime,
            "timestamp": root.timestamp
        }, payload => {
            if (!root || generation !== root.requestGeneration)
                return;

            root.details = payload || {};
            root.detailsLoaded = true;
            root.detailsLoading = false;
            if (root.isFinishedMatch && payload && typeof payload === "object")
                detailsCache.write(detailsCacheKey, payload);
        }, message => {
            if (!root || generation !== root.requestGeneration)
                return;

            root.details = {};
            root.detailsLoaded = true;
            root.detailsLoading = false;
            root.detailsError = message;
        });
    }

    function resetDetails() {
        root.requestGeneration += 1;
        root.details = {};
        root.detailsLoaded = false;
        root.detailsLoading = false;
        root.detailsError = "";
    }

    function _openDetailsTab() {
        if (!root.expanded)
            root.requestExpand();
        Qt.callLater(function() {
            if (detailsLoader.item)
                detailsLoader.item.activeDetailsTab = 1;
        });
    }

    width: parent ? parent.width : implicitWidth
    height: contentColumn.implicitHeight
    implicitHeight: contentColumn.implicitHeight

    Component.onCompleted: loadDetails(false)
    onExpandedChanged: loadDetails(false)
    onDetailsIdentityChanged: {
        resetDetails();
        loadDetails(false);
    }

    Column {
        id: contentColumn

        width: root.width
        spacing: 0

        ScoreDelegate {
            width: parent.width
            height: root.scoreRowHeight > 0 ? root.scoreRowHeight : implicitHeight
            sport: root.sport
            league: root.league
            homeTeam: root.homeTeam
            awayTeam: root.awayTeam
            homeScore: root.homeScore
            awayScore: root.awayScore
            homePenaltyScore: root.homePenaltyScore
            awayPenaltyScore: root.awayPenaltyScore
            status: root.status
            minute: root.minute
            startTime: root.startTime
            splitLeagueAndTimeLines: root.splitLeagueAndTimeLines
            splitDateAndTimeLines: root.splitDateAndTimeLines
            stadium: root.stadium
            homeBadge: root.homeBadge
            awayBadge: root.awayBadge
            poster: root.poster
            popular: root.popular
            showScore: root.showScore
            favorite: root.favorite
            selected: root.selected || root.expanded
            showMatchActions: root.showMatchActions
            matchNotifyOn: root.matchNotifyOn
            matchPinnedToPanel: root.matchPinnedToPanel
            homeIsFavorite: root.homeIsFavorite
            awayIsFavorite: root.awayIsFavorite
            onClicked: root.clicked()
            onDoubleClicked: root.doubleClicked()
            onScoreInfoClicked: root._openDetailsTab()
            onNotifyToggled: root.notifyToggled()
            onFavoriteToggled: (teamName) => root.favoriteToggled(teamName)
            onPanelPinToggled: root.panelPinToggled()
        }

        Loader {
            id: detailsLoader

            width: parent.width
            active: root.expanded
            visible: active
            height: item ? item.implicitHeight : 0

            sourceComponent: LiveMatchDetails {
                width: detailsLoader.width
                details: root.details
                cachedTrackerUrl: root.cachedTrackerUrl
                loading: root.detailsLoading
                errorText: root.detailsError
                homeTeam: root.homeTeam
                awayTeam: root.awayTeam
                visitUrl: root.espnMatchUrl
                sport: root.sport
                // Restore the selected tab on (re)creation and write user changes
                // back to the delegate, so it persists across loader teardown.
                activeDetailsTab: root.activeDetailsTab
                onActiveDetailsTabChanged: root.activeDetailsTab = activeDetailsTab
            }
        }
    }
}
