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
    property int liveCount: liveMatchesModel.count
    property int scheduleCount: scoresModel.count
    property int tableCount: tableModel.count
    property int fixtureCount: fixturesModel.count
    property int statsCount: statsModel.count
    property bool pendingRefresh: false
    property bool tableRequestCompleted: false
    property bool currentManualRefresh: false
    property bool schedulesLoading: false
    property var savedLeagueEntries: savedLeagues()
    property int savedLeagueCount: savedLeagueEntries.length
    property int activeSavedLeagueIndex: normalizedActiveSavedLeagueIndex()
    property var activeLeagueEntry: activeSavedLeague()
    property string selectedCountry: String(activeLeagueEntry.country || "").trim()
    property string selectedLeague: String(activeLeagueEntry.league || "").trim()
    property string favoriteTeam: String(activeLeagueEntry.favoriteTeam || "").trim()
    property string providerLabel: providerDisplayName(effectiveProvider())
    property string sourceText: i18nc("@info:status", "No API key required")
    property string primaryMatchText: liveMatchesModel.count > 0 ? liveMatchesModel.get(0).homeTeam + " vs " + liveMatchesModel.get(0).awayTeam : scoresModel.count > 0 ? scoresModel.get(0).homeTeam + " vs " + scoresModel.get(0).awayTeam : root.hasSportSelection() ? i18nc("@info:status", "No scheduled matches") : i18nc("@action:button", "Add a sport")
    property string secondaryMatchText: liveMatchesModel.count > 0 ? liveMatchesModel.get(0).minute || liveMatchesModel.get(0).status : scoresModel.count > 0 ? scoresModel.get(0).startTime || scoresModel.get(0).status : root.hasSportSelection() ? sourceText : i18nc("@info:status", "Open settings to add a league")
    property string selectedSport: String(activeLeagueEntry.sport || "").trim()
    property string selectedLeagueLabel: displayLeagueLabel(activeLeagueEntry)
    property string selectedCountryLabel: displayCountryLabel(activeLeagueEntry)
    property string primarySport: liveMatchesModel.count > 0 ? liveMatchesModel.get(0).sport : scoresModel.count > 0 ? scoresModel.get(0).sport : SportVisuals.normalizedSport(selectedSport)
    property int pendingRequests: 0
    property var refreshErrors: []
    property var tableRows: []
    property var latestScheduleMatches: []
    property string pendingScheduleMessage: ""

    function hasSportSelection() {
        return root.savedLeagueCount > 0 && root.selectedSport.length > 0 && root.selectedLeague.length > 0;
    }

    function savedLeagues() {
        try {
            const parsed = JSON.parse(Plasmoid.configuration.savedLeagues || "[]");
            return Array.isArray(parsed) ? parsed : [];
        } catch (error) {
            return [];
        }
    }

    function normalizedActiveSavedLeagueIndex() {
        const count = root.savedLeagueEntries.length;
        if (count === 0)
            return -1;

        const configured = Number(Plasmoid.configuration.activeSavedLeagueIndex || 0);
        const index = Number.isFinite(configured) ? Math.round(configured) : 0;
        return Math.max(0, Math.min(count - 1, index));
    }

    function activeSavedLeague() {
        if (root.savedLeagueEntries.length === 0)
            return {};

        return root.savedLeagueEntries[root.activeSavedLeagueIndex] || root.savedLeagueEntries[0] || {};
    }

    function displayLeagueLabel(entry) {
        entry = entry || {};
        return String(entry.customLeagueLabel || entry.leagueLabel || ProviderCatalog.leagueLabel(entry.league) || entry.league || "").trim();
    }

    function displayCountryLabel(entry) {
        entry = entry || {};
        return String(entry.customCountryLabel || entry.countryLabel || entry.country || "").trim();
    }

    function displayFavoriteTeam(entry) {
        entry = entry || {};
        return String(entry.customFavoriteTeamLabel || entry.favoriteTeam || "").trim();
    }

    function setActiveSavedLeagueIndex(index) {
        const count = root.savedLeagueEntries.length;
        if (count === 0)
            return;

        const nextIndex = ((index % count) + count) % count;
        if (nextIndex === root.activeSavedLeagueIndex)
            return;

        Plasmoid.configuration.activeSavedLeagueIndex = nextIndex;
    }

    function openSportSettings() {
        const action = Plasmoid.internalAction("configure") || Plasmoid.action("configure");
        if (action)
            action.trigger();
    }

    function migrateDefaultSelection() {
        if (Plasmoid.configuration.defaultSelectionMigrated)
            return;

        const sports = String(Plasmoid.configuration.selectedSports || "").trim();
        const country = String(Plasmoid.configuration.country || "").trim();
        const league = String(Plasmoid.configuration.league || "").trim();
        const favorite = String(Plasmoid.configuration.favoriteTeam || "").trim();
        const saved = String(Plasmoid.configuration.savedLeagues || "[]").trim();
        if (sports === "football" && country === "england" && league === "english-premier-league" && favorite.length === 0 && (saved.length === 0 || saved === "[]")) {
            Plasmoid.configuration.selectedSports = "";
            Plasmoid.configuration.country = "";
            Plasmoid.configuration.league = "";
        }
        Plasmoid.configuration.defaultSelectionMigrated = true;
    }

    function refreshScores(manual) {
        if (!root.hasSportSelection()) {
            refreshTimer.stop();
            configRefreshTimer.stop();
            emptySchedulesTimer.stop();
            tableFallbackTimer.stop();
            liveMatchesModel.clear();
            scoresModel.clear();
            tableModel.clear();
            fixturesModel.clear();
            statsModel.clear();
            root.tableRows = [];
            root.latestScheduleMatches = [];
            root.loading = false;
            root.schedulesLoading = false;
            root.pendingRefresh = false;
            root.pendingRequests = 0;
            root.tableRequestCompleted = true;
            root.errorMessage = i18nc("@info:status", "Add a sport in the widget settings.");
            root.tableErrorMessage = "";
            root.lastUpdatedText = "";
            return;
        }

        if (!refreshTimer.running)
            refreshTimer.start();

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
        root.pendingRequests = 3;
        root.refreshErrors = [];
        root.pendingRefresh = false;
        root.tableRequestCompleted = false;
        root.currentManualRefresh = manual;
        root.loading = true;
        root.schedulesLoading = true;
        root.pendingScheduleMessage = "";
        emptySchedulesTimer.stop();
        root.errorMessage = "";
        applyTable([]);
        root.tableErrorMessage = "";
        root.latestScheduleMatches = [];
        statsModel.clear();
        tableFallbackTimer.restart();
        SportsApi.fetchLiveScores(options, (matches) => {
            applyLiveMatches(matches);
            refreshMatchStats(options);
            finishRefresh(manual, "");
        }, (message) => {
            applyLiveMatches([]);
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
                enrichTableForm(options);
                refreshSchedulesFromTable(options);
            } else {
                applyTable([]);
                root.tableErrorMessage = i18nc("@info:status", "No table rows returned for %1.", root.selectedLeagueLabel || root.selectedLeague);
            }

            if (!alreadyCounted)
                finishRefresh(manual, "");
        }, (message) => {
            const alreadyCounted = root.tableRequestCompleted;
            root.tableRequestCompleted = true;
            tableFallbackTimer.stop();
            applyTable([]);
            root.tableErrorMessage = message;
            if (!alreadyCounted)
                finishRefresh(manual, message);
        });
        SportsApi.fetchScoresFixtures(options, (fixtures) => {
            const scheduledCount = applySchedules(fixtures, i18nc("@info:status", "Updated %1", Qt.formatTime(new Date(), "hh:mm")));
            if (scheduledCount > 0) {
                emptySchedulesTimer.stop();
                root.schedulesLoading = false;
            } else if (root.tableRequestCompleted && root.tableRows.length === 0) {
                deferEmptySchedulesMessage("");
            }

            applyFixtures(fixtures);
            refreshFixtureStats(options);
            finishRefresh(manual, "");
        }, (message) => {
            applySchedules([], i18nc("@info:status", "Updated %1", Qt.formatTime(new Date(), "hh:mm")));
            if (root.tableRequestCompleted && root.tableRows.length === 0)
                deferEmptySchedulesMessage(message);

            finishRefresh(manual, message);
        });
    }

    function refreshSchedulesFromTable(options) {
        if (root.tableRows.length === 0) {
            deferEmptySchedulesMessage("");

            return;
        }

        root.schedulesLoading = true;
        emptySchedulesTimer.stop();

        SportsApi.fetchScoresFixtures(Object.assign({}, options, {
            "tableRows": root.tableRows
        }), (fixtures) => {
            const scheduledCount = applySchedules(fixtures, i18nc("@info:status", "Updated %1", Qt.formatTime(new Date(), "hh:mm")));
            if (scheduledCount > 0) {
                emptySchedulesTimer.stop();
                root.schedulesLoading = false;
            } else {
                deferEmptySchedulesMessage("");
            }

            applyFixtures(fixtures);
            refreshFixtureStats(options);
        }, (message) => {
            deferEmptySchedulesMessage(message);
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

    function finishRefresh(manual, message) {
        if (message && message.length > 0)
            root.refreshErrors = root.refreshErrors.concat([message]);

        root.pendingRequests -= 1;
        if (root.pendingRequests > 0)
            return ;

        promoteLiveMatches(root.latestScheduleMatches);
        root.loading = false;
        if (root.refreshErrors.length > 0 && liveMatchesModel.count === 0 && scoresModel.count === 0 && tableModel.count === 0 && fixturesModel.count === 0) {
            emptySchedulesTimer.stop();
            root.schedulesLoading = false;
            root.errorMessage = manual ? root.refreshErrors.join(", ") : "";
        } else {
            if (root.schedulesLoading && root.tableRequestCompleted && root.tableRows.length === 0)
                deferEmptySchedulesMessage("");

            if (!root.schedulesLoading && scoresModel.count === 0 && root.errorMessage.length === 0)
                deferEmptySchedulesMessage("");

            if (manual && root.refreshErrors.length > 0)
                root.errorMessage = root.refreshErrors.join(", ");
        }

        if (root.pendingRefresh) {
            root.pendingRefresh = false;
            configRefreshTimer.restart();
        }
    }

    function applySchedules(matches, updateText) {
        scoresModel.clear();
        root.latestScheduleMatches = Array.isArray(matches) ? matches.slice() : [];
        promoteLiveMatches(root.latestScheduleMatches);
        matches = scheduledMatches(root.latestScheduleMatches);
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
        if (matches.length > 0) {
            root.errorMessage = "";
        } else if (!root.schedulesLoading) {
            root.errorMessage = i18nc("@info:status", "No scheduled matches for the selected league.");
        }

        root.lastUpdatedText = updateText;
        return matches.length;
    }

    function applyLiveMatches(matches) {
        liveMatchesModel.clear();
        matches = prioritizeFavorite(Array.isArray(matches) ? matches : []);
        matches.forEach((match) => {
            return liveMatchesModel.append(match);
        });
        return matches.length;
    }

    function promoteLiveMatches(matches) {
        if (liveMatchesModel.count > 0)
            return 0;

        const liveMatches = (Array.isArray(matches) ? matches : []).filter((match) => {
            return SportsApi.isLiveMatch(match);
        }).map((match) => liveMatchForModel(match));
        if (liveMatches.length === 0)
            return 0;

        return applyLiveMatches(liveMatches);
    }

    function liveMatchForModel(match) {
        const copy = Object.assign({}, match);
        const status = String(copy.status || "").trim();
        const lowerStatus = status.toLowerCase();
        if (String(copy.minute || "").length === 0 && (lowerStatus === "ht" || lowerStatus === "1h" || lowerStatus === "2h" || /^\d+\+?$/.test(status)))
            copy.minute = status;

        copy.status = "Live";
        return copy;
    }

    function deferEmptySchedulesMessage(message) {
        if (scoresModel.count > 0)
            return;

        root.pendingScheduleMessage = message && message.length > 0 ? message : i18nc("@info:status", "No scheduled matches for the selected league.");
        root.schedulesLoading = true;
        root.errorMessage = "";
        emptySchedulesTimer.restart();
    }

    function scheduledMatches(matches) {
        const now = Date.now();
        return (Array.isArray(matches) ? matches : []).filter((match) => {
            const status = String(match.status || "").toLowerCase();
            const timestamp = Number(match.timestamp || 0);
            if (SportsApi.isLiveMatch(match))
                return false;

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
        refreshStatsFromModel(liveMatchesModel, options, true);
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
    toolTipSubText: !root.hasSportSelection() ? i18nc("@info:tooltip", "Add a sport") : liveCount > 0 ? i18ncp("@info:tooltip", "%1 live match", "%1 live matches", liveCount) : scheduleCount > 0 ? i18ncp("@info:tooltip", "%1 scheduled match", "%1 scheduled matches", scheduleCount) : i18nc("@info:tooltip", "No scheduled matches")
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    Component.onCompleted: {
        migrateDefaultSelection();
        refreshScores(false);
    }
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18nc("@action", "Refresh")
            icon.name: "view-refresh"
            enabled: root.hasSportSelection()
            onTriggered: root.refreshScores(true)
        }
    ]

    ListModel {
        id: liveMatchesModel
    }

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
            applyTable([]);
            root.tableErrorMessage = i18nc("@info:status", "Table request timed out.");
            finishRefresh(root.currentManualRefresh, i18nc("@info:status", "Table request timed out."));
        }
    }

    Timer {
        id: configRefreshTimer

        interval: 250
        repeat: false
        onTriggered: root.refreshScores(true)
    }

    Timer {
        id: emptySchedulesTimer

        interval: 2500
        repeat: false
        onTriggered: {
            root.schedulesLoading = false;
            if (scoresModel.count === 0)
                root.errorMessage = root.pendingScheduleMessage.length > 0 ? root.pendingScheduleMessage : i18nc("@info:status", "No scheduled matches for the selected league.");

            root.pendingScheduleMessage = "";
        }
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

        function onSavedLeaguesChanged() {
            root.scheduleConfigRefresh();
        }

        function onActiveSavedLeagueIndexChanged() {
            root.scheduleConfigRefresh();
        }

    }

    compactRepresentation: CompactRepresentation {
        liveCount: root.liveCount
        loading: root.loading || root.schedulesLoading
        layoutMode: Plasmoid.configuration.panelLayoutMode
        primaryText: root.primaryMatchText
        secondaryText: root.secondaryMatchText
        sport: root.primarySport
    }

    fullRepresentation: FullRepresentation {
        liveModel: liveMatchesModel
        scoreModel: scoresModel
        loading: root.loading
        schedulesLoading: root.schedulesLoading
        errorMessage: root.errorMessage
        tableErrorMessage: root.tableErrorMessage
        lastUpdatedText: root.lastUpdatedText
        providerLabel: root.providerLabel
        sourceText: root.sourceText
        primaryText: root.primaryMatchText
        secondaryText: root.secondaryMatchText
        sportCount: 1
        sport: root.primarySport
        hasSavedLeagues: root.savedLeagueCount > 0
        savedLeagues: root.savedLeagueEntries
        savedLeagueCount: root.savedLeagueCount
        activeSavedLeagueIndex: root.activeSavedLeagueIndex
        activeLeagueLabel: root.selectedLeagueLabel
        activeCountryLabel: root.selectedCountryLabel
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
        onConfigureRequested: root.openSportSettings()
        onLeagueSelected: (index) => root.setActiveSavedLeagueIndex(index)
    }

}
