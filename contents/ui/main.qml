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
import "../code/SavedSportsModel.js" as SavedSportsModel
import "../code/SportVisuals.js" as SportVisuals
import "../code/providers/ProviderCatalog.js" as ProviderCatalog
import "../code/providers/ProviderCountries.js" as ProviderCountries
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
    property int consecutiveEmptyLiveRefreshes: 0
    property string lastLiveScopeSignature: ""
    property bool scheduleRequestCompleted: false
    property bool tableScheduleFallbackStarted: false
    property bool recentResultsTableFallbackStarted: false
    property int refreshToken: 0
    property int liveRefreshToken: 0
    property var savedSportsModel: SavedSportsModel.create(Plasmoid.configuration.savedLeagues || "[]", {
        "activeIndex": Plasmoid.configuration.activeSavedLeagueIndex,
        "allCompetitionsLabel": i18nc("@label", "All competitions")
    })
    property var savedLeagueEntries: savedSportsModel.entries
    property int savedLeagueCount: savedSportsModel.count
    property var availableSports: savedSportsModel.sports
    property string activeSport: initialSport()
    property var activeSportEntries: savedSportsModel.entriesForSport(activeSport)
    property int activeSavedLeagueIndex: savedSportsModel.activeIndex
    property var activeLeagueEntry: savedSportsModel.activeEntryForSport(activeSport)
    property var primaryLeagueEntry: savedSportsModel.primaryCompetitionForSport(activeSport)
    property string selectedCountry: String(primaryLeagueEntry.country || String(activeLeagueEntry.country || "")).trim()
    property string selectedLeague: String(primaryLeagueEntry.league || String(activeLeagueEntry.league || "")).trim()
    property string favoriteTeam: String(activeLeagueEntry.favoriteTeam || "").trim()
    property string followMode: normalizedFollowMode(activeLeagueEntry)
    property bool followTeamMode: followMode === "team"
    property string sourceText: i18nc("@info:status", "No API key required")
    property int panelRotationIndex: 0
    readonly property int panelRotationCount: panelMatchRotationCount()
    property string primaryMatchText: panelLiveMatchesModel.count > 0 ? panelLiveMatchesModel.get(0).homeTeam + " vs " + panelLiveMatchesModel.get(0).awayTeam : panelScheduleMatchesModel.count > 0 ? panelScheduleMatchesModel.get(0).homeTeam + " vs " + panelScheduleMatchesModel.get(0).awayTeam : root.hasSportSelection() ? i18nc("@info:status", "No scheduled matches") : i18nc("@action:button", "Add a sport")
    property string secondaryMatchText: panelLiveMatchesModel.count > 0 ? panelLiveMatchesModel.get(0).minute || panelLiveMatchesModel.get(0).status : panelScheduleMatchesModel.count > 0 ? panelScheduleMatchesModel.get(0).startTime || panelScheduleMatchesModel.get(0).status : root.hasSportSelection() ? sourceText : i18nc("@info:status", "Open settings to add a league")
    property var panelHeroMatch: panelMatchForRotation()
    property bool panelHeroLive: matchField(panelHeroMatch, "status") === "Live"
    property string panelHeroText: panelHeroLive ? panelTeamsScoreText(panelHeroMatch) : matchField(panelHeroMatch, "homeTeam").length > 0 ? panelScheduleText(panelHeroMatch) : root.hasSportSelection() ? i18nc("@info:status", "No scheduled matches") : i18nc("@action:button", "Add a sport")
    property string panelHeroLiveText: panelHeroLive ? panelLiveText(panelHeroMatch) : ""
    property bool panelHeroShowScore: matchBooleanField(panelHeroMatch, "showScore", panelHeroLive)
    property string panelHeroStatusText: matchStatusText(panelHeroMatch)
    property string panelHeroHomeTeam: matchField(panelHeroMatch, "homeTeam")
    property string panelHeroAwayTeam: matchField(panelHeroMatch, "awayTeam")
    property string panelHeroHomeScore: matchField(panelHeroMatch, "homeScore")
    property string panelHeroAwayScore: matchField(panelHeroMatch, "awayScore")
    property string panelHeroHomeBadge: matchField(panelHeroMatch, "homeBadge")
    property string panelHeroAwayBadge: matchField(panelHeroMatch, "awayBadge")
    property string panelHeroStadium: matchField(panelHeroMatch, "stadium")
    property string selectedSport: activeSport
    property string selectedLeagueLabel: displayLeagueLabel(activeLeagueEntry)
    property string selectedCountryLabel: displayCountryLabel(activeLeagueEntry)
    property string activeDisplayLabel: activeTitleLabel()
    property string activeDisplayCountryLabel: activeSubtitleLabel()
    readonly property string nationalTeamVisualStyle: String(Plasmoid.configuration.nationalTeamVisualStyle || "emblems").trim()
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
    property var unsupportedTableSlugs: ({})
    property string selectedTeamTableSlug: ""
    property var teamTableSeasonOptions: []
    property string selectedTeamTableSeasonKey: ""
    property bool teamTableLoading: false
    property bool teamTableSeasonLoading: false
    property bool pendingSeasonTableRefresh: false
    property int teamTableRequestToken: 0
    property int teamTableSeasonRequestToken: 0
    property string teamTableSeasonScopeKey: ""
    property string tableScopeOrderSignature: ""
    property string pendingScheduleMessage: ""
    readonly property int sectionRequestTimeoutMs: 22000
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

    function normalizedMatchTimestamp(match) {
        let timestamp = Number(match && match.timestamp || 0);
        if (!Number.isFinite(timestamp) || timestamp <= 0)
            return 0;
        if (timestamp < 100000000000)
            timestamp *= 1000;
        return timestamp;
    }

    function upcomingDayWindow() {
        const now = new Date();
        const start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2).getTime();
        return {
            start,
            end
        };
    }

    function upcomingRotationIndexes(model) {
        const indexes = [];
        const count = model && model.count !== undefined ? Number(model.count) : 0;
        const window = root.upcomingDayWindow();
        for (let index = 0; index < count; index += 1) {
            const match = model.get(index);
            const timestamp = root.normalizedMatchTimestamp(match);
            if (timestamp >= window.start && timestamp < window.end)
                indexes.push(index);
        }
        return indexes;
    }

    function panelMatchRotationCount() {
        if (panelLiveMatchesModel.count > 0)
            return panelLiveMatchesModel.count;
        return root.upcomingRotationIndexes(panelScheduleMatchesModel).length;
    }

    function panelMatchForRotation() {
        if (!Plasmoid.configuration.panelMatchRotationEnabled)
            return panelLiveMatchesModel.count > 0 ? panelLiveMatchesModel.get(0) : panelScheduleMatchesModel.count > 0 ? panelScheduleMatchesModel.get(0) : {};

        if (panelLiveMatchesModel.count > 0)
            return panelLiveMatchesModel.get(Math.max(0, root.panelRotationIndex % panelLiveMatchesModel.count));

        const indexes = root.upcomingRotationIndexes(panelScheduleMatchesModel);
        if (indexes.length > 0)
            return panelScheduleMatchesModel.get(indexes[Math.max(0, root.panelRotationIndex % indexes.length)]);

        return panelScheduleMatchesModel.count > 0 ? panelScheduleMatchesModel.get(0) : {};
    }

    function advancePanelRotation() {
        const count = root.panelRotationCount;
        root.panelRotationIndex = count > 1 ? (root.panelRotationIndex + 1) % count : 0;
    }

    function hasSportSelection() {
        if (root.savedLeagueCount === 0)
            return false;

        return root.liveScopeEntries().length > 0
            || root.scheduleScopeEntries().length > 0
            || root.recentScopeEntries().length > 0
            || root.tableScopeEntries().length > 0;
    }

    // Smart mode picks fixed refresh times (30 min schedules, 60s live) to
    // limit requests; turning it off lets the user pick their own values.
    function refreshIntervalMs() {
        const minutes = Plasmoid.configuration.smartRefreshEnabled ? 30 : Plasmoid.configuration.refreshInterval;
        return Math.max(1, minutes) * 60 * 1000;
    }

    function liveRefreshIntervalMs() {
        const seconds = Plasmoid.configuration.smartRefreshEnabled ? 60 : Number(Plasmoid.configuration.liveRefreshInterval || 60);
        return Math.max(10, seconds) * 1000;
    }

    function liveRefreshIsEnabled() {
        return Plasmoid.configuration.smartRefreshEnabled || Plasmoid.configuration.liveRefreshEnabled;
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
        return root.savedSportsModel.entries;
    }

    function initialSport() {
        const sports = root.savedSportsModel ? root.savedSportsModel.sports : [];
        const configured = SportVisuals.normalizedSport(Plasmoid.configuration.defaultSport || "football");
        if (sports.indexOf(configured) >= 0)
            return configured;
        return sports.length > 0 ? sports[0] : configured;
    }

    function ensureActiveSport() {
        const sports = root.savedSportsModel.sports;
        if (sports.length === 0) {
            root.activeSport = SportVisuals.normalizedSport(Plasmoid.configuration.defaultSport || "football");
            return;
        }
        if (sports.indexOf(root.activeSport) < 0)
            root.activeSport = root.initialSport();
    }

    function selectActiveSport(sport) {
        const next = SportVisuals.normalizedSport(sport);
        if (next.length === 0 || root.availableSports.indexOf(next) < 0 || next === root.activeSport)
            return;

        root.refreshToken += 1;
        root.liveRefreshToken += 1;
        root.activeSport = next;
        root.panelRotationIndex = 0;
        root.clearVisibleSportState();
        Qt.callLater(() => root.refreshScores(true));
    }

    function clearVisibleSportState() {
        liveMatchesModel.clear();
        scoresModel.clear();
        recentResultsListModel.clear();
        tableModel.clear();
        panelLiveMatchesModel.clear();
        panelScheduleMatchesModel.clear();
        tooltipLiveMatchesModel.clear();
        tooltipScheduleMatchesModel.clear();
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
    }

    function normalizedSavedEntry(entry) {
        return SavedSportsModel.normalizeEntry(entry, {
            "allCompetitionsLabel": i18nc("@label", "All competitions")
        });
    }

    function firstCompetitionEntry() {
        return root.savedSportsModel.primaryCompetitionForSport(root.activeSport);
    }

    function hasEntryTarget(entry) {
        return SavedSportsModel.hasEntryTarget(entry);
    }

    function scopeEntries(flagName) {
        return root.savedSportsModel.scopeEntries(flagName, root.activeSport);
    }

    function liveScopeEntries() {
        return root.savedSportsModel.liveScopeEntries(root.activeSport);
    }

    function liveScopeSignature() {
        return JSON.stringify(root.liveScopeEntries().map((entry) => ({
            "sport": String(entry && entry.sport || ""),
            "country": String(entry && entry.country || ""),
            "league": String(entry && entry.league || ""),
            "team": String(entry && entry.favoriteTeam || ""),
            "type": String(root.entryType(entry))
        })));
    }

    function scheduleScopeEntries() {
        return root.savedSportsModel.scheduleScopeEntries(root.activeSport);
    }

    function recentScopeEntries() {
        return root.savedSportsModel.recentScopeEntries(root.activeSport);
    }

    function tableScopeEntries() {
        return root.savedSportsModel.tableScopeEntries(root.activeSport);
    }

    function panelScopeEntries() {
        return root.savedSportsModel.panelScopeEntries(root.activeSport);
    }

    function tooltipScopeEntries() {
        return root.savedSportsModel.tooltipScopeEntries(root.activeSport);
    }

    function optionValues(options) {
        return SavedSportsModel.optionValues(options);
    }

    function knownLeagueValues(sport, country) {
        return SavedSportsModel.knownLeagueValues(sport, country);
    }

    function knownCountryTeamValues(sport, country) {
        return SavedSportsModel.knownCountryTeamValues(sport, country);
    }

    function isLikelyLegacyTeamEntry(entry) {
        return SavedSportsModel.isLikelyLegacyTeamEntry(entry);
    }

    function teamWatchMode() {
        return root.savedSportsModel.teamWatchMode(root.activeSport);
    }

    function watchedTeamEntries() {
        return root.savedSportsModel.watchedTeamEntries("", root.activeSport);
    }

    function watchedTeamEntriesForScope(flagName) {
        return root.savedSportsModel.watchedTeamEntries(flagName, root.activeSport);
    }

    function watchedTeamNames() {
        return root.savedSportsModel.watchedTeamNames(root.activeSport);
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
        if (root.activeSportEntries.length > 1)
            return SportVisuals.label(root.selectedSport.length > 0 ? root.selectedSport : "football");

        if (root.followTeamMode && root.watchedTeamNames().length > 1)
            return i18nc("@label", "Saved Teams");

        return root.followTeamMode ? root.displayFavoriteTeam(root.activeLeagueEntry) : root.selectedLeagueLabel;
    }

    function activeSubtitleLabel() {
        return root.followTeamMode ? i18nc("@label", "All competitions") : root.selectedCountryLabel.length > 0 ? root.selectedCountryLabel : i18nc("@label", "Combined scope");
    }

    function displayLeagueLabel(entry) {
        return SavedSportsModel.displayLeagueLabel(entry);
    }

    function stripLegacyTeamPrefix(value) {
        return SavedSportsModel.stripLegacyTeamPrefix(value);
    }

    function displayCountryLabel(entry) {
        return SavedSportsModel.displayCountryLabel(entry);
    }

    function displayFavoriteTeam(entry) {
        return SavedSportsModel.displayFavoriteTeam(entry);
    }

    function savedEntryIsNationalTeam(entry) {
        entry = entry || {};
        if (entry.isNationalTeam === true)
            return true;

        const team = String(entry.favoriteTeam || "").trim();
        const detectedCountry = ProviderCountries.nationalTeamCountry(team);
        const entryCountry = String(entry.country || "").trim().toLowerCase();
        return detectedCountry.length > 0 && detectedCountry === entryCountry;
    }

    function nationalTeamCountryForName(teamName) {
        const team = String(teamName || "").trim();
        if (team.length === 0)
            return "";

        const entries = root.savedLeagueEntries;
        for (let index = 0; index < entries.length; index += 1) {
            const entry = entries[index] || {};
            if (root.entryType(entry) !== "team" || !root.savedEntryIsNationalTeam(entry))
                continue;
            if (SportsApi.sameTeamName(team, entry.favoriteTeam))
                return String(entry.country || "").trim().toLowerCase();
        }

        return ProviderCountries.nationalTeamCountry(team);
    }

    function preferredTeamBadge(teamName, providerBadge) {
        const badge = String(providerBadge || "").trim();
        if (root.nationalTeamVisualStyle !== "flags")
            return badge;

        const country = root.nationalTeamCountryForName(teamName);
        if (country.length === 0)
            return badge;

        const flag = String(ProviderCountries.flagSource(country) || "").trim();
        return flag.indexOf("file://") === 0 ? flag : badge;
    }

    function normalizedFollowMode(entry) {
        return SavedSportsModel.normalizedFollowMode(entry);
    }

    function entryType(entry) {
        return SavedSportsModel.entryType(entry);
    }

    function scoreTextForPanel(match) {
        if (!matchHasDisplayScore(match))
            return "";

        const home = String(match && match.homeScore !== undefined ? match.homeScore : "").trim();
        const away = String(match && match.awayScore !== undefined ? match.awayScore : "").trim();
        return (home.length > 0 ? home : "0") + " - " + (away.length > 0 ? away : "0");
    }

    function liveMinuteText(value, sport) {
        if (SportVisuals.normalizedSport(sport) === "basketball")
            return SportsApi.liveStatusText("basketball", value);

        value = SportsApi.normalizedLiveMinute(value);
        if (value.length === 0)
            return "";

        const minuteMatch = /^(\d+)(?:\+(\d*))?$/.exec(value);
        if (!minuteMatch)
            return value;

        if (minuteMatch[2] === undefined)
            return minuteMatch[1] + "'";
        return minuteMatch[2].length > 0 ? minuteMatch[1] + "' + " + minuteMatch[2] + "'" : minuteMatch[1] + "' +";
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
        if (String(match && match.sport || "").toLowerCase() === "tennis") {
            const setText = String(match && match.minute || "").trim();
            return setText.length > 0 ? setText : i18nc("@info:live match status", "Live");
        }

        const minute = liveMinuteText(match && (match.minute || match.statusText), match && match.sport);
        return minute.length > 0 ? i18nc("@info:live match status", "Live %1", minute) : i18nc("@info:live match status", "Live");
    }

    function panelScheduleText(match) {
        const teams = panelTeamsScoreText(match);
        const status = String(match && (match.startTime || match.status) || "").trim();
        return status.length > 0 ? teams + " · " + status : teams;
    }

    function matchStatusText(match) {
        match = match || {};
        const minute = liveMinuteText(match.minute || match.statusText, match.sport);
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
        copy.homeBadge = root.preferredTeamBadge(copy.homeTeam, copy.homeBadge);
        copy.awayBadge = root.preferredTeamBadge(copy.awayTeam, copy.awayBadge);
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
            "baseUrl": effectiveBaseUrl(String(entry && entry.sport || "football").trim()),
            "apiKey": root.effectiveApiKey(String(entry && entry.sport || "football").trim()),
            "sports": String(entry && entry.sport || "football").trim(),
            "country": String(entry && entry.country || "").trim(),
            "league": type === "team" ? "" : String(entry && entry.league || "").trim(),
            "competitionPath": type === "team" ? "" : String(entry && (entry.competitionPath || entry.leaguePath) || "").trim(),
            "favoriteTeam": type === "team" ? String(entry && entry.favoriteTeam || "").trim() : "",
            "teamSlug": type === "team" ? String(entry && entry.teamSlug || "").trim() : "",
            "teamPath": type === "team" ? String((entry && (entry.teamPath || entry.teamUrl)) || "").trim() : "",
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

        const leagueSlug = ProviderCatalog.slugForValue(entry && entry.league || "");
        const leagueLabelKey = normalizedKey(root.displayLeagueLabel(entry));
        if (leagueSlug.length === 0)
            return true;

        const matchLeagueLabel = String(match && match.league || "").trim();
        if (matchLeagueLabel.length === 0)
            return false;

        const matchLeagueSlug = ProviderCatalog.slugForValue(matchLeagueLabel);
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
            refreshWatchdogTimer.stop();
            liveRefreshWatchdogTimer.stop();
            teamTableWatchdogTimer.stop();
            teamTableSeasonWatchdogTimer.stop();
            liveMatchesModel.clear();
            scoresModel.clear();
            panelLiveMatchesModel.clear();
            panelScheduleMatchesModel.clear();
            tooltipLiveMatchesModel.clear();
            tooltipScheduleMatchesModel.clear();
            tableModel.clear();
            recentResultsListModel.clear();
            root.tableRows = [];
            root.primaryTableRows = [];
            root.latestLiveMatches = [];
            root.consecutiveEmptyLiveRefreshes = 0;
            root.lastLiveScopeSignature = "";
            root.latestScheduleMatches = [];
            root.latestRecentMatches = [];
            root.discoveredTeamCompetitions = [];
            root.teamTableOptions = [];
            root.selectedTeamTableSlug = "";
            root.teamTableSeasonOptions = [];
            root.selectedTeamTableSeasonKey = "";
            root.teamTableLoading = false;
            root.teamTableSeasonLoading = false;
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

        if (root.liveRefreshIsEnabled() && !liveRefreshTimer.running)
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
        root.latestScheduleMatches = [];
        root.latestRecentMatches = [];
        root.discoveredTeamCompetitions = [];
        root.teamTableLoading = false;
        root.teamTableRequestToken += 1;
        root.teamTableSeasonLoading = false;
        root.pendingSeasonTableRefresh = false;
        root.teamTableSeasonRequestToken += 1;
        root.teamTableSeasonScopeKey = "";
        emptySchedulesTimer.stop();
        refreshWatchdogTimer.stop();
        teamTableWatchdogTimer.stop();
        teamTableSeasonWatchdogTimer.stop();
        root.errorMessage = "";
        scoresModel.clear();
        recentResultsListModel.clear();
        root.refreshAuxiliaryMatchModels();
        syncTeamTableOptions();
        root.tableErrorMessage = "";
        if (root.watchedTeamEntries().length > 0)
            refreshTeamCompetitionOptions(options);
        tableFallbackTimer.restart();
        refreshWatchdogTimer.restart();
        root.fetchScopedMatches(root.liveScopeEntries(), token, manual, SportsApi.fetchLiveScores, (matches) => {
            if (!root.isCurrentRefresh(token))
                return;

            applyLiveMatches(matches, manual);
            root.liveLoading = false;
            finishRefresh(manual, "", token);
        }, (message) => {
            if (!root.isCurrentRefresh(token))
                return;

            applyLiveMatches([], manual);
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
                root.markTableCapability(ProviderCatalog.slugForValue(options.league), true);
                if (root.recentScopeEntries().length > 0)
                    refreshRecentResultsFromTable(options);
                if (root.scheduleScopeEntries().length > 0 && scoresModel.count === 0 && (root.teamWatchMode() || root.scheduleRequestCompleted))
                    refreshSchedulesFromTable(options);
                if (root.currentDisplayTableSlug() !== ProviderCatalog.slugForValue(root.selectedLeague))
                    root.refreshDisplayTableForSelection();
                else if (root.selectedTeamTableSeasonKey.length > 0)
                    root.refreshDisplayTableForSelection();
            } else {
                applyTable([], true);
                root.tableErrorMessage = i18nc("@info:status", "No table rows returned for %1.", root.selectedLeagueLabel || root.selectedLeague);
                root.markTableCapability(ProviderCatalog.slugForValue(options.league), false);
                if (root.scheduleScopeEntries().length > 0 || root.recentScopeEntries().length > 0)
                    refreshClubModeSections(options);
                if (root.currentDisplayTableSlug() !== ProviderCatalog.slugForValue(root.selectedLeague) && root.currentDisplayTableSlug().length > 0)
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
            if (root.currentDisplayTableSlug() !== ProviderCatalog.slugForValue(root.selectedLeague) && root.currentDisplayTableSlug().length > 0)
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
            "preferTeamRecentResults": true,
            "recentResultsLimit": 80,
            "recentResultsPerTeam": 50
        });
    }

    function refreshLiveMatches(manual) {
        if (!root.hasSportSelection())
            return;

        if (!root.liveRefreshIsEnabled() && !manual)
            return;

        if (root.liveRefreshInFlight && !manual)
            return;

        const token = root.liveRefreshToken + 1;
        root.liveRefreshToken = token;
        const selectedEntriesSignature = root.liveScopeSignature();
        const selectedWatchSignature = root.teamWatchSignature();

        root.liveLoading = liveMatchesModel.count === 0;
        root.liveRefreshInFlight = true;
        liveRefreshWatchdogTimer.restart();
        root.fetchScopedMatches(root.liveScopeEntries(), root.refreshToken, true, SportsApi.fetchLiveScores, (matches) => {
            if (!root.isCurrentLiveRefresh(token))
                return;

            const currentSignature = root.liveScopeSignature();
            if (selectedEntriesSignature !== currentSignature || selectedWatchSignature !== root.teamWatchSignature()) {
                root.liveRefreshInFlight = false;
                return;
            }

            applyLiveMatches(matches, manual);
            root.liveLoading = false;
            root.liveRefreshInFlight = false;
            liveRefreshWatchdogTimer.stop();
            root.lastUpdatedText = root.updatedText();
        }, () => {
            if (!root.isCurrentLiveRefresh(token))
                return;

            root.liveLoading = false;
            root.liveRefreshInFlight = false;
            liveRefreshWatchdogTimer.stop();
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

        SportsApi.fetchScoresFixtures(Object.assign({}, options, {
            "tableRows": rows
        }), (fixtures) => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            const scopedFixtures = root.filterMatchesByEntries(fixtures, root.scheduleScopeEntries());
            if (scopedFixtures.length > 0) {
                const scheduledCount = applySchedules(scopedFixtures, root.updatedText());
                if (scheduledCount > 0) {
                    emptySchedulesTimer.stop();
                    root.schedulesLoading = false;
                } else if (scoresModel.count === 0) {
                    deferEmptySchedulesMessage("");
                }
                return;
            }

            if (scoresModel.count > 0) {
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

        SportsApi.fetchRecentResults(Object.assign({}, options, {
            "tableRows": rows,
            "preferTeamRecentResults": true,
            "recentResultsLimit": 80,
            "recentResultsPerTeam": 50
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
                "teamSlug": ProviderCatalog.slugForValue(name)
            });
        });

        return rows.filter(row => String(row.team || "").trim().length > 0).map(row => ({
            "team": row.team,
            "teamSlug": String(row.teamSlug || ProviderCatalog.slugForValue(row.team)).trim(),
            "crest": row.crest || ""
        }));
    }

    function refreshClubModeSections(options) {
        if (!root.teamWatchMode())
            return;

        refreshTeamCompetitionOptions(options);
        if (root.recentScopeEntries().length > 0)
            refreshRecentResultsFromTable(options);
        if (root.scheduleScopeEntries().length > 0 && scoresModel.count === 0)
            refreshSchedulesFromTable(options);
    }

    function currentDisplayTableSlug() {
        const selectedRaw = String(root.selectedTeamTableSlug || "").trim();
        let selectedCountry = "";
        const selectedRawSlug = ProviderCatalog.slugForValue(selectedRaw);
        for (let index = 0; index < root.teamTableOptions.length; index += 1) {
            const option = root.teamTableOptions[index] || {};
            if (ProviderCatalog.slugForValue(option.slug) !== selectedRawSlug)
                continue;

            selectedCountry = String(option.country || "").trim();
            break;
        }
        const selectedResolved = ProviderCatalog.resolveFootballLeagueCode(selectedCountry, selectedRaw);
        const selected = ProviderCatalog.slugForValue(selectedResolved);
        if (selected.length > 0)
            return selected;

        const firstOption = Array.isArray(root.teamTableOptions) && root.teamTableOptions.length > 0 ? root.teamTableOptions[0] : {};
        return ProviderCatalog.slugForValue(firstOption.slug || root.selectedLeague);
    }

    function currentDisplayTableLabel() {
        const slug = root.currentDisplayTableSlug();
        for (let index = 0; index < root.teamTableOptions.length; index += 1) {
            const option = root.teamTableOptions[index];
            if (ProviderCatalog.slugForValue(option.slug) === slug)
                return String(option.label || "").trim();
        }

        const label = ProviderCatalog.leagueLabel(slug);
        if (label.length > 0)
            return label;

        if (root.watchedTeamNames().length > 0)
            return slug.length > 0 ? ProviderCatalog.titleFromSlug(slug) : i18nc("@label", "All competitions");

        return root.selectedLeagueLabel;
    }

    function currentDisplayTableCountry() {
        const slug = root.currentDisplayTableSlug();
        for (let index = 0; index < root.teamTableOptions.length; index += 1) {
            const option = root.teamTableOptions[index] || {};
            if (ProviderCatalog.slugForValue(option.slug) !== slug)
                continue;

            const country = String(option.country || "").trim();
            if (country.length > 0)
                return country;
        }

        return root.selectedCountry;
    }

    function addTeamTableOption(options, seen, label, slug, country) {
        const resolvedCountry = String(country || "").trim();
        const resolvedLeague = ProviderCatalog.resolveFootballLeagueCode(resolvedCountry, String(slug || label).trim());
        const normalizedSlug = ProviderCatalog.slugForValue(resolvedLeague);
        if (normalizedSlug.length === 0 || seen[normalizedSlug])
            return;

        const normalizedLabel = String(label || ProviderCatalog.leagueLabel(normalizedSlug) || ProviderCatalog.titleFromSlug(normalizedSlug)).trim();
        if (!root.isTableCompetitionEligible(normalizedSlug, normalizedLabel))
            return;

        const normalizedCountry = String(resolvedCountry || "").trim();
        seen[normalizedSlug] = true;
        options.push({
            "slug": normalizedSlug,
            "label": normalizedLabel,
            "country": normalizedCountry
        });
    }

    function isTableCompetitionEligible(slug, label) {
        const normalizedSlug = ProviderCatalog.slugForValue(slug);
        if (normalizedSlug.length === 0)
            return false;

        if (Boolean(root.unsupportedTableSlugs && root.unsupportedTableSlugs[normalizedSlug]))
            return false;

        const text = String(label || normalizedSlug).trim().toLowerCase();
        if (text.length === 0)
            return true;

        // Friendlies do not provide standings tables.
        if (text.indexOf("friendly") >= 0 || text.indexOf("friendlies") >= 0)
            return false;

        if (text.indexOf("club friendly") >= 0 || text.indexOf("international friendly") >= 0)
            return false;

        return true;
    }

    function markTableCapability(slug, hasTable) {
        const normalizedSlug = ProviderCatalog.slugForValue(slug);
        if (normalizedSlug.length === 0)
            return;

        const current = Object.assign({}, root.unsupportedTableSlugs || {});
        if (hasTable) {
            if (!current[normalizedSlug])
                return;

            delete current[normalizedSlug];
        } else {
            if (current[normalizedSlug])
                return;

            current[normalizedSlug] = true;
        }

        root.unsupportedTableSlugs = current;
        syncTeamTableOptions();
    }

    function addTeamTableOptionsFromMatches(options, seen, matches) {
        (Array.isArray(matches) ? matches : []).forEach(match => {
            const label = String(match && match.league || "").trim();
            if (label.length === 0)
                return;

            root.addTeamTableOption(options, seen, label, label, "");
        });
    }

    function addTeamTableOptionsFromCompetitions(options, seen, competitions) {
        (Array.isArray(competitions) ? competitions : []).forEach(competition => {
            const label = String(competition && competition.label || "").trim();
            const slug = String(competition && competition.slug || label).trim();
            root.addTeamTableOption(options, seen, label, slug, String(competition && competition.country || "").trim());
        });
    }

    function savedEntryKey(entry) {
        entry = entry || {};
        return [
            root.entryType(entry),
            String(entry.sport || "").trim().toLowerCase(),
            String(entry.country || "").trim().toLowerCase(),
            ProviderCatalog.slugForValue(entry.league || ""),
            String(entry.favoriteTeam || "").trim().toLowerCase(),
            ProviderCatalog.slugForValue(entry.teamSlug || ""),
            String(entry.teamPath || entry.teamUrl || "").trim().toLowerCase()
        ].join("|");
    }

    function discoveredCompetitionsForEntry(entry, order) {
        const key = root.savedEntryKey(entry);
        const team = root.displayFavoriteTeam(entry);
        return (Array.isArray(root.discoveredTeamCompetitions) ? root.discoveredTeamCompetitions : []).filter(competition => {
            const competitionKey = String(competition && competition.sourceEntryKey || "").trim();
            if (competitionKey.length > 0)
                return competitionKey === key;

            const competitionOrder = Number(competition && competition.scopeOrder);
            if (Number.isFinite(competitionOrder))
                return competitionOrder === order;

            const sourceTeam = String(competition && competition.sourceTeam || "").trim();
            return sourceTeam.length > 0 && SportsApi.sameTeamName(sourceTeam, team);
        });
    }

    function addTeamTableOptionsFromEntryMatches(options, seen, entry) {
        root.addTeamTableOptionsFromMatches(options, seen, root.filterMatchesByEntries(root.latestLiveMatches, [entry]));
        root.addTeamTableOptionsFromMatches(options, seen, root.filterMatchesByEntries(root.latestScheduleMatches, [entry]));
        root.addTeamTableOptionsFromMatches(options, seen, root.filterMatchesByEntries(root.latestRecentMatches, [entry]));
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

        let teamOrder = 0;
        tableEntries.forEach((entry) => {
            if (root.entryType(entry) !== "team")
                return;

            root.addTeamTableOptionsFromCompetitions(options, seen, root.discoveredCompetitionsForEntry(entry, teamOrder));
            root.addTeamTableOptionsFromEntryMatches(options, seen, entry);
            teamOrder += 1;
        });

        // Keep older untagged discoveries reachable, but only after the ordered saved scopes.
        root.addTeamTableOptionsFromCompetitions(options, seen, root.discoveredTeamCompetitions);
        return options;
    }

    function refreshTeamCompetitionOptions(options) {
        const teamEntries = root.watchedTeamEntriesForScope("includeTables");
        if (teamEntries.length === 0) {
            root.discoveredTeamCompetitions = [];
            syncTeamTableOptions();
            return;
        }

        const requestToken = options.refreshToken;
        let pending = teamEntries.length;
        let competitions = [];
        teamEntries.forEach((entry, sourceOrder) => {
            SportsApi.fetchTeamCompetitions(root.requestOptionsForEntry(entry, requestToken, false), (rows) => {
                const entryKey = root.savedEntryKey(entry);
                const sourceTeam = root.displayFavoriteTeam(entry);
                competitions = competitions.concat((Array.isArray(rows) ? rows : []).map(row => Object.assign({}, row || {}, {
                    "scopeOrder": sourceOrder,
                    "sourceEntryKey": entryKey,
                    "sourceTeam": sourceTeam
                })));
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
        const scopeSignature = JSON.stringify(root.tableScopeEntries().map(entry => root.savedEntryKey(entry)));
        const scopeOrderChanged = scopeSignature !== root.tableScopeOrderSignature;
        root.tableScopeOrderSignature = scopeSignature;
        root.teamTableOptions = options;
        if (options.length === 0) {
            root.teamTableSeasonScopeKey = "";
            root.teamTableSeasonOptions = [];
            root.selectedTeamTableSeasonKey = "";
            return;
        }

        const currentSlug = ProviderCatalog.slugForValue(root.selectedTeamTableSlug);
        const hasCurrent = options.some(option => ProviderCatalog.slugForValue(option.slug) === currentSlug);
        let changed = false;
        if (scopeOrderChanged || currentSlug.length === 0 || !hasCurrent)
            root.selectedTeamTableSlug = options.length > 0 ? ProviderCatalog.slugForValue(options[0].slug) : "";
        changed = ProviderCatalog.slugForValue(root.selectedTeamTableSlug) !== currentSlug;
        if (changed && root.tableRequestCompleted && !root.teamTableLoading && root.currentDisplayTableSlug().length > 0)
            root.refreshDisplayTableForSelection();

        root.syncTableSeasonOptions();
    }

    function selectTeamTable(slug) {
        const normalizedSlug = ProviderCatalog.slugForValue(slug);
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

        const scopeKey = `${SportVisuals.normalizedSport(root.selectedSport)}|${ProviderCatalog.slugForValue(tableCountry)}|${slug}`;
        if (root.teamTableSeasonScopeKey === scopeKey && root.teamTableSeasonOptions.length > 0)
            return;

        root.teamTableSeasonScopeKey = scopeKey;
        root.teamTableSeasonLoading = true;
        teamTableSeasonWatchdogTimer.restart();
        root.teamTableSeasonRequestToken += 1;
        const token = root.teamTableSeasonRequestToken;
        const previousKey = String(root.selectedTeamTableSeasonKey || "").trim();
        SportsApi.fetchLeagueSeasons({
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(root.selectedSport),
            "apiKey": root.effectiveApiKey(root.selectedSport),
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
            teamTableSeasonWatchdogTimer.stop();
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
            teamTableSeasonWatchdogTimer.stop();
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
            "baseUrl": effectiveBaseUrl(String(entry && entry.sport || root.selectedSport || "football").trim()),
            "apiKey": root.effectiveApiKey(String(entry && entry.sport || root.selectedSport || "football").trim()),
            "sports": String(entry && entry.sport || root.selectedSport || "football").trim(),
            "country": String(entry && entry.country || root.selectedCountry || "").trim(),
            "league": type === "team" ? "" : String(entry && entry.league || root.selectedLeague || "").trim(),
            "competitionPath": type === "team" ? "" : String(entry && (entry.competitionPath || entry.leaguePath) || "").trim(),
            "favoriteTeam": type === "team" ? String(entry && entry.favoriteTeam || "").trim() : "",
            "followMode": type === "team" ? "team" : "league",
            "refreshToken": root.refreshToken,
            "scoreboardDaysBack": 30,
            "scoreboardDaysForward": 90
        };
    }


    function refreshDisplayTableForSelection() {
        root.pendingSeasonTableRefresh = false;
        const slug = root.currentDisplayTableSlug();
        const tableCountry = root.currentDisplayTableCountry();
        const primarySlug = root.primaryTableRows.length > 0 ? ProviderCatalog.slugForValue(root.selectedLeague) : "";
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
        const selectedSeasonIsDefault = selectedSeasonKey.length === 0 || Boolean(seasonOption && seasonOption.isDefault);
        const useSeasonRequest = selectedSeasonKey.length > 0;
        const hasResolvedSeasonSelection = selectedSeasonKey.length === 0
            || selectedSeasonId.length > 0
            || selectedSeasonLabel.length > 0
            || selectedSeasonProvider.length > 0;
        root.teamTableRequestToken += 1;
        const token = root.teamTableRequestToken;
        if (slug.length === 0) {
            root.teamTableLoading = false;
            applyTable([], false);
            root.tableErrorMessage = i18nc("@info:status", "Choose a competition to show a table.");
            return;
        }

        if (useSeasonRequest && !hasResolvedSeasonSelection) {
            root.teamTableLoading = false;
            root.pendingSeasonTableRefresh = true;
            if (!root.teamTableSeasonLoading)
                root.syncTableSeasonOptions();
            return;
        }

        if (slug.length === 0 || (primarySlug.length > 0 && slug === primarySlug && !useSeasonRequest)) {
            root.teamTableLoading = false;
            applyTable(root.primaryTableRows, false);
            root.tableErrorMessage = root.primaryTableRows.length > 0 ? "" : i18nc("@info:status", "No table rows returned for %1.", root.selectedLeagueLabel || root.selectedLeague);
            return;
        }

        root.teamTableLoading = true;
        teamTableWatchdogTimer.restart();
        root.tableErrorMessage = "";
        const requestOptions = {
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(root.selectedSport),
            "apiKey": root.effectiveApiKey(root.selectedSport),
            "sports": root.selectedSport,
            "country": tableCountry,
            "league": slug,
            "seasonKey": selectedSeasonKey,
            "seasonLabel": selectedSeasonLabel,
            "seasonId": selectedSeasonId,
            "seasonProvider": selectedSeasonProvider,
            "seasonIsDefault": selectedSeasonIsDefault,
            "followMode": "league",
            "refreshToken": root.refreshToken
        };
        const requestFn = SportsApi.fetchLeagueTable;
        requestFn(requestOptions, (table) => {
            if (token !== root.teamTableRequestToken)
                return;

            root.teamTableLoading = false;
            teamTableWatchdogTimer.stop();
            table = Array.isArray(table) ? table : [];
            applyTable(table, false);
            root.tableErrorMessage = table.length > 0 ? "" : i18nc("@info:status", "No table rows returned for %1.", root.currentDisplayTableLabel());
            if (table.length > 0)
                root.markTableCapability(slug, true);
            else if (!useSeasonRequest)
                root.markTableCapability(slug, false);
        }, (message) => {
            if (token !== root.teamTableRequestToken)
                return;

            root.teamTableLoading = false;
            teamTableWatchdogTimer.stop();
            applyTable([], false);
            root.tableErrorMessage = message;
        });
    }

    function finishRefresh(manual, message, token) {
        if (!root.isCurrentRefresh(token))
            return;

        if (message && message.length > 0)
            root.refreshErrors = root.refreshErrors.concat([message]);

        if (root.pendingRequests <= 0)
            return;

        root.pendingRequests -= 1;
        if (root.pendingRequests > 0)
            return ;

        refreshWatchdogTimer.stop();
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
        root.refreshAuxiliaryMatchModels();
        return matches.length;
    }

    function appendScopedDisplayModels(entries, liveTarget, scheduleTarget) {
        liveTarget.clear();
        scheduleTarget.clear();

        let liveMatches = root.filterMatchesByEntries(root.latestLiveMatches, entries);
        liveMatches = root.sortLiveMatches(root.prioritizeFavorite(liveMatches));
        liveMatches.forEach(match => liveTarget.append(root.matchForModel(root.liveMatchForModel(match))));

        let scheduleMatches = root.filterMatchesByEntries(root.latestScheduleMatches, entries);
        scheduleMatches = root.prioritizeFavorite(root.scheduledMatches(scheduleMatches));
        scheduleMatches.forEach(match => scheduleTarget.append(root.matchForModel(match)));
    }

    function refreshAuxiliaryMatchModels() {
        root.appendScopedDisplayModels(root.panelScopeEntries(), panelLiveMatchesModel, panelScheduleMatchesModel);
        root.appendScopedDisplayModels(root.tooltipScopeEntries(), tooltipLiveMatchesModel, tooltipScheduleMatchesModel);
        if (root.panelRotationCount <= 1)
            root.panelRotationIndex = 0;
        else
            root.panelRotationIndex %= root.panelRotationCount;
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

    function applyLiveMatches(matches, manual) {
        const sourceMatches = Array.isArray(matches) ? matches.slice() : [];
        const scopeSignature = root.liveScopeSignature();
        const sameScope = scopeSignature === root.lastLiveScopeSignature;
        if (!manual && sourceMatches.length === 0 && sameScope && root.latestLiveMatches.length > 0 && root.consecutiveEmptyLiveRefreshes < 2) {
            root.consecutiveEmptyLiveRefreshes += 1;
            return liveMatchesModel.count;
        }

        root.consecutiveEmptyLiveRefreshes = sourceMatches.length === 0 ? root.consecutiveEmptyLiveRefreshes + 1 : 0;
        root.lastLiveScopeSignature = scopeSignature;
        liveMatchesModel.clear();
        root.latestLiveMatches = sourceMatches;
        syncTeamTableOptions();
        matches = prioritizeFavorite(sourceMatches);
        matches = sortLiveMatches(matches);
        matches.forEach((match) => {
            const row = matchForModel(liveMatchForModel(match));
            row.leagueGroup = root.liveLeagueGroupLabel(row);
            return liveMatchesModel.append(row);
        });
        root.refreshAuxiliaryMatchModels();
        return matches.length;
    }

    function applyRecentResults(matches) {
        recentResultsListModel.clear();
        const sourceMatches = Array.isArray(matches) ? matches.slice() : [];
        root.latestRecentMatches = sourceMatches;
        syncTeamTableOptions();
        matches = sortRecentResultsByDate(sourceMatches);
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
        const normalizedMinute = SportsApi.normalizedLiveMinute(copy.minute || status);
        if (normalizedMinute.length > 0)
            copy.minute = normalizedMinute;
        else if (String(copy.minute || "").length === 0 && (lowerStatus === "ht" || lowerStatus === "half-time" || lowerStatus === "halftime" || lowerStatus === "1h" || lowerStatus === "2h"))
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
        rows = rows.map((row) => {
            const copy = Object.assign({}, row || {});
            copy.group = root.normalizeGroupLabel(copy.group);
            copy.providerCrest = String(copy.providerCrest || copy.crest || "").trim();
            copy.crest = root.preferredTeamBadge(copy.team, copy.providerCrest);
            return copy;
        });
        rows = root.reindexSequentialGroupLabels(rows);
        if (updatePrimary !== false)
            root.primaryTableRows = rows.slice();

        root.tableRows = rows.slice();
        tableModel.clear();
        rows.forEach((row) => {
            return tableModel.append(row);
        });
    }

    function normalizeGroupLabel(value) {
        const text = String(value || "").trim();
        if (text.length === 0)
            return text;

        const converted = text.replace(/\bGroup\s+(\d{1,2})\b/gi, (match, numberText) => {
            const number = Number(numberText);
            if (!Number.isFinite(number) || number < 1 || number > 26)
                return match;

            return "Group " + String.fromCharCode(64 + number);
        });

        return converted;
    }

    function reindexSequentialGroupLabels(rows) {
        rows = Array.isArray(rows) ? rows : [];
        if (rows.length === 0)
            return rows;

        function isSimpleGroupLabel(value) {
            return /^Group\s+[A-Z]$/i.test(String(value || "").trim());
        }

        function groupLetterForIndex(index) {
            const number = Number(index);
            if (!Number.isFinite(number) || number < 0)
                return "";

            if (number < 26)
                return String.fromCharCode(65 + number);

            // After Z continue as AA, AB, AC...
            let n = number;
            let result = "";
            while (n >= 0) {
                result = String.fromCharCode(65 + (n % 26)) + result;
                n = Math.floor(n / 26) - 1;
            }
            return result;
        }

        let normalized = [];
        let previousGroup = "";
        let currentAssignedGroup = "";
        let groupSectionIndex = 0;

        rows.forEach((row) => {
            const copy = Object.assign({}, row || {});
            const group = String(copy.group || "").trim();
            if (group.length === 0) {
                normalized.push(copy);
                return;
            }

            if (group !== previousGroup) {
                if (isSimpleGroupLabel(group)) {
                    currentAssignedGroup = "Group " + groupLetterForIndex(groupSectionIndex);
                    groupSectionIndex += 1;
                } else {
                    currentAssignedGroup = group;
                }
                previousGroup = group;
            }

            copy.group = currentAssignedGroup;
            normalized.push(copy);
        });

        return normalized;
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



    function effectiveProvider() {
        return "sportscore";
    }

    function effectiveBaseUrl(sport) {
        return "https://sportscore.com";
    }

    function effectiveApiKey(sport) {
        return "";
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
    toolTipMainText: ""
    toolTipSubText: ""
    toolTipItem: MatchesToolTip {
        liveModel: tooltipLiveMatchesModel
        scheduleModel: tooltipScheduleMatchesModel
    }
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
        dynamicRoles: true
    }

    ListModel {
        id: scoresModel
        dynamicRoles: true
    }

    ListModel {
        id: panelLiveMatchesModel
        dynamicRoles: true
    }

    ListModel {
        id: panelScheduleMatchesModel
        dynamicRoles: true
    }

    ListModel {
        id: tooltipLiveMatchesModel
        dynamicRoles: true
    }

    ListModel {
        id: tooltipScheduleMatchesModel
        dynamicRoles: true
    }

    ListModel {
        id: tableModel
        dynamicRoles: true
    }

    ListModel {
        id: recentResultsListModel
        dynamicRoles: true
    }

    Timer {
        id: refreshTimer

        interval: root.refreshIntervalMs()
        repeat: true
        running: true
        onTriggered: root.refreshScores(false)
    }

    Timer {
        id: liveRefreshTimer

        interval: root.liveRefreshIntervalMs()
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
        id: refreshWatchdogTimer

        interval: root.sectionRequestTimeoutMs
        repeat: false
        onTriggered: {
            if (root.pendingRequests <= 0)
                return;

            root.pendingRequests = 0;
            root.loading = false;
            root.liveLoading = false;
            if (root.schedulesLoading && scoresModel.count === 0)
                deferEmptySchedulesMessage("");
            else
                root.schedulesLoading = false;

            root.recentResultsLoading = false;
            root.liveRefreshInFlight = false;
            root.tableRequestCompleted = true;
            root.scheduleRequestCompleted = true;
            tableFallbackTimer.stop();
            if (tableModel.count === 0 && root.tableErrorMessage.length === 0)
                root.tableErrorMessage = i18nc("@info:status", "Table request timed out.");
        }
    }

    Timer {
        id: liveRefreshWatchdogTimer

        interval: root.sectionRequestTimeoutMs
        repeat: false
        onTriggered: {
            if (!root.liveRefreshInFlight)
                return;

            root.liveRefreshToken += 1;
            root.liveLoading = false;
            root.liveRefreshInFlight = false;
        }
    }

    Timer {
        id: teamTableWatchdogTimer

        interval: root.sectionRequestTimeoutMs
        repeat: false
        onTriggered: {
            if (!root.teamTableLoading)
                return;

            root.teamTableRequestToken += 1;
            root.teamTableLoading = false;
            if (tableModel.count === 0 && root.tableErrorMessage.length === 0)
                root.tableErrorMessage = i18nc("@info:status", "Table request timed out.");
        }
    }

    Timer {
        id: teamTableSeasonWatchdogTimer

        interval: root.sectionRequestTimeoutMs
        repeat: false
        onTriggered: {
            if (!root.teamTableSeasonLoading)
                return;

            root.teamTableSeasonRequestToken += 1;
            root.teamTableSeasonLoading = false;
            root.pendingSeasonTableRefresh = false;
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

        function onRefreshIntervalChanged() {
            root.scheduleConfigRefresh();
        }

        function onLiveRefreshEnabledChanged() {
            if (root.liveRefreshIsEnabled() && root.hasSportSelection()) {
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

        function onSmartRefreshEnabledChanged() {
            refreshTimer.restart();
            if (root.liveRefreshIsEnabled() && root.hasSportSelection()) {
                liveRefreshTimer.restart();
                root.refreshLiveMatches(true);
            } else {
                liveRefreshTimer.stop();
            }
        }

        function onMatchDateFormatChanged() {
            root.reformatDisplayedMatches();
        }

        function onMatchTimeFormatChanged() {
            root.reformatDisplayedMatches();
        }

        function onNationalTeamVisualStyleChanged() {
            root.reformatDisplayedMatches();
            root.applyTable(root.tableRows, false);
        }

        function onSelectedSportsChanged() {
            root.scheduleConfigRefresh();
        }

        function onSavedLeaguesChanged() {
            root.ensureActiveSport();
            Qt.callLater(root.refreshAuxiliaryMatchModels);
            root.scheduleConfigRefresh();
        }

        function onDefaultSportChanged() {
            const next = root.initialSport();
            if (next !== root.activeSport) {
                root.selectActiveSport(next);
                return;
            }
            root.scheduleConfigRefresh();
        }

        function onActiveSavedLeagueIndexChanged() {
            root.syncTeamTableOptions();
        }

    }

    compactRepresentation: CompactRepresentation {
        liveCount: panelLiveMatchesModel.count
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
        sport: root.matchField(root.panelHeroMatch, "sport") || root.primarySport
        matchRotationEnabled: Plasmoid.configuration.panelMatchRotationEnabled
        matchRotationInterval: Plasmoid.configuration.panelMatchRotationInterval
        matchRotationCount: root.panelRotationCount
        onRotateMatchRequested: root.advancePanelRotation()
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
        sourceText: root.sourceText
        primaryText: root.primaryMatchText
        secondaryText: root.secondaryMatchText
        sportCount: root.availableSports.length
        availableSports: root.availableSports
        selectedSport: root.activeSport
        sport: root.primarySport
        hasSavedLeagues: root.savedLeagueCount > 0
        savedLeagues: root.activeSportEntries
        savedLeagueCount: root.activeSportEntries.length
        activeSavedLeagueIndex: root.activeSavedLeagueIndex
        activeLeagueLabel: root.activeDisplayLabel
        activeCountryLabel: root.activeDisplayCountryLabel
        tableLeagueLabel: root.currentDisplayTableLabel()
        followTeamMode: root.teamWatchMode()
        teamTableOptions: root.teamTableOptions
        selectedTableSlug: root.currentDisplayTableSlug()
        teamTableSeasonOptions: root.teamTableSeasonOptions
        selectedTableSeasonKey: root.selectedTeamTableSeasonKey
        teamTableSeasonLoading: root.teamTableSeasonLoading
        tableLoading: root.teamTableLoading || root.teamTableSeasonLoading
        tableModel: tableModel
        tableRows: root.tableRows
        league: root.selectedLeague
        tableCount: root.tableCount
        recentResultsCount: root.recentResultsCount
        widgetTabs: Plasmoid.configuration.widgetTabs
        widgetLayoutMode: Plasmoid.configuration.widgetLayoutMode
        matchRotationEnabled: Plasmoid.configuration.widgetMatchRotationEnabled
        matchRotationInterval: Plasmoid.configuration.widgetMatchRotationInterval
        favoriteTeam: root.teamWatchMode() && root.watchedTeamNames().length === 1 ? root.effectiveFavoriteTeamName() : ""
        onRefreshRequested: root.refreshScores(true)
        onConfigureRequested: root.openSportSettings()
        onLeagueSelected: (index) => root.setActiveSavedLeagueIndex(index)
        onSportSelected: (sport) => root.selectActiveSport(sport)
        onTeamTableSelected: (slug) => root.selectTeamTable(slug)
        onTeamTableSeasonSelected: (seasonKey) => root.selectTeamTableSeason(seasonKey)
    }

}
