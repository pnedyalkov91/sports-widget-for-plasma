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
    property string status: ""
    property string minute: ""
    property string startTime: ""
    property string stadium: ""
    property string homeBadge: ""
    property string awayBadge: ""
    property string poster: ""
    property string matchPath: ""
    property string liveUrl: ""
    property string detailsProvider: ""
    property string espnLeagueSlug: ""
    property string espnEventId: ""
    property bool popular: false
    property bool favorite: false
    property bool selected: false
    property bool expanded: false
    property bool detailsLoading: false
    property bool detailsLoaded: false
    property string detailsError: ""
    property var details: ({})
    property int requestGeneration: 0

    signal clicked()

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
            root.detailsError = i18nc("@info:status", "Detailed live information is not available for this match.");
            return;
        }

        const generation = root.requestGeneration + 1;
        root.requestGeneration = generation;
        root.detailsLoading = true;
        root.detailsError = "";

        SportsApi.fetchLiveMatchDetails({
            "liveUrl": root.liveUrl,
            "matchPath": root.matchPath,
            "detailsProvider": root.detailsProvider,
            "espnLeagueSlug": root.espnLeagueSlug,
            "espnEventId": root.espnEventId,
            "homeTeam": root.homeTeam,
            "awayTeam": root.awayTeam,
            "homeScore": root.homeScore,
            "awayScore": root.awayScore
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

    width: parent ? parent.width : implicitWidth
    height: contentColumn.implicitHeight
    implicitHeight: contentColumn.implicitHeight

    Component.onCompleted: loadDetails(false)
    onExpandedChanged: loadDetails(false)

    Column {
        id: contentColumn

        width: root.width
        spacing: 0

        ScoreDelegate {
            width: parent.width
            sport: root.sport
            league: root.league
            homeTeam: root.homeTeam
            awayTeam: root.awayTeam
            homeScore: root.homeScore
            awayScore: root.awayScore
            status: root.status
            minute: root.minute
            startTime: root.startTime
            stadium: root.stadium
            homeBadge: root.homeBadge
            awayBadge: root.awayBadge
            poster: root.poster
            popular: root.popular
            favorite: root.favorite
            selected: root.selected || root.expanded
            onClicked: root.clicked()
        }

        LiveMatchDetails {
            width: parent.width
            visible: root.expanded
            height: root.expanded ? implicitHeight : 0
            details: root.details
            loading: root.detailsLoading
            errorText: root.detailsError
            homeTeam: root.homeTeam
            awayTeam: root.awayTeam
        }
    }
}
