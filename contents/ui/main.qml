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
import "../code/MatchNotifications.js" as MatchNotifications
import "../code/CalendarSync.js" as CalendarSync
import "../code/providers/ProviderCatalog.js" as ProviderCatalog
import "../code/providers/ProviderCountries.js" as ProviderCountries
import "../code/providers/PopularCatalog.js" as PopularCatalog
import "config" as WizardConfig
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.notification
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    property bool loading: false
    property string errorMessage: ""
    property string tableErrorMessage: ""
    property string lastUpdatedText: ""
    property int liveCount: liveMatchesModel.count
    // Upcoming matches in the panel scope (simple mode count): kickoff within the
    // next 24 hours, or every future fixture, per panelSimpleScheduleWindow.
    readonly property int panelRemainingCount: String(Plasmoid.configuration.panelSimpleScheduleWindow || "next24h") === "all"
        ? panelScheduleMatchesModel.count
        : root.next24hUpcomingCount(panelScheduleMatchesModel)
    // Real-match counts come from the source arrays, not the list models, because
    // the Recent/Schedule models also hold invisible placeholder rows (group
    // headers for not-yet-loaded lazy groups) that must not inflate these counts.
    property int scheduleCount: root.latestScheduleMatches.length
    property int tableCount: tableModel.count
    property int recentResultsCount: root.latestRecentMatches.length
    property bool tableRequestCompleted: false
    property bool currentManualRefresh: false
    property bool liveLoading: false
    property bool schedulesLoading: false
    property bool recentResultsLoading: false
    property bool liveRefreshInFlight: false
    property int consecutiveEmptyLiveRefreshes: 0
    property string lastLiveScopeSignature: ""
    // Entries whose live fetch failed on the most recent refresh (e.g. a
    // SportScore 504). A match disappearing only because of one of these is a
    // fetch failure, not the match ending - see pushMatchNotifications().
    property var lastLiveFetchFailedEntries: []
    property bool scheduleRequestCompleted: false
    property bool tableScheduleFallbackStarted: false
    property bool recentResultsTableFallbackStarted: false
    // Lazy-loading state. To avoid over-requesting, only the first saved entry's
    // Recent/Schedule data is fetched up front; every other group is fetched the
    // first time the user expands it (then kept). These track which group labels
    // have already been fetched in the current refresh cycle so a re-expand is a
    // no-op, and which groups should start collapsed.
    // Schedule groups already attempted this refresh cycle (cleared on refresh), so
    // a group that legitimately has no upcoming fixtures isn't re-fetched on every
    // re-expand, yet is re-checked after the next refresh.
    property var attemptedScheduleGroups: ({})
    // Recent groups whose lazy load has completed (cleared on refresh) - drives the
    // "no recent matches" notice for an expanded group that came back empty.
    property var recentAttemptedGroups: ({})
    property var collapsedRecentGroups: ({})
    property var collapsedScheduleGroups: ({})
    // Leagues tab: groups start collapsed, so this only records groups the user
    // has explicitly expanded (value false) or re-collapsed (value true).
    property var leaguesCollapsedGroups: ({})
    // Re-render the lists when a group is collapsed/expanded so collapsed groups
    // drop their match rows from the model entirely (kept lightweight: in-memory,
    // no refetch). Guarded so the very first assignment during startup doesn't run
    // before the helpers/models exist.
    property bool _modelRebuildReady: false
    onCollapsedRecentGroupsChanged: if (_modelRebuildReady)
        rebuildRecentModel()
    onCollapsedScheduleGroupsChanged: if (_modelRebuildReady)
        rebuildScheduleModel()
    // In-flight per-group loads, so a rapid double-expand can't fire two fetches.
    property var pendingRecentGroups: ({})
    property var pendingScheduleGroups: ({})
    property int refreshToken: 0
    property int liveRefreshToken: 0
    // Wall-clock of the last wake-detector tick; a large jump between ticks means
    // the machine was suspended (timers freeze during sleep), so we force a
    // refresh on resume instead of showing pre-sleep "live" matches.
    property double lastWakeTickMs: 0
    // Memo for matchForModel, keyed by display-relevant match fields. Cleared each
    // full refresh (bounds growth) and on format-config changes.
    property var _matchModelCache: ({})
    // Cached "today" so per-match start-time formatting doesn't allocate a Date for
    // it on every call; refreshed at most once a minute.
    property var _todayDate: null
    property double _todayDateMs: 0
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
    // Bumped after any per-match action toggle so bound icon states in the match
    // rows re-evaluate against the freshly written config maps.
    property int matchActionsTick: 0
    // Transient message shown in the popup after pinning a match auto-unpinned
    // the previously pinned one(s); cleared on dismiss or after a few seconds.
    property string pinNotice: ""
    // Set just before a quick-favourite star writes savedLeagues, so the
    // onSavedLeaguesChanged handler can take a light path (lazily load only the
    // new team's groups) instead of the full forced refresh, which cleared and
    // refetched every model and froze the shell for seconds per click.
    property bool quickFavoriteEditPending: false
    property string quickFavoritePendingGroup: ""
    readonly property int panelRotationCount: panelMatchRotationCount()
    property string primaryMatchText: panelLiveMatchesModel.count > 0 ? panelLiveMatchesModel.get(0).homeTeam + " vs " + panelLiveMatchesModel.get(0).awayTeam : panelScheduleMatchesModel.count > 0 ? panelScheduleMatchesModel.get(0).homeTeam + " vs " + panelScheduleMatchesModel.get(0).awayTeam : panelEmptyStatusText()
    property string secondaryMatchText: panelLiveMatchesModel.count > 0 ? panelLiveMatchesModel.get(0).minute || panelLiveMatchesModel.get(0).status : panelScheduleMatchesModel.count > 0 ? panelScheduleMatchesModel.get(0).startTime || panelScheduleMatchesModel.get(0).status : root.hasSportSelection() ? sourceText : i18nc("@info:status", "Open settings to add a league")
    property var panelHeroMatch: (root.matchActionsTick, panelMatchForRotation())
    property bool panelHeroLive: matchField(panelHeroMatch, "status") === "Live"
    property string panelHeroText: panelHeroLive ? panelTeamsScoreText(panelHeroMatch) : matchField(panelHeroMatch, "homeTeam").length > 0 ? panelScheduleText(panelHeroMatch) : panelEmptyStatusText()
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
    // Matches to show side by side in the panel's "stack" mode: live ones first,
    // then upcoming as filler, capped by panelStackMaxMatches. Each entry is a
    // plain object with the fields the compact stack cell needs.
    property var panelStackMatches: (root.matchActionsTick, buildPanelStackMatches())
    property string selectedSport: activeSport
    property string selectedLeagueLabel: displayLeagueLabel(activeLeagueEntry)
    property string selectedCountryLabel: displayCountryLabel(activeLeagueEntry)
    property string activeDisplayLabel: activeTitleLabel()
    property string activeDisplayCountryLabel: activeSubtitleLabel()
    readonly property string nationalTeamVisualStyle: String(Plasmoid.configuration.nationalTeamVisualStyle || "emblems").trim()
    property string primarySport: liveMatchesModel.count > 0 ? liveMatchesModel.get(0).sport : root.latestScheduleMatches.length > 0 ? String(root.latestScheduleMatches[0].sport || "") : SportVisuals.normalizedSport(selectedSport)
    property int pendingRequests: 0
    property var refreshErrors: []
    property var tableRows: []
    property var primaryTableRows: []
    property var latestLiveMatches: []
    property var latestScheduleMatches: []
    property var notifyLiveSnapshot: ({})
    property bool notifyHasBaseline: false
    // Opt-in detailed events (goal scorer / cards / substitutions): map of
    // matchId -> array of incidentId strings already notified for that match.
    property var notifyIncidentIds: ({})
    property bool detailedEventsPollInFlight: false
    property var startsSoonAnnounced: ({})
    property string lastCalendarSnapshot: ""
    property string lastCalendarIcs: ""
    property bool calendarAkonadiEnsured: false
    property var pendingCalendarRows: []
    property bool calendarHadData: false
    property var latestRecentMatches: []
    // Which data providers actually supplied the currently-loaded matches, so the
    // footer can credit each one in use (SportScore and/or ESPN). Recomputed
    // whenever the loaded match sets change.
    readonly property var activeProviders: root.computeActiveProviders(root.latestLiveMatches, root.latestScheduleMatches, root.latestRecentMatches)
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

    // Placeholder for the panel when no match is available yet: while a refresh
    // is in flight show "Updating" instead of a premature "No scheduled matches"
    // (visible for several seconds after plasmashell restarts).
    function panelEmptyStatusText() {
        if (!root.hasSportSelection())
            return i18nc("@action:button", "Add a sport");
        if (root.loading || root.schedulesLoading || root.liveLoading)
            return i18nc("@info:status", "Updating…");
        return i18nc("@info:status", "No scheduled matches");
    }

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

    // Scheduled matches kicking off within the next 24 hours. No lower bound:
    // the schedule models already exclude started matches (they move to Live),
    // so anything still listed with a known kickoff before the cutoff counts.
    function next24hUpcomingCount(model) {
        const cutoff = Date.now() + 24 * 60 * 60 * 1000;
        const count = model && model.count !== undefined ? Number(model.count) : 0;
        let upcoming = 0;
        for (let index = 0; index < count; index += 1) {
            const timestamp = root.normalizedMatchTimestamp(model.get(index));
            if (timestamp > 0 && timestamp < cutoff)
                upcoming += 1;
        }
        return upcoming;
    }

    function panelMatchRotationCount() {
        if (panelLiveMatchesModel.count > 0)
            return panelLiveMatchesModel.count;
        return root.upcomingRotationIndexes(panelScheduleMatchesModel).length;
    }

    // The pinned match, if the user pinned one that is in the current panel
    // scope, takes precedence over rotation. Live pins beat upcoming pins.
    function pinnedPanelMatch() {
        for (let i = 0; i < panelLiveMatchesModel.count; i += 1) {
            const match = panelLiveMatchesModel.get(i);
            if (root.matchPinnedToPanel(match))
                return match;
        }
        for (let j = 0; j < panelScheduleMatchesModel.count; j += 1) {
            const match = panelScheduleMatchesModel.get(j);
            if (root.matchPinnedToPanel(match))
                return match;
        }
        return null;
    }

    function panelMatchForRotation() {
        // A user-pinned match overrides rotation entirely while it is in scope.
        const pinned = root.pinnedPanelMatch();
        if (pinned)
            return pinned;

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

    // Flattens a panel match into the minimal record the compact stack cell
    // renders (teams, score, badges, live state). Pinned matches are floated to
    // the front so a user pin is always visible in stack mode too.
    function panelStackCell(match) {
        const live = root.matchField(match, "status") === "Live";
        return {
            "homeTeam": root.matchField(match, "homeTeam"),
            "awayTeam": root.matchField(match, "awayTeam"),
            "homeScore": root.matchField(match, "homeScore"),
            "awayScore": root.matchField(match, "awayScore"),
            "homeBadge": root.matchField(match, "homeBadge"),
            "awayBadge": root.matchField(match, "awayBadge"),
            "isLive": live,
            "liveText": live ? root.panelLiveText(match) : "",
            "statusText": root.matchStatusText(match),
            "startTime": root.matchField(match, "startTime"),
            "showScore": root.matchBooleanField(match, "showScore", live),
            "pinned": root.matchPinnedToPanel(match),
            "sport": root.matchField(match, "sport")
        };
    }

    function buildPanelStackMatches() {
        const max = Math.max(2, Number(Plasmoid.configuration.panelStackMaxMatches) || 3);
        const cells = [];
        const seen = {};
        const push = (match) => {
            if (cells.length >= max)
                return;
            const key = root.stableMatchKey(match);
            if (key.length > 0 && seen[key])
                return;
            seen[key] = true;
            cells.push(root.panelStackCell(match));
        };

        // Pinned matches first (live or upcoming), then remaining live, then
        // upcoming fixtures as filler up to the cap.
        for (let p = 0; p < panelLiveMatchesModel.count && cells.length < max; p += 1) {
            const m = panelLiveMatchesModel.get(p);
            if (root.matchPinnedToPanel(m))
                push(m);
        }
        for (let i = 0; i < panelLiveMatchesModel.count && cells.length < max; i += 1)
            push(panelLiveMatchesModel.get(i));

        const upcoming = root.upcomingRotationIndexes(panelScheduleMatchesModel);
        for (let j = 0; j < upcoming.length && cells.length < max; j += 1)
            push(panelScheduleMatchesModel.get(upcoming[j]));

        // Sort pinned cells to the very front, keeping the rest in insertion order.
        cells.sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
        return cells;
    }

    function hasSportSelection() {
        if (root.savedLeagueCount === 0)
            return false;

        return root.liveScopeEntries().length > 0 || root.scheduleScopeEntries().length > 0 || root.recentScopeEntries().length > 0 || root.tableScopeEntries().length > 0;
    }

    // Smart mode picks fixed refresh times (30 min schedules, 60s live) to
    // limit requests; turning it off lets the user pick their own values.
    function refreshIntervalMs() {
        // Smart mode: the full refresh (live + schedules + recent + tables for all
        // saved entries) is heavier than the live poll, so it runs sparsely while
        // idle and tightens only while something is live or about to start - to keep
        // schedules/recent/tables current during matches without over-requesting at
        // other times. Manual mode keeps the user's configured interval.
        if (Plasmoid.configuration.smartRefreshEnabled) {
            return root.hasImminentOrLiveActivity() ? root.smartActiveFullRefreshMs : root.smartIdleFullRefreshMs;
        }
        const minutes = Plasmoid.configuration.refreshInterval;
        return Math.max(1, minutes) * 60 * 1000;
    }

    // Full-refresh cadence in smart mode: tighter while live/imminent, sparse while
    // idle. Active stays well above the 60 s live poll since a full refresh touches
    // every saved entry across every tab.
    readonly property int smartActiveFullRefreshMs: 5 * 60 * 1000
    readonly property int smartIdleFullRefreshMs: 30 * 60 * 1000

    function liveRefreshIntervalMs() {
        // Smart mode polls fast (60 s, matching SportScore's 60 s edge cache) only
        // while something is live or about to kick off; otherwise it idles slowly to
        // avoid over-requesting - the whole point of the option. A one-shot timer
        // scheduled for the next kickoff (see scheduleKickoffWake) guarantees the
        // transition is caught promptly even while idling. Manual mode keeps the
        // user's fixed interval.
        if (Plasmoid.configuration.smartRefreshEnabled)
            return root.hasImminentOrLiveActivity() ? 60000 : root.smartIdleLiveIntervalMs;
        const seconds = Number(Plasmoid.configuration.liveRefreshInterval || 60);
        return Math.max(10, seconds) * 1000;
    }

    // Idle live-poll cadence in smart mode when nothing is live or imminent.
    readonly property int smartIdleLiveIntervalMs: 10 * 60 * 1000
    // A match counts as "imminent" from this long before kickoff (so the fast poll
    // and local promotion are already active when it starts).
    readonly property int kickoffImminentLeadMs: 5 * 60 * 1000
    // How long after kickoff a started match is still treated as live without the
    // provider confirming the finish. Long enough to cover a full match incl. extra
    // time and penalties (~2.5 h), with margin; after this a not-yet-updated match
    // stops being shown as live so it can't linger as a phantom. The live poll
    // normally moves it to a real finished state well before this.
    readonly property int liveGraceAfterKickoffMs: 2.75 * 60 * 60 * 1000

    // (Re)arm the one-shot kickoff wake for the next upcoming match. Fires shortly
    // after kickoff (the lead makes promotion active a touch early; a small pad
    // covers clock skew) so a starting match enters Live without waiting for the
    // slow idle poll. Clamped so it never schedules absurdly far out.
    function armKickoffWake() {
        kickoffWakeTimer.stop();
        if (!root.hasSportSelection() || !root.liveRefreshIsEnabled())
            return;

        const next = root.nextKickoffMs();
        if (next <= 0)
            return;

        const now = Date.now();
        // Wake when the match becomes "imminent" (lead before kickoff); if that is
        // already past, wake almost immediately. Cap the wait at the idle interval
        // so we re-check periodically regardless.
        let delay = next - root.kickoffImminentLeadMs - now;
        if (delay < 1000)
            delay = 1000;
        kickoffWakeTimer.interval = Math.min(delay, root.smartIdleLiveIntervalMs);
        kickoffWakeTimer.start();
    }

    // Earliest future kickoff among the scheduled matches, or 0 if none.
    function nextKickoffMs() {
        const now = Date.now();
        let next = 0;
        (Array.isArray(root.latestScheduleMatches) ? root.latestScheduleMatches : []).forEach(match => {
            if (SportsApi.isFinishedMatch(match))
                return;
            const ts = Number(match && match.timestamp || 0);
            if (ts > now && (next === 0 || ts < next))
                next = ts;
        });
        return next;
    }

    // True when any match is live now, or kicked off within the live grace window,
    // or kicks off within the imminent lead - i.e. when fast polling is worthwhile.
    function hasImminentOrLiveActivity() {
        if (liveMatchesModel.count > 0)
            return true;

        const now = Date.now();
        const all = (Array.isArray(root.latestScheduleMatches) ? root.latestScheduleMatches : []).concat(Array.isArray(root.latestLiveMatches) ? root.latestLiveMatches : []);
        return all.some(match => {
            if (SportsApi.isLiveMatch(match))
                return true;
            if (SportsApi.isFinishedMatch(match))
                return false;
            const ts = Number(match && match.timestamp || 0);
            if (ts <= 0)
                return false;
            return ts >= now - root.liveGraceAfterKickoffMs && ts <= now + root.kickoffImminentLeadMs;
        });
    }

    // A match the widget should display as live: the provider says so, OR its
    // kickoff has passed and it isn't finished yet (within the grace window). The
    // second case is what makes a 20:00 match appear at 20:00 instead of whenever
    // the provider's status finally flips.
    function isEffectivelyLive(match) {
        if (SportsApi.isLiveMatch(match))
            return true;
        if (SportsApi.isFinishedMatch(match))
            return false;
        const ts = Number(match && match.timestamp || 0);
        if (ts <= 0)
            return false;
        const now = Date.now();
        return ts <= now && ts >= now - root.liveGraceAfterKickoffMs;
    }

    // A gap between wake-detector ticks (which fire every 15 s) beyond this means
    // the machine was asleep. Fixed at 2 minutes - far above normal timer jitter,
    // well below any real suspend - and independent of the live-poll cadence (which
    // now varies in smart mode and would otherwise make this threshold too large).
    function wakeRefreshThresholdMs() {
        return 120000;
    }

    function handleSystemWake() {
        // Live matches shown from before the suspend are almost certainly stale
        // (often already finished). Drop them right away so the user never sees
        // phantom live games, then pull everything fresh.
        liveMatchesModel.clear();
        root.latestLiveMatches = [];
        root.refreshScores(true);
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
        leaguesMatchesModel.clear();
        recentResultsListModel.clear();
        tableModel.clear();
        panelLiveMatchesModel.clear();
        panelScheduleMatchesModel.clear();
        tooltipLiveMatchesModel.clear();
        tooltipScheduleMatchesModel.clear();
        tooltipRecentMatchesModel.clear();
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
        return JSON.stringify(root.liveScopeEntries().map(entry => ({
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

    // ─── Lazy group loading ──────────────────────────────────────────────────
    // Build the initial collapse map for a set of scope entries: the first entry's
    // group is expanded, all others collapsed. Returns { groupLabel: true } for the
    // collapsed ones.
    function initialCollapsedGroups(entries) {
        const list = Array.isArray(entries) ? entries : [];
        const map = ({});
        list.forEach((entry, index) => {
            if (index === 0)
                return;
            const group = root.entryGroupLabel(entry);
            if (group.length > 0)
                map[group] = true;
        });
        return map;
    }

    // Fetch a single entry's matches for one tab and merge them into the existing
    // model without disturbing the already-loaded groups. `fetcher` is the same
    // SportsApi function used by the bulk path; `appendFn(scopeGroup, rows, ok)` is
    // always called exactly once - on success or failure - so the caller can clear
    // its pending flag and decide whether to mark the group loaded. Deliberately NOT
    // gated on the refresh token: a lazy expand is user-initiated and must complete
    // even if a periodic refresh happens to fire while it is in flight.
    function loadGroupForEntry(entry, override, fetcher, appendFn, scopeOrder) {
        const scopeGroup = root.entryGroupLabel(entry);
        const order = Number.isFinite(scopeOrder) ? scopeOrder : 0;
        const options = root.requestOptionsForEntry(entry, root.refreshToken, false, override);
        fetcher(options, matches => {
            const scoped = (Array.isArray(matches) ? matches : []).filter(match => root.matchBelongsToEntry(entry, match)).map(match => {
                const copy = Object.assign({}, match || {});
                copy.scopeGroup = scopeGroup;
                copy.scopeOrder = order;
                return copy;
            });
            appendFn(scopeGroup, scoped, true);
        }, () => {
            appendFn(scopeGroup, [], false);
        });
    }

    // Does the in-memory recent data already hold matches for this group? Used to
    // decide whether an expanded group still needs fetching, instead of trusting a
    // "loaded" flag that a subsequent refresh (which clears latestRecentMatches)
    // can leave stale - the cause of a group showing expanded but empty.
    function recentGroupHasData(group) {
        const key = String(group || "").trim();
        return (Array.isArray(root.latestRecentMatches) ? root.latestRecentMatches : []).some(match => String(match && match.scopeGroup || "").trim() === key);
    }

    function recentGroupAttempted(group) {
        return Boolean(root.recentAttemptedGroups[String(group || "").trim()]);
    }

    // Triggered when the user expands a Recent Results group. Fetches that group's
    // results on demand (once), then keeps them.
    function requestRecentGroupLoad(group) {
        const key = String(group || "").trim();
        if (key.length === 0)
            return;

        const next = Object.assign({}, root.collapsedRecentGroups);
        delete next[key];
        root.collapsedRecentGroups = next;

        // Already in flight, or already have its data → nothing to fetch. Note we
        // check actual data presence, not just a "loaded" flag, so a group whose
        // data was dropped by a refresh re-fetches when expanded again.
        // Skip if in flight, if we already have its data, or if it was already tried
        // this cycle and came back empty (attempted marker is cleared on refresh).
        if (root.pendingRecentGroups[key] || root.recentGroupHasData(key) || root.recentAttemptedGroups[key])
            return;
        const entries = root.recentScopeEntries();
        const order = entries.findIndex(e => root.entryGroupLabel(e) === key);
        const entry = order >= 0 ? entries[order] : null;
        if (!entry)
            return;

        root.pendingRecentGroups = Object.assign({}, root.pendingRecentGroups, {
            [key]: true
        });
        root.loadGroupForEntry(entry, {
            "preferTeamRecentResults": true,
            "recentResultsLimit": 80,
            "recentResultsPerTeam": 50
        }, SportsApi.fetchRecentResults, (scopeGroup, scoped, ok) => {
            const pend = Object.assign({}, root.pendingRecentGroups);
            delete pend[key];
            root.pendingRecentGroups = pend;
            if (ok) {
                root.recentAttemptedGroups = Object.assign({}, root.recentAttemptedGroups, {
                    [key]: true
                });
                if (Array.isArray(scoped) && scoped.length > 0)
                    root.mergeRecentResults(scoped);
                else
                    root.rebuildRecentModel();
            }
        }, order);
    }

    // Expand + lazily load the currently-active entry's Recent and Schedule groups.
    // Called when the user switches the active entry so its data appears without a
    // manual expand. Both request* functions are no-ops if the group is already
    // loaded, so this never re-fetches.
    function loadActiveEntryGroups() {
        const group = root.entryGroupLabel(root.activeLeagueEntry);
        if (group.length === 0)
            return;
        root.requestRecentGroupLoad(group);
        root.requestScheduleGroupLoad(group);
    }

    function collapseRecentGroup(group) {
        const key = String(group || "").trim();
        if (key.length === 0)
            return;
        root.collapsedRecentGroups = Object.assign({}, root.collapsedRecentGroups, {
            [key]: true
        });
    }

    function collapseScheduleGroup(group) {
        const key = String(group || "").trim();
        if (key.length === 0)
            return;
        root.collapsedScheduleGroups = Object.assign({}, root.collapsedScheduleGroups, {
            [key]: true
        });
    }

    // Toggle a league row in the Leagues tab. Groups default to collapsed, so an
    // unset key is treated as collapsed and the first toggle expands it.
    function toggleLeaguesGroup(group) {
        const key = String(group || "").trim();
        if (key.length === 0)
            return;
        const current = root.leaguesCollapsedGroups[key];
        const collapsed = current === undefined ? true : Boolean(current);
        root.leaguesCollapsedGroups = Object.assign({}, root.leaguesCollapsedGroups, {
            [key]: !collapsed
        });
    }

    // Does the in-memory schedule data already hold matches for this group?
    function scheduleGroupHasData(group) {
        const key = String(group || "").trim();
        return (Array.isArray(root.latestScheduleMatches) ? root.latestScheduleMatches : []).some(match => String(match && match.scopeGroup || "").trim() === key);
    }

    // Triggered when the user expands a Schedule group.
    function requestScheduleGroupLoad(group) {
        const key = String(group || "").trim();
        if (key.length === 0)
            return;

        const next = Object.assign({}, root.collapsedScheduleGroups);
        delete next[key];
        root.collapsedScheduleGroups = next;

        // Skip if a fetch is in flight, if we already have this group's fixtures, or
        // if we already tried this refresh cycle and it legitimately had none (a
        // team can simply have no upcoming fixtures - off-season). The "attempted"
        // marker is cleared on each refresh, so a later expand re-checks. Unlike a
        // plain "loaded" flag, this never leaves a group stuck empty after a refresh
        // wipes its data: data-presence is re-evaluated and the attempt re-runs.
        if (root.pendingScheduleGroups[key] || root.scheduleGroupHasData(key) || root.attemptedScheduleGroups[key])
            return;
        const entries = root.scheduleScopeEntries();
        const order = entries.findIndex(e => root.entryGroupLabel(e) === key);
        const entry = order >= 0 ? entries[order] : null;
        if (!entry)
            return;

        root.pendingScheduleGroups = Object.assign({}, root.pendingScheduleGroups, {
            [key]: true
        });
        root.loadGroupForEntry(entry, {
            "preferTeamRecentResults": false
        }, SportsApi.fetchScoresFixtures, (scopeGroup, scoped, ok) => {
            const pend = Object.assign({}, root.pendingScheduleGroups);
            delete pend[key];
            root.pendingScheduleGroups = pend;
            // Mark attempted only on a successful fetch (so a real failure retries on
            // re-expand). An empty success is a valid "no upcoming fixtures" result.
            if (ok) {
                root.attemptedScheduleGroups = Object.assign({}, root.attemptedScheduleGroups, {
                    [key]: true
                });
                root.mergeScheduleMatches(scoped);
            }
        }, order);
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

        // Quick favourites (one-click star) rank just after the saved favourites,
        // so a starred team's matches still float above the rest of its league.
        if (root.quickFavoriteMap()[normalizedTeam.toLowerCase()] === true)
            return names.length;

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

    // Section label for a saved entry: the followed team's name for a team entry,
    // the competition label otherwise. Used to group Recent Results per team.
    function entryGroupLabel(entry) {
        if (root.entryType(entry) === "team") {
            const team = String(root.displayFavoriteTeam(entry) || "").trim();
            if (team.length > 0)
                return team;
        }
        return String(root.displayLeagueLabel(entry) || "").trim();
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
        return String(Plasmoid.configuration.matchDateFormat || "dd.MM.yy").trim();
    }

    // How far ahead (days) the Schedules tab looks for fixtures (Appearance →
    // Widget → Scheduled), clamped to the supported range.
    function configuredScheduleDaysAhead() {
        return Math.min(365, Math.max(1, Number(Plasmoid.configuration.widgetScheduleDaysAhead) || 150));
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
        return left.getFullYear() === right.getFullYear() && left.getMonth() === right.getMonth() && left.getDate() === right.getDate();
    }

    function currentDayDate() {
        const now = Date.now();
        if (root._todayDate === null || (now - root._todayDateMs) > 60000) {
            root._todayDate = new Date(now);
            root._todayDateMs = now;
        }
        return root._todayDate;
    }

    function formattedMatchStartTime(match) {
        const timestamp = Number(match && match.timestamp || 0);
        if (timestamp <= 0)
            return String(match && match.startTime || "").trim();

        const date = new Date(timestamp);
        const timeText = formatConfiguredTime(date);
        if (sameCalendarDay(date, root.currentDayDate()))
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

    // matchForModel runs locale date formatting + badge resolution per match, and
    // the same matches flow through several models (main + panel + tooltip) each
    // refresh - so memoize the expensive result. The key encodes every
    // display-relevant field (incl. score/status/minute), so any live change
    // misses the cache and recomputes; only format-config changes need an explicit
    // clear (see clearMatchModelCache). A fresh shallow copy is returned so callers
    // that tweak the row (e.g. leagueGroup) can't poison the shared entry.
    function matchModelCacheKey(match) {
        return root.matchKey(match) + "|" + String(match && match.minute || "");
    }

    function clearMatchModelCache() {
        root._matchModelCache = ({});
    }

    function matchForModel(match) {
        const key = root.matchModelCacheKey(match);
        const cached = root._matchModelCache[key];
        if (cached !== undefined)
            return Object.assign({}, cached);

        const copy = Object.assign({}, match || {});
        copy.homeBadge = root.preferredTeamBadge(copy.homeTeam, copy.homeBadge);
        copy.awayBadge = root.preferredTeamBadge(copy.awayTeam, copy.awayBadge);
        copy.showScore = matchHasDisplayScore(copy);
        copy.startTime = formattedMatchStartTime(copy);
        root._matchModelCache[key] = copy;
        return Object.assign({}, copy);
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
            // The competition a followed team came from, so ESPN can resolve the
            // team's league even when its country doesn't map to a single one.
            "teamLeague": type === "team" ? String(entry && (entry.teamLeague || entry.league) || "").trim() : "",
            "competitionPath": type === "team" ? "" : String(entry && (entry.competitionPath || entry.leaguePath) || "").trim(),
            "favoriteTeam": type === "team" ? String(entry && entry.favoriteTeam || "").trim() : "",
            "teamSlug": type === "team" ? String(entry && entry.teamSlug || "").trim() : "",
            "teamPath": type === "team" ? String((entry && (entry.teamPath || entry.teamUrl)) || "").trim() : "",
            "followMode": type === "team" ? "team" : "league",
            "refreshToken": token,
            "forceLiveRefresh": Boolean(manual),
            "scoreboardDaysBack": 30,
            "scoreboardDaysForward": root.configuredScheduleDaysAhead()
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

    // Stable identity for a fixture that does NOT change while it is played -
    // unlike matchKey() it omits score/status/minute. Used to persist per-match
    // user choices (notify / pin / quick favourite) across refreshes. The day
    // bucket (not the exact timestamp) keeps the key stable if the provider
    // nudges kickoff time slightly.
    function stableMatchKey(match) {
        const value = match || {};
        const league = String(value.league || "").trim().toLowerCase();
        const home = String(value.homeTeam || "").trim().toLowerCase();
        const away = String(value.awayTeam || "").trim().toLowerCase();
        const timestamp = Number(value.timestamp || 0);
        let day = "";
        if (timestamp > 0) {
            const d = new Date(timestamp);
            day = d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
        } else {
            day = String(value.startTime || "").trim().toLowerCase();
        }
        if (home.length === 0 && away.length === 0)
            return "";
        return [league, home, away, day].join("|");
    }

    function parseJsonMap(raw) {
        try {
            const parsed = JSON.parse(String(raw || "{}"));
            return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
        } catch (error) {
            return {};
        }
    }

    function perMatchNotifyMap() {
        return root.parseJsonMap(Plasmoid.configuration.perMatchNotify);
    }

    function perMatchPinMap() {
        return root.parseJsonMap(Plasmoid.configuration.perMatchPanelPins);
    }

    function quickFavoriteMap() {
        return root.parseJsonMap(Plasmoid.configuration.quickFavoriteTeams);
    }

    function matchNotifyEnabled(match) {
        const key = root.stableMatchKey(match);
        // Legacy entries are plain `true`; newer ones are objects carrying the
        // match details for the Notifications settings page. Both count.
        return key.length > 0 && Boolean(root.perMatchNotifyMap()[key]);
    }

    function matchPinnedToPanel(match) {
        const key = root.stableMatchKey(match);
        return key.length > 0 && root.perMatchPinMap()[key] === true;
    }

    function isQuickFavoriteMatch(match) {
        const favorites = root.quickFavoriteMap();
        const home = String(match && match.homeTeam || "").trim().toLowerCase();
        const away = String(match && match.awayTeam || "").trim().toLowerCase();
        return (home.length > 0 && favorites[home] === true) || (away.length > 0 && favorites[away] === true);
    }

    function toggleMatchNotify(match) {
        const key = root.stableMatchKey(match);
        if (key.length === 0)
            return;

        const map = root.perMatchNotifyMap();
        if (map[key]) {
            delete map[key];
        } else {
            // Store the display details alongside the flag so the Notifications
            // settings page can list this match by name.
            map[key] = {
                "sport": String(match && match.sport || ""),
                "league": String(match && match.league || ""),
                "homeTeam": String(match && match.homeTeam || ""),
                "awayTeam": String(match && match.awayTeam || ""),
                "startTime": String(match && match.startTime || ""),
                "timestamp": Number(match && match.timestamp || 0)
            };
        }
        Plasmoid.configuration.perMatchNotify = JSON.stringify(map);
    }

    function toggleMatchPin(match) {
        const key = root.stableMatchKey(match);
        if (key.length === 0)
            return;

        const map = root.perMatchPinMap();
        if (map[key]) {
            delete map[key];
            Plasmoid.configuration.perMatchPanelPins = JSON.stringify(map);
            return;
        }

        // Only one match drives the panel at a time, so pinning a new match
        // replaces any previous pin. When that actually unpinned something,
        // surface it with a transient inline message in the popup.
        const unpinnedCount = Object.keys(map).length;
        const next = {};
        next[key] = true;
        Plasmoid.configuration.perMatchPanelPins = JSON.stringify(next);

        if (unpinnedCount > 0) {
            const home = String(match && match.homeTeam || "");
            const away = String(match && match.awayTeam || "");
            root.pinNotice = i18ncp("@info %2 and %3 are team names",
                "Pinned %2 vs %3 to the panel - the previously pinned match was unpinned.",
                "Pinned %2 vs %3 to the panel - %1 previously pinned matches were unpinned.",
                unpinnedCount, home, away);
            pinNoticeTimer.restart();
        }
    }

    // Is this specific team name a quick favourite (one-click star)?
    function isQuickFavoriteTeam(teamName) {
        const key = String(teamName || "").trim().toLowerCase();
        return key.length > 0 && root.quickFavoriteMap()[key] === true;
    }

    // Toggle one specific team as a quick favourite. The star UI asks the user
    // which side of the match (home or away) before calling this, so there is no
    // ambiguity about who gets favourited. Favouriting also saves the team as a
    // followed entry (the Sports settings page); unfavouriting removes only
    // entries this shortcut created, never ones added manually in the wizard.
    function toggleQuickFavoriteTeam(teamName, match) {
        const key = String(teamName || "").trim().toLowerCase();
        if (key.length === 0)
            return;

        const map = root.quickFavoriteMap();
        if (map[key]) {
            delete map[key];
            root.removeAutoSavedFavoriteTeam(teamName);
        } else {
            map[key] = true;
            root.autoSaveFavoriteTeam(teamName, match);
        }
        Plasmoid.configuration.quickFavoriteTeams = JSON.stringify(map);
    }

    function parseSavedLeagueEntries() {
        try {
            const parsed = JSON.parse(String(Plasmoid.configuration.savedLeagues || "[]"));
            return Array.isArray(parsed) ? parsed : [];
        } catch (error) {
            return [];
        }
    }

    function savedTeamEntryName(entry) {
        return String((entry && (entry.customFavoriteTeamLabel || entry.favoriteTeam)) || "").replace(/^[★*]\s*/, "").trim().toLowerCase();
    }

    // Adds the starred team to the saved sports entries so it shows up in the
    // Sports settings page and its fixtures are followed, unless a team entry
    // with the same name already exists.
    function autoSaveFavoriteTeam(teamName, match) {
        const name = String(teamName || "").trim();
        if (name.length === 0)
            return;

        const entries = root.parseSavedLeagueEntries();
        const wanted = name.toLowerCase();
        const exists = entries.some(entry => String(entry && entry.type || "") === "team" && root.savedTeamEntryName(entry) === wanted);
        if (exists)
            return;

        const isHome = String(match && match.homeTeam || "").trim().toLowerCase() === wanted;
        entries.push({
            "sport": String(match && match.sport || root.activeSport || "football"),
            "country": "",
            "league": "",
            "favoriteTeam": name,
            "teamBadge": String((isHome ? match && match.homeBadge : match && match.awayBadge) || ""),
            "followMode": "team",
            "type": "team",
            "autoAdded": true
        });
        root.quickFavoriteEditPending = true;
        root.quickFavoritePendingGroup = name;
        Plasmoid.configuration.savedLeagues = JSON.stringify(entries);
    }

    function removeAutoSavedFavoriteTeam(teamName) {
        const wanted = String(teamName || "").trim().toLowerCase();
        if (wanted.length === 0)
            return;

        const entries = root.parseSavedLeagueEntries();
        const kept = entries.filter(entry => !(entry && entry.autoAdded === true
            && String(entry.type || "") === "team"
            && root.savedTeamEntryName(entry) === wanted));
        if (kept.length !== entries.length) {
            // Light path: the removed team's cached rows stay visible until the
            // next regular refresh instead of forcing a full refetch now.
            root.quickFavoriteEditPending = true;
            root.quickFavoritePendingGroup = "";
            Plasmoid.configuration.savedLeagues = JSON.stringify(kept);
        }
    }

    // Drop per-match notify/pin entries for fixtures no longer present in any
    // current model so the maps cannot grow without bound. Called after each
    // full refresh. Keys for matches still in today's data are retained.
    function prunePerMatchState(liveMatches, scheduleMatches) {
        const live = Array.isArray(liveMatches) ? liveMatches : [];
        const upcoming = Array.isArray(scheduleMatches) ? scheduleMatches : [];
        let alive = {};
        live.concat(upcoming).forEach(match => {
            const key = root.stableMatchKey(match);
            if (key.length > 0)
                alive[key] = true;
        });

        ["perMatchNotify", "perMatchPanelPins"].forEach(cfgName => {
            const map = root.parseJsonMap(Plasmoid.configuration[cfgName]);
            let changed = false;
            Object.keys(map).forEach(key => {
                if (!alive[key]) {
                    delete map[key];
                    changed = true;
                }
            });
            if (changed)
                Plasmoid.configuration[cfgName] = JSON.stringify(map);
        });
    }

    function mergeScopedMatches(existing, scopedMatches) {
        let byKey = {};
        (Array.isArray(existing) ? existing : []).forEach(match => {
            const key = root.matchKey(match);
            if (key.length > 0)
                byKey[key] = Object.assign({}, match);
        });
        (Array.isArray(scopedMatches) ? scopedMatches : []).forEach(match => {
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
            if (!Number.isFinite(currentOrder) || (Number.isFinite(nextOrder) && nextOrder < currentOrder)) {
                current.scopeOrder = nextOrder;
                // Keep the group label aligned with the scope it now sorts under, so a
                // match shared by two followed teams renders under the earlier group.
                if (String(match.scopeGroup || "").trim().length > 0)
                    current.scopeGroup = match.scopeGroup;
            }
            if (String(current.league || "").trim().length === 0 && String(match.league || "").trim().length > 0)
                current.league = match.league;
            if (String(current.homeBadge || "").trim().length === 0 && String(match.homeBadge || "").trim().length > 0)
                current.homeBadge = match.homeBadge;
            if (String(current.awayBadge || "").trim().length === 0 && String(match.awayBadge || "").trim().length > 0)
                current.awayBadge = match.awayBadge;
        });

        return Object.keys(byKey).map(key => byKey[key]);
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

            return SportsApi.sameTeamName(match && match.homeTeam, team) || SportsApi.sameTeamName(match && match.awayTeam, team) || SportsApi.sameTeamName(match && match.team, team);
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

    function fetchScopedMatches(entries, token, manual, fetcher, onSuccess, onError, override, onEntryError) {
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
            const scopeGroup = root.entryGroupLabel(entry);
            fetcher(options, matches => {
                const scopedMatches = (Array.isArray(matches) ? matches : []).filter(match => root.matchBelongsToEntry(entry, match)).map(match => {
                    const copy = Object.assign({}, match || {});
                    copy.scopeOrder = index;
                    copy.scopeGroup = scopeGroup;
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
            }, message => {
                const text = String(message || "").trim();
                if (text.length > 0)
                    errors.push(text);
                // A failed entry is NOT "this entry has no live matches" - its
                // previously-live matches must not be treated as finished just
                // because this one fetch (e.g. a SportScore 504) came back empty.
                if (onEntryError)
                    onEntryError(entry);
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
            kickoffWakeTimer.stop();
            configRefreshTimer.stop();
            emptySchedulesTimer.stop();
            tableFallbackTimer.stop();
            refreshWatchdogTimer.stop();
            liveRefreshWatchdogTimer.stop();
            teamTableWatchdogTimer.stop();
            teamTableSeasonWatchdogTimer.stop();
            liveMatchesModel.clear();
            scoresModel.clear();
            leaguesMatchesModel.clear();
            panelLiveMatchesModel.clear();
            panelScheduleMatchesModel.clear();
            tooltipLiveMatchesModel.clear();
            tooltipScheduleMatchesModel.clear();
            tooltipRecentMatchesModel.clear();
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
        root.clearMatchModelCache();
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
        // Reset lazy-load bookkeeping: only the first entry of each scope loads now;
        // all later groups start collapsed and load when the user expands them.
        root.attemptedScheduleGroups = ({});
        root.recentAttemptedGroups = ({});
        root.pendingRecentGroups = ({});
        root.pendingScheduleGroups = ({});
        root.collapsedRecentGroups = root.initialCollapsedGroups(root.recentScopeEntries());
        root.collapsedScheduleGroups = root.initialCollapsedGroups(root.scheduleScopeEntries());
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
        root.requestAuxiliaryMatchModelsRefresh();
        syncTeamTableOptions();
        root.tableErrorMessage = "";
        if (root.watchedTeamEntries().length > 0)
            refreshTeamCompetitionOptions(options);
        tableFallbackTimer.restart();
        refreshWatchdogTimer.restart();
        const liveFetchFailedEntries = [];
        root.fetchScopedMatches(root.liveScopeEntries(), token, manual, SportsApi.fetchLiveScores, matches => {
            if (!root.isCurrentRefresh(token))
                return;

            root.lastLiveFetchFailedEntries = liveFetchFailedEntries;
            applyLiveMatches(matches, manual);
            root.liveLoading = false;
            finishRefresh(manual, "", token);
        }, message => {
            if (!root.isCurrentRefresh(token))
                return;

            root.lastLiveFetchFailedEntries = liveFetchFailedEntries;
            applyLiveMatches([], manual);
            root.liveLoading = false;
            finishRefresh(manual, message, token);
        }, undefined, entry => liveFetchFailedEntries.push(entry));
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
            SportsApi.fetchLeagueTable(options, table => {
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
                    if (root.scheduleScopeEntries().length > 0 && root.scheduleCount === 0 && (root.teamWatchMode() || root.scheduleRequestCompleted))
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
            }, message => {
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
        // Lazy: only fetch the FIRST schedule entry now; mark it attempted so it is
        // not re-fetched on expand. Other groups load when the user expands them.
        const firstScheduleEntries = root.scheduleScopeEntries().slice(0, 1);
        firstScheduleEntries.forEach(entry => {
            const group = root.entryGroupLabel(entry);
            if (group.length > 0)
                root.attemptedScheduleGroups = Object.assign({}, root.attemptedScheduleGroups, {
                    [group]: true
                });
        });
        root.fetchScopedMatches(firstScheduleEntries, token, manual, SportsApi.fetchScoresFixtures, fixtures => {
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
        }, message => {
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
        // Lazy: only the FIRST recent-results entry loads now; its matches land in
        // latestRecentMatches (tagged with their scopeGroup), and every other group
        // fetches on expand - gated on whether its data is already present.
        const firstRecentEntries = root.recentScopeEntries().slice(0, 1);
        firstRecentEntries.forEach(entry => {
            const group = root.entryGroupLabel(entry);
            if (group.length > 0)
                root.recentAttemptedGroups = Object.assign({}, root.recentAttemptedGroups, {
                    [group]: true
                });
        });
        root.fetchScopedMatches(firstRecentEntries, token, manual, SportsApi.fetchRecentResults, results => {
            if (!root.isCurrentRefresh(token))
                return;

            const hasResults = results.length > 0;
            if (results.length > 0 || root.recentResultsCount === 0)
                applyRecentResults(results);
            if (hasResults || !root.recentResultsTableFallbackStarted)
                root.recentResultsLoading = false;
            finishRefresh(manual, "", token);
        }, message => {
            if (!root.isCurrentRefresh(token))
                return;

            if (root.recentResultsCount === 0)
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
        // TEMP DIAGNOSTIC: how many scope entries this one live poll fans out to.
        // Each non-ESPN entry triggers its own full SportScore-page fetch+parse on
        // the UI thread, so a high count here is the suspected freeze amplifier.
        console.warn("[sports-widget][profile] live refresh dispatch: " + root.liveScopeEntries().length + " scope entries");
        const liveFetchFailedEntries = [];
        root.fetchScopedMatches(root.liveScopeEntries(), root.refreshToken, true, SportsApi.fetchLiveScores, matches => {
            // A superseded poll must still release the in-flight flag, or every
            // later non-manual poll is blocked by the `liveRefreshInFlight` guard
            // and the live data silently stops updating until plasmashell restarts.
            if (!root.isCurrentLiveRefresh(token)) {
                root.liveRefreshInFlight = false;
                return;
            }

            const currentSignature = root.liveScopeSignature();
            if (selectedEntriesSignature !== currentSignature || selectedWatchSignature !== root.teamWatchSignature()) {
                root.liveRefreshInFlight = false;
                return;
            }

            root.lastLiveFetchFailedEntries = liveFetchFailedEntries;
            applyLiveMatches(matches, manual);
            root.liveLoading = false;
            root.liveRefreshInFlight = false;
            liveRefreshWatchdogTimer.stop();
            root.lastUpdatedText = root.updatedText();
        }, () => {
            if (!root.isCurrentLiveRefresh(token)) {
                root.liveRefreshInFlight = false;
                return;
            }

            root.liveLoading = false;
            root.liveRefreshInFlight = false;
            liveRefreshWatchdogTimer.stop();
        }, {
            "scoreboardDaysBack": 1,
            "scoreboardDaysForward": 1
        }, entry => liveFetchFailedEntries.push(entry));
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
        }), fixtures => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            const scopedFixtures = root.filterMatchesByEntries(fixtures, root.scheduleScopeEntries());
            if (scopedFixtures.length > 0) {
                const scheduledCount = applySchedules(scopedFixtures, root.updatedText());
                if (scheduledCount > 0) {
                    emptySchedulesTimer.stop();
                    root.schedulesLoading = false;
                } else if (root.scheduleCount === 0) {
                    deferEmptySchedulesMessage("");
                }
                return;
            }

            if (root.scheduleCount > 0) {
                emptySchedulesTimer.stop();
                root.schedulesLoading = false;
            } else {
                deferEmptySchedulesMessage("");
            }
        }, message => {
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
        root.recentResultsLoading = root.recentResultsCount === 0;

        SportsApi.fetchRecentResults(Object.assign({}, options, {
            "tableRows": rows,
            "preferTeamRecentResults": true,
            "recentResultsLimit": 80,
            "recentResultsPerTeam": 50
        }), results => {
            if (!root.isCurrentRefresh(options.refreshToken))
                return;

            const scopedResults = root.filterMatchesByEntries(results, root.recentScopeEntries());
            if ((scopedResults.length > 0 && (root.recentResultsCount === 0 || scopedResults.length > root.recentResultsCount)) || root.recentResultsCount === 0)
                applyRecentResults(scopedResults);
            root.recentResultsLoading = false;
        }, message => {
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
        if (root.scheduleScopeEntries().length > 0 && root.scheduleCount === 0)
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

    function addTeamTableOption(options, seen, label, slug, country, fromDiscovery) {
        const resolvedCountry = String(country || "").trim();
        const resolvedLeague = ProviderCatalog.resolveFootballLeagueCode(resolvedCountry, String(slug || label).trim());
        const normalizedSlug = ProviderCatalog.slugForValue(resolvedLeague);
        if (normalizedSlug.length === 0 || seen[normalizedSlug])
            return;

        const normalizedLabel = String(label || ProviderCatalog.leagueLabel(normalizedSlug) || ProviderCatalog.titleFromSlug(normalizedSlug)).trim();
        // A competition the followed team actively plays in (fromDiscovery) must
        // stay selectable even if a previous fetch transiently failed and flagged
        // it unsupported - otherwise a one-off 504 permanently hides a real league
        // (e.g. a SportScore-only league like the Bulgarian First League). Only the
        // permanent disqualifiers (friendlies) still suppress it.
        if (!root.isTableCompetitionEligible(normalizedSlug, normalizedLabel, fromDiscovery === true))
            return;

        const normalizedCountry = String(resolvedCountry || "").trim();
        seen[normalizedSlug] = true;
        options.push({
            "slug": normalizedSlug,
            "label": normalizedLabel,
            "country": normalizedCountry
        });
    }

    function isTableCompetitionEligible(slug, label, ignoreUnsupported) {
        const normalizedSlug = ProviderCatalog.slugForValue(slug);
        if (normalizedSlug.length === 0)
            return false;

        if (ignoreUnsupported !== true && Boolean(root.unsupportedTableSlugs && root.unsupportedTableSlugs[normalizedSlug]))
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
            root.addTeamTableOption(options, seen, label, slug, String(competition && competition.country || "").trim(), true);
        });
    }

    function savedEntryKey(entry) {
        entry = entry || {};
        return [root.entryType(entry), String(entry.sport || "").trim().toLowerCase(), String(entry.country || "").trim().toLowerCase(), ProviderCatalog.slugForValue(entry.league || ""), String(entry.favoriteTeam || "").trim().toLowerCase(), ProviderCatalog.slugForValue(entry.teamSlug || ""), String(entry.teamPath || entry.teamUrl || "").trim().toLowerCase()].join("|");
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
        tableEntries.forEach(entry => {
            if (root.entryType(entry) !== "competition")
                return;

            const league = String(entry && entry.league || "").trim();
            if (league.length === 0)
                return;

            root.addTeamTableOption(options, seen, root.displayLeagueLabel(entry), league, String(entry && entry.country || "").trim());
        });

        let teamOrder = 0;
        tableEntries.forEach(entry => {
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

    readonly property int teamCompetitionsTtlMs: 24 * 60 * 60 * 1000
    // Background wizard-cache refresh skips team lists younger than this. Kept
    // just under the daily refresh timer so the daily tick actually refreshes
    // (a full 24 h threshold would race it and skip every other day).
    readonly property int wizardTeamsRefreshMs: 20 * 60 * 60 * 1000
    readonly property int seasonsTtlMs: 7 * 24 * 60 * 60 * 1000

    function refreshTeamCompetitionOptions(options) {
        // Discover the competitions of EVERY followed team that shows tables, so the
        // table dropdown lists each team's leagues (e.g. the Bulgarian First League
        // for Levski/CSKA) and the user can pick one without first making that team
        // the active entry. This only populates the dropdown LIST - it does not
        // fetch any table rows; the selected table's data still loads lazily (see
        // refreshDisplayTableForSelection). Each team's competition list is cached
        // for 24h, so this is one cheap team-page request per club, once.
        let teamEntries = root.watchedTeamEntriesForScope("includeTables");
        if (teamEntries.length === 0) {
            root.discoveredTeamCompetitions = [];
            syncTeamTableOptions();
            return;
        }

        const requestToken = options.refreshToken;
        let pending = teamEntries.length;
        let competitions = [];

        function appendRows(entry, sourceOrder, rows) {
            const entryKey = root.savedEntryKey(entry);
            const sourceTeam = root.displayFavoriteTeam(entry);
            competitions = competitions.concat((Array.isArray(rows) ? rows : []).map(row => Object.assign({}, row || {}, {
                    "scopeOrder": sourceOrder,
                    "sourceEntryKey": entryKey,
                    "sourceTeam": sourceTeam
                })));
        }

        function complete() {
            pending -= 1;
            if (pending > 0 || !root.isCurrentRefresh(requestToken))
                return;

            // Merge with anything already discovered (from a prior activation) so
            // switching between followed teams accumulates their leagues in the
            // dropdown instead of dropping the previous team's. Re-discovering an
            // entry replaces only that entry's rows.
            const discoveredKeys = {};
            competitions.forEach(row => {
                discoveredKeys[String(row && row.sourceEntryKey || "")] = true;
            });
            const retained = (Array.isArray(root.discoveredTeamCompetitions) ? root.discoveredTeamCompetitions : []).filter(row => !discoveredKeys[String(row && row.sourceEntryKey || "")]);
            root.discoveredTeamCompetitions = retained.concat(competitions);
            syncTeamTableOptions();
            if (root.currentDisplayTableSlug().length > 0)
                root.refreshDisplayTableForSelection();
        }

        teamEntries.forEach((entry, sourceOrder) => {
            // A team's set of competitions changes ~once a season, yet this fires
            // for every followed team on every refresh - so serve it from the
            // persistent cache and only re-fetch once the cache is stale.
            const cacheKey = "teamcomps|" + root.savedEntryKey(entry);
            const cached = matchCache.read(cacheKey);
            const hasFreshCache = cached && Array.isArray(cached.value) && (Date.now() - cached.ts) < root.teamCompetitionsTtlMs;
            if (hasFreshCache) {
                appendRows(entry, sourceOrder, cached.value);
                complete();
                return;
            }

            SportsApi.fetchTeamCompetitions(root.requestOptionsForEntry(entry, requestToken, false), rows => {
                if (Array.isArray(rows) && rows.length > 0)
                    matchCache.write(cacheKey, rows);
                appendRows(entry, sourceOrder, rows);
                complete();
            }, () => {
                if (cached && Array.isArray(cached.value))
                    appendRows(entry, sourceOrder, cached.value);
                complete();
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
        const previousKey = String(root.selectedTeamTableSeasonKey || "").trim();

        // A competition's season list is static; serve it from the persistent
        // cache and only re-fetch once the cache is stale.
        const cacheKey = "seasons|" + scopeKey;
        const cached = matchCache.read(cacheKey);
        if (cached && Array.isArray(cached.value) && cached.value.length > 0 && (Date.now() - cached.ts) < root.seasonsTtlMs) {
            root.teamTableSeasonLoading = false;
            root.applyTeamTableSeasons(cached.value, previousKey);
            return;
        }

        root.teamTableSeasonLoading = true;
        teamTableSeasonWatchdogTimer.restart();
        root.teamTableSeasonRequestToken += 1;
        const token = root.teamTableSeasonRequestToken;
        SportsApi.fetchLeagueSeasons({
            "provider": effectiveProvider(),
            "baseUrl": effectiveBaseUrl(root.selectedSport),
            "apiKey": root.effectiveApiKey(root.selectedSport),
            "sports": root.selectedSport,
            "country": tableCountry,
            "league": slug,
            "followMode": "league",
            "refreshToken": root.refreshToken
        }, seasons => {
            if (token !== root.teamTableSeasonRequestToken)
                return;
            if (Array.isArray(seasons) && seasons.length > 0)
                matchCache.write(cacheKey, seasons);
            root.applyTeamTableSeasons(seasons, previousKey);
        }, () => {
            if (token !== root.teamTableSeasonRequestToken)
                return;
            if (cached && Array.isArray(cached.value) && cached.value.length > 0) {
                root.applyTeamTableSeasons(cached.value, previousKey);
                return;
            }

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

    function applyTeamTableSeasons(seasons, previousKey) {
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
        const canRefreshNow = root.tableRequestCompleted && !root.teamTableLoading && root.currentDisplayTableSlug().length > 0 && nextKey.length > 0;
        if (canRefreshNow) {
            root.pendingSeasonTableRefresh = false;
            root.refreshDisplayTableForSelection();
        } else if (nextKey.length > 0 && root.currentDisplayTableSlug().length > 0) {
            root.pendingSeasonTableRefresh = true;
        }
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
            "scoreboardDaysForward": root.configuredScheduleDaysAhead()
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
        const hasResolvedSeasonSelection = selectedSeasonKey.length === 0 || selectedSeasonId.length > 0 || selectedSeasonLabel.length > 0 || selectedSeasonProvider.length > 0;
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
        requestFn(requestOptions, table => {
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
        }, message => {
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
            return;

        refreshWatchdogTimer.stop();
        promoteLiveMatches(root.latestScheduleMatches);
        root.loading = false;
        if (root.refreshErrors.length > 0 && liveMatchesModel.count === 0 && root.scheduleCount === 0 && root.recentResultsCount === 0 && tableModel.count === 0) {
            emptySchedulesTimer.stop();
            root.schedulesLoading = false;
            root.errorMessage = manual ? root.refreshErrors.join(", ") : "";
        } else {
            if (root.schedulesLoading && root.tableRequestCompleted && root.tableRows.length === 0)
                deferEmptySchedulesMessage("");

            if (!root.schedulesLoading && root.scheduleCount === 0 && root.errorMessage.length === 0)
                deferEmptySchedulesMessage("");

            if (manual && root.refreshErrors.length > 0)
                root.errorMessage = root.refreshErrors.join(", ");
        }
    }

    MatchDataCache {
        id: matchCache
    }

    // Same on-disk cache the configuration wizard reads from, so the background
    // refresh below can keep its competition teams + emblems current.
    WizardConfig.WizardCache {
        id: wizardCache
    }

    // Quietly refreshes the wizard's cached emblems and competition team lists in
    // the background (shortly after start, then daily) so cached data never goes
    // stale and missing emblems get backfilled. Uses the hardened, concurrency-
    // limited request layer, so it stays light on the provider.
    function refreshWizardCaches() {
        const saved = Array.isArray(root.savedLeagues()) ? root.savedLeagues() : [];

        // Sports the user actually follows (fall back to the active sport).
        let sports = [];
        saved.forEach(entry => {
            const sport = SportVisuals.normalizedSport(entry && entry.sport);
            if (sport.length > 0 && sports.indexOf(sport) < 0)
                sports.push(sport);
        });
        if (sports.length === 0) {
            const sport = SportVisuals.normalizedSport(root.activeSport);
            if (sport.length > 0)
                sports.push(sport);
        }

        sports.forEach(sport => {
            // 1) Emblems map for this sport (one matches request).
            SportsApi.fetchPopularEmblems({
                "sports": sport
            }, map => {
                if (map && typeof map === "object")
                    wizardCache.write("emblems|" + sport, map);
            });

            // 2) Team lists for the competitions worth keeping fresh: the ones the
            // user follows plus this sport's curated popular competitions. Capped
            // so a daily refresh never bursts the provider.
            let slugs = [];
            saved.forEach(entry => {
                if (SportVisuals.normalizedSport(entry && entry.sport) !== sport)
                    return;
                const slug = String(entry && entry.league || "").trim();
                if (slug.length > 0 && !slugs.some(item => item.slug === slug))
                    slugs.push({
                        "slug": slug,
                        "country": String(entry && entry.country || ""),
                        "path": String(entry && (entry.competitionPath || entry.leaguePath) || "").trim()
                    });
            });
            const popular = PopularCatalog.popularCompetitions(sport) || [];
            popular.forEach(comp => {
                const slug = String(comp && (comp.value || comp.slug) || "").trim();
                if (slug.length > 0 && !slugs.some(item => item.slug === slug))
                    slugs.push({
                        "slug": slug,
                        "country": String(comp && comp.country || ""),
                        "path": String(comp && comp.path || "").trim()
                    });
            });

            // Skip lists whose on-disk copy is still recent and stagger the rest:
            // this used to re-fetch all ~24 lists in one burst 30 s after every
            // plasmashell start, and each competition the standings API couldn't
            // serve fell back to a full HTML page scrape+parse on the UI thread -
            // right at login. Passing the catalog's competition path lets the
            // standings API serve leagues whose label-derived slug 404s.
            let staggerIndex = 0;
            slugs.slice(0, 24).forEach(item => {
                const cacheKey = "compteams|" + sport + "|" + item.slug;
                const cached = wizardCache.read(cacheKey);
                if (cached && Array.isArray(cached.value) && cached.value.length > 0
                        && (Date.now() - cached.ts) < root.wizardTeamsRefreshMs)
                    return;

                staggerIndex += 1;
                root.scheduleNetworkDelay(() => {
                    SportsApi.fetchCompetitionTeams({
                        "sports": sport,
                        "league": item.slug,
                        "country": item.country,
                        "competitionPath": item.path
                    }, teams => {
                        if (Array.isArray(teams) && teams.length > 0)
                            wizardCache.write(cacheKey, teams);
                    }, () => {});
                }, staggerIndex * 1500);
            });
        });
    }

    Timer {
        id: wizardInitialRefreshTimer
        interval: 30 * 1000
        repeat: false
        running: true
        onTriggered: root.refreshWizardCaches()
    }

    Timer {
        id: wizardDailyRefreshTimer
        interval: 24 * 60 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: root.refreshWizardCaches()
    }

    // A stable signature of the followed competitions/teams, so cached live data
    // is restored only for the selection it was captured under.
    function dataScopeSignature() {
        // The schedule/recent/table caches hold the CURRENTLY DISPLAYED sport's view
        // only, so the key must be scoped to the active sport. Without it every sport
        // shared one cache slot: switching from football to a sport whose own fetch
        // came back empty restored (and showed) the previous sport's matches - e.g.
        // FIFA World Cup fixtures leaking under WTA/NHL. Keying on activeSport gives
        // each sport its own slot. Entries are still filtered to the active sport so
        // the signature changes when this sport's own leagues/teams change.
        const sport = SportVisuals.normalizedSport(root.activeSport);
        const entries = (Array.isArray(root.savedLeagueEntries) ? root.savedLeagueEntries : [])
            .filter(entry => SportVisuals.normalizedSport(entry && entry.sport) === sport);
        return JSON.stringify({
            "sport": sport,
            "entries": entries.map(entry => ({
                    "s": String(entry && entry.sport || ""),
                    "c": String(entry && entry.country || ""),
                    "l": String(entry && entry.league || ""),
                    "t": String(entry && entry.favoriteTeam || "")
                }))
        });
    }

    // Cached "upcoming" matches that are still in the future (or in progress),
    // so finished matches from an old cache are never shown as upcoming.
    function futureMatches(matches) {
        const now = Date.now();
        return (Array.isArray(matches) ? matches : []).filter(match => {
            let timestamp = Number(match && match.timestamp || 0);
            if (!Number.isFinite(timestamp) || timestamp <= 0)
                return true;
            if (timestamp < 100000000000)
                timestamp *= 1000;
            return timestamp >= now - 3 * 60 * 60 * 1000;
        });
    }

    function tableCacheKey() {
        return "table|" + root.dataScopeSignature() + "|" + String(root.selectedTeamTableSlug || "") + "|" + String(root.selectedTeamTableSeasonKey || "");
    }

    // Restore the last-known views from disk so the widget is not blank while the
    // first (possibly slow) refresh runs, or when SportScore is unreachable.
    function seedFromCache() {
        if (!root.hasSportSelection())
            return;

        const scheduleCache = matchCache.read("schedule|" + root.dataScopeSignature());
        if (scheduleCache && Array.isArray(scheduleCache.value)) {
            const future = root.futureMatches(scheduleCache.value);
            if (future.length > 0)
                root.applySchedules(future, root.lastUpdatedText);
        }

        const recentCache = matchCache.read("recent|" + root.dataScopeSignature());
        if (recentCache && Array.isArray(recentCache.value) && recentCache.value.length > 0)
            root.applyRecentResults(recentCache.value);

        const tableCache = matchCache.read(root.tableCacheKey());
        if (tableCache && Array.isArray(tableCache.value) && tableCache.value.length > 0)
            root.applyTable(tableCache.value, true);
    }

    function applySchedules(matches, updateText) {
        matches = Array.isArray(matches) ? matches : [];
        const cacheKey = "schedule|" + root.dataScopeSignature();
        if (matches.length > 0) {
            matchCache.write(cacheKey, matches);
        } else {
            const cached = matchCache.read(cacheKey);
            const restored = cached && Array.isArray(cached.value) ? root.futureMatches(cached.value) : [];
            if (restored.length > 0)
                matches = restored;
        }
        root.latestScheduleMatches = matches.slice();
        promoteLiveMatches(root.latestScheduleMatches);
        syncTeamTableOptions();
        const visibleCount = root.rebuildScheduleModel();
        if (visibleCount > 0) {
            root.errorMessage = "";
        } else if (!root.schedulesLoading) {
            root.errorMessage = emptySchedulesText();
        }

        root.lastUpdatedText = updateText;
        root.requestAuxiliaryMatchModelsRefresh();
        root.requestCalendarSync();
        root.checkStartsSoon();
        root.armKickoffWake();
        return visibleCount;
    }

    // (Re)build the Schedule model from in-memory matches honouring collapse state.
    // Like rebuildRecentModel, a collapsed group contributes only its header row so
    // the ListView never holds height-0 match rows (the cause of scroll jumps).
    function rebuildScheduleModel() {
        scoresModel.clear();
        let matches = scheduledMatches(root.latestScheduleMatches);
        matches = prioritizeFavorite(matches);
        if (Plasmoid.configuration.prioritizePopular) {
            matches = matches.slice().sort((left, right) => {
                return Number(Boolean(right.popular)) - Number(Boolean(left.popular));
            });
            matches = prioritizeFavorite(matches);
        }

        const byGroup = ({});
        const order = [];
        matches.forEach(match => {
            const row = matchForModel(match);
            const scopeGroup = String(match.scopeGroup || "").trim();
            row.leagueGroup = scopeGroup.length > 0 ? scopeGroup : root.liveLeagueGroupLabel(row);
            if (!byGroup[row.leagueGroup]) {
                byGroup[row.leagueGroup] = [];
                order.push(row.leagueGroup);
            }
            byGroup[row.leagueGroup].push(row);
        });

        // Soonest N upcoming matches per group (fixtures are sorted soonest-first),
        // as configured in Appearance → Widget → Scheduled.
        const perGroup = Math.min(30, Math.max(1, Number(Plasmoid.configuration.widgetScheduleMatchesPerGroup) || 5));

        const emitted = ({});
        function emitGroup(group) {
            const key = String(group || "").trim();
            if (key.length === 0 || emitted[key])
                return;
            emitted[key] = true;
            scoresModel.append({
                "leagueGroup": key,
                "rowType": "header",
                "isPlaceholder": true
            });
            if (Boolean(root.collapsedScheduleGroups[key]))
                return;
            const rows = (byGroup[key] || []).slice(0, perGroup);
            rows.forEach(row => scoresModel.append(Object.assign({
                    "rowType": "match"
                }, row)));
            // Expanded group that finished loading with no upcoming fixtures: show a
            // clear "nothing scheduled" line instead of a blank gap (common in the
            // off-season). Only once the group was actually attempted/loaded.
            if (rows.length === 0 && !root.pendingScheduleGroups[key] && root.attemptedScheduleGroups[key])
                scoresModel.append({
                    "leagueGroup": key,
                    "rowType": "notice",
                    "isEmptyNotice": true
                });
        }

        root.scheduleScopeEntries().forEach(entry => emitGroup(root.entryGroupLabel(entry)));
        order.forEach(group => emitGroup(group));
        // The Live tab renders the combined leagues model (live + today's
        // upcoming), so it must be rebuilt whenever the schedule model changes -
        // otherwise upcoming matches never appear there until a live refresh.
        root.rebuildLeaguesModel();
        return matches.length;
    }

    function appendScopedDisplayModels(entries, liveTarget, scheduleTarget, recentTarget) {
        liveTarget.clear();
        scheduleTarget.clear();

        let liveMatches = root.filterMatchesByEntries(root.latestLiveMatches, entries);
        liveMatches = root.sortLiveMatches(root.prioritizeFavorite(liveMatches));
        liveMatches.forEach(match => liveTarget.append(root.matchForModel(root.liveMatchForModel(match))));

        let scheduleMatches = root.filterMatchesByEntries(root.latestScheduleMatches, entries);
        scheduleMatches = root.prioritizeFavorite(root.scheduledMatches(scheduleMatches));
        scheduleMatches.forEach(match => scheduleTarget.append(root.matchForModel(match)));

        if (!recentTarget)
            return;

        recentTarget.clear();
        let recentMatches = root.filterMatchesByEntries(root.latestRecentMatches, entries);
        recentMatches = root.sortRecentResultsByDate(recentMatches);
        recentMatches.forEach(match => recentTarget.append(root.matchForModel(match)));
    }

    // The panel + tooltip models are rebuilt from scratch (re-running matchForModel
    // for every match). A single refresh applies live, schedule and recent results
    // separately, so calling this directly each time rebuilt them 3× - expensive
    // with a busy competition (e.g. the live World Cup). Coalesce the bursts into
    // one rebuild; the panel/tooltip aren't even visible while the full view is.
    function requestAuxiliaryMatchModelsRefresh() {
        auxModelsRefreshTimer.restart();
    }

    function refreshAuxiliaryMatchModels() {
        root.appendScopedDisplayModels(root.panelScopeEntries(), panelLiveMatchesModel, panelScheduleMatchesModel);
        root.appendScopedDisplayModels(root.tooltipScopeEntries(), tooltipLiveMatchesModel, tooltipScheduleMatchesModel, tooltipRecentMatchesModel);
        if (root.panelRotationCount <= 1)
            root.panelRotationIndex = 0;
        else
            root.panelRotationIndex %= root.panelRotationCount;
    }

    function reformatDisplayedMatches() {
        // Display formatting (time/date format, badge style) may have changed, so
        // drop the memoized rows before re-rendering from the retained matches.
        root.clearMatchModelCache();
        if (root.latestLiveMatches.length > 0)
            applyLiveMatches(root.latestLiveMatches);
        if (root.latestScheduleMatches.length > 0 || root.scheduleCount > 0)
            applySchedules(root.latestScheduleMatches, root.lastUpdatedText);
        if (root.latestRecentMatches.length > 0 || root.recentResultsCount > 0)
            applyRecentResults(root.latestRecentMatches);
        if (root.lastUpdatedText.length > 0)
            root.lastUpdatedText = root.updatedText();
    }

    function liveLeagueGroupLabel(match) {
        const league = String(match && match.league || "").trim();
        if (league.length > 0)
            return league;

        // Some friendly/tournament fixtures arrive with an empty league but carry
        // the competition name in group/matchday - prefer that over a generic
        // bucket so the section header is meaningful (and we never show "Matches").
        const group = String((match && (match.group || match.matchday)) || "").trim();
        if (group.length > 0)
            return group;

        return SportVisuals.label(String(match && match.sport || "").trim() || root.activeSport);
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

    function postNotification(title, text, iconName, url) {
        const notification = notificationComponent.createObject(root, {
            "title": title,
            "text": text,
            "iconName": iconName || "appointment-soon"
        });
        if (!notification)
            return;

        notification.closed.connect(() => notification.destroy());

        const targetUrl = String(url || "").trim();
        if (targetUrl.length > 0) {
            const action = notificationOpenActionComponent.createObject(notification, {
                "label": i18nc("@action:button", "Open match")
            });
            if (action) {
                action.activated.connect(() => Qt.openUrlExternally(targetUrl));
                notification.defaultAction = action;
            }
        }

        notification.sendEvent();
    }

    function notificationIconFor(kind) {
        if (kind === "fulltime")
            return "checkmark";
        if (kind === "halftime")
            return "media-playback-pause";
        if (kind === "secondhalf")
            return "media-playback-start";
        if (kind === "startssoon")
            return "appointment-soon";
        if (kind === "goal" || kind === "goalscorer")
            return "starred";
        if (kind === "yellowcard")
            return "dialog-warning";
        if (kind === "redcard")
            return "dialog-error";
        if (kind === "substitution")
            return "view-refresh";
        if (kind === "extratime" || kind === "extratimesecondhalf")
            return "media-playback-start";
        if (kind === "shootout")
            return "appointment-soon";
        return "media-playback-start";
    }

    // Returns the set of data providers that contributed any of the given match
    // sets, as a stable-ordered list of { name, url } (SportScore first, then
    // ESPN). Used to credit each active source in the footer. A match is ESPN if
    // its detailsProvider/sourceProvider says so; otherwise it is SportScore.
    function computeActiveProviders(live, schedule, recent) {
        let sawEspn = false;
        let sawSportScore = false;
        const scan = (list) => {
            (Array.isArray(list) ? list : []).forEach(match => {
                const provider = String((match && (match.detailsProvider || match.sourceProvider)) || "").trim().toLowerCase();
                if (provider === "espn")
                    sawEspn = true;
                else
                    sawSportScore = true;
            });
        };
        scan(live);
        scan(schedule);
        scan(recent);

        const providers = [];
        if (sawSportScore)
            providers.push({ "name": "SportScore", "url": "https://sportscore.com/" });
        if (sawEspn)
            providers.push({ "name": "ESPN", "url": "https://www.espn.com/" });
        // Default to SportScore before any data has loaded, so the footer is never
        // empty on first paint.
        if (providers.length === 0)
            providers.push({ "name": "SportScore", "url": "https://sportscore.com/" });
        return providers;
    }

    // Match page URL for the notification's "Open match" action, in the same
    // style as the in-widget "Powered by SportScore" link.
    function matchPageUrl(match) {
        const path = String((match && match.matchPath) || "").trim();
        if (path.length > 0)
            return root.effectiveBaseUrl(String(match.sport || "football")) + path;

        // ESPN-sourced matches have no SportScore matchPath; build their public
        // ESPN gamecast URL from the event id instead (Colosseum-style "Visit").
        return root.espnMatchUrl(match);
    }

    // Public ESPN gamecast/summary URL for a match, or "" when it isn't an
    // ESPN-sourced match. Soccer uses ".../match/_/gameId/", the US team sports
    // use ".../game/_/gameId/"; the path segment is the ESPN sport slug.
    function espnMatchUrl(match) {
        if (String((match && match.detailsProvider) || "") !== "espn")
            return "";
        const eventId = String((match && match.espnEventId) || "").trim();
        if (eventId.length === 0)
            return "";

        const espnSport = String((match && match.espnSport) || "").trim().toLowerCase();
        const sportPath = espnSport.length > 0 ? espnSport : "soccer";
        const verb = sportPath === "soccer" ? "match" : "game";
        return "https://www.espn.com/" + sportPath + "/" + verb + "/_/gameId/" + eventId;
    }

    // Whether a "Visit on ESPN" link should be offered for this match.
    function hasEspnMatchUrl(match) {
        return root.espnMatchUrl(match).length > 0;
    }

    function emitMatchNotification(event) {
        const match = event.match || {};
        const home = String(match.homeTeam || "");
        const away = String(match.awayTeam || "");
        const teams = home + " vs " + away;
        const league = String(match.league || "").trim();
        const score = String(event.scoreText || "");
        // GnomeFootball-style body: "Home Score Away - League".
        const scoreLine = score.length > 0 ? home + " " + score.replace("–", "-") + " " + away : teams;
        const fullBody = league.length > 0 ? scoreLine + " - " + league : scoreLine;

        let title = teams;
        let body = league;

        if (event.kind === "kickoff") {
            title = i18nc("@title:notification", "Kick-off");
            body = league.length > 0 ? teams + " - " + league : teams;
        } else if (event.kind === "goal") {
            title = i18nc("@title:notification", "GOAL");
            body = fullBody;
        } else if (event.kind === "halftime") {
            title = i18nc("@title:notification", "Half-time");
            body = fullBody;
        } else if (event.kind === "secondhalf") {
            title = i18nc("@title:notification", "Second half");
            body = fullBody;
        } else if (event.kind === "fulltime") {
            title = i18nc("@title:notification", "Full-time");
            body = fullBody;
        } else if (event.kind === "extratime") {
            title = i18nc("@title:notification", "Extra time");
            body = fullBody;
        } else if (event.kind === "extratimesecondhalf") {
            title = i18nc("@title:notification", "Extra time: second half");
            body = fullBody;
        } else if (event.kind === "shootout") {
            title = i18nc("@title:notification", "Penalty shootout");
            body = fullBody;
        } else if (event.kind === "startssoon") {
            title = i18ncp("@title:notification", "Starts in %1 minute", "Starts in %1 minutes", event.minutes);
            body = league.length > 0 ? teams + " - " + league : teams;
        } else if (event.kind === "goalscorer" || event.kind === "yellowcard" || event.kind === "redcard" || event.kind === "substitution") {
            const incident = event.incident || {};
            const player = String(incident.player || "");
            const minute = String(incident.minute || "");
            const team = incident.side === "home" ? home : incident.side === "away" ? away : "";
            const currentScore = String(match.homeScore || "") + "-" + String(match.awayScore || "");
            const matchLine = league.length > 0 ? home + " " + currentScore + " " + away + " - " + league : home + " " + currentScore + " " + away;

            if (event.kind === "goalscorer") {
                title = i18nc("@title:notification", "GOAL");
                const playerLine = [player, minute.length > 0 ? minute + "'" : ""].filter(part => part.length > 0).join(" ");
                body = [matchLine, [playerLine, team].filter(part => part.length > 0).join(" • ")].filter(part => part.length > 0).join(" • ");
            } else if (event.kind === "yellowcard") {
                title = i18nc("@title:notification", "Yellow card");
                body = [[player, minute.length > 0 ? minute + "'" : ""].filter(part => part.length > 0).join(" "), team, matchLine].filter(part => part.length > 0).join(" • ");
            } else if (event.kind === "redcard") {
                title = i18nc("@title:notification", "Red card");
                body = [[player, minute.length > 0 ? minute + "'" : ""].filter(part => part.length > 0).join(" "), team, matchLine].filter(part => part.length > 0).join(" • ");
            } else {
                title = i18nc("@title:notification", "Substitution");
                body = [player, minute.length > 0 ? minute + "'" : "", team, matchLine].filter(part => part.length > 0).join(" • ");
            }
        }

        root.postNotification(title, body, root.notificationIconFor(event.kind), root.matchPageUrl(match));
    }

    // Saved entries the user has explicitly opted into for the given feature.
    // An empty inclusion list means nothing is included (the default).
    function enabledEntriesFor(inclusionConfigKey) {
        let included = [];
        try {
            const parsed = JSON.parse(Plasmoid.configuration[inclusionConfigKey] || "[]");
            included = Array.isArray(parsed) ? parsed.map(String) : [];
        } catch (error) {
            included = [];
        }

        const entries = Array.isArray(root.savedLeagueEntries) ? root.savedLeagueEntries : [];
        return {
            "all": false,
            "entries": entries.filter(entry => included.indexOf(MatchNotifications.entryKey(entry)) >= 0)
        };
    }

    function rowMatchesEnabled(row, enabled) {
        if (enabled.all)
            return true;

        return enabled.entries.some(entry => root.matchBelongsToEntry(entry, row));
    }

    function liveMatchRowsForNotify() {
        const enabled = root.enabledEntriesFor("notifyEntryInclusions");
        const rows = [];
        for (let index = 0; index < liveMatchesModel.count; index += 1) {
            const match = liveMatchesModel.get(index);
            if (!match)
                continue;

            const row = {
                "matchPath": String(match.matchPath || ""),
                "liveUrl": String(match.liveUrl || ""),
                "homeTeam": String(match.homeTeam || ""),
                "awayTeam": String(match.awayTeam || ""),
                "league": String(match.league || ""),
                "sport": String(match.sport || ""),
                "status": String(match.status || ""),
                "minute": String(match.minute || ""),
                "homeScore": String(match.homeScore || ""),
                "awayScore": String(match.awayScore || ""),
                "detailsProvider": String(match.detailsProvider || ""),
                "espnEventId": String(match.espnEventId || ""),
                "espnSport": String(match.espnSport || ""),
                "espnLeague": String(match.espnLeague || "")
            };
            if (root.rowMatchesEnabled(row, enabled))
                rows.push(row);
        }
        return rows;
    }

    function scheduleRows(inclusionConfigKey) {
        const enabled = root.enabledEntriesFor(inclusionConfigKey);
        const rows = [];
        for (let index = 0; index < scoresModel.count; index += 1) {
            const match = scoresModel.get(index);
            if (!match || match.isPlaceholder === true)
                continue;

            const row = {
                "matchPath": String(match.matchPath || ""),
                "liveUrl": String(match.liveUrl || ""),
                "homeTeam": String(match.homeTeam || ""),
                "awayTeam": String(match.awayTeam || ""),
                "league": String(match.league || ""),
                "matchday": String(match.matchday || ""),
                "sport": String(match.sport || ""),
                "emoji": SportVisuals.emoji(String(match.sport || "")),
                "status": String(match.status || ""),
                "homeScore": String(match.homeScore || ""),
                "awayScore": String(match.awayScore || ""),
                "stadium": String(match.stadium || ""),
                "timestamp": Number(match.timestamp || 0)
            };
            if (root.rowMatchesEnabled(row, enabled))
                rows.push(row);
        }
        return rows;
    }

    function pushMatchNotifications() {
        if (!Plasmoid.configuration.notificationsEnabled) {
            root.notifyHasBaseline = false;
            root.notifyIncidentIds = ({});
            return;
        }

        // A match that vanished only because its entry's fetch failed this cycle
        // (e.g. a SportScore 504) has NOT necessarily finished - don't let that
        // fire a false "full-time" notification.
        const failedEntries = root.lastLiveFetchFailedEntries;
        const result = MatchNotifications.computeLiveNotifications(root.notifyLiveSnapshot, root.liveMatchRowsForNotify(), {
            "hasBaseline": root.notifyHasBaseline,
            "triggers": {
                "kickoff": Plasmoid.configuration.notifyKickoff,
                "goals": Plasmoid.configuration.notifyGoals,
                "halfTime": Plasmoid.configuration.notifyHalfTime,
                "fullTime": Plasmoid.configuration.notifyFullTime
            },
            "favoriteOnly": Plasmoid.configuration.notifyFavoriteTeamsOnly,
            "favoriteNames": root.watchedTeamNames(),
            "forceInclude": match => root.matchNotifyEnabled(match),
            "isUnreliable": match => failedEntries.some(entry => root.matchBelongsToEntry(entry, match)),
            "detailedEventsAvailable": match => root.detailedEventsAvailableFor(match)
        });

        root.notifyLiveSnapshot = result.snapshot;
        root.notifyHasBaseline = true;
        result.events.forEach(event => root.emitMatchNotification(event));
    }

    // Detailed events (scorer name, cards, substitutions) are opt-in: only
    // football matches sourced from ESPN are polled, since that is the only
    // incident feed currently implemented (see fetchEspnMatchIncidents).
    function detailedEventsAvailableFor(match) {
        if (!Plasmoid.configuration.notifyDetailedEvents)
            return false;
        if (String((match && match.sport) || "").trim().toLowerCase() !== "football")
            return false;
        if (String((match && match.detailsProvider) || "") !== "espn")
            return false;
        return String((match && match.espnEventId) || "").length > 0;
    }

    function pollDetailedEvents() {
        if (!Plasmoid.configuration.notificationsEnabled || !Plasmoid.configuration.notifyDetailedEvents)
            return;
        if (root.detailedEventsPollInFlight)
            return;

        const candidates = root.liveMatchRowsForNotify().filter(match => root.detailedEventsAvailableFor(match));
        if (candidates.length === 0)
            return;

        root.detailedEventsPollInFlight = true;
        let pending = candidates.length;
        const nextIncidentIds = Object.assign({}, root.notifyIncidentIds);

        function settleOne() {
            pending -= 1;
            if (pending <= 0) {
                root.notifyIncidentIds = nextIncidentIds;
                root.detailedEventsPollInFlight = false;
            }
        }

        candidates.forEach(match => {
            const id = MatchNotifications.matchId(match);
            SportsApi.fetchEspnMatchIncidents(match.espnSport, match.espnLeague, match.espnEventId, match.homeTeam, match.awayTeam, incidents => {
                const result = MatchNotifications.computeIncidentNotifications(root.notifyIncidentIds[id], match, incidents, {
                    "goals": Plasmoid.configuration.notifyGoals,
                    "cards": true,
                    "substitutions": true,
                    "halfTime": Plasmoid.configuration.notifyHalfTime
                });
                nextIncidentIds[id] = result.incidentIds;
                result.events.forEach(event => root.emitMatchNotification(event));
                settleOne();
            }, () => settleOne());
        });
    }

    function checkStartsSoon() {
        if (!Plasmoid.configuration.notificationsEnabled || !Plasmoid.configuration.notifyStartsSoon)
            return;

        const events = MatchNotifications.computeStartsSoon(root.scheduleRows("notifyEntryInclusions"), Date.now(), Plasmoid.configuration.notifyStartsSoonMinutes, root.startsSoonAnnounced, {
            "favoriteOnly": Plasmoid.configuration.notifyFavoriteTeamsOnly,
            "favoriteNames": root.watchedTeamNames(),
            "forceInclude": match => root.matchNotifyEnabled(match)
        });
        events.forEach(event => root.emitMatchNotification(event));
    }

    readonly property string calendarDirectory: "$HOME/.local/share/sports-widget-for-plasma"
    readonly property string calendarFilePath: root.calendarDirectory + "/sports-matches.json"
    readonly property string calendarIcsFilePath: root.calendarDirectory + "/sports-matches.ics"
    readonly property string calendarDisplayName: i18nc("@title calendar name", "Sports Widget for Plasma upcoming matches")

    function syncCalendar() {
        root.writeCalendar(root.scheduleRows("calendarEntryInclusions"));
    }

    function writeCalendar(rows) {
        if (!Plasmoid.configuration.calendarSyncEnabled)
            return;

        rows = Array.isArray(rows) ? rows : [];
        // Don't write an empty snapshot before any fixtures have ever loaded
        // (avoids a startup write of 0 events). Once real data has been seen,
        // empties are allowed through so the calendar can legitimately clear.
        if (rows.length > 0)
            root.calendarHadData = true;
        else if (!root.calendarHadData)
            return;

        // Write a plain, inert JSON snapshot. The bundled Plasma calendar-events
        // plugin (plugin/sportsmatchesevents) reads it and feeds the matches to the
        // Plasma calendar in memory. Nothing parses/reconciles/indexes this file -
        // no Akonadi resource, no PIM indexer - so it can never hang plasmashell
        // (the failure mode the old Akonadi path had).
        const json = CalendarSync.buildSnapshot(rows, {
            "nowMs": Date.now()
        });
        if (json !== root.lastCalendarSnapshot) {
            root.lastCalendarSnapshot = json;
            root.writeFileAtomic(root.calendarFilePath, json);
        }

        // Optional: also write a plain .ics EXPORT file the user can import into
        // any calendar app. This is just a file on disk - it is never registered
        // as an Akonadi resource, so it cannot hang Plasma.
        root.writeIcsExport(rows);
    }

    function writeIcsExport(rows) {
        // Akonadi mode needs the .ics on disk, so treat it as implying the export.
        if (!Plasmoid.configuration.calendarIcsExportEnabled && !Plasmoid.configuration.calendarAkonadiEnabled)
            return;

        const ics = CalendarSync.buildIcs(rows, {
            "nowMs": Date.now(),
            "reminderMinutes": Plasmoid.configuration.calendarReminderMinutes
        });
        if (ics !== root.lastCalendarIcs) {
            root.lastCalendarIcs = ics;
            root.writeFileAtomic(root.calendarIcsFilePath, ics);
        }

        root.ensureAkonadiResource();
    }

    // UNSTABLE / opt-in: register the exported .ics as a read-only Akonadi
    // resource so it shows as a live KDE calendar. Done once per session, fully
    // detached (setsid) so the slow PIM reconfiguration can never block or hang
    // plasmashell. The in-memory plugin remains the recommended path.
    function ensureAkonadiResource() {
        if (!Plasmoid.configuration.calendarAkonadiEnabled || root.calendarAkonadiEnsured)
            return;
        root.calendarAkonadiEnsured = true;

        const ensure = CalendarSync.resourceEnsureScript(root.calendarIcsFilePath, root.calendarDisplayName);
        const command = "printf %s \"" + Qt.btoa(ensure) + "\" | base64 -d | " + root.detachedShellPrefix();
        calendarRunner.connectSource("( " + command + " ) >/dev/null 2>&1 &");
    }

    // Runs the piped-in script in a new session (setsid), detached from
    // plasmashell's process group, so a wedged Akonadi/qdbus call cannot freeze
    // plasmashell. Falls back to a plain shell if setsid is unavailable.
    function detachedShellPrefix() {
        return "sh -c 'command -v setsid >/dev/null 2>&1 && exec setsid sh || exec sh'";
    }

    function takeAkonadiResourceOffline() {
        const offline = CalendarSync.resourceOfflineScript();
        const command = "printf %s \"" + Qt.btoa(offline) + "\" | base64 -d | " + root.detachedShellPrefix();
        calendarRunner.connectSource("( " + command + " ) >/dev/null 2>&1 &");
    }

    // Atomic, detached write of arbitrary text to a file (tmp + rename), so a
    // reader never sees a half-written file and the write never blocks the UI.
    function writeFileAtomic(path, content) {
        const base64 = Qt.btoa(content);
        const tmp = path + ".tmp";
        const command = "mkdir -p \"" + root.calendarDirectory + "\"" + " && printf %s \"" + base64 + "\" | base64 -d > \"" + tmp + "\"" + " && mv -f \"" + tmp + "\" \"" + path + "\"";
        calendarRunner.connectSource("( " + command + " ) >/dev/null 2>&1 &");
    }

    function removeCalendarResource() {
        // Disable: clear both files to an empty match list. The plugin sees zero
        // events and shows nothing; the .ics export becomes an empty calendar. No
        // file deletion - nothing that could hang Plasma.
        root.lastCalendarSnapshot = "";
        root.lastCalendarIcs = "";

        // If an Akonadi resource was registered, take it offline so it stops
        // watching the file (the safe way to quiet it; see CalendarSync).
        if (root.calendarAkonadiEnsured) {
            root.takeAkonadiResourceOffline();
            root.calendarAkonadiEnsured = false;
        }

        if (!root.calendarHadData)
            return;
        root.writeFileAtomic(root.calendarFilePath, CalendarSync.buildSnapshot([], {
            "nowMs": Date.now()
        }));
        if (Plasmoid.configuration.calendarIcsExportEnabled || Plasmoid.configuration.calendarAkonadiEnabled)
            root.writeFileAtomic(root.calendarIcsFilePath, CalendarSync.buildIcs([], {
                "nowMs": Date.now()
            }));
    }

    function requestCalendarSync() {
        if (!Plasmoid.configuration.calendarSyncEnabled)
            return;

        // Capture the rows now, while scoresModel is freshly populated; the
        // debounced timer only defers the file write, not the data snapshot.
        root.pendingCalendarRows = root.scheduleRows("calendarEntryInclusions");
        calendarSyncTimer.restart();
    }

    // Merge into the provider-live set any scheduled match that has effectively
    // started (kickoff passed, not finished) and isn't already present, marking it
    // Live. Deduped by matchKey so a match the provider already reports live is not
    // shown twice.
    function withKickoffPromotedMatches(liveMatches) {
        const result = Array.isArray(liveMatches) ? liveMatches.slice() : [];
        const seen = ({});
        const looseSeen = ({});
        result.forEach(match => {
            seen[root.matchKey(match)] = true;
            const loose = root.looseMatchKey(match);
            if (loose.length > 0)
                looseSeen[loose] = true;
        });

        (Array.isArray(root.latestScheduleMatches) ? root.latestScheduleMatches : []).forEach(match => {
            if (!root.isEffectivelyLive(match) || SportsApi.isLiveMatch(match))
                return;
            const key = root.matchKey(match);
            if (seen[key])
                return;
            // Also skip if the same fixture is already live under a cleaner label
            // (the schedule copy can carry a display-formatted name + empty league,
            // which dodges the exact matchKey but is the same match) - this is what
            // caused a live match to also appear as a promoted "upcoming" duplicate.
            const loose = root.looseMatchKey(match);
            if (loose.length > 0 && looseSeen[loose])
                return;
            seen[key] = true;
            if (loose.length > 0)
                looseSeen[loose] = true;
            // Mark it live but keep its identity; liveMatchForModel sets status="Live".
            result.push(Object.assign({}, match, {
                status: "Live"
            }));
        });
        return result;
    }

    // Collapses copies of the same fixture that arrived from different saved
    // scopes (e.g. a combined "Football" entry and a specific competition entry
    // both covering it). Keeps the richest copy - the one with an actual league
    // name and a clean away label - while preserving the smallest scopeOrder so
    // the survivor still sorts under the user's highest-priority scope.
    function dedupLiveMatches(matches) {
        const list = Array.isArray(matches) ? matches : [];
        const byKey = {};
        const order = [];
        const cleanliness = (m) => {
            let score = 0;
            if (String(m && m.league || "").trim().length > 0)
                score += 2;
            // A mangled away label carries the competition after a dash; penalise it.
            if (!/\s[—-]\s/.test(String(m && m.awayTeam || "")))
                score += 1;
            return score;
        };
        list.forEach(match => {
            const key = root.looseMatchKey(match);
            if (key.length === 0) {
                order.push(match);
                return;
            }
            const existing = byKey[key];
            if (!existing) {
                byKey[key] = match;
                order.push(key);
                return;
            }
            // Prefer the cleaner copy; keep the lower scopeOrder either way.
            const keepNew = cleanliness(match) > cleanliness(existing);
            const winner = keepNew ? match : existing;
            const loser = keepNew ? existing : match;
            const winnerOrder = Number(winner.scopeOrder);
            const loserOrder = Number(loser.scopeOrder);
            if (Number.isFinite(loserOrder) && (!Number.isFinite(winnerOrder) || loserOrder < winnerOrder))
                winner.scopeOrder = loserOrder;
            byKey[key] = winner;
        });
        return order.map(item => typeof item === "string" ? byKey[item] : item);
    }

    function applyLiveMatches(matches, manual) {
        // TEMP DIAGNOSTIC: time this main-thread model rebuild so we can tell
        // whether the freeze is in the QML model update vs. the JS parse step.
        const _applyStart = Date.now();
        let sourceMatches = Array.isArray(matches) ? matches.slice() : [];
        // Promote any scheduled match whose kickoff has passed but the provider
        // hasn't flagged live yet, so it appears in Live at kickoff instead of when
        // the provider catches up. The live poll then fills in its minute/score.
        sourceMatches = root.withKickoffPromotedMatches(sourceMatches);
        // Drop cross-scope duplicates of the same fixture (kept the richest copy).
        sourceMatches = root.dedupLiveMatches(sourceMatches);
        const scopeSignature = root.liveScopeSignature();
        const sameScope = scopeSignature === root.lastLiveScopeSignature;
        if (!manual && sourceMatches.length === 0 && sameScope && root.latestLiveMatches.length > 0 && root.consecutiveEmptyLiveRefreshes < 2) {
            root.consecutiveEmptyLiveRefreshes += 1;
            // We keep the existing live rows (a single empty poll is treated as a
            // blip), but still rebuild the Live tab's combined model so any newly
            // arrived schedule data is reflected.
            root.rebuildLeaguesModel();
            const _blipMs = Date.now() - _applyStart;
            if (_blipMs >= 8)
                console.warn("[sports-widget][profile] applyLiveMatches (blip rebuild) took " + _blipMs + "ms");
            return liveMatchesModel.count;
        }

        root.consecutiveEmptyLiveRefreshes = sourceMatches.length === 0 ? root.consecutiveEmptyLiveRefreshes + 1 : 0;
        root.lastLiveScopeSignature = scopeSignature;
        liveMatchesModel.clear();
        root.latestLiveMatches = sourceMatches;
        syncTeamTableOptions();
        matches = prioritizeFavorite(sourceMatches);
        matches = sortLiveMatches(matches);
        matches.forEach(match => {
            const row = matchForModel(liveMatchForModel(match));
            row.leagueGroup = root.liveLeagueGroupLabel(row);
            return liveMatchesModel.append(row);
        });
        root.requestAuxiliaryMatchModelsRefresh();
        root.pushMatchNotifications();
        root.prunePerMatchStateFromModels();
        const _applyMs = Date.now() - _applyStart;
        if (_applyMs >= 8)
            console.warn("[sports-widget][profile] applyLiveMatches took " + _applyMs + "ms (" + matches.length + " rows)");
        return matches.length;
    }

    // Collects current fixtures from the live and schedule models and prunes
    // per-match notify/pin entries for fixtures no longer present.
    function prunePerMatchStateFromModels() {
        const collect = (model) => {
            const out = [];
            for (let i = 0; i < model.count; i += 1) {
                const m = model.get(i);
                if (m && m.isPlaceholder !== true)
                    out.push(m);
            }
            return out;
        };
        root.prunePerMatchState(collect(liveMatchesModel), collect(scoresModel));
        root.rebuildLeaguesModel();
    }

    // A loose fixture identity (just the two teams, normalized) used to dedup the
    // same match across the live and schedule models. Schedule rows can carry
    // display-formatted team names (e.g. an away label with the competition
    // appended) and an empty league, while the live copy is clean - keying on
    // teams alone, with any trailing " - <league>" / " — <league>" suffix
    // stripped, catches both as the same match so it isn't listed twice.
    function looseMatchKey(match) {
        const strip = (name) => String(name || "")
            .replace(/\s*[—-]\s*[^—-]+$/, "")
            .trim()
            .toLowerCase();
        const home = strip(match && match.homeTeam);
        const away = strip(match && match.awayTeam);
        if (home.length === 0 && away.length === 0)
            return "";
        return home + "|" + away;
    }

    // Rebuilds leaguesMatchesModel: LIVE matches only, grouped under their league
    // with a stable per-league scopeOrder (the smallest scopeOrder seen for that
    // league), so leagues render in the user's configured priority. Upcoming
    // fixtures used to be mixed in here too, but that duplicated the Schedules
    // tab on the Live tab - live rows are the tab's whole point.
    function rebuildLeaguesModel() {
        const rows = [];

        for (let i = 0; i < liveMatchesModel.count; i += 1) {
            const m = liveMatchesModel.get(i);
            if (!m || m.isPlaceholder === true)
                continue;
            const copy = matchForModel(m);
            copy.leagueGroup = root.liveLeagueGroupLabel(copy);
            copy._isLive = true;
            rows.push(copy);
        }

        // Per-league priority = smallest scopeOrder seen for the league.
        let leaguePriority = {};
        rows.forEach(r => {
            const group = String(r.leagueGroup || "");
            const order = Number(r.scopeOrder);
            const current = leaguePriority[group];
            if (current === undefined || (Number.isFinite(order) && order < current))
                leaguePriority[group] = Number.isFinite(order) ? order : Number.MAX_SAFE_INTEGER;
        });

        rows.sort((left, right) => {
            const lp = leaguePriority[String(left.leagueGroup || "")];
            const rp = leaguePriority[String(right.leagueGroup || "")];
            if (lp !== rp)
                return lp - rp;
            const lg = String(left.leagueGroup || "").localeCompare(String(right.leagueGroup || ""));
            if (lg !== 0)
                return lg;
            // Kickoff order first so the longest-running match tops the group;
            // watched teams only break ties between simultaneous kickoffs.
            const timeDelta = root.normalizedMatchTimestamp(left) - root.normalizedMatchTimestamp(right);
            if (timeDelta !== 0)
                return timeDelta;
            return root.watchedTeamPriorityForMatch(left) - root.watchedTeamPriorityForMatch(right);
        });

        // Per-league summary (total + live counts) for the tab's section headers.
        let summaries = {};
        rows.forEach(r => {
            const group = String(r.leagueGroup || "");
            if (!summaries[group])
                summaries[group] = { "total": 0, "live": 0 };
            summaries[group].total += 1;
            if (r._isLive)
                summaries[group].live += 1;
        });
        root.leaguesGroupSummaries = summaries;

        leaguesMatchesModel.clear();
        rows.forEach(r => leaguesMatchesModel.append(r));
    }

    property var leaguesGroupSummaries: ({})

    function applyRecentResults(matches) {
        matches = Array.isArray(matches) ? matches : [];
        const cacheKey = "recent|" + root.dataScopeSignature();
        if (matches.length > 0) {
            matchCache.write(cacheKey, matches);
        } else {
            const cached = matchCache.read(cacheKey);
            if (cached && Array.isArray(cached.value) && cached.value.length > 0)
                matches = cached.value;
        }
        root.latestRecentMatches = matches.slice();
        syncTeamTableOptions();
        root.rebuildRecentModel();
        root.requestAuxiliaryMatchModelsRefresh();
        return root.latestRecentMatches.length;
    }

    // (Re)build the Recent Results model from the in-memory matches + scope list,
    // honouring the current collapse state. Crucially, a COLLAPSED group contributes
    // only a single fixed-height header row (a placeholder) and NONE of its match
    // rows - so the ListView never holds height-0 rows. Mixing height-0 rows with
    // full-height ones is what made contentHeight drift and the scroll jump; keeping
    // the model free of them makes every realized row a real, measurable height.
    function rebuildRecentModel() {
        recentResultsListModel.clear();
        const matches = sortRecentResultsByDate(root.latestRecentMatches);
        const byGroup = ({});
        matches.forEach(match => {
            const row = matchForModel(match);
            const scopeGroup = String(match.scopeGroup || "").trim();
            row.leagueGroup = scopeGroup.length > 0 ? scopeGroup : root.liveLeagueGroupLabel(row);
            if (!byGroup[row.leagueGroup])
                byGroup[row.leagueGroup] = [];
            byGroup[row.leagueGroup].push(row);
        });

        // Latest N matches per group (newest first; matches are already sorted), as
        // configured in Appearance → Widget → Recent.
        const perGroup = Math.min(30, Math.max(1, Number(Plasmoid.configuration.widgetRecentMatchesPerGroup) || 5));
        // Show teams, competitions, or both (Appearance → Widget → Recent).
        const filter = String(Plasmoid.configuration.widgetRecentFilter || "both");
        function typeAllowed(type) {
            if (filter === "teams")
                return type === "team";
            if (filter === "competitions")
                return type === "competition";
            return true;
        }

        // Emit groups in saved-scope order; each group is a header row, followed by
        // its (capped) match rows only when expanded.
        const emitted = ({});
        function emitGroup(group) {
            const key = String(group || "").trim();
            if (key.length === 0 || emitted[key])
                return;
            emitted[key] = true;
            const collapsed = Boolean(root.collapsedRecentGroups[key]);
            // Header marker row (always present so the section header renders).
            recentResultsListModel.append({
                "leagueGroup": key,
                "rowType": "header",
                "isPlaceholder": true
            });
            if (collapsed)
                return;
            const groupRows = (byGroup[key] || []).slice(0, perGroup);
            groupRows.forEach(row => recentResultsListModel.append(Object.assign({
                    "rowType": "match"
                }, row)));
            // Expanded but loaded-empty group (a club with no recent matches) gets a
            // clear notice instead of a blank gap.
            if (groupRows.length === 0 && !root.pendingRecentGroups[key] && root.recentGroupAttempted(key))
                recentResultsListModel.append({
                    "leagueGroup": key,
                    "rowType": "notice",
                    "isEmptyNotice": true
                });
        }

        root.recentScopeEntries().forEach(entry => {
            if (typeAllowed(root.entryType(entry)))
                emitGroup(root.entryGroupLabel(entry));
        });
        // Any groups present in the data but not in the scope list (defensive) - only
        // when not restricting to a single type, since their type is unknown.
        if (filter === "both")
            for (let group in byGroup)
                emitGroup(group);
    }

    // Append a lazily-loaded group's recent matches to whatever is already shown,
    // de-duped, then re-render. Used by requestRecentGroupLoad so expanding a group
    // adds to the list instead of replacing the first group's results.
    function mergeRecentResults(matches) {
        const additions = Array.isArray(matches) ? matches : [];
        if (additions.length === 0)
            return;
        const merged = root.mergeScopedMatches(root.latestRecentMatches.slice(), additions);
        applyRecentResults(merged);
    }

    // Same incremental merge for the Schedule tab.
    function mergeScheduleMatches(matches) {
        const additions = Array.isArray(matches) ? matches : [];
        root.schedulesLoading = false;
        if (additions.length === 0) {
            // No new fixtures (e.g. an off-season team): still re-render so the
            // expanded group shows its "no upcoming matches" notice and clears the
            // header spinner, instead of staying blank.
            if (root._modelRebuildReady)
                root.rebuildScheduleModel();
            return;
        }
        const merged = root.mergeScopedMatches(root.latestScheduleMatches.slice(), additions);
        applySchedules(merged, root.updatedText());
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

        // Include both provider-live matches and ones whose kickoff has passed, so
        // the Live tab is populated from schedule data the moment a match starts.
        const liveMatches = (Array.isArray(matches) ? matches : []).filter(match => {
            return root.isEffectivelyLive(match);
        }).map(match => liveMatchForModel(match));
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
        if (root.scheduleCount > 0)
            return;

        root.pendingScheduleMessage = message && message.length > 0 ? message : emptySchedulesText();
        root.schedulesLoading = true;
        root.errorMessage = "";
        emptySchedulesTimer.restart();
    }

    function scheduledMatches(matches) {
        const now = Date.now();
        return (Array.isArray(matches) ? matches : []).filter(match => {
            const status = String(match.status || "").toLowerCase();
            const timestamp = Number(match.timestamp || 0);
            // A match past kickoff (or provider-live) belongs in Live, not Schedules,
            // so it never shows in both places once it has started.
            if (root.isEffectivelyLive(match))
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
        // Only the primary (active competition) table is cached/restored.
        if (updatePrimary !== false) {
            const cacheKey = root.tableCacheKey();
            if (rows.length > 0) {
                matchCache.write(cacheKey, rows);
            } else {
                const cached = matchCache.read(cacheKey);
                if (cached && Array.isArray(cached.value) && cached.value.length > 0)
                    rows = cached.value;
            }
        }
        rows = rows.map(row => {
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
        rows.forEach(row => {
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

        rows.forEach(row => {
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
        recentModel: tooltipRecentMatchesModel
        loading: root.loading || root.schedulesLoading || root.liveLoading
        liveMatchesLimit: Math.max(1, Plasmoid.configuration.tooltipLiveMatchesLimit || 5)
        scheduleDaysAhead: Math.max(1, Plasmoid.configuration.tooltipScheduleDaysAhead || 1)
        recentDaysBack: Math.max(1, Plasmoid.configuration.tooltipRecentDaysBack || 5)
    }
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    // One-time migration from the old widgetTabs preset (all/liveStats/
    // liveTables/liveOnly) to the per-tab visibility switches. Runs only while a
    // legacy preset is still set; afterwards widgetTabs is cleared to "" so the
    // per-tab switches are the single source of truth.
    function migrateWidgetTabsPreset() {
        const preset = String(Plasmoid.configuration.widgetTabs || "").trim();
        if (preset.length === 0)
            return; // already migrated

        // Live + Schedules were always on; the preset only governed Recent/Tables.
        Plasmoid.configuration.showTabLive = true;
        Plasmoid.configuration.showTabSchedules = true;
        Plasmoid.configuration.showTabRecent = preset === "all" || preset === "liveStats";
        Plasmoid.configuration.showTabTables = preset === "all" || preset === "liveTables";
        Plasmoid.configuration.widgetTabs = "";
    }

    Component.onCompleted: {
        SportsApi.setDelayScheduler(root.scheduleNetworkDelay);
        migrateDefaultSelection();
        migrateWidgetTabsPreset();
        seedFromCache();
        root._modelRebuildReady = true;
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

    // Combined live + today's upcoming matches for the compact Leagues tab,
    // grouped by league and ordered by saved-entry priority (scopeOrder).
    ListModel {
        id: leaguesMatchesModel
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
        id: tooltipRecentMatchesModel
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

    // --- Match notifications & calendar sync ---

    Component {
        id: notificationComponent

        Notification {
            componentName: "plasma_workspace"
            eventId: "notification"
            flags: Notification.CloseOnTimeout
        }
    }

    // Default ("clicked") action for a match notification: opens the match page.
    Component {
        id: notificationOpenActionComponent

        NotificationAction {}
    }

    Component {
        id: networkDelayTimerComponent

        Timer {
            repeat: false
        }
    }

    // Delay scheduler handed to SportsApi so its request retries/cooldowns can
    // use real timed backoff (a .pragma library cannot create timers itself).
    function scheduleNetworkDelay(callback, delayMs) {
        const timer = networkDelayTimerComponent.createObject(root, {
            "interval": Math.max(0, Number(delayMs) || 0)
        });
        if (!timer) {
            callback();
            return;
        }

        timer.triggered.connect(() => {
            timer.destroy();
            callback();
        });
        timer.start();
    }

    Plasma5Support.DataSource {
        id: calendarRunner

        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => calendarRunner.disconnectSource(source)
    }

    Timer {
        id: startsSoonTimer

        interval: 60000
        repeat: true
        running: Plasmoid.configuration.notificationsEnabled && Plasmoid.configuration.notifyStartsSoon
        onTriggered: root.checkStartsSoon()
    }

    Timer {
        id: calendarSyncTimer

        interval: 4000
        repeat: false
        onTriggered: root.writeCalendar(root.pendingCalendarRows)
    }

    Connections {
        target: Plasmoid.configuration

        function onNotificationsEnabledChanged() {
            root.notifyHasBaseline = false;
            root.notifyLiveSnapshot = ({});
            root.notifyIncidentIds = ({});
        }

        function onCalendarSyncEnabledChanged() {
            if (Plasmoid.configuration.calendarSyncEnabled)
                root.syncCalendar();
            else
                root.removeCalendarResource();
        }

        function onCalendarIcsExportEnabledChanged() {
            // Toggled on: write the .ics now. Toggled off: leave the last file in
            // place (the user may still want to import it); a fresh write only
            // happens again if they re-enable.
            root.lastCalendarIcs = "";
            if (Plasmoid.configuration.calendarSyncEnabled && Plasmoid.configuration.calendarIcsExportEnabled)
                root.syncCalendar();
        }

        function onCalendarAkonadiEnabledChanged() {
            root.lastCalendarIcs = "";
            if (Plasmoid.configuration.calendarAkonadiEnabled) {
                // (Re)write the .ics and register the resource on next sync.
                if (Plasmoid.configuration.calendarSyncEnabled)
                    root.syncCalendar();
            } else if (root.calendarAkonadiEnsured) {
                // Turned Akonadi off: quiet the resource without touching the file.
                root.takeAkonadiResourceOffline();
                root.calendarAkonadiEnsured = false;
            }
        }

        function onCalendarEntryInclusionsChanged() {
            root.requestCalendarSync();
        }
    }

    Timer {
        id: refreshTimer

        // Reactive interval: recomputed when the live model or schedule/live arrays
        // change, so smart mode tightens the full-refresh cadence while matches are
        // live/imminent and relaxes it when idle (see liveRefreshTimer for the same
        // pattern). Manual mode just returns the fixed configured interval.
        interval: {
            void liveMatchesModel.count;
            void root.latestScheduleMatches;
            void root.latestLiveMatches;
            return root.refreshIntervalMs();
        }
        repeat: true
        running: true
        onTriggered: root.refreshScores(false)
    }

    Timer {
        id: liveRefreshTimer

        // Reactive interval: recomputed whenever the live model or the schedule/live
        // arrays change, so smart mode switches between fast (60 s) and idle cadence
        // automatically as matches start and finish.
        interval: {
            // Touch the reactive deps so the binding re-evaluates on changes.
            void liveMatchesModel.count;
            void root.latestScheduleMatches;
            void root.latestLiveMatches;
            return root.liveRefreshIntervalMs();
        }
        repeat: true
        running: false
        onTriggered: root.refreshLiveMatches(false)
    }

    // One-shot wake fired ~at the next kickoff so a starting match is picked up
    // promptly even while the live poll is idling in smart mode. Re-armed after
    // every refresh (see armKickoffWake).
    Timer {
        id: kickoffWakeTimer

        repeat: false
        running: false
        onTriggered: {
            // Promote immediately from already-known data, then pull fresh.
            if (root._modelRebuildReady) {
                applyLiveMatches(root.latestLiveMatches, false);
                root.rebuildScheduleModel();
            }
            root.refreshLiveMatches(false);
            root.armKickoffWake();
        }
    }

    // Debounces panel/tooltip model rebuilds so a refresh that applies live,
    // schedule and recent in quick succession rebuilds them once, not three times.
    Timer {
        id: auxModelsRefreshTimer

        interval: 120
        repeat: false
        onTriggered: root.refreshAuxiliaryMatchModels()
    }

    // Resume-from-suspend detector. Timers don't tick while the machine sleeps, so
    // on wake the gap since the previous tick is far larger than this interval -
    // that's the signal to force a refresh (otherwise stale pre-sleep live matches
    // linger until the next periodic refresh, which can be up to 30 min away).
    Timer {
        id: wakeDetectTimer

        interval: 15000
        repeat: true
        running: true
        onTriggered: {
            const now = Date.now();
            if (root.lastWakeTickMs > 0 && (now - root.lastWakeTickMs) > root.wakeRefreshThresholdMs())
                root.handleSystemWake();
            root.lastWakeTickMs = now;
        }
    }

    // Opt-in, slower than the live score refresh: polls each eligible live
    // match's ESPN incident feed for goal scorer / cards / substitutions.
    // Only runs while notifications + the "detailed events" setting are both
    // enabled (see detailedEventsAvailableFor / pollDetailedEvents).
    Timer {
        id: detailedEventsTimer

        interval: 90000
        repeat: true
        running: Plasmoid.configuration.notificationsEnabled && Plasmoid.configuration.notifyDetailedEvents
        onTriggered: root.pollDetailedEvents()
    }

    Timer {
        id: tableFallbackTimer

        interval: 15000
        repeat: false
        onTriggered: {
            if (root.tableRequestCompleted)
                return;

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
            if (root.schedulesLoading && root.scheduleCount === 0)
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
            if (root.scheduleCount === 0)
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

        function onWidgetRecentMatchesPerGroupChanged() {
            // Apply the new per-group cap immediately from already-fetched data.
            if (root._modelRebuildReady)
                root.rebuildRecentModel();
        }

        function onWidgetRecentFilterChanged() {
            // Apply the Teams/Competitions/Both filter immediately.
            if (root._modelRebuildReady)
                root.rebuildRecentModel();
        }

        function onWidgetScheduleMatchesPerGroupChanged() {
            // Per-group cap applies to already-fetched fixtures - just re-render.
            if (root._modelRebuildReady)
                root.rebuildScheduleModel();
        }

        function onWidgetScheduleDaysAheadChanged() {
            // The look-ahead window changes what is fetched, so a refresh is needed.
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
                root.armKickoffWake();
            } else {
                liveRefreshTimer.stop();
                kickoffWakeTimer.stop();
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
            // A quick-favourite star only added/removed a single team entry. A
            // full forced refresh here cleared every model and refetched every
            // saved entry, freezing the shell for seconds - instead just fetch
            // the new team's schedule/recent groups and merge them in.
            if (root.quickFavoriteEditPending) {
                root.quickFavoriteEditPending = false;
                const group = root.quickFavoritePendingGroup;
                root.quickFavoritePendingGroup = "";
                root.ensureActiveSport();
                Qt.callLater(root.refreshAuxiliaryMatchModels);
                if (group.length > 0) {
                    Qt.callLater(() => {
                        root.requestScheduleGroupLoad(group);
                        root.requestRecentGroupLoad(group);
                    });
                }
                return;
            }

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
            // Switching the active entry should reveal its data: expand + lazily
            // load its Recent/Schedule groups (no-op if already loaded).
            root.loadActiveEntryGroups();
        }
    }

    Timer {
        id: pinNoticeTimer

        interval: 6000
        onTriggered: root.pinNotice = ""
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
        matchRotationEnabled: Plasmoid.configuration.panelMatchRotationEnabled && Plasmoid.configuration.panelMode !== "simple"
        matchRotationInterval: Plasmoid.configuration.panelMatchRotationInterval
        matchRotationCount: root.panelRotationCount
        panelMode: Plasmoid.configuration.panelMode
        panelCountsFormat: Plasmoid.configuration.panelCountsFormat
        remainingCount: root.panelRemainingCount
        multiMatchMode: Plasmoid.configuration.panelMultiMatchMode
        stackMaxMatches: Plasmoid.configuration.panelStackMaxMatches
        stackSeparator: Plasmoid.configuration.panelStackSeparator
        stackMatches: root.panelStackMatches
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
        activeProviders: root.activeProviders
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
        showTabLive: Plasmoid.configuration.showTabLive
        showTabSchedules: Plasmoid.configuration.showTabSchedules
        showTabRecent: Plasmoid.configuration.showTabRecent
        showTabTables: Plasmoid.configuration.showTabTables
        widgetLayoutMode: Plasmoid.configuration.widgetLayoutMode
        simpleScheduleWindow: Plasmoid.configuration.widgetSimpleScheduleWindow
        heroEnabled: Plasmoid.configuration.widgetHeroEnabled
        tabsPosition: Plasmoid.configuration.widgetTabsPosition
        matchRotationEnabled: Plasmoid.configuration.widgetMatchRotationEnabled
        matchRotationInterval: Plasmoid.configuration.widgetMatchRotationInterval
        favoriteTeam: root.teamWatchMode() && root.watchedTeamNames().length === 1 ? root.effectiveFavoriteTeamName() : ""
        collapsedRecentGroups: root.collapsedRecentGroups
        collapsedScheduleGroups: root.collapsedScheduleGroups
        loadingRecentGroups: root.pendingRecentGroups
        loadingScheduleGroups: root.pendingScheduleGroups
        onRefreshRequested: root.refreshScores(true)
        onConfigureRequested: root.openSportSettings()
        onLeagueSelected: index => root.setActiveSavedLeagueIndex(index)
        onSportSelected: sport => root.selectActiveSport(sport)
        onTeamTableSelected: slug => root.selectTeamTable(slug)
        onTeamTableSeasonSelected: seasonKey => root.selectTeamTableSeason(seasonKey)
        onRecentGroupExpanded: group => root.requestRecentGroupLoad(group)
        onScheduleGroupExpanded: group => root.requestScheduleGroupLoad(group)
        onRecentGroupCollapsed: group => root.collapseRecentGroup(group)
        onScheduleGroupCollapsed: group => root.collapseScheduleGroup(group)

        showMatchActions: Plasmoid.configuration.showMatchRowActions
        matchActionsTick: root.matchActionsTick
        matchNotifyState: match => root.matchNotifyEnabled(match)
        matchPinnedState: match => root.matchPinnedToPanel(match)
        matchFavoriteState: match => root.isQuickFavoriteMatch(match)
        teamFavoriteState: teamName => root.isQuickFavoriteTeam(teamName)
        pinNoticeText: root.pinNotice
        onPinNoticeDismissed: root.pinNotice = ""
        onMatchNotifyToggled: match => { root.toggleMatchNotify(match); root.matchActionsTick += 1; }
        onMatchFavoriteToggled: (teamName, match) => { root.toggleQuickFavoriteTeam(teamName, match); root.matchActionsTick += 1; }
        onMatchPanelPinToggled: match => { root.toggleMatchPin(match); root.matchActionsTick += 1; }

        leaguesModel: leaguesMatchesModel
        leaguesCollapsedGroups: root.leaguesCollapsedGroups
        leaguesGroupSummaries: root.leaguesGroupSummaries
        onLeaguesGroupToggled: group => root.toggleLeaguesGroup(group)
    }
}
