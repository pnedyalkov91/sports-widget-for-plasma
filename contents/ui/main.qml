/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../code/SportsApi.js" as SportsApi
import "../code/SportVisuals.js" as SportVisuals
import "../code/providers/ProviderCatalog.js" as ProviderCatalog
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    property bool loading: false
    property string errorMessage: ""
    property string tableErrorMessage: ""
    property string lastUpdatedText: ""
    property int liveCount: scoresModel.count
    property int tableCount: tableModel.count
    property int fixtureCount: fixturesModel.count
    property int statsCount: statsModel.count
    property bool pendingRefresh: false
    property bool tableRequestCompleted: false
    property bool currentManualRefresh: false
    property string selectedCountry: String(Plasmoid.configuration.country || "england").trim() || "england"
    property string selectedLeague: String(Plasmoid.configuration.league || "english-premier-league").trim() || "english-premier-league"
    property string favoriteTeam: String(Plasmoid.configuration.favoriteTeam || "").trim()
    property string providerLabel: providerDisplayName(effectiveProvider())
    property string sourceText: i18nc("@info:status", "No API key required")
    property string primaryMatchText: scoresModel.count > 0 ? scoresModel.get(0).homeTeam + " vs " + scoresModel.get(0).awayTeam : i18nc("@info:status", "No scheduled matches")
    property string secondaryMatchText: scoresModel.count > 0 ? scoresModel.get(0).startTime || scoresModel.get(0).status : sourceText
    property string selectedSport: SportsApi.normalizeSports(Plasmoid.configuration.selectedSports)[0] || "football"
    property string primarySport: scoresModel.count > 0 ? scoresModel.get(0).sport : SportVisuals.normalizedSport(selectedSport)
    property int pendingRequests: 0
    property var refreshErrors: []
    property var tableRows: []

    function refreshScores(manual) {
        if (root.loading) {
            root.pendingRefresh = true;
            return ;
        }

        const options = {
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(),
            "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
            "sports": root.selectedSport,
            "country": root.selectedCountry,
            "league": root.selectedLeague,
            "scoreboardDaysBack": 14,
            "scoreboardDaysForward": 90
        };
        root.pendingRequests = 2;
        root.refreshErrors = [];
        root.pendingRefresh = false;
        root.tableRequestCompleted = false;
        root.currentManualRefresh = manual;
        root.loading = true;
        root.errorMessage = "";
        applyInitialTableState();
        statsModel.clear();
        tableFallbackTimer.restart();
        SportsApi.fetchLeagueTable(options, (table) => {
            const alreadyCounted = root.tableRequestCompleted;
            table = Array.isArray(table) ? table : [];
            root.tableRequestCompleted = true;
            tableFallbackTimer.stop();
            if (table.length > 0) {
                applyTable(table);
                root.tableErrorMessage = "";
                enrichTableForm(options);
            } else if (tableModel.count === 0) {
                applyFallbackTable(i18nc("@info:status", "No table rows returned for %1.", root.selectedLeague));
            } else {
                root.tableErrorMessage = i18nc("@info:status", "Showing cached Premier League table.");
            }

            if (!alreadyCounted)
                finishRefresh(manual, "");
        }, (message) => {
            const alreadyCounted = root.tableRequestCompleted;
            root.tableRequestCompleted = true;
            tableFallbackTimer.stop();
            applyFallbackTable(message);
            if (!alreadyCounted)
                finishRefresh(manual, message);
        });
        SportsApi.fetchScoresFixtures(options, (fixtures) => {
            applySchedules(fixtures, i18nc("@info:status", "Updated %1", Qt.formatTime(new Date(), "hh:mm")));
            applyFixtures(fixtures);
            refreshFixtureStats(options);
            finishRefresh(manual, "");
        }, (message) => {
            applySchedules([], i18nc("@info:status", "Updated %1", Qt.formatTime(new Date(), "hh:mm")));
            finishRefresh(manual, message);
        });
    }

    function enrichTableForm(options) {
        const requestSport = SportVisuals.normalizedSport(options.sports);
        const requestLeague = String(options.league || "").trim().toUpperCase();
        SportsApi.fetchLeagueForm(Object.assign({}, options, {
            "provider": "sportscore",
            "baseUrl": "https://sportscore.com/api/widget",
            "tableRows": root.tableRows
        }), (formByTeam) => {
            if (requestSport !== SportVisuals.normalizedSport(root.selectedSport) || requestLeague !== String(root.selectedLeague || "").trim().toUpperCase())
                return;

            if (Object.keys(formByTeam).length === 0)
                return;

            const rows = root.tableRows.map((row) => {
                const form = SportsApi.formForTeam(formByTeam, row.team);
                if (!form || form.length === 0)
                    return row;

                const copy = Object.assign({}, row);
                copy.form = form;
                return copy;
            });
            applyTable(rows);
        }, () => {
        });
    }

    function applyFallbackTable(message) {
        const rows = fallbackTableRows();
        if (rows.length > 0) {
            if (tableModel.count === 0)
                applyTable(rows);

            root.tableErrorMessage = i18nc("@info:status", "Showing cached Premier League table. %1", message);
        } else {
            root.tableErrorMessage = message;
        }
    }

    function applyInitialTableState() {
        const rows = fallbackTableRows();
        if (rows.length > 0) {
            applyTable(rows);
            root.tableErrorMessage = i18nc("@info:status", "Showing cached Premier League table while updating.");
        } else {
            applyTable([]);
            root.tableErrorMessage = "";
        }
    }

    function fallbackTableRows() {
        const sport = SportVisuals.normalizedSport(root.selectedSport);
        const league = ProviderCatalog.sportScoreSlug(root.selectedLeague);
        if ((sport === "football" || sport === "soccer") && league === "english-premier-league")
            return SportsApi.demoTable();

        return [];
    }

    function finishRefresh(manual, message) {
        if (message && message.length > 0)
            root.refreshErrors = root.refreshErrors.concat([message]);

        root.pendingRequests -= 1;
        if (root.pendingRequests > 0)
            return ;

        root.loading = false;
        if (root.refreshErrors.length > 0 && scoresModel.count === 0 && tableModel.count === 0 && fixturesModel.count === 0) {
            applySchedules(SportsApi.demoFixtures(), i18nc("@info:status", "Offline sample data"));
            applyTable(SportsApi.demoTable());
            applyFixtures(SportsApi.demoFixtures());
            root.errorMessage = manual ? root.refreshErrors.join(", ") : "";
        } else {
            root.errorMessage = manual && root.refreshErrors.length > 0 ? root.refreshErrors.join(", ") : "";
        }

        if (root.pendingRefresh) {
            root.pendingRefresh = false;
            configRefreshTimer.restart();
        }
    }

    function applySchedules(matches, updateText) {
        scoresModel.clear();
        matches = scheduledMatches(matches);
        matches = prioritizeFavorite(matches);
        if (Plasmoid.configuration.prioritizePopular) {
            matches = matches.slice().sort((left, right) => {
                return Number(Boolean(right.popular)) - Number(Boolean(left.popular));
            });
            matches = prioritizeFavorite(matches);
        }
        matches.forEach((match) => {
            return scoresModel.append(match);
        });
        root.errorMessage = matches.length === 0 ? i18nc("@info:status", "No scheduled matches for the selected league.") : "";
        root.lastUpdatedText = updateText;
    }

    function scheduledMatches(matches) {
        const now = Date.now();
        return (Array.isArray(matches) ? matches : []).filter((match) => {
            const status = String(match.status || "").toLowerCase();
            const timestamp = Number(match.timestamp || 0);
            if (status.indexOf("finished") >= 0 || status.indexOf("final") >= 0)
                return false;

            if (status.indexOf("upcoming") >= 0 || status.indexOf("scheduled") >= 0 || status.indexOf("not started") >= 0 || status.indexOf("postponed") >= 0)
                return true;

            if (timestamp > 0)
                return timestamp >= now - 3 * 60 * 60 * 1000;

            return String(match.homeScore || "").length === 0 && String(match.awayScore || "").length === 0;
        }).sort((left, right) => {
            const leftTime = Number(left.timestamp || 0);
            const rightTime = Number(right.timestamp || 0);
            if (leftTime > 0 && rightTime > 0 && leftTime !== rightTime)
                return leftTime - rightTime;

            if (leftTime > 0 && rightTime === 0)
                return -1;

            if (rightTime > 0 && leftTime === 0)
                return 1;

            return String(left.homeTeam || "").localeCompare(String(right.homeTeam || ""));
        });
    }

    function applyTable(rows) {
        root.tableRows = rows.slice();
        tableModel.clear();
        rows.forEach((row) => {
            return tableModel.append(row);
        });
    }

    function applyFixtures(matches) {
        fixturesModel.clear();
        matches = prioritizeFavorite(matches);
        matches.forEach((match) => {
            return fixturesModel.append(match);
        });
    }

    function refreshMatchStats(options) {
        statsModel.clear();
        refreshStatsFromModel(scoresModel, options, true);
    }

    function refreshFixtureStats(options) {
        if (statsModel.count > 0)
            return ;

        refreshStatsFromModel(fixturesModel, options, false);
    }

    function refreshStatsFromModel(model, options, clearWhenEmpty) {
        if (!model || model.count === 0)
            return ;

        const match = statsCandidateMatch(model);
        const embeddedStats = match && match.statsRows ? match.statsRows : [];
        if (embeddedStats && embeddedStats.length > 0) {
            applyStats(embeddedStats);
            return ;
        }

        if (!match || match.statsProvider !== "sportscore")
            return ;

        const matchId = String(match.id || "").trim();
        if (matchId.length === 0)
            return ;

        const statsOptions = Object.assign({
        }, options, {
            "sports": match.sport || options.sports,
            "matchId": matchId
        });
        SportsApi.fetchMatchStats(statsOptions, (rows) => {
            if (rows.length > 0 || (clearWhenEmpty && statsModel.count === 0))
                applyStats(rows);
        }, () => {
            if (clearWhenEmpty && statsModel.count === 0)
                applyStats([]);
        });
    }

    function statsCandidateMatch(model) {
        let fallback = null;
        for (let index = 0; index < model.count; index += 1) {
            const match = model.get(index);
            if (match.statsRows && match.statsRows.length > 0)
                return match;

            if (!fallback && match.id && match.status !== "Upcoming")
                fallback = match;

        }
        return fallback || model.get(0);
    }

    function applyStats(rows) {
        statsModel.clear();
        rows.forEach((row) => {
            return statsModel.append(row);
        });
    }

    function prioritizeFavorite(items) {
        if (root.favoriteTeam.length === 0)
            return items;

        return items.slice().sort((left, right) => {
            return Number(isFavoriteMatch(right)) - Number(isFavoriteMatch(left));
        });
    }

    function isFavoriteMatch(match) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(match.homeTeam || "").toLowerCase().indexOf(favorite) >= 0 || String(match.awayTeam || "").toLowerCase().indexOf(favorite) >= 0 || String(match.team || "").toLowerCase().indexOf(favorite) >= 0;
    }

    function providerDisplayName(provider) {
        return ProviderCatalog.displayName("sportscore");
    }

    function effectiveProvider() {
        return "sportscore";
    }

    function effectiveBaseUrl() {
        const provider = effectiveProvider();
        const configured = String(Plasmoid.configuration.apiBaseUrl || "").trim();
        const defaultUrl = providerDefaultBaseUrl(provider);
        if (configured.length === 0 || (isKnownProviderUrl(configured) && configured.indexOf(defaultUrl) < 0))
            return defaultUrl;

        return configured;
    }

    function providerDefaultBaseUrl(provider) {
        return ProviderCatalog.defaultBaseUrl("sportscore");
    }

    function isKnownProviderUrl(url) {
        const known = ["sportscore.com"];
        for (let index = 0; index < known.length; index += 1) {
            if (url.indexOf(known[index]) >= 0)
                return true;

        }
        return false;
    }

    function scheduleConfigRefresh() {
        configRefreshTimer.restart();
    }

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    Plasmoid.icon: "applications-games"
    Plasmoid.title: i18n("Sports Widget for Plasma")
    toolTipMainText: Plasmoid.title
    toolTipSubText: liveCount > 0 ? i18ncp("@info:tooltip", "%1 scheduled match", "%1 scheduled matches", liveCount) : i18nc("@info:tooltip", "No scheduled matches")
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    Component.onCompleted: refreshScores(false)
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action", "Refresh")
            icon.name: "view-refresh"
            onTriggered: root.refreshScores(true)
        }
    ]

    ListModel {
        id: scoresModel
    }

    ListModel {
        id: tableModel
    }

    ListModel {
        id: fixturesModel
    }

    ListModel {
        id: statsModel
    }

    Timer {
        id: refreshTimer

        interval: Math.max(1, Plasmoid.configuration.refreshInterval) * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refreshScores(false)
    }

    Timer {
        id: tableFallbackTimer

        interval: 15000
        repeat: false
        onTriggered: {
            if (root.tableRequestCompleted)
                return ;

            root.tableRequestCompleted = true;
            applyFallbackTable(i18nc("@info:status", "Table request timed out."));
            finishRefresh(root.currentManualRefresh, i18nc("@info:status", "Table request timed out."));
        }
    }

    Timer {
        id: configRefreshTimer

        interval: 250
        repeat: false
        onTriggered: root.refreshScores(true)
    }

    Connections {
        target: Plasmoid.configuration
        ignoreUnknownSignals: true

        function onApiBaseUrlChanged() {
            root.scheduleConfigRefresh();
        }

        function onApiKeyChanged() {
            root.scheduleConfigRefresh();
        }

        function onFavoriteTeamChanged() {
            root.scheduleConfigRefresh();
        }

        function onCountryChanged() {
            root.scheduleConfigRefresh();
        }

        function onLeagueChanged() {
            root.scheduleConfigRefresh();
        }

        function onPrioritizePopularChanged() {
            root.scheduleConfigRefresh();
        }

        function onProviderChanged() {
            root.scheduleConfigRefresh();
        }

        function onRefreshIntervalChanged() {
            root.scheduleConfigRefresh();
        }

        function onSelectedSportsChanged() {
            root.scheduleConfigRefresh();
        }

    }

    compactRepresentation: CompactRepresentation {
        liveCount: root.liveCount
        loading: root.loading
        layoutMode: Plasmoid.configuration.panelLayoutMode
        primaryText: root.primaryMatchText
        secondaryText: root.secondaryMatchText
        sport: root.primarySport
    }

    fullRepresentation: FullRepresentation {
        scoreModel: scoresModel
        loading: root.loading
        errorMessage: root.errorMessage
        tableErrorMessage: root.tableErrorMessage
        lastUpdatedText: root.lastUpdatedText
        providerLabel: root.providerLabel
        sourceText: root.sourceText
        primaryText: root.primaryMatchText
        secondaryText: root.secondaryMatchText
        sportCount: 1
        sport: root.primarySport
        tableModel: tableModel
        tableRows: root.tableRows
        fixturesModel: fixturesModel
        league: root.selectedLeague
        tableCount: root.tableCount
        fixtureCount: root.fixtureCount
        statsModel: statsModel
        statsCount: root.statsCount
        widgetTabs: Plasmoid.configuration.widgetTabs
        favoriteTeam: root.favoriteTeam
        onRefreshRequested: root.refreshScores(true)
        onConfigureRequested: Plasmoid.action("configure").trigger()
    }

}
