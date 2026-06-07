/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
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
    property bool popular: false
    property bool favorite: false
    property bool selected: false
    property bool showScore: true
    property bool splitLeagueAndTimeLines: false
    property bool splitDateAndTimeLines: false
    property real scoreRowHeight: 0
    property bool expanded: false
    property bool detailsLoading: false
    property bool detailsLoaded: false
    property string detailsError: ""
    property var details: ({})
    property int requestGeneration: 0
    readonly property string detailsIdentity: [
        root.detailsProvider,
        root.matchPath,
        root.liveUrl,
        root.homeTeam,
        root.awayTeam,
        root.homeScore,
        root.awayScore,
        root.startTime,
        root.timestamp
    ].join("|")

    signal clicked()
    signal doubleClicked()

    function loadDetails(force) {
        if (!root.expanded)
            return;

        if (root.detailsLoading)
            return;

        if (root.detailsLoaded && !force)
            return;

        if (root.liveUrl.length === 0 && root.matchPath.length === 0) {
            root.details = {};
            root.detailsLoaded = true;
            root.detailsError = i18nc("@info:status", "Detailed match information is not available for this match.");
            return;
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
            onClicked: root.clicked()
            onDoubleClicked: root.doubleClicked()
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
                loading: root.detailsLoading
                errorText: root.detailsError
                homeTeam: root.homeTeam
                awayTeam: root.awayTeam
            }
        }
    }
}
