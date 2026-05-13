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
    property string selectedLeague: String(Plasmoid.configuration.league || "PL").trim() || "PL"
    property string favoriteTeam: String(Plasmoid.configuration.favoriteTeam || "").trim()
    property string providerLabel: providerDisplayName(effectiveProvider())
    property string sourceText: effectiveProvider() === "sportdb" ? i18nc("@info:status", "API key provider") : i18nc("@info:status", "No API key required")
    property string primaryMatchText: scoresModel.count > 0 ? scoresModel.get(0).homeTeam + " vs " + scoresModel.get(0).awayTeam : i18nc("@info:status", "No matches")
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
            "league": root.selectedLeague
        };
        root.pendingRequests = 3;
        root.refreshErrors = [];
        root.pendingRefresh = false;
        root.tableRequestCompleted = false;
        root.currentManualRefresh = manual;
        root.loading = true;
        root.errorMessage = "";
        applyInitialTableState();
        statsModel.clear();
        tableFallbackTimer.restart();
        refreshSportSrcTable(options, manual);
        SportsApi.fetchLiveScores(options, (matches) => {
            applyMatches(matches, i18nc("@info:status", "Updated %1", Qt.formatTime(new Date(), "hh:mm")));
            refreshMatchStats(options);
            finishRefresh(manual, "");
        }, (message) => {
            finishRefresh(manual, message);
        });
        SportsApi.fetchLeagueTable(options, (table) => {
            const alreadyCounted = root.tableRequestCompleted;
            table = Array.isArray(table) ? table : [];
            root.tableRequestCompleted = true;
            tableFallbackTimer.stop();
            if (table.length > 0) {
                applyTable(table);
                root.tableErrorMessage = "";
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
            applyFixtures(fixtures);
            refreshFixtureStats(options);
            finishRefresh(manual, "");
        }, (message) => {
            finishRefresh(manual, message);
        });
    }

    function refreshSportSrcTable(options, manual) {
        const sport = SportVisuals.normalizedSport(options.sports);
        const league = String(options.league || "").trim().toUpperCase();
        if ((sport !== "football" && sport !== "soccer") || league.length === 0)
            return;

        root.tableErrorMessage = i18nc("@info:status", "Loading %1 table from SportSRC...", league);
        SportsApi.fetchLeagueTable(Object.assign({}, options, {
            "provider": "sportsrc",
            "baseUrl": "https://api.sportsrc.org"
        }), (rows) => {
            rows = Array.isArray(rows) ? rows : [];
            if (rows.length === 0) {
                if (tableModel.count === 0)
                    root.tableErrorMessage = i18nc("@info:status", "SportSRC returned no table rows for %1.", league);
                return;
            }

            applyTable(rows);
            root.tableErrorMessage = i18ncp("@info:status", "Loaded %1 table row from SportSRC.", "Loaded %1 table rows from SportSRC.", rows.length);
        }, (message) => {
            if (tableModel.count === 0)
                root.tableErrorMessage = i18nc("@info:status", "SportSRC table request for %1 failed: %2", league, message);
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
        const league = String(root.selectedLeague || "").trim().toUpperCase();
        if ((sport === "football" || sport === "soccer") && league === "PL")
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
        if (root.refreshErrors.length > 0 && effectiveProvider() === "sportsrc" && scoresModel.count === 0 && tableModel.count === 0 && fixturesModel.count === 0) {
            applyMatches(SportsApi.demoMatches(), i18nc("@info:status", "Offline sample data"));
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

    function applyMatches(matches, updateText) {
        scoresModel.clear();
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
        root.errorMessage = matches.length === 0 ? i18nc("@info:status", "No live matches right now.") : "";
        root.lastUpdatedText = updateText;
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

        if (!match || (options.provider === "auto" && match.statsProvider !== "espn"))
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
        if (provider === "auto")
            return "Auto";

        if (ProviderCatalog.isProvider(provider))
            return ProviderCatalog.displayName(provider);

        if (provider === "sportdb")
            return "SportDB.dev";

        if (provider === "espn")
            return "ESPN";

        return "SportSRC";
    }

    function effectiveProvider() {
        const provider = Plasmoid.configuration.provider || "auto";
        const apiKey = String(Plasmoid.configuration.apiKey || "").trim();
        if (provider === "sportdb" && apiKey.length === 0)
            return "auto";

        return provider;
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
        if (provider === "auto")
            return "";

        if (ProviderCatalog.isProvider(provider))
            return ProviderCatalog.defaultBaseUrl(provider);

        if (provider === "sportdb")
            return "https://api.sportdb.dev";

        if (provider === "espn")
            return "https://site.api.espn.com/apis/site/v2/sports";

        return "https://api.sportsrc.org";
    }

    function isKnownProviderUrl(url) {
        const known = ["api.sportsrc.org", "api.sportdb.dev", "site.api.espn.com", "football.api-sports.io", "thesportsdb.com", "api.football-data.org", "sports.highlightly.net", "openligadb.de", "balldontlie.io"];
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
    toolTipSubText: liveCount > 0 ? i18ncp("@info:tooltip", "%1 live match", "%1 live matches", liveCount) : i18nc("@info:tooltip", "No live matches")
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

        interval: Math.max(30, Plasmoid.configuration.refreshInterval) * 1000
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
