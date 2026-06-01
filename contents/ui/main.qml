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
    property int recentResultsCount: recentResultsListModel.count
    property bool tableRequestCompleted: false
    property bool currentManualRefresh: false
    property bool liveLoading: false
    property bool schedulesLoading: false
    property bool recentResultsLoading: false
    property bool liveRefreshInFlight: false
    property bool scheduleRequestCompleted: false
    property bool tableScheduleFallbackStarted: false
    property bool recentResultsTableFallbackStarted: false
    property int refreshToken: 0
    property int liveRefreshToken: 0
    property var savedLeagueEntries: savedLeagues()
    property int savedLeagueCount: savedLeagueEntries.length
    property int activeSavedLeagueIndex: normalizedActiveSavedLeagueIndex()
    property var activeLeagueEntry: activeSavedLeague()
    property var primaryLeagueEntry: firstCompetitionEntry()
    property string selectedCountry: String(primaryLeagueEntry.country || String(activeLeagueEntry.country || "")).trim()
    property string selectedLeague: String(primaryLeagueEntry.league || String(activeLeagueEntry.league || "")).trim()
    property string favoriteTeam: String(activeLeagueEntry.favoriteTeam || "").trim()
    property string followMode: normalizedFollowMode(activeLeagueEntry)
    property bool followTeamMode: followMode === "team"
    property string providerLabel: providerDisplayName(effectiveProvider())
    property string sourceText: i18nc("@info:status", "No API key required")
    property string primaryMatchText: liveMatchesModel.count > 0 ? liveMatchesModel.get(0).homeTeam + " vs " + liveMatchesModel.get(0).awayTeam : scoresModel.count > 0 ? scoresModel.get(0).homeTeam + " vs " + scoresModel.get(0).awayTeam : root.hasSportSelection() ? i18nc("@info:status", "No scheduled matches") : i18nc("@action:button", "Add a sport")
    property string secondaryMatchText: liveMatchesModel.count > 0 ? liveMatchesModel.get(0).minute || liveMatchesModel.get(0).status : scoresModel.count > 0 ? scoresModel.get(0).startTime || scoresModel.get(0).status : root.hasSportSelection() ? sourceText : i18nc("@info:status", "Open settings to add a league")
    property string panelHeroText: liveMatchesModel.count > 0 ? panelTeamsScoreText(liveMatchesModel.get(0)) : scoresModel.count > 0 ? panelScheduleText(scoresModel.get(0)) : root.hasSportSelection() ? i18nc("@info:status", "No scheduled matches") : i18nc("@action:button", "Add a sport")
    property string panelHeroLiveText: liveMatchesModel.count > 0 ? panelLiveText(liveMatchesModel.get(0)) : ""
    property bool panelHeroLive: liveMatchesModel.count > 0
    property var panelHeroMatch: liveMatchesModel.count > 0 ? liveMatchesModel.get(0) : scoresModel.count > 0 ? scoresModel.get(0) : ({})
    property bool panelHeroShowScore: matchBooleanField(panelHeroMatch, "showScore", liveMatchesModel.count > 0)
    property string panelHeroStatusText: matchStatusText(panelHeroMatch)
    property string panelHeroHomeTeam: matchField(panelHeroMatch, "homeTeam")
    property string panelHeroAwayTeam: matchField(panelHeroMatch, "awayTeam")
    property string panelHeroHomeScore: matchField(panelHeroMatch, "homeScore")
    property string panelHeroAwayScore: matchField(panelHeroMatch, "awayScore")
    property string panelHeroHomeBadge: matchField(panelHeroMatch, "homeBadge")
    property string panelHeroAwayBadge: matchField(panelHeroMatch, "awayBadge")
    property string panelHeroStadium: matchField(panelHeroMatch, "stadium")
    property string selectedSport: String(primaryLeagueEntry.sport || String(activeLeagueEntry.sport || "")).trim()
    property string selectedLeagueLabel: displayLeagueLabel(activeLeagueEntry)
    property string selectedCountryLabel: displayCountryLabel(activeLeagueEntry)
    property string activeDisplayLabel: activeTitleLabel()
    property string activeDisplayCountryLabel: activeSubtitleLabel()
    property string activeClubBadge: activeHeaderBadge()
    property string primarySport: liveMatchesModel.count > 0 ? liveMatchesModel.get(0).sport : scoresModel.count > 0 ? scoresModel.get(0).sport : SportVisuals.normalizedSport(selectedSport)
    property int pendingRequests: 0
    property var refreshErrors: []
    property var tableRows: []
    property var primaryTableRows: []
    property var latestLiveMatches: []
    property var latestScheduleMatches: []
    property var latestRecentMatches: []
    property var discoveredTeamCompetitions: []
    property var teamTableOptions: []
    property string selectedTeamTableSlug: ""
    property var teamTableSeasonOptions: []
    property string selectedTeamTableSeasonKey: ""
    property bool teamTableLoading: false
    property bool teamTableSeasonLoading: false
    property bool teamTableFormLoading: false
    property bool pendingSeasonTableRefresh: false
    property int teamTableRequestToken: 0
    property int teamTableSeasonRequestToken: 0
    property int teamTableFormRequestToken: 0
    property string teamTableSeasonScopeKey: ""
    property string pendingScheduleMessage: ""
    readonly property string panelAreaMode: normalizedPanelAreaMode()
    readonly property int panelAreaSize: Math.max(20, Number(Plasmoid.configuration.panelAreaSize || 240))
    readonly property bool panelAreaFill: panelAreaMode === "fill"
    readonly property int compactPanelWidth: panelAreaMode === "manual" ? panelAreaSize : compactRepresentation ? Math.ceil(compactRepresentation.implicitWidth) : Kirigami.Units.gridUnit * 9

    function normalizedPanelAreaMode() {
        const mode = String(Plasmoid.configuration.panelAreaMode || "auto").trim();
        if (mode === "fill" || mode === "manual")
            return mode;

        return "auto";
    }

    function hasSportSelection() {
        if (root.savedLeagueCount === 0)
            return false;

        return root.liveScopeEntries().length > 0
            || root.scheduleScopeEntries().length > 0
            || root.recentScopeEntries().length > 0
            || root.tableScopeEntries().length > 0;
    }

    function matchField(match, field) {
        if (!match || match[field] === undefined || match[field] === null)
            return "";

        return String(match[field]).trim();
    }

    function matchBooleanField(match, field, fallback) {
        if (!match || match[field] === undefined || match[field] === null)
            return Boolean(fallback);

        if (typeof match[field] === "boolean")
            return match[field];

        const value = String(match[field]).trim().toLowerCase();
        return value === "true" || value === "1" || value === "yes";
    }

    function savedLeagues() {
        try {
            const parsed = JSON.parse(Plasmoid.configuration.savedLeagues || "[]");
            return Array.isArray(parsed) ? parsed.map(entry => root.normalizedSavedEntry(entry)) : [];
        } catch (error) {
            return [];
        }
    }

    function normalizedSavedEntry(entry) {
        const copy = Object.assign({}, entry || {});
        copy.type = root.entryType(copy);
        copy.followMode = copy.type === "team" ? "team" : "league";
        copy.includeLive = copy.includeLive !== false;
        copy.includeSchedules = copy.includeSchedules !== false;
        copy.includeRecent = copy.includeRecent !== false;
        copy.includeTables = copy.includeTables !== false;
        if (copy.type === "team") {
            copy.favoriteTeam = root.stripLegacyTeamPrefix(copy.customFavoriteTeamLabel || copy.favoriteTeam || copy.customLeagueLabel || copy.leagueLabel || copy.league || "");
            copy.league = "";
            copy.leagueLabel = i18nc("@label", "All competitions");
        } else {
            copy.favoriteTeam = String(copy.favoriteTeam || "").trim();
        }

        delete copy.starred;
        return copy;
    }

    function firstCompetitionEntry() {
        const entries = root.savedLeagueEntries;
        for (let index = 0; index < entries.length; index += 1) {
            const entry = entries[index] || {};
            if (root.entryType(entry) === "competition" && String(entry.league || "").trim().length > 0)
                return entry;
        }

        return root.activeLeagueEntry || {};
    }

    function hasEntryTarget(entry) {
        if (root.entryType(entry) === "team")
            return String(entry && entry.favoriteTeam || "").trim().length > 0;

        return String(entry && entry.league || "").trim().length > 0;
    }

    function scopeEntries(flagName) {
        return root.savedLeagueEntries.filter((entry) => {
            if (!root.hasEntryTarget(entry))
                return false;

            return entry && entry[flagName] !== false;
        });
    }

    function liveScopeEntries() {
        return root.scopeEntries("includeLive");
    }

    function scheduleScopeEntries() {
        return root.scopeEntries("includeSchedules");
    }

    function recentScopeEntries() {
        return root.scopeEntries("includeRecent");
    }

    function tableScopeEntries() {
        return root.scopeEntries("includeTables");
    }

    function optionValues(options) {
        return (Array.isArray(options) ? options : []).map(option => String(option && option.value || "").trim().toLowerCase()).filter(value => value.length > 0);
    }

    function knownLeagueValues(sport, country) {
        return root.optionValues(ProviderCatalog.leagueOptions("sportscore", String(sport || "football").trim(), String(country || "").trim()));
    }

    function knownCountryTeamValues(sport, country) {
        return root.optionValues(ProviderCatalog.countryTeamOptions("sportscore", String(sport || "football").trim(), String(country || "").trim()));
    }

    function isLikelyLegacyTeamEntry(entry) {
        entry = entry || {};
        const league = String(entry.league || "").trim().toLowerCase();
        const favoriteTeam = String(entry.favoriteTeam || "").trim();
        const followMode = String(entry.followMode || "").trim();
        if (league.length === 0 || favoriteTeam.length > 0 || followMode === "team")
            return false;

        const leagues = root.knownLeagueValues(entry.sport, entry.country);
        if (leagues.indexOf(league) >= 0)
            return false;

        const teams = root.knownCountryTeamValues(entry.sport, entry.country);
        return teams.indexOf(league) >= 0;
    }

    function saveSavedLeagues(items) {
        const normalizedItems = Array.isArray(items) ? items.map(entry => root.normalizedSavedEntry(entry)) : [];
        Plasmoid.configuration.savedLeagues = JSON.stringify(normalizedItems);
        Plasmoid.configuration.selectionRevision = Number(Plasmoid.configuration.selectionRevision || 0) + 1;
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

    function teamWatchMode() {
        return root.watchedTeamEntries().length > 0;
    }

    function watchedTeamEntries() {
        const teams = root.savedLeagueEntries.filter((entry) => {
            return root.entryType(entry) === "team" && String(entry.favoriteTeam || "").trim().length > 0;
        });
        if (teams.length > 0)
            return teams;

        return root.favoriteTeam.length > 0 && root.entryType(root.activeLeagueEntry) === "team" ? [root.activeLeagueEntry] : [];
    }

    function watchedTeamNames() {
        let seen = {};
        let names = [];
        root.watchedTeamEntries().forEach(entry => {
            const name = String(entry && entry.favoriteTeam || "").trim();
            const key = name.toLowerCase();
            if (key.length === 0 || seen[key])
                return;

            seen[key] = true;
            names.push(name);
        });
        return names;
    }

    function watchedTeamDisplayNames() {
        let seen = {};
        let names = [];
        root.watchedTeamEntries().forEach(entry => {
            const name = root.displayFavoriteTeam(entry);
            const key = String(entry && entry.favoriteTeam || name).trim().toLowerCase();
            if (name.length === 0 || seen[key])
                return;

            seen[key] = true;
            names.push(name);
        });
        return names;
    }

    function watchedTeamPriorityMap() {
        let order = {};
        const names = root.watchedTeamNames();
        for (let index = 0; index < names.length; index += 1)
            order[names[index].toLowerCase()] = index;

        return order;
    }

    function watchedTeamPriorityForName(teamName) {
        const names = root.watchedTeamNames();
        if (names.length === 0)
            return Number.MAX_SAFE_INTEGER;

        const normalizedTeam = String(teamName || "").trim();
        if (normalizedTeam.length === 0)
            return Number.MAX_SAFE_INTEGER;

        for (let index = 0; index < names.length; index += 1) {
            const favorite = names[index];
            if (SportsApi.sameTeamName(normalizedTeam, favorite) || normalizedTeam.toLowerCase().indexOf(favorite.toLowerCase()) >= 0)
                return index;
        }

        return Number.MAX_SAFE_INTEGER;
    }

    function watchedTeamPriorityForMatch(match) {
        if (!match)
            return Number.MAX_SAFE_INTEGER;

        return Math.min(root.watchedTeamPriorityForName(match.homeTeam), root.watchedTeamPriorityForName(match.awayTeam), root.watchedTeamPriorityForName(match.team));
    }

    function effectiveFavoriteTeamName() {
        const names = root.watchedTeamNames();
        return names.length > 0 ? names[0] : root.favoriteTeam;
    }

    function effectiveRequestLeague() {
        return root.selectedLeague;
    }

    function effectiveFollowMode() {
        return root.teamWatchMode() ? "team" : root.followMode;
    }

    function watchedTeamsLabel() {
        const names = root.watchedTeamDisplayNames();
        if (names.length === 1)
            return names[0];

        return names.length > 1 ? i18ncp("@label", "%1 saved team", "%1 saved teams", names.length) : root.favoriteTeam;
    }

    function teamWatchSignature() {
        return root.watchedTeamNames().map(name => name.toLowerCase()).sort().join("|");
    }

    function activeTitleLabel() {
        if (root.savedLeagueCount > 1)
            return SportVisuals.label(root.selectedSport.length > 0 ? root.selectedSport : "football");

        if (root.followTeamMode && root.watchedTeamNames().length > 1)
            return i18nc("@label", "Saved Teams");

        return root.followTeamMode ? root.displayFavoriteTeam(root.activeLeagueEntry) : root.selectedLeagueLabel;
    }

    function activeSubtitleLabel() {
        return root.followTeamMode ? i18nc("@label", "All competitions") : root.selectedCountryLabel.length > 0 ? root.selectedCountryLabel : i18nc("@label", "Combined scope");
    }

    function activeHeaderBadge() {
        return root.teamWatchMode() && root.watchedTeamNames().length === 1 ? root.favoriteTeamBadge() : "";
    }

    function displayLeagueLabel(entry) {
        entry = entry || {};
        return String(entry.customLeagueLabel || entry.leagueLabel || ProviderCatalog.leagueLabel(entry.league) || entry.league || "").trim();
    }

    function stripLegacyTeamPrefix(value) {
        return String(value || "").replace(/^[★*]\s*/, "").trim();
    }

    function displayCountryLabel(entry) {
        entry = entry || {};
        return String(entry.customCountryLabel || entry.countryLabel || entry.country || "").trim();
    }

    function displayFavoriteTeam(entry) {
        entry = entry || {};
        return root.stripLegacyTeamPrefix(entry.customFavoriteTeamLabel || entry.favoriteTeam || "");
    }

    function badgeFromMatch(match) {
        if (!match)
            return "";

        if (isFavoriteMatch({"team": match.homeTeam || ""}))
            return String(match.homeBadge || "").trim();

        if (isFavoriteMatch({"team": match.awayTeam || ""}))
            return String(match.awayBadge || "").trim();

        return "";
    }

    function favoriteTeamBadge() {
        const rowSources = [root.primaryTableRows, root.tableRows];
        for (let sourceIndex = 0; sourceIndex < rowSources.length; sourceIndex += 1) {
            const rows = Array.isArray(rowSources[sourceIndex]) ? rowSources[sourceIndex] : [];
            for (let index = 0; index < rows.length; index += 1) {
                const row = rows[index] || {};
                if (isFavoriteMatch({"team": row.team || ""}) && String(row.crest || "").trim().length > 0)
                    return String(row.crest).trim();
            }
        }

        const matchSources = [root.latestLiveMatches, root.latestScheduleMatches, root.latestRecentMatches];
        for (let sourceIndex = 0; sourceIndex < matchSources.length; sourceIndex += 1) {
            const matches = Array.isArray(matchSources[sourceIndex]) ? matchSources[sourceIndex] : [];
            for (let index = 0; index < matches.length; index += 1) {
                const badge = root.badgeFromMatch(matches[index]);
                if (badge.length > 0)
                    return badge;
            }
        }

        for (let index = 0; index < root.discoveredTeamCompetitions.length; index += 1) {
            const badge = String(root.discoveredTeamCompetitions[index] && root.discoveredTeamCompetitions[index].teamBadge || "").trim();
            if (badge.length > 0)
                return badge;
        }

        return "";
    }

    function titleFromSlug(slug) {
        return String(slug || "")
            .replace(/[-_]+/g, " ")
            .replace(/\s+/g, " ")
            .trim()
            .split(" ")
            .filter(part => part.length > 0)
            .map(part => part.charAt(0).toUpperCase() + part.slice(1))
            .join(" ");
    }

    function normalizedFollowMode(entry) {
        entry = entry || {};
        const favorite = String(entry.favoriteTeam || "").trim();
        return root.entryType(entry) === "team" && favorite.length > 0 ? "team" : "league";
    }

    function entryType(entry) {
        entry = entry || {};
        const explicit = String(entry.type || "").trim();
        const followMode = String(entry.followMode || "").trim();
        const favoriteTeam = String(entry.favoriteTeam || "").trim();
        const league = String(entry.league || "").trim();
        const legacyLabel = String(entry.customLeagueLabel || entry.leagueLabel || "").trim();
        const legacyStarredLabel = /^[★*]\s*/.test(legacyLabel);
        const looksLikeTeam = followMode === "team" || legacyStarredLabel || (favoriteTeam.length > 0 && league.length === 0) || root.isLikelyLegacyTeamEntry(entry);
        if (explicit === "team")
            return "team";
        if (explicit === "competition")
            return looksLikeTeam ? "team" : "competition";

        return looksLikeTeam ? "team" : "competition";
    }

    function scoreTextForPanel(match) {
        if (!matchHasDisplayScore(match))
            return "";

        const home = String(match && match.homeScore !== undefined ? match.homeScore : "").trim();
        const away = String(match && match.awayScore !== undefined ? match.awayScore : "").trim();
        return (home.length > 0 ? home : "0") + " - " + (away.length > 0 ? away : "0");
    }

    function liveMinuteText(value) {
        value = String(value || "").trim();
        if (value.length === 0)
            return "";

        return /^\d+\+?$/.test(value) ? value + "'" : value;
    }

    function configuredDateFormat() {
        return String(Plasmoid.configuration.matchDateFormat || "dd.MM").trim();
    }

    function configuredTimeFormat() {
        return String(Plasmoid.configuration.matchTimeFormat || "HH:mm").trim();
    }

    function formatConfiguredDate(date) {
        const format = configuredDateFormat();
        if (format === "locale-long")
            return date.toLocaleDateString(Qt.locale(), Locale.LongFormat);
        if (format === "locale-short")
            return date.toLocaleDateString(Qt.locale(), Locale.ShortFormat);
        if (format.length === 0)
            return "";

        return Qt.formatDate(date, format);
    }

    function formatConfiguredTime(date) {
        const format = configuredTimeFormat();
        if (format === "locale")
            return date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
        if (format.length === 0)
            return "";

        return Qt.formatTime(date, format);
    }

    function sameCalendarDay(left, right) {
        return left.getFullYear() === right.getFullYear()
            && left.getMonth() === right.getMonth()
            && left.getDate() === right.getDate();
    }

    function formattedMatchStartTime(match) {
        const timestamp = Number(match && match.timestamp || 0);
        if (timestamp <= 0)
            return String(match && match.startTime || "").trim();

        const date = new Date(timestamp);
        const timeText = formatConfiguredTime(date);
        const today = new Date();
        if (sameCalendarDay(date, today))
            return timeText;

        const dateText = formatConfiguredDate(date);
        return [dateText, timeText].filter(part => part.length > 0).join(" ");
    }

    function updatedText() {
        const timeText = formatConfiguredTime(new Date());
        return timeText.length > 0 ? i18nc("@info:status", "Updated %1", timeText) : i18nc("@info:status", "Updated");
    }

    function panelTeamsScoreText(match) {
        match = match || {};
        const home = String(match.homeTeam || "").trim();
        const away = String(match.awayTeam || "").trim();
        const score = scoreTextForPanel(match);
        return home.length > 0 && away.length > 0 && score.length > 0 ? home + " " + score + " " + away : home.length > 0 && away.length > 0 ? home + " vs " + away : home + away;
    }

    function panelLiveText(match) {
        const minute = liveMinuteText(match && match.minute);
        return minute.length > 0 ? i18nc("@info:live match status", "Live %1", minute) : i18nc("@info:live match status", "Live");
    }

    function panelScheduleText(match) {
        const teams = panelTeamsScoreText(match);
        const status = String(match && (match.startTime || match.status) || "").trim();
        return status.length > 0 ? teams + " · " + status : teams;
    }

    function matchStatusText(match) {
        match = match || {};
        const minute = liveMinuteText(match.minute);
        if (minute.length > 0)
            return minute;

        const status = String(match.status || "").trim();
        if (SportsApi.isLiveMatch(match))
            return status.length > 0 ? status : i18nc("@info:live match status", "Live");

        return String(match.startTime || status || "").trim();
    }

    function matchHasDisplayScore(match) {
        match = match || {};
        if (SportsApi.isLiveMatch(match))
            return true;

        const status = String(match.status || "").trim().toLowerCase();
        if (status.indexOf("upcoming") >= 0 || status.indexOf("scheduled") >= 0 || status.indexOf("not started") >= 0 || status.indexOf("postponed") >= 0 || status.indexOf("cancel") >= 0)
            return false;

        const timestamp = Number(match.timestamp || 0);
        if (timestamp > Date.now())
            return false;

        const home = String(match.homeScore !== undefined ? match.homeScore : "").trim();
        const away = String(match.awayScore !== undefined ? match.awayScore : "").trim();
        if (home.length === 0 && away.length === 0)
            return false;

        return SportsApi.isFinishedMatch(match);
    }

    function matchForModel(match) {
        const copy = Object.assign({}, match || {});
        copy.showScore = matchHasDisplayScore(copy);
        copy.startTime = formattedMatchStartTime(copy);
        return copy;
    }

    function emptySchedulesText() {
        const teamScopes = root.scheduleScopeEntries().filter(entry => root.entryType(entry) === "team").length;
        const competitionScopes = root.scheduleScopeEntries().filter(entry => root.entryType(entry) === "competition").length;
        if (teamScopes > 0 && competitionScopes === 0)
            return i18nc("@info:status", "No scheduled matches for %1.", root.watchedTeamsLabel());

        return i18nc("@info:status", "No scheduled matches for your saved sports.");
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

    function isCurrentRefresh(token) {
        return token === root.refreshToken;
    }

    function isCurrentLiveRefresh(token) {
        return token === root.liveRefreshToken;
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

    function requestOptionsForEntry(entry, token, manual, override) {
        const type = root.entryType(entry);
        const options = {
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(),
            "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
            "sports": String(entry && entry.sport || "football").trim(),
            "country": String(entry && entry.country || "").trim(),
            "league": type === "team" ? "" : String(entry && entry.league || "").trim(),
            "favoriteTeam": type === "team" ? String(entry && entry.favoriteTeam || "").trim() : "",
            "followMode": type === "team" ? "team" : "league",
            "refreshToken": token,
            "forceLiveRefresh": Boolean(manual),
            "scoreboardDaysBack": 30,
            "scoreboardDaysForward": 90
        };
        return Object.assign(options, override || {});
    }

    function matchKey(match) {
        const value = match || {};
        const timestamp = Number(value.timestamp || 0);
        const status = String(value.status || "").trim().toLowerCase();
        const start = String(value.startTime || "").trim().toLowerCase();
        const league = String(value.league || "").trim().toLowerCase();
        const home = String(value.homeTeam || "").trim().toLowerCase();
        const away = String(value.awayTeam || "").trim().toLowerCase();
        const homeScore = String(value.homeScore !== undefined ? value.homeScore : "").trim();
        const awayScore = String(value.awayScore !== undefined ? value.awayScore : "").trim();
        return [league, home, away, timestamp > 0 ? String(timestamp) : start, status, homeScore, awayScore].join("|");
    }

    function mergeScopedMatches(existing, scopedMatches) {
        let byKey = {};
        (Array.isArray(existing) ? existing : []).forEach((match) => {
            const key = root.matchKey(match);
            if (key.length > 0)
                byKey[key] = Object.assign({}, match);
        });
        (Array.isArray(scopedMatches) ? scopedMatches : []).forEach((match) => {
            const key = root.matchKey(match);
            if (key.length === 0)
                return;

            const current = byKey[key];
            if (!current) {
                byKey[key] = Object.assign({}, match);
                return;
            }

            const currentOrder = Number(current.scopeOrder);
            const nextOrder = Number(match.scopeOrder);
            if (!Number.isFinite(currentOrder) || (Number.isFinite(nextOrder) && nextOrder < currentOrder))
                current.scopeOrder = nextOrder;
            if (String(current.league || "").trim().length === 0 && String(match.league || "").trim().length > 0)
                current.league = match.league;
            if (String(current.homeBadge || "").trim().length === 0 && String(match.homeBadge || "").trim().length > 0)
                current.homeBadge = match.homeBadge;
            if (String(current.awayBadge || "").trim().length === 0 && String(match.awayBadge || "").trim().length > 0)
                current.awayBadge = match.awayBadge;
        });

        return Object.keys(byKey).map((key) => byKey[key]);
    }

    function filterMatchesByEntries(matches, entries) {
        const scopedEntries = Array.isArray(entries) ? entries : [];
        if (scopedEntries.length === 0)
            return [];

        return (Array.isArray(matches) ? matches : []).filter(match => {
            for (let index = 0; index < scopedEntries.length; index += 1) {
                if (root.matchBelongsToEntry(scopedEntries[index], match))
                    return true;
            }
            return false;
        });
    }

    function matchBelongsToEntry(entry, match) {
        function normalizedKey(value) {
            return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "");
        }

        const type = root.entryType(entry);
        if (type === "team") {
            const team = String(entry && entry.favoriteTeam || "").trim();
            if (team.length === 0)
                return false;

            return SportsApi.sameTeamName(match && match.homeTeam, team)
                || SportsApi.sameTeamName(match && match.awayTeam, team)
                || SportsApi.sameTeamName(match && match.team, team);
        }

        const leagueSlug = ProviderCatalog.sportScoreSlug(entry && entry.league || "");
        const leagueLabelKey = normalizedKey(root.displayLeagueLabel(entry));
        if (leagueSlug.length === 0)
            return true;

        const matchLeagueLabel = String(match && match.league || "").trim();
        if (matchLeagueLabel.length === 0)
            return false;

        const matchLeagueSlug = ProviderCatalog.sportScoreSlug(matchLeagueLabel);
        if (matchLeagueSlug === leagueSlug)
            return true;

        const matchLeagueKey = normalizedKey(matchLeagueLabel);
        const leagueSlugKey = normalizedKey(leagueSlug);
        return matchLeagueKey.length > 0 && (matchLeagueKey.indexOf(leagueSlugKey) >= 0 || leagueSlugKey.indexOf(matchLeagueKey) >= 0 || (leagueLabelKey.length > 0 && (matchLeagueKey.indexOf(leagueLabelKey) >= 0 || leagueLabelKey.indexOf(matchLeagueKey) >= 0)));
    }

    function fetchScopedMatches(entries, token, manual, fetcher, onSuccess, onError, override) {
        const scopeEntries = Array.isArray(entries) ? entries : [];
        if (scopeEntries.length === 0) {
            onSuccess([]);
            return;
        }

        let pending = scopeEntries.length;
        let merged = [];
        let errors = [];
        scopeEntries.forEach((entry, index) => {
            const options = root.requestOptionsForEntry(entry, token, manual, override);
            fetcher(options, (matches) => {
                const scopedMatches = (Array.isArray(matches) ? matches : []).filter(match => root.matchBelongsToEntry(entry, match)).map(match => {
                    const copy = Object.assign({}, match || {});
                    copy.scopeOrder = index;
                    return copy;
                });
                merged = root.mergeScopedMatches(merged, scopedMatches);
                pending -= 1;
                if (pending > 0)
                    return;

                if (merged.length > 0 || errors.length === 0) {
                    onSuccess(merged);
                } else {
                    onError(errors.join(", "));
                }
            }, (message) => {
                const text = String(message || "").trim();
                if (text.length > 0)
                    errors.push(text);
                pending -= 1;
                if (pending > 0)
                    return;

                if (merged.length > 0 || errors.length === 0) {
                    onSuccess(merged);
                } else {
                    onError(errors.join(", "));
                }
            });
        });
    }

    function refreshScores(manual) {
        if (!root.hasSportSelection()) {
            root.refreshToken += 1;
            root.liveRefreshToken += 1;
            refreshTimer.stop();
            liveRefreshTimer.stop();
            configRefreshTimer.stop();
            emptySchedulesTimer.stop();
            tableFallbackTimer.stop();
            liveMatchesModel.clear();
            scoresModel.clear();
            tableModel.clear();
            recentResultsListModel.clear();
            root.tableRows = [];
            root.primaryTableRows = [];
            root.latestLiveMatches = [];
            root.latestScheduleMatches = [];
            root.latestRecentMatches = [];
            root.discoveredTeamCompetitions = [];
            root.teamTableOptions = [];
            root.selectedTeamTableSlug = "";
            root.teamTableSeasonOptions = [];
            root.selectedTeamTableSeasonKey = "";
            root.teamTableLoading = false;
            root.teamTableSeasonLoading = false;
            root.teamTableFormLoading = false;
            root.pendingSeasonTableRefresh = false;
            root.loading = false;
            root.liveLoading = false;
            root.schedulesLoading = false;
            root.recentResultsLoading = false;
            root.liveRefreshInFlight = false;
            root.pendingRequests = 0;
            root.tableRequestCompleted = true;
            root.scheduleRequestCompleted = true;
            root.tableScheduleFallbackStarted = false;
            root.recentResultsTableFallbackStarted = false;
            root.teamTableSeasonScopeKey = "";
            root.errorMessage = i18nc("@info:status", "Add a sport in the widget settings.");
            root.tableErrorMessage = "";
            root.lastUpdatedText = "";
            return;
        }

        if (!refreshTimer.running)
            refreshTimer.start();

        if (Plasmoid.configuration.liveRefreshEnabled && !liveRefreshTimer.running)
            liveRefreshTimer.start();

        const token = root.refreshToken + 1;
        root.refreshToken = token;
        root.liveRefreshToken += 1;
        root.liveRefreshInFlight = false;
        const options = root.currentRequestOptions();
        options.refreshToken = token;
        options.forceLiveRefresh = Boolean(manual);
        root.pendingRequests = 4;
        root.refreshErrors = [];
        root.tableRequestCompleted = false;
        root.scheduleRequestCompleted = false;
        root.tableScheduleFallbackStarted = false;
        root.recentResultsTableFallbackStarted = false;
        root.currentManualRefresh = manual;
        root.loading = true;
        root.liveLoading = true;
        root.schedulesLoading = true;
        root.recentResultsLoading = true;
        root.pendingScheduleMessage = "";
        root.primaryTableRows = [];
        root.latestLiveMatches = [];
        root.latestScheduleMatches = [];
        root.latestRecentMatches = [];
        root.discoveredTeamCompetitions = [];
        root.teamTableLoading = false;
        root.teamTableRequestToken += 1;
        root.teamTableSeasonLoading = false;
        root.teamTableFormLoading = false;
        root.teamTableFormRequestToken += 1;
        root.pendingSeasonTableRefresh = false;
        root.teamTableSeasonRequestToken += 1;
        root.teamTableSeasonScopeKey = "";
        emptySchedulesTimer.stop();
        root.errorMessage = "";
        liveMatchesModel.clear();
        scoresModel.clear();
        recentResultsListModel.clear();
        syncTeamTableOptions();
        applyTable([], true);
        root.tableErrorMessage = "";
        if (root.watchedTeamEntries().length > 0)
            refreshTeamCompetitionOptions(options);
        tableFallbackTimer.restart();
        root.fetchScopedMatches(root.liveScopeEntries(), token, manual, SportsApi.fetchLiveScores, (matches) => {
            if (!root.isCurrentRefresh(token))
                return;

            applyLiveMatches(matches);
            root.liveLoading = false;
            finishRefresh(manual, "", token);
        }, (message) => {
            if (!root.isCurrentRefresh(token))
                return;

            applyLiveMatches([]);
            root.liveLoading = false;
            finishRefresh(manual, message, token);
        });
        const hasCompetitionTableScope = root.tableScopeEntries().some(entry => root.entryType(entry) === "competition");
        if (!hasCompetitionTableScope || String(options.league || "").trim().length === 0) {
            root.tableRequestCompleted = true;
            tableFallbackTimer.stop();
            applyTable([], true);
            root.tableErrorMessage = root.teamTableOptions.length > 0 ? "" : i18nc("@info:status", "No table scope enabled.");
            if (root.currentDisplayTableSlug().length > 0)
                root.refreshDisplayTableForSelection();
            finishRefresh(manual, "", token);
        } else {
            SportsApi.fetchLeagueTable(options, (table) => {
            if (!root.isCurrentRefresh(token))
                return;

            const alreadyCounted = root.tableRequestCompleted;
            table = Array.isArray(table) ? table : [];
            root.tableRequestCompleted = true;
            tableFallbackTimer.stop();
            if (table.length > 0) {
                applyTable(table, true);
                root.tableErrorMessage = "";
                const activeSeasonOption = root.selectedTeamTableSeasonOption();
                enrichTableForm(Object.assign({}, options, {
                    "followMode": "league",
                    "league": root.currentDisplayTableSlug(),
                    "country": root.currentDisplayTableCountry(),
                    "seasonKey": String(root.selectedTeamTableSeasonKey || "").trim(),
                    "seasonLabel": String(activeSeasonOption && activeSeasonOption.label || "").trim(),
                    "seasonId": String(activeSeasonOption && activeSeasonOption.id || "").trim(),
                    "seasonProvider": String(activeSeasonOption && activeSeasonOption.provider || "").trim()
                }));
                if (root.recentScopeEntries().length > 0)
                    refreshRecentResultsFromTable(options);
                if (root.scheduleScopeEntries().length > 0 && (root.teamWatchMode() || (root.scheduleRequestCompleted && scoresModel.count === 0)))
                    refreshSchedulesFromTable(options);
                if (root.currentDisplayTableSlug() !== ProviderCatalog.sportScoreSlug(root.selectedLeague))
                    root.refreshDisplayTableForSelection();
                else if (root.selectedTeamTableSeasonKey.length > 0)
                    root.refreshDisplayTableForSelection();
            } else {
                applyTable([], true);
                root.tableErrorMessage = i18nc("@info:status", "No table rows returned for %1.", root.selectedLeagueLabel || root.selectedLeague);
                if (root.scheduleScopeEntries().length > 0 || root.recentScopeEntries().length > 0)
                    refreshClubModeSections(options);
                if (root.currentDisplayTableSlug() !== ProviderCatalog.sportScoreSlug(root.selectedLeague) && root.currentDisplayTableSlug().length > 0)
                    root.refreshDisplayTableForSelection();
            }

            if (root.pendingSeasonTableRefresh && root.selectedTeamTableSeasonKey.length > 0 && root.currentDisplayTableSlug().length > 0) {
                root.pendingSeasonTableRefresh = false;
                root.refreshDisplayTableForSelection();
            }

            if (!alreadyCounted)
                finishRefresh(manual, "", token);
        }, (message) => {
            if (!root.isCurrentRefresh(token))
                return;

            const alreadyCounted = root.tableRequestCompleted;
            root.tableRequestCompleted = true;
            tableFallbackTimer.stop();
            applyTable([], true);
            root.tableErrorMessage = message;
            if (root.scheduleScopeEntries().length > 0 || root.recentScopeEntries().length > 0)
                refreshClubModeSections(options);
            if (root.currentDisplayTableSlug() !== ProviderCatalog.sportScoreSlug(root.selectedLeague) && root.currentDisplayTableSlug().length > 0)
                root.refreshDisplayTableForSelection();
            if (root.pendingSeasonTableRefresh && root.selectedTeamTableSeasonKey.length > 0 && root.currentDisplayTableSlug().length > 0) {
                root.pendingSeasonTableRefresh = false;
                root.refreshDisplayTableForSelection();
            }
            if (!alreadyCounted)
                finishRefresh(manual, message, token);
        });
        }
        root.fetchScopedMatches(root.scheduleScopeEntries(), token, manual, SportsApi.fetchScoresFixtures, (fixtures) => {
            if (!root.isCurrentRefresh(token))
                return;

            root.scheduleRequestCompleted = true;

            const scheduledCount = applySchedules(fixtures, root.updatedText());
            if (scheduledCount > 0) {
                emptySchedulesTimer.stop();
                root.schedulesLoading = false;
            } else if (root.scheduleScopeEntries().length === 0) {
                emptySchedulesTimer.stop();
                root.schedulesLoading = false;
                root.errorMessage = i18nc("@info:status", "No saved items are enabled for Schedules.");
            } else if (root.tableRows.length > 0) {
                refreshSchedulesFromTable(options);
            } else if (root.tableRequestCompleted && root.tableRows.length === 0) {
                deferEmptySchedulesMessage("");
            }

            finishRefresh(manual, "", token);
        }, (message) => {
            if (!root.isCurrentRefresh(token))
                return;

            root.scheduleRequestCompleted = true;
            applySchedules([], root.updatedText());
            if (root.scheduleScopeEntries().length === 0) {
                emptySchedulesTimer.stop();
                root.schedulesLoading = false;
                root.errorMessage = i18nc("@info:status", "No saved items are enabled for Schedules.");
            } else if (root.tableRows.length > 0) {
                refreshSchedulesFromTable(options);
            } else if (root.tableRequestCompleted && root.tableRows.length === 0) {
                deferEmptySchedulesMessage(message);
            }

            finishRefresh(manual, message, token);
        }, {
            "preferTeamRecentResults": false
        });
        root.fetchScopedMatches(root.recentScopeEntries(), token, manual, SportsApi.fetchRecentResults, (results) => {
            if (!root.isCurrentRefresh(token))
                return;

            const hasResults = results.length > 0;
            if (results.length > 0 || recentResultsListModel.count === 0)
                applyRecentResults(results);
            if (hasResults || !root.recentResultsTableFallbackStarted)
                root.recentResultsLoading = false;
            finishRefresh(manual, "", token);
        }, (message) => {
            if (!root.isCurrentRefresh(token))
                return;

            if (recentResultsListModel.count === 0)
                applyRecentResults([]);
            if (!root.recentResultsTableFallbackStarted)
                root.recentResultsLoading = false;
            finishRefresh(manual, message, token);
        }, {
            "preferTeamRecentResults": true
        });
    }

    function refreshLiveMatches(manual) {
        if (!root.hasSportSelection())
            return;

        if (!Plasmoid.configuration.liveRefreshEnabled && !manual)
            return;

        if (root.liveRefreshInFlight && !manual)
            return;

        const token = root.liveRefreshToken + 1;
        root.liveRefreshToken = token;
        const selectedEntriesSignature = JSON.stringify(root.liveScopeEntries().map((entry) => ({
            "sport": String(entry && entry.sport || ""),
            "country": String(entry && entry.country || ""),
            "league": String(entry && entry.league || ""),
            "team": String(entry && entry.favoriteTeam || ""),
            "type": String(root.entryType(entry))
        })));
        const selectedWatchSignature = root.teamWatchSignature();

        root.liveLoading = liveMatchesModel.count === 0;
        root.liveRefreshInFlight = true;
        root.fetchScopedMatches(root.liveScopeEntries(), root.refreshToken, true, SportsApi.fetchLiveScores, (matches) => {
            if (!root.isCurrentLiveRefresh(token))
                return;

            const currentSignature = JSON.stringify(root.liveScopeEntries().map((entry) => ({
                "sport": String(entry && entry.sport || ""),
                "country": String(entry && entry.country || ""),
                "league": String(entry && entry.league || ""),
                "team": String(entry && entry.favoriteTeam || ""),
                "type": String(root.entryType(entry))
            })));
            if (selectedEntriesSignature !== currentSignature || selectedWatchSignature !== root.teamWatchSignature()) {
                root.liveRefreshInFlight = false;
                return;
            }

            applyLiveMatches(matches);
            root.liveLoading = false;
            root.liveRefreshInFlight = false;
            root.lastUpdatedText = root.updatedText();
        }, () => {
            if (!root.isCurrentLiveRefresh(token))
                return;

            root.liveLoading = false;
            root.liveRefreshInFlight = false;
        }, {
            "scoreboardDaysBack": 1,
            "scoreboardDaysForward": 1
        });
    }

    function refreshSchedulesFromTable(options) {
        if (!root.isCurrentRefresh(options.refreshToken))
            return;

        if (root.tableScheduleFallbackStarted)
            return;

        const rows = root.rowsForFollowMode();
        if (rows.length === 0) {
            deferEmptySchedulesMessage("");

            return;
        }

        root.tableScheduleFallbackStarted = true;
        root.schedulesLoading = true;
        emptySchedulesTimer.stop();

        SportsApi.fetchScoresFixtures(Object.assign({}, root.matchScopeOptions(options), {
            "tableRows": rows
        }), (fixtures) => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            const scopedFixtures = root.filterMatchesByEntries(fixtures, root.scheduleScopeEntries());
            const scheduledCount = applySchedules(scopedFixtures, root.updatedText());
            if (scheduledCount > 0) {
                emptySchedulesTimer.stop();
                root.schedulesLoading = false;
            } else {
                deferEmptySchedulesMessage("");
            }

        }, (message) => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            deferEmptySchedulesMessage(message);
        });
    }

    function refreshRecentResultsFromTable(options) {
        if (!root.isCurrentRefresh(options.refreshToken))
            return;

        if (root.recentResultsTableFallbackStarted)
            return;

        const rows = root.rowsForFollowMode();
        if (rows.length === 0) {
            root.recentResultsLoading = false;
            return;
        }

        root.recentResultsTableFallbackStarted = true;
        root.recentResultsLoading = recentResultsListModel.count === 0;

        SportsApi.fetchRecentResults(Object.assign({}, root.matchScopeOptions(options), {
            "tableRows": rows,
            "preferTeamRecentResults": true
        }), (results) => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            const scopedResults = root.filterMatchesByEntries(results, root.recentScopeEntries());
            if ((scopedResults.length > 0 && (recentResultsListModel.count === 0 || scopedResults.length > recentResultsListModel.count)) || recentResultsListModel.count === 0)
                applyRecentResults(scopedResults);
            root.recentResultsLoading = false;
        }, (message) => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            root.recentResultsLoading = false;
        });
    }

    function rowsForFollowMode() {
        if (!root.teamWatchMode())
            return root.tableRows;

        const watched = root.watchedTeamNames();
        let seen = {};
        let rows = [];
        root.primaryTableRows.forEach(row => {
            const team = String(row && row.team || "").trim();
            for (let index = 0; index < watched.length; index += 1) {
                const name = watched[index];
                if (SportsApi.sameTeamName(team, name) || team.toLowerCase().indexOf(name.toLowerCase()) >= 0) {
                    seen[name.toLowerCase()] = true;
                    rows.push(row);
                    return;
                }
            }
        });

        watched.forEach(name => {
            if (seen[name.toLowerCase()])
                return;

            rows.push({
                "team": name,
                "teamSlug": ProviderCatalog.sportScoreSlug(name)
            });
        });

        return rows.filter(row => String(row.team || "").trim().length > 0).map(row => ({
            "team": row.team,
            "teamSlug": String(row.teamSlug || ProviderCatalog.sportScoreSlug(row.team)).trim(),
            "crest": row.crest || ""
        }));
    }

    function refreshClubModeSections(options) {
        if (!root.teamWatchMode())
            return;

        refreshTeamCompetitionOptions(options);
        if (root.recentScopeEntries().length > 0)
            refreshRecentResultsFromTable(options);
        if (root.scheduleScopeEntries().length > 0)
            refreshSchedulesFromTable(options);
    }

    function enrichTableForm(options) {
        root.teamTableFormRequestToken += 1;
        const formToken = root.teamTableFormRequestToken;
        root.teamTableFormLoading = true;
        const requestSport = SportVisuals.normalizedSport(options.sports);
        const requestLeague = ProviderCatalog.sportScoreSlug(options.league);
        SportsApi.fetchLeagueForm(Object.assign({}, options, {
            "provider": "sportscore",
            "baseUrl": "https://sportscore.com/api/widget",
            "matchDateFormat": root.configuredDateFormat(),
            "matchTimeFormat": root.configuredTimeFormat(),
            "tableRows": root.tableRows
        }), (formByTeam) => {
            if (formToken !== root.teamTableFormRequestToken)
                return;

            root.teamTableFormLoading = false;
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            if (requestSport !== SportVisuals.normalizedSport(root.selectedSport) || requestLeague !== root.currentDisplayTableSlug())
                return;

            if (Object.keys(formByTeam).length === 0)
                return;

            const rows = root.tableRows.map((row) => {
                const form = SportsApi.formForTeam(formByTeam, row.team);
                if (!form || form.length === 0)
                    return row;

                const incomingDetails = SportsApi.formDetailsForTeam(formByTeam, row.team);
                const copy = Object.assign({}, row);
                copy.form = form;
                copy.formDetails = incomingDetails;
                return copy;
            });
            applyTable(rows, root.currentDisplayTableSlug() === ProviderCatalog.sportScoreSlug(root.selectedLeague));
        }, () => {
            if (formToken !== root.teamTableFormRequestToken)
                return;

            root.teamTableFormLoading = false;
        });
    }

    function currentDisplayTableSlug() {
        const selectedRaw = String(root.selectedTeamTableSlug || "").trim();
        let selectedCountry = "";
        const selectedRawSlug = ProviderCatalog.sportScoreSlug(selectedRaw);
        for (let index = 0; index < root.teamTableOptions.length; index += 1) {
            const option = root.teamTableOptions[index] || {};
            if (ProviderCatalog.sportScoreSlug(option.slug) !== selectedRawSlug)
                continue;

            selectedCountry = String(option.country || "").trim();
            break;
        }
        const selectedResolved = ProviderCatalog.resolveFootballLeagueCode(selectedCountry, selectedRaw);
        const selected = ProviderCatalog.sportScoreSlug(selectedResolved);
        if (selected.length > 0)
            return selected;

        const firstOption = Array.isArray(root.teamTableOptions) && root.teamTableOptions.length > 0 ? root.teamTableOptions[0] : {};
        return ProviderCatalog.sportScoreSlug(firstOption.slug || root.selectedLeague);
    }

    function currentDisplayTableLabel() {
        const slug = root.currentDisplayTableSlug();
        for (let index = 0; index < root.teamTableOptions.length; index += 1) {
            const option = root.teamTableOptions[index];
            if (ProviderCatalog.sportScoreSlug(option.slug) === slug)
                return String(option.label || "").trim();
        }

        const label = ProviderCatalog.leagueLabel(slug);
        if (label.length > 0)
            return label;

        if (root.watchedTeamNames().length > 0)
            return slug.length > 0 ? root.titleFromSlug(slug) : i18nc("@label", "All competitions");

        return root.selectedLeagueLabel;
    }

    function currentDisplayTableCountry() {
        const slug = root.currentDisplayTableSlug();
        for (let index = 0; index < root.teamTableOptions.length; index += 1) {
            const option = root.teamTableOptions[index] || {};
            if (ProviderCatalog.sportScoreSlug(option.slug) !== slug)
                continue;

            const country = String(option.country || "").trim();
            if (country.length > 0)
                return country;
        }

        const inferred = String(ProviderCatalog.countryCodeForLeague(slug) || "").trim();
        if (inferred.length > 0)
            return inferred;

        return root.selectedCountry;
    }

    function addTeamTableOption(options, seen, label, slug, country) {
        const resolvedCountry = String(country || "").trim();
        const resolvedLeague = ProviderCatalog.resolveFootballLeagueCode(resolvedCountry, String(slug || label).trim() || String(label || "").trim());
        const normalizedSlug = ProviderCatalog.sportScoreSlug(resolvedLeague);
        if (normalizedSlug.length === 0 || seen[normalizedSlug])
            return;

        const normalizedLabel = String(label || ProviderCatalog.leagueLabel(normalizedSlug) || root.titleFromSlug(normalizedSlug)).trim();
        const normalizedCountry = String(resolvedCountry || ProviderCatalog.countryCodeForLeague(normalizedSlug) || "").trim();
        seen[normalizedSlug] = true;
        options.push({
            "slug": normalizedSlug,
            "label": normalizedLabel,
            "country": normalizedCountry
        });
    }

    function addTeamTableOptionsFromMatches(options, seen, matches) {
        (Array.isArray(matches) ? matches : []).forEach(match => {
            const label = String(match && match.league || "").trim();
            if (label.length === 0)
                return;

            root.addTeamTableOption(options, seen, label, label, ProviderCatalog.countryCodeForLeague(label));
        });
    }

    function addTeamTableOptionsFromCompetitions(options, seen, competitions) {
        (Array.isArray(competitions) ? competitions : []).forEach(competition => {
            const label = String(competition && competition.label || "").trim();
            const slug = String(competition && competition.slug || label).trim();
            root.addTeamTableOption(options, seen, label, slug, ProviderCatalog.countryCodeForLeague(slug));
        });
    }

    function collectTeamTableOptions() {
        let seen = {};
        let options = [];
        const tableEntries = root.tableScopeEntries();
        tableEntries.forEach((entry) => {
            if (root.entryType(entry) !== "competition")
                return;

            const league = String(entry && entry.league || "").trim();
            if (league.length === 0)
                return;

            root.addTeamTableOption(options, seen, root.displayLeagueLabel(entry), league, String(entry && entry.country || "").trim());
        });
        // Include discovered team competitions (now constrained to provider-matched teams)
        // to expose domestic leagues that may not appear in the current match window.
        root.addTeamTableOptionsFromCompetitions(options, seen, root.discoveredTeamCompetitions);
        root.addTeamTableOptionsFromMatches(options, seen, root.latestLiveMatches);
        root.addTeamTableOptionsFromMatches(options, seen, root.latestScheduleMatches);
        root.addTeamTableOptionsFromMatches(options, seen, root.latestRecentMatches);
        return options;
    }

    function refreshTeamCompetitionOptions(options) {
        const teamEntries = root.watchedTeamEntries();
        if (teamEntries.length === 0)
            return;

        const requestToken = options.refreshToken;
        let pending = teamEntries.length;
        let competitions = [];
        teamEntries.forEach((entry) => {
            SportsApi.fetchTeamCompetitions(root.requestOptionsForEntry(entry, requestToken, false), (rows) => {
                competitions = competitions.concat(Array.isArray(rows) ? rows : []);
                pending -= 1;
                if (pending > 0 || !root.isCurrentRefresh(requestToken))
                    return;

                root.discoveredTeamCompetitions = competitions;
                syncTeamTableOptions();
                if (root.currentDisplayTableSlug().length > 0)
                    root.refreshDisplayTableForSelection();
            }, () => {
                pending -= 1;
                if (pending > 0 || !root.isCurrentRefresh(requestToken))
                    return;

                root.discoveredTeamCompetitions = competitions;
                syncTeamTableOptions();
                if (root.currentDisplayTableSlug().length > 0)
                    root.refreshDisplayTableForSelection();
            });
        });
    }

    function syncTeamTableOptions() {
        const options = root.collectTeamTableOptions();
        root.teamTableOptions = options;
        if (options.length === 0) {
            root.teamTableSeasonScopeKey = "";
            root.teamTableSeasonOptions = [];
            root.selectedTeamTableSeasonKey = "";
            return;
        }

        const currentSlug = ProviderCatalog.sportScoreSlug(root.selectedTeamTableSlug);
        const hasCurrent = options.some(option => ProviderCatalog.sportScoreSlug(option.slug) === currentSlug);
        let changed = false;
        if (currentSlug.length === 0 || !hasCurrent)
            root.selectedTeamTableSlug = options.length > 0 ? ProviderCatalog.sportScoreSlug(options[0].slug) : "";
        changed = ProviderCatalog.sportScoreSlug(root.selectedTeamTableSlug) !== currentSlug;
        if (changed && root.tableRequestCompleted && !root.teamTableLoading && root.currentDisplayTableSlug().length > 0)
            root.refreshDisplayTableForSelection();

        root.syncTableSeasonOptions();
    }

    function selectTeamTable(slug) {
        const normalizedSlug = ProviderCatalog.sportScoreSlug(slug);
        if (normalizedSlug.length === 0 || normalizedSlug === root.currentDisplayTableSlug())
            return;

        root.selectedTeamTableSlug = normalizedSlug;
        root.syncTableSeasonOptions();
        root.refreshDisplayTableForSelection();
    }

    function selectTeamTableSeason(seasonKey) {
        const normalizedKey = String(seasonKey || "").trim();
        if (normalizedKey.length === 0 || normalizedKey === root.selectedTeamTableSeasonKey)
            return;

        root.selectedTeamTableSeasonKey = normalizedKey;
        root.refreshDisplayTableForSelection();
    }

    function selectedTeamTableSeasonOption() {
        const selected = String(root.selectedTeamTableSeasonKey || "").trim();
        const options = Array.isArray(root.teamTableSeasonOptions) ? root.teamTableSeasonOptions : [];
        for (let index = 0; index < options.length; index += 1) {
            const option = options[index] || {};
            if (String(option.key || "").trim() === selected)
                return option;
        }

        return {};
    }

    function syncTableSeasonOptions() {
        const slug = root.currentDisplayTableSlug();
        const tableCountry = root.currentDisplayTableCountry();
        if (slug.length === 0) {
            root.teamTableSeasonScopeKey = "";
            root.teamTableSeasonLoading = false;
            root.teamTableSeasonOptions = [];
            root.selectedTeamTableSeasonKey = "";
            return;
        }

        const scopeKey = `${SportVisuals.normalizedSport(root.selectedSport)}|${ProviderCatalog.sportScoreSlug(tableCountry)}|${slug}`;
        if (root.teamTableSeasonScopeKey === scopeKey && root.teamTableSeasonOptions.length > 0)
            return;

        root.teamTableSeasonScopeKey = scopeKey;
        root.teamTableSeasonLoading = true;
        root.teamTableSeasonRequestToken += 1;
        const token = root.teamTableSeasonRequestToken;
        const previousKey = String(root.selectedTeamTableSeasonKey || "").trim();
        SportsApi.fetchLeagueSeasons({
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(),
            "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
            "sports": root.selectedSport,
            "country": tableCountry,
            "league": slug,
            "followMode": "league",
            "refreshToken": root.refreshToken
        }, (seasons) => {
            if (token !== root.teamTableSeasonRequestToken)
                return;

            const options = Array.isArray(seasons) ? seasons.filter(row => String(row && row.key || "").trim().length > 0) : [];
            root.teamTableSeasonOptions = options;
            let nextKey = "";
            if (options.some(option => String(option.key || "").trim() === previousKey)) {
                nextKey = previousKey;
            } else {
                const preferred = options.find(option => Boolean(option && option.isDefault));
                nextKey = String(preferred && preferred.key || options[0] && options[0].key || "").trim();
            }

            root.selectedTeamTableSeasonKey = nextKey;
            root.teamTableSeasonLoading = false;
            const canRefreshNow = root.tableRequestCompleted
                && !root.teamTableLoading
                && root.currentDisplayTableSlug().length > 0
                && nextKey.length > 0;
            if (canRefreshNow) {
                root.pendingSeasonTableRefresh = false;
                root.refreshDisplayTableForSelection();
            } else if (nextKey.length > 0 && root.currentDisplayTableSlug().length > 0) {
                root.pendingSeasonTableRefresh = true;
            }
        }, () => {
            if (token !== root.teamTableSeasonRequestToken)
                return;

            root.teamTableSeasonOptions = [];
            root.teamTableSeasonLoading = false;
            root.pendingSeasonTableRefresh = false;
            const hadSelection = root.selectedTeamTableSeasonKey.length > 0;
            root.selectedTeamTableSeasonKey = "";
            if (hadSelection && root.tableRequestCompleted && !root.teamTableLoading && root.currentDisplayTableSlug().length > 0)
                root.refreshDisplayTableForSelection();
        });
    }

    function currentRequestOptions() {
        const entry = root.firstCompetitionEntry();
        const type = root.entryType(entry);
        return {
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(),
            "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
            "sports": String(entry && entry.sport || root.selectedSport || "football").trim(),
            "country": String(entry && entry.country || root.selectedCountry || "").trim(),
            "league": type === "team" ? "" : String(entry && entry.league || root.selectedLeague || "").trim(),
            "favoriteTeam": type === "team" ? String(entry && entry.favoriteTeam || "").trim() : "",
            "followMode": type === "team" ? "team" : "league",
            "refreshToken": root.refreshToken,
            "scoreboardDaysBack": 30,
            "scoreboardDaysForward": 90
        };
    }

    function matchScopeOptions(options) {
        return Object.assign({}, options);
    }

    function refreshDisplayTableForSelection() {
        root.pendingSeasonTableRefresh = false;
        const slug = root.currentDisplayTableSlug();
        const tableCountry = root.currentDisplayTableCountry();
        const primarySlug = root.primaryTableRows.length > 0 ? ProviderCatalog.sportScoreSlug(root.selectedLeague) : "";
        const seasonOptions = Array.isArray(root.teamTableSeasonOptions) ? root.teamTableSeasonOptions : [];
        let selectedSeasonKey = String(root.selectedTeamTableSeasonKey || "").trim();
        if (selectedSeasonKey.length === 0 && seasonOptions.length > 0) {
            const preferred = seasonOptions.find(option => Boolean(option && option.isDefault));
            selectedSeasonKey = String(preferred && preferred.key || seasonOptions[0] && seasonOptions[0].key || "").trim();
            if (selectedSeasonKey.length > 0)
                root.selectedTeamTableSeasonKey = selectedSeasonKey;
        }

        let seasonOption = root.selectedTeamTableSeasonOption();
        if (selectedSeasonKey.length > 0 && String(seasonOption && seasonOption.key || "").trim() !== selectedSeasonKey)
            seasonOption = seasonOptions.find(option => String(option && option.key || "").trim() === selectedSeasonKey) || seasonOption;
        const selectedSeasonId = String(seasonOption && seasonOption.id || "").trim();
        const selectedSeasonLabel = String(seasonOption && seasonOption.label || "").trim();
        const selectedSeasonProvider = String(seasonOption && seasonOption.provider || "").trim();
        const useSeasonRequest = selectedSeasonKey.length > 0;
        const hasResolvedSeasonSelection = selectedSeasonKey.length === 0
            || selectedSeasonId.length > 0
            || selectedSeasonLabel.length > 0
            || selectedSeasonProvider.length > 0;
        root.teamTableRequestToken += 1;
        const token = root.teamTableRequestToken;
        if (slug.length === 0) {
            root.teamTableLoading = false;
            root.teamTableFormLoading = false;
            root.teamTableFormRequestToken += 1;
            applyTable([], false);
            root.tableErrorMessage = i18nc("@info:status", "Choose a competition to show a table.");
            return;
        }

        if (useSeasonRequest && !hasResolvedSeasonSelection) {
            root.teamTableLoading = false;
            root.teamTableFormLoading = false;
            root.teamTableFormRequestToken += 1;
            root.pendingSeasonTableRefresh = true;
            if (!root.teamTableSeasonLoading)
                root.syncTableSeasonOptions();
            return;
        }

        if (slug.length === 0 || (primarySlug.length > 0 && slug === primarySlug && !useSeasonRequest)) {
            root.teamTableLoading = false;
            applyTable(root.primaryTableRows, false);
            root.tableErrorMessage = root.primaryTableRows.length > 0 ? "" : i18nc("@info:status", "No table rows returned for %1.", root.selectedLeagueLabel || root.selectedLeague);
            enrichTableForm({
                "provider": effectiveProvider(),
                "baseUrl": effectiveBaseUrl(),
                "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
                "sports": root.selectedSport,
                "country": tableCountry,
                "league": slug,
                "seasonKey": selectedSeasonKey,
                "seasonLabel": selectedSeasonLabel,
                "seasonId": selectedSeasonId,
                "seasonProvider": selectedSeasonProvider,
                "followMode": "league",
                "refreshToken": root.refreshToken
            });
            return;
        }

        root.teamTableLoading = true;
        root.tableErrorMessage = "";
        const requestOptions = {
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(),
            "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
            "sports": root.selectedSport,
            "country": tableCountry,
            "league": slug,
            "seasonKey": selectedSeasonKey,
            "seasonLabel": selectedSeasonLabel,
            "seasonId": selectedSeasonId,
            "seasonProvider": selectedSeasonProvider,
            "followMode": "league",
            "refreshToken": root.refreshToken
        };
        const requestFn = useSeasonRequest ? SportsApi.fetchLeagueTableForSeason : SportsApi.fetchLeagueTable;
        requestFn(requestOptions, (table) => {
            if (token !== root.teamTableRequestToken)
                return;

            root.teamTableLoading = false;
            root.teamTableFormLoading = false;
            root.teamTableFormRequestToken += 1;
            table = Array.isArray(table) ? table : [];
            applyTable(table, false);
            root.tableErrorMessage = table.length > 0 ? "" : i18nc("@info:status", "No table rows returned for %1.", root.currentDisplayTableLabel());
            if (table.length > 0) {
                enrichTableForm({
                    "provider": effectiveProvider(),
                    "baseUrl": effectiveBaseUrl(),
                    "apiKey": String(Plasmoid.configuration.apiKey || "").trim(),
                    "sports": root.selectedSport,
                    "country": tableCountry,
                    "league": slug,
                    "seasonKey": selectedSeasonKey,
                    "seasonLabel": selectedSeasonLabel,
                    "seasonId": selectedSeasonId,
                    "seasonProvider": selectedSeasonProvider,
                    "followMode": "league",
                    "refreshToken": root.refreshToken
                });
            }
        }, (message) => {
            if (token !== root.teamTableRequestToken)
                return;

            root.teamTableLoading = false;
            root.teamTableFormLoading = false;
            root.teamTableFormRequestToken += 1;
            applyTable([], false);
            root.tableErrorMessage = message;
        });
    }

    function finishRefresh(manual, message, token) {
        if (!root.isCurrentRefresh(token))
            return;

        if (message && message.length > 0)
            root.refreshErrors = root.refreshErrors.concat([message]);

        root.pendingRequests -= 1;
        if (root.pendingRequests > 0)
            return ;

        promoteLiveMatches(root.latestScheduleMatches);
        root.loading = false;
        if (root.refreshErrors.length > 0 && liveMatchesModel.count === 0 && scoresModel.count === 0 && recentResultsListModel.count === 0 && tableModel.count === 0) {
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
    }

    function applySchedules(matches, updateText) {
        scoresModel.clear();
        root.latestScheduleMatches = Array.isArray(matches) ? matches.slice() : [];
        promoteLiveMatches(root.latestScheduleMatches);
        syncTeamTableOptions();
        matches = scheduledMatches(root.latestScheduleMatches);
        matches = filterFavoriteMatches(matches);
        matches = filterCurrentCompetitionMatches(matches);
        matches = prioritizeFavorite(matches);
        if (Plasmoid.configuration.prioritizePopular) {
            matches = matches.slice().sort((left, right) => {
                return Number(Boolean(right.popular)) - Number(Boolean(left.popular));
            });
            matches = prioritizeFavorite(matches);
        }
        matches.forEach((match) => {
            const row = matchForModel(match);
            row.leagueGroup = root.liveLeagueGroupLabel(row);
            return scoresModel.append(row);
        });
        if (matches.length > 0) {
            root.errorMessage = "";
        } else if (!root.schedulesLoading) {
            root.errorMessage = emptySchedulesText();
        }

        root.lastUpdatedText = updateText;
        return matches.length;
    }

    function reformatDisplayedMatches() {
        if (root.latestLiveMatches.length > 0)
            applyLiveMatches(root.latestLiveMatches);
        if (root.latestScheduleMatches.length > 0 || scoresModel.count > 0)
            applySchedules(root.latestScheduleMatches, root.lastUpdatedText);
        if (root.latestRecentMatches.length > 0 || recentResultsListModel.count > 0)
            applyRecentResults(root.latestRecentMatches);
        if (root.lastUpdatedText.length > 0)
            root.lastUpdatedText = root.updatedText();
    }

    function liveLeagueGroupLabel(match) {
        const league = String(match && match.league || "").trim();
        if (league.length > 0)
            return league;

        return i18nc("@label", "Matches");
    }

    function sortLiveMatches(matches) {
        return (Array.isArray(matches) ? matches.slice() : []).sort((left, right) => {
            const leftScopeOrder = Number(left && left.scopeOrder);
            const rightScopeOrder = Number(right && right.scopeOrder);
            if (Number.isFinite(leftScopeOrder) && Number.isFinite(rightScopeOrder) && leftScopeOrder !== rightScopeOrder)
                return leftScopeOrder - rightScopeOrder;

            const leftGroup = root.liveLeagueGroupLabel(left);
            const rightGroup = root.liveLeagueGroupLabel(right);
            const groupOrder = leftGroup.localeCompare(rightGroup);
            if (groupOrder !== 0)
                return groupOrder;

            const leftPriority = root.watchedTeamPriorityForMatch(left);
            const rightPriority = root.watchedTeamPriorityForMatch(right);
            if (leftPriority !== rightPriority)
                return leftPriority - rightPriority;

            const leftMinute = String(left && left.minute || "");
            const rightMinute = String(right && right.minute || "");
            if (leftMinute !== rightMinute)
                return rightMinute.localeCompare(leftMinute);

            return String(left && left.homeTeam || "").localeCompare(String(right && right.homeTeam || ""));
        });
    }

    function applyLiveMatches(matches) {
        liveMatchesModel.clear();
        const sourceMatches = Array.isArray(matches) ? matches.slice() : [];
        root.latestLiveMatches = sourceMatches;
        syncTeamTableOptions();
        matches = filterFavoriteMatches(sourceMatches);
        matches = filterCurrentCompetitionMatches(matches);
        matches = prioritizeFavorite(matches);
        matches = sortLiveMatches(matches);
        matches.forEach((match) => {
            const row = matchForModel(match);
            row.leagueGroup = root.liveLeagueGroupLabel(row);
            return liveMatchesModel.append(row);
        });
        return matches.length;
    }

    function applyRecentResults(matches) {
        recentResultsListModel.clear();
        const sourceMatches = Array.isArray(matches) ? matches.slice() : [];
        root.latestRecentMatches = sourceMatches;
        syncTeamTableOptions();
        matches = filterFavoriteMatches(sourceMatches);
        matches = filterCurrentCompetitionMatches(matches);
        matches = sortRecentResultsByDate(matches);
        matches.forEach((match) => {
            const row = matchForModel(match);
            row.leagueGroup = root.liveLeagueGroupLabel(row);
            return recentResultsListModel.append(row);
        });
        return matches.length;
    }

    function sortRecentResultsByDate(matches) {
        return (Array.isArray(matches) ? matches.slice() : []).sort((left, right) => {
            const leftScopeOrder = Number(left && left.scopeOrder);
            const rightScopeOrder = Number(right && right.scopeOrder);
            if (Number.isFinite(leftScopeOrder) && Number.isFinite(rightScopeOrder) && leftScopeOrder !== rightScopeOrder)
                return leftScopeOrder - rightScopeOrder;

            const leftPriority = root.watchedTeamPriorityForMatch(left);
            const rightPriority = root.watchedTeamPriorityForMatch(right);
            if (leftPriority !== rightPriority)
                return leftPriority - rightPriority;

            const leftTime = Number(left && left.timestamp || 0);
            const rightTime = Number(right && right.timestamp || 0);
            if (leftTime > 0 && rightTime > 0 && leftTime !== rightTime)
                return rightTime - leftTime;

            if (leftTime > 0 && rightTime === 0)
                return -1;

            if (rightTime > 0 && leftTime === 0)
                return 1;

            const leftStart = String(left && left.startTime || "");
            const rightStart = String(right && right.startTime || "");
            if (leftStart !== rightStart)
                return rightStart.localeCompare(leftStart);

            return String(left && left.homeTeam || "").localeCompare(String(right && right.homeTeam || ""));
        });
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

        root.pendingScheduleMessage = message && message.length > 0 ? message : emptySchedulesText();
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
                return timestamp === 0 || timestamp >= now - 3 * 60 * 60 * 1000;

            if (timestamp > 0)
                return timestamp >= now - 3 * 60 * 60 * 1000;

            return String(match.homeScore || "").length === 0 && String(match.awayScore || "").length === 0;
        }).sort((left, right) => {
            const leftScopeOrder = Number(left && left.scopeOrder);
            const rightScopeOrder = Number(right && right.scopeOrder);
            if (Number.isFinite(leftScopeOrder) && Number.isFinite(rightScopeOrder) && leftScopeOrder !== rightScopeOrder)
                return leftScopeOrder - rightScopeOrder;

            const leftPriority = root.watchedTeamPriorityForMatch(left);
            const rightPriority = root.watchedTeamPriorityForMatch(right);
            if (leftPriority !== rightPriority)
                return leftPriority - rightPriority;

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

    function applyTable(rows, updatePrimary) {
        rows = Array.isArray(rows) ? rows : [];
        if (updatePrimary !== false)
            root.primaryTableRows = rows.slice();

        root.tableRows = rows.slice();
        tableModel.clear();
        rows.forEach((row) => {
            return tableModel.append(row);
        });
    }

    function prioritizeFavorite(items) {
        if (root.watchedTeamNames().length === 0)
            return items;

        return items.map((match, index) => ({
            match,
            index,
            priority: root.watchedTeamPriorityForMatch(match)
        })).sort((left, right) => {
            if (left.priority !== right.priority)
                return left.priority - right.priority;

            return left.index - right.index;
        }).map(item => item.match);
    }

    function filterFavoriteMatches(items) {
        return items;
    }

    function filterCurrentCompetitionMatches(items) {
        return items;
    }

    function isFavoriteMatch(match) {
        if (root.watchedTeamNames().length === 0)
            return false;

        return root.isFavoriteTeamName(match.homeTeam) || root.isFavoriteTeamName(match.awayTeam) || root.isFavoriteTeamName(match.team);
    }

    function isFavoriteTeamName(teamName) {
        const names = root.watchedTeamNames();
        if (names.length === 0)
            return false;

        const normalizedTeam = String(teamName || "").toLowerCase();
        for (let index = 0; index < names.length; index += 1) {
            const favorite = names[index];
            if (SportsApi.sameTeamName(teamName, favorite) || normalizedTeam.indexOf(favorite.toLowerCase()) >= 0)
                return true;
        }
        return false;
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
    Layout.fillWidth: Plasmoid.formFactor === PlasmaCore.Types.Horizontal && root.panelAreaFill
    Layout.fillHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical && root.panelAreaFill
    Layout.minimumWidth: Plasmoid.formFactor === PlasmaCore.Types.Horizontal ? root.panelAreaFill ? 0 : root.compactPanelWidth : -1
    Layout.preferredWidth: Plasmoid.formFactor === PlasmaCore.Types.Horizontal ? root.panelAreaFill ? -1 : root.compactPanelWidth : -1
    Layout.minimumHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical && root.panelAreaMode === "manual" ? root.panelAreaSize : -1
    Layout.preferredHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? root.panelAreaFill ? -1 : root.panelAreaMode === "manual" ? root.panelAreaSize : -1 : -1
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
        id: recentResultsListModel
    }

    Timer {
        id: refreshTimer

        interval: Math.max(1, Plasmoid.configuration.refreshInterval) * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refreshScores(false)
    }

    Timer {
        id: liveRefreshTimer

        interval: Math.max(10, Number(Plasmoid.configuration.liveRefreshInterval || 30)) * 1000
        repeat: true
        running: false
        onTriggered: root.refreshLiveMatches(false)
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
            finishRefresh(root.currentManualRefresh, i18nc("@info:status", "Table request timed out."), root.refreshToken);
        }
    }

    Timer {
        id: configRefreshTimer

        interval: 60
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
                root.errorMessage = root.pendingScheduleMessage.length > 0 ? root.pendingScheduleMessage : emptySchedulesText();

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

        function onLiveRefreshEnabledChanged() {
            if (Plasmoid.configuration.liveRefreshEnabled && root.hasSportSelection()) {
                liveRefreshTimer.restart();
                root.refreshLiveMatches(true);
            } else {
                liveRefreshTimer.stop();
            }
        }

        function onLiveRefreshIntervalChanged() {
            if (liveRefreshTimer.running)
                liveRefreshTimer.restart();
        }

        function onMatchDateFormatChanged() {
            root.reformatDisplayedMatches();
        }

        function onMatchTimeFormatChanged() {
            root.reformatDisplayedMatches();
        }

        function onSelectedSportsChanged() {
            root.scheduleConfigRefresh();
        }

        function onSavedLeaguesChanged() {
            root.scheduleConfigRefresh();
        }

        function onActiveSavedLeagueIndexChanged() {
            root.syncTeamTableOptions();
        }

    }

    compactRepresentation: CompactRepresentation {
        liveCount: root.liveCount
        loading: root.loading || root.schedulesLoading
        layoutMode: Plasmoid.configuration.panelLayoutMode
        primaryText: root.primaryMatchText
        secondaryText: root.secondaryMatchText
        panelText: root.panelHeroText
        liveText: root.panelHeroLiveText
        isLive: root.panelHeroLive
        homeTeam: root.panelHeroHomeTeam
        awayTeam: root.panelHeroAwayTeam
        homeScore: root.panelHeroHomeScore
        awayScore: root.panelHeroAwayScore
        showScore: root.panelHeroShowScore
        statusText: root.panelHeroStatusText
        stadium: root.panelHeroStadium
        homeBadge: root.panelHeroHomeBadge
        awayBadge: root.panelHeroAwayBadge
        favoriteTeam: root.teamWatchMode() && root.watchedTeamNames().length === 1 ? root.effectiveFavoriteTeamName() : ""
        panelUseSystemFont: Plasmoid.configuration.panelUseSystemFont
        panelFontFamily: Plasmoid.configuration.panelFontFamily
        panelFontSize: Plasmoid.configuration.panelFontSize
        panelFontBold: Plasmoid.configuration.panelFontBold
        panelEmblemSize: Plasmoid.configuration.panelEmblemSize
        panelAreaMode: root.panelAreaMode
        panelAreaSize: root.panelAreaSize
        sport: root.primarySport
    }

    fullRepresentation: FullRepresentation {
        liveModel: liveMatchesModel
        scoreModel: scoresModel
        recentResultsModel: recentResultsListModel
        loading: root.loading
        liveLoading: root.liveLoading
        schedulesLoading: root.schedulesLoading
        recentResultsLoading: root.recentResultsLoading
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
        activeLeagueLabel: root.activeDisplayLabel
        activeCountryLabel: root.activeDisplayCountryLabel
        activeClubBadge: root.activeClubBadge
        tableLeagueLabel: root.currentDisplayTableLabel()
        followTeamMode: root.teamWatchMode()
        teamTableOptions: root.teamTableOptions
        selectedTableSlug: root.currentDisplayTableSlug()
        teamTableSeasonOptions: root.teamTableSeasonOptions
        selectedTableSeasonKey: root.selectedTeamTableSeasonKey
        teamTableSeasonLoading: root.teamTableSeasonLoading
        tableLoading: root.teamTableLoading || root.teamTableSeasonLoading
        tableFormLoading: root.teamTableFormLoading
        tableModel: tableModel
        tableRows: root.tableRows
        league: root.selectedLeague
        tableCount: root.tableCount
        recentResultsCount: root.recentResultsCount
        widgetTabs: Plasmoid.configuration.widgetTabs
        favoriteTeam: root.teamWatchMode() && root.watchedTeamNames().length === 1 ? root.effectiveFavoriteTeamName() : ""
        onRefreshRequested: root.refreshScores(true)
        onConfigureRequested: root.openSportSettings()
        onLeagueSelected: (index) => root.setActiveSavedLeagueIndex(index)
        onTeamTableSelected: (slug) => root.selectTeamTable(slug)
        onTeamTableSeasonSelected: (seasonKey) => root.selectTeamTableSeason(seasonKey)
    }

}
