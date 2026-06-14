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

import "../../code/SportsApi.js" as SportsApi
import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var configRoot
    property string combinedFilter: ""
    // Debounced copy of combinedFilter used by the grids below, so typing
    // doesn't trigger a full Repeater rebuild (recreating every card) on
    // each keystroke.
    property string appliedFilter: ""

    // League loading
    property bool loadingLeagues: false
    property string leagueLoadError: ""
    property int leagueRequestToken: 0

    // National teams
    property var nationalTeamOptions: []
    property bool loadingNationalTeams: false
    property int nationalTeamRequestToken: 0

    // Team discovery
    property var badgeByTeam: ({})
    property var pendingBadgeTeams: ({})
    property var attemptedBadgeTeams: ({})
    property var discoveredTeams: ({})
    property int discoveredTeamRevision: 0
    property var staticTeamOptions: []
    property bool staticTeamOptionsReady: false
    property bool teamDiscoveryRunning: false
    property int teamDiscoveryToken: 0
    property int teamDiscoveryDoneLeagues: 0
    property int teamDiscoveryTotalLeagues: 0
    property int teamDiscoveryRank: 0
    readonly property int teamDiscoveryLeagueLimit: 16
    readonly property int teamDiscoveryMaxRowsPerLeague: 40
    readonly property int badgePrefetchLimit: 20
    readonly property int idleResultLimit: 60
    readonly property int cardMinimumWidth: Kirigami.Units.gridUnit * 10

    readonly property bool pageActive: root.configRoot && root.configRoot.pageIndex === root.configRoot.combinedPageIndex
    readonly property bool footballMode: {
        const sportsStr = root.configRoot ? String(root.configRoot.cfg_selectedSports || "") : "";
        return sportsStr.split(",")[0].trim().toLowerCase() === "football";
    }
    readonly property bool playerMode: {
        const sportsStr = root.configRoot ? String(root.configRoot.cfg_selectedSports || "") : "";
        return sportsStr.split(",")[0].trim().toLowerCase() === "tennis";
    }
    readonly property bool isInternationalCountry: root.configRoot
        ? String(root.configRoot.cfg_country || "").trim().toLowerCase() === "world"
        : false

    readonly property var displayedLeagues: {
        if (!root.pageActive || !root.configRoot || root.loadingLeagues)
            return [];
        return root.configRoot.filtered(root.configRoot.leagueOptions(), root.appliedFilter);
    }

    readonly property var displayedTeams: {
        if (!root.pageActive || root.isInternationalCountry)
            return [];
        const _rev = root.discoveredTeamRevision;
        return root.mergedTeamOptions(root.appliedFilter);
    }

    readonly property var displayedNationalTeams: {
        if (!root.pageActive || !root.footballMode)
            return [];
        const opts = root.configRoot
            ? root.configRoot.filtered(root.nationalTeamOptions, root.appliedFilter)
            : root.nationalTeamOptions;
        return Array.isArray(opts) ? opts : [];
    }

    spacing: Kirigami.Units.smallSpacing
    Layout.fillWidth: true
    Layout.fillHeight: true

    Timer {
        id: badgePrefetchTimer
        interval: 120
        repeat: false
        onTriggered: root.prefetchVisibleBadges()
    }

    // Coalesces rapid-fire discovery updates (one per fetched league) into a
    // single re-render, since each bump forces a full team grid rebuild.
    Timer {
        id: discoveredTeamsRevisionTimer
        interval: 250
        repeat: false
        onTriggered: root.discoveredTeamRevision += 1
    }

    // Delays applying the search filter to the grids, since each change
    // rebuilds every visible card (Repeater model replacement).
    Timer {
        id: filterApplyTimer
        interval: 300
        repeat: false
        onTriggered: root.appliedFilter = root.combinedFilter
    }

    Connections {
        target: root.configRoot
        ignoreUnknownSignals: true

        function onCfg_countryChanged() {
            root.leagueRequestToken += 1;
            root.loadingLeagues = false;
            root.leagueLoadError = "";
            root.nationalTeamOptions = [];
            root.nationalTeamRequestToken += 1;
            root.badgeByTeam = ({});
            root.pendingBadgeTeams = ({});
            root.attemptedBadgeTeams = ({});
            root.refreshTeamPool();
            if (root.pageActive && root.footballMode)
                root.refreshNationalVariants();
        }

        function onCfg_selectedSportsChanged() {
            root.leagueRequestToken += 1;
            root.loadingLeagues = false;
            root.leagueLoadError = "";
            root.nationalTeamOptions = [];
            root.nationalTeamRequestToken += 1;
            root.badgeByTeam = ({});
            root.pendingBadgeTeams = ({});
            root.attemptedBadgeTeams = ({});
            root.refreshTeamPool();
            if (root.pageActive && root.footballMode)
                root.refreshNationalVariants();
        }

        function onPageIndexChanged() {
            if (!root.pageActive) {
                root.teamDiscoveryToken += 1;
                root.teamDiscoveryRunning = false;
                return;
            }
            root.loadLeagues();
            root.ensureStaticTeamOptions();
            root.scheduleBadgePrefetch();
            if (!root.teamDiscoveryRunning && root.discoveredTeamCount() === 0)
                root.startCountryTeamDiscovery();
            if (root.footballMode && root.nationalTeamOptions.length === 0)
                root.refreshNationalVariants();
        }
    }

    Component.onCompleted: {
        root.ensureStaticTeamOptions();
        root.scheduleBadgePrefetch();
    }

    // ── League loading ────────────────────────────────────────────────────────

    function loadLeagues() {
        if (!root.configRoot || !root.pageActive)
            return;
        const country = String(root.configRoot.cfg_country || "").trim();
        const sport = String(root.configRoot.normalizedSport() || "").trim();
        if (country.length === 0 || sport.length === 0)
            return;
        if (root.configRoot.cfg_providerLeagueCountry === country
                && Array.isArray(root.configRoot.cfg_providerLeagueOptions)
                && root.configRoot.cfg_providerLeagueOptions.length > 0)
            return;
        const token = root.leagueRequestToken + 1;
        root.leagueRequestToken = token;
        root.loadingLeagues = true;
        root.leagueLoadError = "";
        root.configRoot.cfg_providerLeagueCountry = "";
        root.configRoot.cfg_providerLeagueOptions = [];
        SportsApi.fetchCountryCompetitions({
            "provider": root.configRoot.currentProvider,
            "sports": sport,
            "country": country
        }, rows => {
            if (token !== root.leagueRequestToken)
                return;
            root.loadingLeagues = false;
            const options = (Array.isArray(rows) ? rows : []).map(row => ({
                "label": ProviderCatalog.normalizedCompetitionLabel(
                    String(row && row.label || "").trim(),
                    String(row && (row.slug || row.value) || "").trim()
                ),
                "value": String(row && (row.value || row.slug || row.label) || "").trim(),
                "slug": String(row && (row.slug || row.value) || "").trim(),
                "country": String(row && row.country || country).trim(),
                "path": String(row && row.path || "").trim(),
                "url": String(row && row.url || "").trim()
            })).filter(row => row.label.length > 0 && row.value.length > 0);
            root.configRoot.cfg_providerLeagueCountry = country;
            root.configRoot.cfg_providerLeagueOptions = options;
            if (options.length === 0)
                root.leagueLoadError = i18nc("@info", "No leagues or cups were found for this country.");
            if (root.pageActive && !root.playerMode && !root.teamDiscoveryRunning && root.teamDiscoveryTotalLeagues === 0)
                root.startCountryTeamDiscovery();
        }, message => {
            if (token !== root.leagueRequestToken)
                return;
            root.loadingLeagues = false;
            root.configRoot.cfg_providerLeagueCountry = country;
            root.configRoot.cfg_providerLeagueOptions = [];
            root.leagueLoadError = String(message || i18nc("@info", "Unable to load leagues from provider.")).trim();
        });
    }

    // ── National team variants ─────────────────────────────────────────────

    function normalizeText(value) {
        return String(value || "").trim().toLowerCase().replace(/\s+/g, " ");
    }

    function countryName() {
        return root.configRoot ? String(root.configRoot.countryLabel() || "").trim() : "";
    }

    function countryCode() {
        return root.configRoot ? String(root.configRoot.cfg_country || "").trim().toLowerCase() : "";
    }

    function countryFlagSource() {
        return root.configRoot ? String(root.configRoot.countryIcon(root.configRoot.cfg_country) || "") : "";
    }

    function isNationalVariant(teamName) {
        const country = root.normalizeText(root.countryName());
        const team = root.normalizeText(teamName);
        if (country.length === 0 || team.length === 0)
            return false;
        return team === country || team.indexOf(country + " ") === 0 || team.indexOf(country + "(") === 0;
    }

    function nationalVariantPriority(option) {
        const country = root.normalizeText(root.countryName());
        const label = root.normalizeText(option && option.label);
        if (label === country) return 0;
        if (label.indexOf(country + " women") === 0 || label.indexOf(country + "(w") === 0) return 1;
        if (label.indexOf("u23") >= 0) return 2;
        if (label.indexOf("u21") >= 0) return 3;
        if (label.indexOf("u20") >= 0) return 4;
        if (label.indexOf("u19") >= 0) return 5;
        return 6;
    }

    function loadVariantLeagues() {
        return [];
    }

    function refreshNationalVariants() {
        root.nationalTeamRequestToken += 1;
        root.loadingNationalTeams = false;
        root.nationalTeamOptions = [];
        const code = root.countryCode();
        if (code.length === 0 || code === "world" || code === "all")
            return;
        const token = root.nationalTeamRequestToken;
        const variants = {};

        function addVariant(teamName) {
            const value = String(teamName || "").trim();
            if (value.length === 0 || !root.isNationalVariant(value))
                return;
            const key = root.normalizeText(value);
            if (!variants[key])
                variants[key] = { label: value, value, flagSource: root.countryFlagSource() };
        }

        function commitVariants() {
            if (token !== root.nationalTeamRequestToken)
                return;
            let rows = Object.keys(variants).map(key => variants[key]);
            rows.sort((left, right) => root.nationalVariantPriority(left) - root.nationalVariantPriority(right)
                || String(left.label || "").localeCompare(String(right.label || "")));
            root.nationalTeamOptions = rows;
            root.loadingNationalTeams = false;
        }

        // Show base country name immediately so the user sees something at once.
        addVariant(root.countryName());
        root.nationalTeamOptions = Object.keys(variants).map(key => variants[key]);

        const leagues = root.loadVariantLeagues();
        if (leagues.length === 0)
            return;

        // Fetch world competition tables to discover variants (Women, U21, etc.).
        root.loadingNationalTeams = true;
        let pending = leagues.length;
        leagues.forEach(league => {
            SportsApi.fetchLeagueTable({
                "sports": "football",
                "country": "world",
                "league": String(league && league.value || "").trim(),
                "followMode": "league"
            }, rows => {
                if (token === root.nationalTeamRequestToken)
                    (Array.isArray(rows) ? rows : []).forEach(row => addVariant(row && row.team));
                pending -= 1;
                if (pending === 0)
                    commitVariants();
            }, () => {
                pending -= 1;
                if (pending === 0)
                    commitVariants();
            });
        });
    }

    // ── Team discovery ────────────────────────────────────────────────────────

    function teamKey(teamName) {
        return String(teamName || "").trim().toLowerCase();
    }

    function mergedTeamOptions(filterText) {
        const staticOptions = root.staticTeamOptionsReady ? root.staticTeamOptions : [];
        let merged = [];
        let seen = {};

        function appendOption(option) {
            const value = String(option && option.value || "").trim();
            if (value.length === 0) return;
            const key = root.teamKey(value);
            if (!key || seen[key]) return;
            seen[key] = true;
            merged.push({
                label: String(option && option.label || value).trim(),
                value,
                badge: String(option && option.badge || "").trim(),
                teamSlug: String(option && (option.teamSlug || option.team_slug) || "").trim(),
                teamPath: String(option && (option.teamPath || option.teamUrl || option.url) || "").trim(),
                rank: Number(option && option.rank)
            });
        }

        (Array.isArray(staticOptions) ? staticOptions : []).forEach(appendOption);
        Object.keys(root.discoveredTeams).forEach(key => appendOption(root.discoveredTeams[key]));

        merged.sort((left, right) => {
            const leftRank = Number(left && left.rank);
            const rightRank = Number(right && right.rank);
            const hasL = Number.isFinite(leftRank);
            const hasR = Number.isFinite(rightRank);
            if (hasL && hasR && leftRank !== rightRank) return leftRank - rightRank;
            if (hasL !== hasR) return hasL ? -1 : 1;
            return String(left.label || "").localeCompare(String(right.label || ""));
        });
        const filteredMerged = root.configRoot ? root.configRoot.filtered(merged, filterText) : merged;
        if (String(filterText || "").trim().length === 0)
            return filteredMerged.slice(0, root.idleResultLimit);
        return filteredMerged;
    }

    function isStaticTeamKey(key) {
        if (!root.staticTeamOptionsReady) return false;
        for (let i = 0; i < root.staticTeamOptions.length; i += 1) {
            const k = root.teamKey(root.staticTeamOptions[i] && root.staticTeamOptions[i].value);
            if (k.length > 0 && k === key) return true;
        }
        return false;
    }

    function scheduleBadgePrefetch() {
        if (!root.pageActive) return;
        badgePrefetchTimer.restart();
    }

    function ensureStaticTeamOptions() {
        if (root.staticTeamOptionsReady || !root.configRoot || !root.pageActive) return;
        const options = Array.isArray(root.configRoot.favoriteOptions()) ? root.configRoot.favoriteOptions() : [];
        root.staticTeamOptions = options;
        root.staticTeamOptionsReady = true;
    }

    function refreshTeamPool() {
        root.staticTeamOptions = [];
        root.staticTeamOptionsReady = false;
        root.discoveredTeams = ({});
        discoveredTeamsRevisionTimer.stop();
        root.discoveredTeamRevision += 1;
        root.teamDiscoveryRunning = false;
        root.teamDiscoveryDoneLeagues = 0;
        root.teamDiscoveryTotalLeagues = 0;
        root.teamDiscoveryRank = 0;
        root.teamDiscoveryToken += 1;
        root.ensureStaticTeamOptions();
        root.scheduleBadgePrefetch();
        if (root.pageActive)
            root.startCountryTeamDiscovery();
    }

    function leaguePriority(league) {
        const label = String(league && league.label || "").toLowerCase();
        if (label.length === 0) return -200;
        let score = 0;
        if (label.indexOf("premier") >= 0 || label.indexOf("super league") >= 0 || label.indexOf("division 1") >= 0 || label.indexOf("serie a") >= 0 || label.indexOf("bundesliga") >= 0 || label.indexOf("la liga") >= 0 || label.indexOf("ligue 1") >= 0 || label.indexOf("eredivisie") >= 0 || label.indexOf("primera") >= 0) score += 45;
        if (label.indexOf("championship") >= 0 || label.indexOf("league one") >= 0 || label.indexOf("league two") >= 0 || label.indexOf("division 2") >= 0 || label.indexOf("serie b") >= 0 || label.indexOf("segunda") >= 0 || label.indexOf("ligue 2") >= 0 || label.indexOf("2.liga") >= 0 || label.indexOf("2 liga") >= 0) score += 32;
        if (label.indexOf("league") >= 0 || label.indexOf("liga") >= 0) score += 12;
        if (label.indexOf("cup") >= 0 || label.indexOf("playoff") >= 0 || label.indexOf("play-off") >= 0 || label.indexOf("qualif") >= 0) score -= 22;
        if (label.indexOf("women") >= 0 || label.indexOf("womens") >= 0 || label.indexOf("ladies") >= 0) score -= 35;
        if (label.indexOf("reserve") >= 0 || label.indexOf("reserves") >= 0 || label.indexOf("youth") >= 0 || /\bu[0-9]{2}\b/.test(label) || /\bu[0-9]{1}\b/.test(label)) score -= 35;
        if (label.indexOf("amateur") >= 0 || label.indexOf("regional") >= 0 || label.indexOf("state") >= 0 || label.indexOf("metro") >= 0) score -= 20;
        if (label.indexOf("friendly") >= 0 || label.indexOf("friendlies") >= 0 || label.indexOf("virtual") >= 0 || label.indexOf("esoccer") >= 0) score -= 90;
        return score;
    }

    function prioritizedLeagues() {
        if (!root.configRoot) return [];
        const leagues = Array.isArray(root.configRoot.leagueOptions()) ? root.configRoot.leagueOptions().slice() : [];
        leagues.sort((left, right) => root.leaguePriority(right) - root.leaguePriority(left));
        return leagues.slice(0, root.teamDiscoveryLeagueLimit);
    }

    function mergeDiscoveredRows(rows) {
        const tableRows = Array.isArray(rows) ? rows : [];
        if (tableRows.length === 0) return;
        let nextTeams = Object.assign({}, root.discoveredTeams);
        let nextBadges = Object.assign({}, root.badgeByTeam);
        let nextAttempted = Object.assign({}, root.attemptedBadgeTeams);
        let nextRank = root.teamDiscoveryRank;
        let teamsChanged = false;
        let badgesChanged = false;
        tableRows.slice(0, root.teamDiscoveryMaxRowsPerLeague).forEach(row => {
            const team = String(row && row.team || "").trim();
            const key = root.teamKey(team);
            if (key.length === 0) return;
            const crest = String(row && (row.crest || row.team_logo) || "").trim();
            if (!nextTeams[key]) {
                nextTeams[key] = { label: team, value: team, badge: crest, teamSlug: String(row && (row.teamSlug || row.team_slug) || "").trim(), teamPath: String(row && (row.teamPath || row.teamUrl || row.url) || "").trim(), rank: nextRank };
                nextRank += 1;
                teamsChanged = true;
            } else if (crest.length > 0 && String(nextTeams[key].badge || "").trim().length === 0) {
                nextTeams[key] = Object.assign({}, nextTeams[key], { badge: crest });
                teamsChanged = true;
            }
            if (crest.length > 0 && String(nextBadges[key] || "").trim() !== crest) { nextBadges[key] = crest; nextAttempted[key] = true; badgesChanged = true; }
        });
        if (teamsChanged) { root.discoveredTeams = nextTeams; discoveredTeamsRevisionTimer.restart(); }
        root.teamDiscoveryRank = nextRank;
        if (badgesChanged) { root.badgeByTeam = nextBadges; root.attemptedBadgeTeams = nextAttempted; }
    }

    function mergeDiscoveredOptions(options) {
        const rows = Array.isArray(options) ? options : [];
        if (rows.length === 0) return;
        let nextTeams = Object.assign({}, root.discoveredTeams);
        let nextBadges = Object.assign({}, root.badgeByTeam);
        let nextAttempted = Object.assign({}, root.attemptedBadgeTeams);
        let nextRank = root.teamDiscoveryRank;
        let teamsChanged = false;
        let badgesChanged = false;
        rows.forEach(option => {
            const team = String(option && option.value || option && option.label || "").trim();
            const key = root.teamKey(team);
            if (key.length === 0) return;
            if (!nextTeams[key]) {
                nextTeams[key] = { label: String(option && option.label || team).trim(), value: team, badge: String(option && option.badge || "").trim(), teamSlug: String(option && (option.teamSlug || option.team_slug) || "").trim(), teamPath: String(option && (option.teamPath || option.teamUrl || option.url) || "").trim(), rank: nextRank };
                nextRank += 1;
                teamsChanged = true;
            }
            const badge = String(option && option.badge || "").trim();
            const tSlug = String(option && (option.teamSlug || option.team_slug) || "").trim();
            const tPath = String(option && (option.teamPath || option.teamUrl || option.url) || "").trim();
            if (badge.length > 0 && String(nextTeams[key].badge || "").trim() !== badge) { nextTeams[key].badge = badge; teamsChanged = true; }
            if (tSlug.length > 0 && String(nextTeams[key].teamSlug || "").trim() !== tSlug) { nextTeams[key].teamSlug = tSlug; teamsChanged = true; }
            if (tPath.length > 0 && String(nextTeams[key].teamPath || "").trim() !== tPath) { nextTeams[key].teamPath = tPath; teamsChanged = true; }
            if (badge.length > 0 && String(nextBadges[key] || "").trim() !== badge) { nextBadges[key] = badge; nextAttempted[key] = true; badgesChanged = true; }
        });
        if (teamsChanged) { root.discoveredTeams = nextTeams; discoveredTeamsRevisionTimer.restart(); }
        root.teamDiscoveryRank = nextRank;
        if (badgesChanged) { root.badgeByTeam = nextBadges; root.attemptedBadgeTeams = nextAttempted; }
    }





    function discoveredTeamCount() {
        return Object.keys(root.discoveredTeams).length;
    }

    function teamDiscoveryStatusText() {
        if (root.playerMode)
            return i18nc("@info", "Loading players from provider...");
        if (root.teamDiscoveryTotalLeagues === 0)
            return i18nc("@info", "Loading teams...");
        return i18nc("@info", "Loading teams from %1 of %2 competitions...", root.teamDiscoveryDoneLeagues, root.teamDiscoveryTotalLeagues);
    }

    function seededCountryTeams() {
        const sport = String(root.configRoot && root.configRoot.normalizedSport() || "").trim().toLowerCase();
        if (sport !== "football") return [];
        const country = String(root.configRoot && root.configRoot.cfg_country || "").trim().toLowerCase();
        const seeds = {
            "england": [["Arsenal","arsenal"],["Aston Villa","aston-villa"],["Bournemouth AFC","bournemouth-afc"],["Brentford","brentford"],["Brighton Hove Albion","brighton-hove-albion"],["Burnley","burnley"],["Chelsea","chelsea"],["Crystal Palace","crystal-palace"],["Everton","everton"],["Fulham","fulham"],["Leeds United","leeds-united"],["Liverpool","liverpool"],["Manchester City","manchester-city"],["Manchester United","manchester-united"],["Newcastle United","newcastle-united"],["Nottingham Forest","nottingham-forest"],["Sunderland","sunderland"],["Tottenham Hotspur","tottenham-hotspur"],["West Ham United","west-ham-united"],["Wolverhampton Wanderers","wolverhampton-wanderers"],["Leicester City","leicester-city"],["Ipswich Town","ipswich-town"],["Southampton","southampton"],["Sheffield United","sheffield-united"],["Coventry City","coventry-city"],["Middlesbrough","middlesbrough"],["West Bromwich Albion","west-bromwich-albion"],["Norwich City","norwich-city"],["Watford","watford"],["Swansea City","swansea-city"],["Queens Park Rangers","queens-park-rangers"],["Blackburn Rovers","blackburn-rovers"],["Preston North End","preston-north-end"],["Stoke City","stoke-city"],["Millwall","millwall"],["Bristol City","bristol-city"],["Hull City","hull-city"],["Portsmouth","portsmouth"],["Derby County","derby-county"],["Oxford United","oxford-united"]],
            "spain": [["Real Madrid","real-madrid"],["FC Barcelona","barcelona"],["Atletico Madrid","atletico-madrid"],["Athletic Bilbao","athletic-bilbao"],["Villarreal","villarreal"],["Real Betis","real-betis"],["Real Sociedad","real-sociedad"],["Sevilla","sevilla"],["Valencia","valencia"],["Celta Vigo","celta-vigo"],["Rayo Vallecano","rayo-vallecano"],["Osasuna","osasuna"],["Mallorca","mallorca"],["Getafe","getafe"],["Espanyol","espanyol"],["Girona","girona"],["Alaves","alaves"],["Levante","levante"],["Elche","elche"],["Real Oviedo","real-oviedo"],["Deportivo La Coruna","deportivo-la-coruna"],["Granada CF","granada-cf"],["Las Palmas","las-palmas"],["Real Zaragoza","real-zaragoza"],["Sporting Gijon","sporting-gijon"],["Malaga","malaga"],["Eibar","eibar"],["Almeria","almeria"],["Leganes","leganes"],["Cadiz","cadiz"]],
            "italy": [["Inter Milan","inter-milan"],["AC Milan","ac-milan"],["Juventus","juventus"],["Napoli","napoli"],["AS Roma","as-roma"],["Lazio","lazio"],["Atalanta","atalanta"],["Fiorentina","fiorentina"],["Bologna","bologna"],["Torino","torino"],["Genoa","genoa"],["Udinese","udinese"],["Sassuolo","sassuolo"],["Parma","parma"],["Cagliari","cagliari"],["Lecce","lecce"],["Hellas Verona","hellas-verona"],["Como","como"],["Pisa","pisa"],["Cremonese","cremonese"],["Palermo","palermo"],["Sampdoria","sampdoria"],["Bari","bari"],["Venezia","venezia"],["Empoli","empoli"],["Monza","monza"],["Frosinone","frosinone"],["Spezia","spezia"],["Cesena","cesena"],["Modena","modena"]],
            "germany": [["Bayern Munich","bayern-munich"],["Borussia Dortmund","borussia-dortmund"],["Bayer Leverkusen","bayer-leverkusen"],["RB Leipzig","rb-leipzig"],["Eintracht Frankfurt","eintracht-frankfurt"],["VfB Stuttgart","vfb-stuttgart"],["VfL Wolfsburg","vfl-wolfsburg"],["SC Freiburg","sc-freiburg"],["TSG Hoffenheim","tsg-hoffenheim"],["Mainz 05","mainz-05"],["Werder Bremen","werder-bremen"],["Augsburg","augsburg"],["Union Berlin","union-berlin"],["Borussia Monchengladbach","borussia-monchengladbach"],["Hamburger SV","hamburger-sv"],["FC Koln","fc-koln"],["St Pauli","st-pauli"],["Heidenheim","heidenheim"],["Schalke 04","schalke-04"],["Hertha Berlin","hertha-berlin"],["Hannover 96","hannover-96"],["Nurnberg","nurnberg"],["Kaiserslautern","kaiserslautern"],["Fortuna Dusseldorf","fortuna-dusseldorf"],["Darmstadt","darmstadt"],["Greuther Furth","greuther-furth"],["Paderborn","paderborn"],["Holstein Kiel","holstein-kiel"]],
            "france": [["Paris Saint Germain","paris-saint-germain"],["PSG","psg"],["Marseille","marseille"],["Lyon","lyon"],["Monaco","monaco"],["Lille","lille"],["Lens","lens"],["Rennes","rennes"],["Nice","nice"],["Strasbourg","strasbourg"],["Toulouse","toulouse"],["Nantes","nantes"],["Montpellier","montpellier"],["Brest","brest"],["Auxerre","auxerre"],["Lorient","lorient"],["Metz","metz"],["Paris FC","paris-fc"],["Le Havre","le-havre"],["Angers","angers"],["Saint Etienne","saint-etienne"],["Bordeaux","bordeaux"],["Caen","caen"],["Guingamp","guingamp"],["Nancy","nancy"],["Dijon","dijon"]],
            "portugal": [["Benfica","benfica"],["FC Porto","fc-porto"],["Sporting CP","sporting-cp"],["Braga","braga"],["Vitoria Guimaraes","vitoria-guimaraes"],["Boavista","boavista"],["Rio Ave","rio-ave"],["Famalicao","famalicao"],["Estoril","estoril"],["Casa Pia","casa-pia"]],
            "netherlands": [["Ajax","ajax"],["PSV Eindhoven","psv-eindhoven"],["Feyenoord","feyenoord"],["AZ Alkmaar","az-alkmaar"],["FC Twente","fc-twente"],["Utrecht","utrecht"],["Heerenveen","heerenveen"],["Groningen","groningen"],["Sparta Rotterdam","sparta-rotterdam"],["Vitesse","vitesse"]],
            "bulgaria": [["Levski Sofia","levski-sofia"],["Ludogorets Razgrad","ludogorets-razgrad"],["CSKA 1948 Sofia","cska-1948-sofia"],["CSKA Sofia","cska-sofia"],["Lokomotiv Plovdiv","lokomotiv-plovdiv"],["Cherno More Varna","cherno-more-varna"],["Arda","arda"],["Botev Plovdiv","botev-plovdiv"],["Slavia Sofia","slavia-sofia"],["Beroe","beroe"],["Lokomotiv Sofia","lokomotiv-sofia"],["Botev Vratsa","botev-vratsa"],["Spartak Varna","spartak-varna"],["Septemvri Sofia","septemvri-sofia"],["Dobrudzha","dobrudzha"],["Montana","montana"]],
            "argentina": [["Boca Juniors","boca-juniors"],["River Plate","river-plate"],["Racing Club","racing-club"],["Independiente","independiente"],["San Lorenzo","san-lorenzo"],["Estudiantes","estudiantes"],["Lanus","lanus"],["Huracan","huracan"],["Rosario Central","rosario-central"],["Newells Old Boys","newells-old-boys"],["Velez Sarsfield","velez-sarsfield"],["Atletico Tucuman","atletico-tucuman"],["Talleres","talleres"],["Banfield","banfield"],["Belgrano","belgrano"],["Platense","platense"],["Defensa y Justicia","defensa-y-justicia"],["Tigre","tigre"]],
            "austria": [["Red Bull Salzburg","red-bull-salzburg"],["Rapid Vienna","rapid-vienna"],["Austria Vienna","austria-vienna"],["LASK","lask"],["Sturm Graz","sturm-graz"],["Wolfsberg","wolfsberg"],["WSG Tirol","wsg-tirol"],["Blau-Weiss Linz","blau-weiss-linz"],["Altach","altach"],["Ried","ried"],["Klagenfurt","klagenfurt"],["Hartberg","hartberg"]],
            "belgium": [["Club Brugge","club-brugge"],["Anderlecht","anderlecht"],["Gent","gent"],["Standard Liege","standard-liege"],["Genk","genk"],["Union SG","union-sg"],["Antwerp","royal-antwerp"],["Cercle Brugge","cercle-brugge"],["Westerlo","westerlo"],["Charleroi","charleroi"],["Mechelen","mechelen"],["OHL","oud-heverlee-leuven"],["Kortrijk","kortrijk"],["Sint-Truiden","sint-truiden"],["Beerschot","beerschot"],["Eupen","eupen"]],
            "brazil": [["Flamengo","flamengo"],["Palmeiras","palmeiras"],["Corinthians","corinthians"],["Atletico Mineiro","atletico-mineiro"],["Fluminense","fluminense"],["Botafogo","botafogo"],["Sao Paulo","sao-paulo"],["Internacional","internacional"],["Gremio","gremio"],["Santos","santos"],["Cruzeiro","cruzeiro"],["Vasco da Gama","vasco-da-gama"],["Athletico Paranaense","athletico-paranaense"],["Fortaleza","fortaleza"],["Bahia","bahia"],["Red Bull Bragantino","red-bull-bragantino"],["Sport Recife","sport-recife"],["Ceara","ceara"],["Goias","goias"],["Coritiba","coritiba"]],
            "croatia": [["Dinamo Zagreb","dinamo-zagreb"],["Hajduk Split","hajduk-split"],["HNK Rijeka","rijeka"],["NK Osijek","osijek"],["NK Sibenik","sibenik"],["HNK Gorica","gorica"],["Varazdin","varazdin"],["Istra 1961","istra-1961"],["Lokomotiva Zagreb","lokomotiva-zagreb"],["NK Slaven Belupo","slaven-belupo"]],
            "czech-republic": [["Sparta Prague","sparta-prague"],["Slavia Prague","slavia-prague"],["Viktoria Plzen","viktoria-plzen"],["Mlada Boleslav","mlada-boleslav"],["FK Jablonec","jablonec"],["Sigma Olomouc","sigma-olomouc"],["Bohemians 1905","bohemians-1905"],["Banik Ostrava","banik-ostrava"],["Teplice","teplice"],["Slovacko","slovacko"],["Liberec","liberec"],["Ceske Budejovice","ceske-budejovice"]],
            "greece": [["Olympiacos","olympiacos"],["PAOK","paok"],["AEK Athens","aek-athens"],["Panathinaikos","panathinaikos"],["Aris","aris"],["Atromitos","atromitos"],["Asteras Tripolis","asteras-tripolis"],["OFI Crete","ofi-crete"],["Panetolikos","panetolikos"],["Ionikos","ionikos"],["Volos","volos"],["Lamia","lamia"]],
            "japan": [["Urawa Red Diamonds","urawa-red-diamonds"],["Gamba Osaka","gamba-osaka"],["Kashima Antlers","kashima-antlers"],["Kawasaki Frontale","kawasaki-frontale"],["Yokohama F Marinos","yokohama-f-marinos"],["Vissel Kobe","vissel-kobe"],["Cerezo Osaka","cerezo-osaka"],["Nagoya Grampus","nagoya-grampus"],["FC Tokyo","fc-tokyo"],["Sanfrecce Hiroshima","sanfrecce-hiroshima"],["Sagan Tosu","sagan-tosu"],["Avispa Fukuoka","avispa-fukuoka"],["Jubilo Iwata","jubilo-iwata"],["Shimizu S-Pulse","shimizu-s-pulse"]],
            "mexico": [["Club America","club-america"],["Guadalajara","guadalajara"],["Cruz Azul","cruz-azul"],["Tigres UANL","tigres-uanl"],["Monterrey","monterrey"],["Pumas UNAM","pumas-unam"],["Atlas","atlas"],["Leon","leon"],["Toluca","toluca"],["Santos Laguna","santos-laguna"],["Tijuana","tijuana"],["Necaxa","necaxa"],["Pachuca","pachuca"],["Queretaro","queretaro"],["Juarez","juarez"],["Mazatlan","mazatlan"]],
            "poland": [["Legia Warsaw","legia-warsaw"],["Lech Poznan","lech-poznan"],["Wisla Krakow","wisla-krakow"],["Rakow Czestochowa","rakow-czestochowa"],["Piast Gliwice","piast-gliwice"],["Jagiellonia Bialystok","jagiellonia"],["Gornik Zabrze","gornik-zabrze"],["Pogon Szczecin","pogon-szczecin"],["Cracovia","cracovia"],["Zaglebie Lubin","zaglebie-lubin"],["Korona Kielce","korona-kielce"],["Slask Wroclaw","slask-wroclaw"],["Warta Poznan","warta-poznan"],["Widzew Lodz","widzew-lodz"]],
            "romania": [["FCSB","fcsb"],["CFR Cluj","cfr-cluj"],["Rapid Bucharest","rapid-bucharest"],["Dinamo Bucharest","dinamo-bucharest"],["FC U Craiova","fc-u-craiova"],["Universitatea Craiova","universitatea-craiova"],["FC Botosani","fc-botosani"],["Sepsi OSK","sepsi-osk"],["Petrolul Ploiesti","petrolul"],["Farul Constanta","farul-constanta"],["FC Voluntari","fc-voluntari"],["Hermannstadt","hermannstadt"]],
            "russia": [["Zenit","zenit"],["Spartak Moscow","spartak-moscow"],["CSKA Moscow","cska-moscow"],["Lokomotiv Moscow","lokomotiv-moscow"],["Dynamo Moscow","dynamo-moscow"],["Krasnodar","krasnodar"],["Rostov","rostov"],["Rubin Kazan","rubin-kazan"],["Akhmat Grozny","akhmat-grozny"],["Ural Yekaterinburg","ural"],["Arsenal Tula","arsenal-tula"],["Krylya Sovetov","krylya-sovetov"]],
            "scotland": [["Celtic","celtic"],["Rangers","rangers"],["Hearts","hearts"],["Hibernian","hibernian"],["Aberdeen","aberdeen"],["Dundee United","dundee-united"],["Motherwell","motherwell"],["St Mirren","st-mirren"],["Livingston","livingston"],["Kilmarnock","kilmarnock"],["Ross County","ross-county"],["St Johnstone","st-johnstone"],["Dundee","dundee"],["Partick Thistle","partick-thistle"],["Inverness CT","inverness-caledonian-thistle"],["Hamilton Academical","hamilton-academical"]],
            "serbia": [["Red Star Belgrade","red-star-belgrade"],["Partizan","partizan"],["FK Vojvodina","vojvodina"],["FK Cukaricki","cukaricki"],["Radnicki Nis","radnicki-nis"],["Napredak","napredak"],["Spartak Subotica","spartak-subotica"],["TSC Backa Topola","tsc-backa-topola"],["FK Mladost","mladost"],["FK Proleter Novi Sad","proleter-novi-sad"]],
            "switzerland": [["Young Boys","young-boys"],["FC Basel","fc-basel"],["Servette","servette"],["FC Zurich","fc-zurich"],["Lugano","lugano"],["Luzern","luzern"],["Sion","sion"],["GC Zurich","grasshopper"],["FC Winterthur","fc-winterthur"],["Lausanne-Sport","lausanne-sport"],["St Gallen","st-gallen"],["Yverdon","yverdon"]],
            "turkey": [["Galatasaray","galatasaray"],["Fenerbahce","fenerbahce"],["Besiktas","besiktas"],["Trabzonspor","trabzonspor"],["Istanbul Basaksehir","istanbul-basaksehir"],["Sivasspor","sivasspor"],["Alanyaspor","alanyaspor"],["Antalyaspor","antalyaspor"],["Kayserispor","kayserispor"],["Kasimpasa","kasimpasa"],["Konyaspor","konyaspor"],["Goztepe","goztepe"],["Adana Demirspor","adana-demirspor"],["Hatayspor","hatayspor"],["Rizespor","rizespor"],["Bursaspor","bursaspor"]],
            "united-states": [["LA Galaxy","la-galaxy"],["LAFC","lafc"],["Inter Miami","inter-miami"],["Seattle Sounders","seattle-sounders"],["Atlanta United","atlanta-united"],["New York City FC","new-york-city-fc"],["New York Red Bulls","new-york-red-bulls"],["Portland Timbers","portland-timbers"],["Philadelphia Union","philadelphia-union"],["Columbus Crew","columbus-crew"],["FC Dallas","fc-dallas"],["Sporting Kansas City","sporting-kansas-city"],["New England Revolution","new-england-revolution"],["Toronto FC","toronto-fc"],["DC United","dc-united"],["Chicago Fire","chicago-fire"],["Colorado Rapids","colorado-rapids"],["Vancouver Whitecaps","vancouver-whitecaps"],["Orlando City","orlando-city"],["Nashville SC","nashville-sc"],["FC Cincinnati","fc-cincinnati"]]
        };
        return (seeds[country] || []).map(row => ({ label: row[0], value: row[0], teamSlug: row[1], badge: row[2] || "" }));
    }

    function startCountryTeamDiscovery() {
        if (!root.configRoot) return;
        const token = root.teamDiscoveryToken + 1;
        root.teamDiscoveryToken = token;
        root.teamDiscoveryDoneLeagues = 0;
        root.teamDiscoveryTotalLeagues = 0;

        if (root.isInternationalCountry) {
            root.teamDiscoveryRunning = false;
            root.finishTeamDiscovery(token);
            return;
        }

        root.teamDiscoveryRunning = true;

        if (root.playerMode) {
            SportsApi.fetchCountryTeams({
                "sports": root.configRoot.normalizedSport(),
                "country": root.configRoot.cfg_country || "world"
            }, rows => {
                if (token !== root.teamDiscoveryToken) return;
                root.mergeDiscoveredOptions(Array.isArray(rows) ? rows : []);
                root.finishTeamDiscovery(token);
            }, () => {
                if (token !== root.teamDiscoveryToken) return;
                root.finishTeamDiscovery(token);
            });
            return;
        }

        const leagues = root.prioritizedLeagues();
        root.teamDiscoveryTotalLeagues = leagues.length;

        const seededTeams = root.seededCountryTeams();
        if (seededTeams.length > 0) root.mergeDiscoveredOptions(seededTeams);

        if (leagues.length === 0) {
            root.finishTeamDiscovery(token);
            return;
        }

        let pending = leagues.length;
        leagues.forEach(league => {
            const leagueValue = String(league && league.value || "").trim();
            if (leagueValue.length === 0) {
                root.teamDiscoveryDoneLeagues += 1;
                pending -= 1;
                if (pending === 0) root.finishTeamDiscovery(token);
                return;
            }
            SportsApi.fetchLeagueTable({
                "sports": root.configRoot.normalizedSport(),
                "country": root.configRoot.cfg_country || "",
                "league": leagueValue,
                "followMode": "league"
            }, rows => {
                if (token !== root.teamDiscoveryToken) { pending -= 1; if (pending === 0) root.finishTeamDiscovery(token); return; }
                root.mergeDiscoveredRows(rows);
                root.teamDiscoveryDoneLeagues += 1;
                pending -= 1;
                if (pending === 0) root.finishTeamDiscovery(token);
            }, () => {
                if (token !== root.teamDiscoveryToken) { pending -= 1; if (pending === 0) root.finishTeamDiscovery(token); return; }
                root.teamDiscoveryDoneLeagues += 1;
                pending -= 1;
                if (pending === 0) root.finishTeamDiscovery(token);
            });
        });
    }

    function finishTeamDiscovery(token) {
        if (token !== root.teamDiscoveryToken) return;
        root.teamDiscoveryRunning = false;
        if (discoveredTeamsRevisionTimer.running) {
            discoveredTeamsRevisionTimer.stop();
            root.discoveredTeamRevision += 1;
        }
        root.prefetchVisibleBadges();
    }

    function setPendingTeam(teamName, pending) {
        const key = root.teamKey(teamName);
        if (key.length === 0) return;
        let next = Object.assign({}, root.pendingBadgeTeams);
        next[key] = Boolean(pending);
        root.pendingBadgeTeams = next;
    }

    function setTeamBadge(teamName, badge) {
        const key = root.teamKey(teamName);
        badge = String(badge || "").trim();
        if (key.length === 0) return;
        let next = Object.assign({}, root.badgeByTeam);
        next[key] = badge;
        root.badgeByTeam = next;
        let attempted = Object.assign({}, root.attemptedBadgeTeams);
        attempted[key] = true;
        root.attemptedBadgeTeams = attempted;
    }

    function fetchBadgeFromCountryLeagues(teamName, onDone) {
        onDone = onDone || function () {};
        if (!root.configRoot) { onDone(); return; }
        const leagues = root.prioritizedLeagues();
        if (!Array.isArray(leagues) || leagues.length === 0) { root.setTeamBadge(teamName, ""); onDone(); return; }
        const maxLookups = Math.min(6, leagues.length);
        let leagueIndex = 0;
        function lookupNextLeague() {
            if (leagueIndex >= maxLookups) { root.setTeamBadge(teamName, ""); onDone(); return; }
            const leagueValue = String(leagues[leagueIndex] && leagues[leagueIndex].value || "").trim();
            leagueIndex += 1;
            if (leagueValue.length === 0) { lookupNextLeague(); return; }
            SportsApi.fetchLeagueTable({
                "sports": root.configRoot.normalizedSport(),
                "country": root.configRoot.cfg_country || "",
                "league": leagueValue,
                "favoriteTeam": teamName,
                "followMode": "league"
            }, rows => {
                const tableRows = Array.isArray(rows) ? rows : [];
                for (let i = 0; i < tableRows.length; i += 1) {
                    const row = tableRows[i] || {};
                    if (SportsApi.sameTeamName(row.team, teamName)) {
                        const crest = String(row.crest || row.team_logo || "").trim();
                        if (crest.length > 0) { root.setTeamBadge(teamName, crest); onDone(); return; }
                    }
                }
                lookupNextLeague();
            }, () => { lookupNextLeague(); });
        }
        lookupNextLeague();
    }

    function ensureTeamBadge(teamName, forceRefresh, teamSlug) {
        forceRefresh = Boolean(forceRefresh);
        teamSlug = String(teamSlug || "").trim();
        const key = root.teamKey(teamName);
        if (key.length === 0) return;
        const existingBadge = String(root.badgeByTeam[key] || "").trim();
        if (!forceRefresh && existingBadge.length > 0) return;
        if (!forceRefresh && Boolean(root.attemptedBadgeTeams[key])) return;
        if (Boolean(root.pendingBadgeTeams[key])) return;
        if (root.isStaticTeamKey(key)) {
            root.setPendingTeam(teamName, true);
            root.fetchBadgeFromCountryLeagues(teamName, () => root.setPendingTeam(teamName, false));
            return;
        }
        root.setPendingTeam(teamName, true);
        SportsApi.fetchTeamBadge({
            "sports": root.configRoot ? root.configRoot.normalizedSport() : "football",
            "country": root.configRoot ? root.configRoot.cfg_country : "",
            "favoriteTeam": teamName,
            "teamSlug": teamSlug
        }, badge => {
            root.setPendingTeam(teamName, false);
            badge = String(badge || "").trim();
            if (badge.length > 0) { root.setTeamBadge(teamName, badge); return; }
            if (existingBadge.length > 0) return;
            root.fetchBadgeFromCountryLeagues(teamName, () => root.setPendingTeam(teamName, false));
        }, () => {
            if (existingBadge.length > 0) { root.setPendingTeam(teamName, false); return; }
            root.fetchBadgeFromCountryLeagues(teamName, () => root.setPendingTeam(teamName, false));
        });
    }

    function teamBadge(teamName) {
        const key = root.teamKey(teamName);
        if (key.length === 0) return "";
        return String(root.badgeByTeam[key] || "").trim();
    }

    function prefetchVisibleBadges() {
        if (!root.configRoot || root.teamDiscoveryRunning) return;
        const verifyExistingBadges = root.discoveredTeamCount() > 0;
        root.displayedTeams.slice(0, root.badgePrefetchLimit).forEach(option => {
            const teamName = String(option && option.value || "").trim();
            const teamSlug = String(option && (option.teamSlug || option.team_slug) || "").trim();
            if (teamName.length > 0) root.ensureTeamBadge(teamName, verifyExistingBadges, teamSlug);
        });
    }

    // ── UI ────────────────────────────────────────────────────────────────────

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            text: i18nc("@title:group", "Competitions & Teams")
            level: 2
        }

        Label {
            Layout.fillWidth: true
            text: root.configRoot
                ? (root.configRoot.multiSelectEnabled
                    ? i18nc("@info", "Choose competitions and teams to follow for %1.", root.configRoot.countryLabel())
                    : i18nc("@info", "Edit the competition or team for %1.", root.configRoot.countryLabel()))
                : ""
            opacity: 0.72
            wrapMode: Text.WordWrap
        }
    }

    TextField {
        Layout.fillWidth: true
        placeholderText: root.playerMode
            ? i18nc("@info:placeholder", "Search competitions and players")
            : i18nc("@info:placeholder", "Search competitions and teams")
        text: root.combinedFilter
        leftPadding: Kirigami.Units.gridUnit * 1.8
        onTextEdited: {
            root.combinedFilter = text;
            filterApplyTimer.restart();
        }

        Kirigami.Icon {
            anchors.left: parent.left
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.verticalCenter: parent.verticalCenter
            width: Kirigami.Units.iconSizes.small
            height: width
            source: "search"
            color: Kirigami.Theme.disabledTextColor
        }
    }

    ScrollView {
        id: mainScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true

        ColumnLayout {
            width: mainScroll.availableWidth
            spacing: Kirigami.Units.smallSpacing

            // ── Competitions ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    text: i18nc("@title:section", "Competitions")
                    level: 3
                    opacity: 0.85
                }

                Label {
                    visible: root.configRoot && root.configRoot.selectedLeagueValues().length > 0
                    text: root.configRoot ? i18nc("@label", "%1 selected", root.configRoot.selectedLeagueValues().length) : ""
                    color: Kirigami.Theme.highlightColor
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.loadingLeagues
                spacing: Kirigami.Units.smallSpacing

                BusyIndicator {
                    running: root.loadingLeagues
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                }

                Label {
                    text: i18nc("@info", "Loading competitions from provider...")
                    opacity: 0.78
                }
            }

            Label {
                Layout.fillWidth: true
                visible: !root.loadingLeagues && root.displayedLeagues.length === 0
                text: root.leagueLoadError.length > 0
                    ? root.leagueLoadError
                    : i18nc("@info", "No competitions found for this country.")
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.78
                wrapMode: Text.WordWrap
            }

            GridLayout {
                id: leagueGrid
                Layout.fillWidth: true
                visible: root.displayedLeagues.length > 0
                width: parent.width
                columns: Math.max(1, Math.floor((width + columnSpacing) / (root.cardMinimumWidth + columnSpacing)))
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.displayedLeagues
                    SportChoiceCard {
                        title: modelData.label
                        iconName: "view-calendar-list"
                        selected: root.configRoot && root.configRoot.isLeagueSelected(modelData.value)
                        onClicked: root.configRoot.selectLeague(modelData.value)
                    }
                }
            }

            // ── Teams ───────────────────────────────────────────────────────
            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                visible: !root.isInternationalCountry
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !root.isInternationalCountry

                Kirigami.Heading {
                    text: root.playerMode ? i18nc("@title:section", "Players") : i18nc("@title:section", "Teams")
                    level: 3
                    opacity: 0.85
                }

                Label {
                    readonly property int teamCount: root.configRoot
                        ? (root.configRoot.selectedNationalTeamValues().length
                           + root.configRoot.selectedFavoriteTeamValues().length)
                        : 0
                    visible: teamCount > 0
                    text: i18nc("@label", "%1 selected", teamCount)
                    color: Kirigami.Theme.highlightColor
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.footballMode && root.loadingNationalTeams
                spacing: Kirigami.Units.smallSpacing

                BusyIndicator {
                    running: root.loadingNationalTeams
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                }

                Label {
                    text: i18nc("@info", "Loading national team variants from provider...")
                    color: Kirigami.Theme.disabledTextColor
                    opacity: 0.78
                }
            }

            GridLayout {
                id: nationalTeamGrid
                Layout.fillWidth: true
                visible: root.displayedNationalTeams.length > 0
                width: parent.width
                columns: Math.max(1, Math.floor((width + columnSpacing) / (root.cardMinimumWidth + columnSpacing)))
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.displayedNationalTeams
                    SportChoiceCard {
                        title: modelData.label
                        flagSource: String(modelData.flagSource || "").indexOf("file://") === 0 ? modelData.flagSource : ""
                        iconName: "im-user"
                        selected: root.configRoot && root.configRoot.isNationalTeamSelected(modelData.value)
                        onClicked: root.configRoot.selectNationalTeam(modelData.value)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.teamDiscoveryRunning
                spacing: Kirigami.Units.smallSpacing

                BusyIndicator {
                    running: root.teamDiscoveryRunning
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                }

                Label {
                    Layout.fillWidth: true
                    text: root.teamDiscoveryStatusText()
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.WordWrap
                }
            }

            GridLayout {
                id: teamGrid
                Layout.fillWidth: true
                visible: root.displayedTeams.length > 0
                width: parent.width
                columns: Math.max(1, Math.floor((width + columnSpacing) / (root.cardMinimumWidth + columnSpacing)))
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.displayedTeams
                    SportChoiceCard {
                        title: modelData.label
                        iconSource: modelData.badge || root.teamBadge(modelData.value)
                        iconName: "im-user"
                        selected: root.configRoot && root.configRoot.isFavoriteTeamSelected(modelData.value)
                        onClicked: root.configRoot.selectFavoriteTeam(modelData.value, modelData)
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                visible: !root.isInternationalCountry && !root.teamDiscoveryRunning && root.displayedTeams.length === 0
                text: root.playerMode
                    ? i18nc("@info", "No tennis players were found by the provider.")
                    : i18nc("@info", "No teams were found for this country yet. Try another country or competition.")
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Item { Layout.preferredHeight: Kirigami.Units.gridUnit }
        }
    }
}
