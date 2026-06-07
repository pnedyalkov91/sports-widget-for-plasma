/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../../code/SportsApi.js" as SportsApi
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

SportStepPage {
    id: root

    property var configRoot
    property string favoriteFilter: ""
    readonly property var displayedOptions: root.computeDisplayedOptions()
    property var badgeByTeam: ({})
    property var pendingBadgeTeams: ({})
    property var attemptedBadgeTeams: ({})
    property var discoveredTeams: ({})
    property var fallbackCountryTeams: []
    property var featuredFallbackCountryTeams: []
    property var staticTeamOptions: []
    property bool staticTeamOptionsReady: false
    property bool teamDiscoveryRunning: false
    property int teamDiscoveryToken: 0
    property int teamDiscoveryDoneLeagues: 0
    property int teamDiscoveryTotalLeagues: 0
    property int teamDiscoveryRank: 0
    property int activeDiscoveryIndex: -1
    property int activeDiscoveryToken: 0
    property var activeDiscoveryLeagues: []
    property bool leagueTableDiscoveryStarted: false
    readonly property int directTeamDiscoveryLeagueLimit: 8
    readonly property int directTeamDiscoveryTimeoutMs: 9000
    readonly property int teamDiscoveryLeagueLimit: 8
    readonly property int teamDiscoveryTargetTeams: 160
    readonly property int teamDiscoveryMaxRowsPerLeague: 40
    readonly property int badgePrefetchLimit: 20
    readonly property bool pageActive: root.configRoot && root.configRoot.pageIndex === 2

    readonly property bool playerMode: root.configRoot && root.configRoot.normalizedSport() === "tennis"

    title: root.configRoot && root.configRoot.cfg_type === "team"
        ? (root.playerMode ? i18nc("@title:group", "Player") : i18nc("@title:group", "Team"))
        : i18nc("@title:group", "Highlighted Team")
    subtitle: root.configRoot && root.configRoot.cfg_type === "team"
        ? (root.playerMode
            ? i18nc("@info", "Choose one or more tennis players this widget should follow across competitions.")
            : root.configRoot.multiSelectEnabled
                ? i18nc("@info", "Choose one or more teams this widget should follow across competitions.")
                : i18nc("@info", "Choose the team this saved item should follow across competitions."))
        : i18nc("@info", "Optional. Choose a team to highlight inside this competition.")
    filterText: root.favoriteFilter
    filterPlaceholder: root.playerMode ? i18nc("@info:placeholder", "Search players") : i18nc("@info:placeholder", "Search teams")
    onFilterEdited: text => root.favoriteFilter = text
    onDisplayedOptionsChanged: root.scheduleBadgePrefetch()
    Component.onCompleted: root.refreshTeamPool()

    Connections {
        target: root.configRoot
        ignoreUnknownSignals: true

        function onCfg_countryChanged() {
            root.badgeByTeam = ({});
            root.pendingBadgeTeams = ({});
            root.attemptedBadgeTeams = ({});
            root.refreshTeamPool();
        }

        function onCfg_selectedSportsChanged() {
            root.badgeByTeam = ({});
            root.pendingBadgeTeams = ({});
            root.attemptedBadgeTeams = ({});
            root.refreshTeamPool();
        }

        function onCfg_typeChanged() {
            root.badgeByTeam = ({});
            root.pendingBadgeTeams = ({});
            root.attemptedBadgeTeams = ({});
            root.refreshTeamPool();
        }

        function onPageIndexChanged() {
            if (!root.pageActive) {
                root.teamDiscoveryToken += 1;
                root.teamDiscoveryRunning = false;
                root.activeDiscoveryIndex = -1;
                teamDiscoveryStepTimer.stop();
                directTeamDiscoveryTimer.stop();
                return;
            }

            root.ensureStaticTeamOptions();
            root.scheduleBadgePrefetch();
            if (root.isTeamMode() && !root.teamDiscoveryRunning && root.discoveredTeamCount() === 0)
                root.startCountryTeamDiscovery();
        }
    }

    Timer {
        id: badgePrefetchTimer

        interval: 120
        repeat: false
        onTriggered: root.prefetchVisibleBadges()
    }

    Timer {
        id: teamDiscoveryStepTimer

        interval: 8000
        repeat: false
        onTriggered: {
            if (root.activeDiscoveryToken !== root.teamDiscoveryToken || root.activeDiscoveryIndex < 0)
                return;

            root.teamDiscoveryDoneLeagues = Math.min(root.teamDiscoveryTotalLeagues, root.activeDiscoveryIndex + 1);
            root.fetchTeamsFromLeague(root.activeDiscoveryToken, root.activeDiscoveryLeagues, root.activeDiscoveryIndex + 1);
        }
    }

    Timer {
        id: directTeamDiscoveryTimer

        interval: root.directTeamDiscoveryTimeoutMs
        repeat: false
        onTriggered: root.startLeagueTableTeamDiscovery(root.activeDiscoveryToken, root.activeDiscoveryLeagues)
    }

    function teamKey(teamName) {
        return String(teamName || "").trim().toLowerCase();
    }

    function isTeamMode() {
        return root.configRoot && root.configRoot.cfg_type === "team";
    }

    function filteredStaticOptions() {
        if (!root.configRoot || !root.staticTeamOptionsReady)
            return [];

        return root.configRoot.filtered(root.staticTeamOptions, root.favoriteFilter);
    }

    function shouldIncludeFallbackTeams(filterText) {
        const filter = String(filterText || "").trim();
        return root.fallbackTeamOptions(filterText).length > 0;
    }

    function fallbackTeamOptions(filterText) {
        const filter = String(filterText || "").trim();
        if (filter.length >= 3)
            return root.fallbackCountryTeams;

        if (!root.teamDiscoveryRunning && root.discoveredTeamCount() === 0)
            return root.featuredFallbackCountryTeams;

        return [];
    }

    function mergedTeamOptions(filterText) {
        const staticOptions = root.staticTeamOptionsReady ? root.staticTeamOptions : [];
        let merged = [];
        let seen = {};

        function appendOption(option) {
            const value = String(option && option.value || "").trim();
            if (value.length === 0)
                return;

            const key = root.teamKey(value);
            if (key.length === 0 || seen[key])
                return;

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
        if (root.shouldIncludeFallbackTeams(filterText))
            root.fallbackTeamOptions(filterText).forEach(appendOption);

        merged.sort((left, right) => {
            const leftRank = Number(left && left.rank);
            const rightRank = Number(right && right.rank);
            const hasLeftRank = Number.isFinite(leftRank);
            const hasRightRank = Number.isFinite(rightRank);
            if (hasLeftRank && hasRightRank && leftRank !== rightRank)
                return leftRank - rightRank;
            if (hasLeftRank !== hasRightRank)
                return hasLeftRank ? -1 : 1;

            return String(left.label || "").localeCompare(String(right.label || ""));
        });
        return root.configRoot ? root.configRoot.filtered(merged, filterText) : merged;
    }

    function isStaticTeamKey(key) {
        if (!root.staticTeamOptionsReady)
            return false;

        for (let index = 0; index < root.staticTeamOptions.length; index += 1) {
            const optionKey = root.teamKey(root.staticTeamOptions[index] && root.staticTeamOptions[index].value);
            if (optionKey.length > 0 && optionKey === key)
                return true;
        }
        return false;
    }

    function computeDisplayedOptions() {
        if (!root.configRoot)
            return [];

        const options = root.isTeamMode() ? root.mergedTeamOptions(root.favoriteFilter) : root.filteredStaticOptions();
        return options;
    }

    function scheduleBadgePrefetch() {
        if (!root.pageActive)
            return;

        badgePrefetchTimer.restart();
    }

    function ensureStaticTeamOptions() {
        if (root.staticTeamOptionsReady || !root.configRoot || !root.pageActive)
            return;

        const options = Array.isArray(root.configRoot.favoriteOptions()) ? root.configRoot.favoriteOptions() : [];
        root.staticTeamOptions = options;
        root.staticTeamOptionsReady = true;
    }

    function refreshTeamPool() {
        root.staticTeamOptions = [];
        root.staticTeamOptionsReady = false;
        root.discoveredTeams = ({});
        root.fallbackCountryTeams = [];
        root.featuredFallbackCountryTeams = [];
        root.teamDiscoveryRunning = false;
        root.teamDiscoveryDoneLeagues = 0;
        root.teamDiscoveryTotalLeagues = 0;
        root.teamDiscoveryRank = 0;
        root.activeDiscoveryIndex = -1;
        root.leagueTableDiscoveryStarted = false;
        teamDiscoveryStepTimer.stop();
        directTeamDiscoveryTimer.stop();
        root.teamDiscoveryToken += 1;

        root.ensureStaticTeamOptions();
        root.scheduleBadgePrefetch();
        if (root.isTeamMode() && root.pageActive)
            root.startCountryTeamDiscovery();
    }

    function leaguePriority(league) {
        const label = String(league && league.label || "").toLowerCase();
        if (label.length === 0)
            return -200;

        let score = 0;
        if (label.indexOf("premier") >= 0 || label.indexOf("super league") >= 0 || label.indexOf("division 1") >= 0 || label.indexOf("serie a") >= 0 || label.indexOf("bundesliga") >= 0 || label.indexOf("la liga") >= 0 || label.indexOf("ligue 1") >= 0 || label.indexOf("eredivisie") >= 0 || label.indexOf("primera") >= 0)
            score += 45;

        if (label.indexOf("championship") >= 0 || label.indexOf("league one") >= 0 || label.indexOf("league two") >= 0 || label.indexOf("division 2") >= 0 || label.indexOf("serie b") >= 0 || label.indexOf("segunda") >= 0 || label.indexOf("ligue 2") >= 0 || label.indexOf("2.liga") >= 0 || label.indexOf("2 liga") >= 0)
            score += 32;

        if (label.indexOf("league") >= 0 || label.indexOf("liga") >= 0)
            score += 12;

        if (label.indexOf("cup") >= 0 || label.indexOf("playoff") >= 0 || label.indexOf("play-off") >= 0 || label.indexOf("qualif") >= 0)
            score -= 22;

        if (label.indexOf("women") >= 0 || label.indexOf("womens") >= 0 || label.indexOf("ladies") >= 0)
            score -= 35;

        if (label.indexOf("reserve") >= 0 || label.indexOf("reserves") >= 0 || label.indexOf("youth") >= 0 || /\bu[0-9]{2}\b/.test(label) || /\bu[0-9]{1}\b/.test(label))
            score -= 35;

        if (label.indexOf("amateur") >= 0 || label.indexOf("regional") >= 0 || label.indexOf("state") >= 0 || label.indexOf("metro") >= 0)
            score -= 20;

        if (label.indexOf("friendly") >= 0 || label.indexOf("friendlies") >= 0 || label.indexOf("virtual") >= 0 || label.indexOf("esoccer") >= 0)
            score -= 90;

        return score;
    }

    function prioritizedLeagues() {
        if (!root.configRoot)
            return [];

        const leagues = Array.isArray(root.configRoot.leagueOptions()) ? root.configRoot.leagueOptions().slice() : [];
        leagues.sort((left, right) => root.leaguePriority(right) - root.leaguePriority(left));
        return leagues.slice(0, root.teamDiscoveryLeagueLimit);
    }

    function mergeDiscoveredRows(rows) {
        const tableRows = Array.isArray(rows) ? rows : [];
        if (tableRows.length === 0)
            return;

        let nextTeams = Object.assign({}, root.discoveredTeams);
        let nextBadges = Object.assign({}, root.badgeByTeam);
        let nextAttempted = Object.assign({}, root.attemptedBadgeTeams);
        let nextRank = root.teamDiscoveryRank;
        let teamsChanged = false;
        let badgesChanged = false;

        tableRows.slice(0, root.teamDiscoveryMaxRowsPerLeague).forEach(row => {
            const team = String(row && row.team || "").trim();
            const key = root.teamKey(team);
            if (key.length === 0)
                return;

            if (!nextTeams[key]) {
                nextTeams[key] = {
                    label: team,
                    value: team,
                    badge: String(row && (row.crest || row.team_logo) || "").trim(),
                    teamSlug: String(row && (row.teamSlug || row.team_slug) || "").trim(),
                    teamPath: String(row && (row.teamPath || row.teamUrl || row.url) || "").trim(),
                    rank: nextRank
                };
                nextRank += 1;
                teamsChanged = true;
            }

            const crest = String(row && (row.crest || row.team_logo) || "").trim();
            if (crest.length > 0 && String(nextBadges[key] || "").trim() !== crest) {
                nextBadges[key] = crest;
                nextAttempted[key] = true;
                badgesChanged = true;
            }
        });

        if (teamsChanged)
            root.discoveredTeams = nextTeams;
        root.teamDiscoveryRank = nextRank;
        if (badgesChanged) {
            root.badgeByTeam = nextBadges;
            root.attemptedBadgeTeams = nextAttempted;
        }
    }

    function storeFallbackCountryTeams(options) {
        const rows = Array.isArray(options) ? options : [];
        if (rows.length === 0) {
            root.fallbackCountryTeams = [];
            root.featuredFallbackCountryTeams = [];
            return;
        }

        let seen = {};
        let nextOptions = [];
        let nextBadges = Object.assign({}, root.badgeByTeam);
        let nextAttempted = Object.assign({}, root.attemptedBadgeTeams);
        let badgesChanged = false;

        rows.forEach(option => {
            const team = String(option && option.value || option && option.label || "").trim();
            const key = root.teamKey(team);
            if (key.length === 0 || seen[key])
                return;

            seen[key] = true;
            nextOptions.push({
                label: String(option && option.label || team).trim(),
                value: team,
                badge: String(option && option.badge || "").trim(),
                teamSlug: String(option && (option.teamSlug || option.team_slug) || "").trim(),
                teamPath: String(option && (option.teamPath || option.teamUrl || option.url) || "").trim(),
                leagues: Array.isArray(option && option.leagues) ? option.leagues.slice() : []
            });

            const badge = String(option && option.badge || "").trim();
            if (badge.length > 0 && String(nextBadges[key] || "").trim() !== badge) {
                nextBadges[key] = badge;
                nextAttempted[key] = true;
                badgesChanged = true;
            }
        });

        root.fallbackCountryTeams = nextOptions;
        root.featuredFallbackCountryTeams = root.featuredCountryTeams(nextOptions);
        if (badgesChanged) {
            root.badgeByTeam = nextBadges;
            root.attemptedBadgeTeams = nextAttempted;
        }
    }

    function mergeDiscoveredOptions(options) {
        const rows = Array.isArray(options) ? options : [];
        if (rows.length === 0)
            return;

        let nextTeams = Object.assign({}, root.discoveredTeams);
        let nextBadges = Object.assign({}, root.badgeByTeam);
        let nextAttempted = Object.assign({}, root.attemptedBadgeTeams);
        let nextRank = root.teamDiscoveryRank;
        let teamsChanged = false;
        let badgesChanged = false;

        rows.forEach(option => {
            const team = String(option && option.value || option && option.label || "").trim();
            const key = root.teamKey(team);
            if (key.length === 0)
                return;

            if (!nextTeams[key]) {
                nextTeams[key] = {
                    label: String(option && option.label || team).trim(),
                    value: team,
                    badge: String(option && option.badge || "").trim(),
                    teamSlug: String(option && (option.teamSlug || option.team_slug) || "").trim(),
                    teamPath: String(option && (option.teamPath || option.teamUrl || option.url) || "").trim(),
                    rank: nextRank
                };
                nextRank += 1;
                teamsChanged = true;
            }

            const badge = String(option && option.badge || "").trim();
            const teamSlug = String(option && (option.teamSlug || option.team_slug) || "").trim();
            const teamPath = String(option && (option.teamPath || option.teamUrl || option.url) || "").trim();
            if (badge.length > 0 && String(nextTeams[key].badge || "").trim() !== badge) {
                nextTeams[key].badge = badge;
                teamsChanged = true;
            }
            if (teamSlug.length > 0 && String(nextTeams[key].teamSlug || "").trim() !== teamSlug) {
                nextTeams[key].teamSlug = teamSlug;
                teamsChanged = true;
            }
            if (teamPath.length > 0 && String(nextTeams[key].teamPath || "").trim() !== teamPath) {
                nextTeams[key].teamPath = teamPath;
                teamsChanged = true;
            }
            if (badge.length > 0 && String(nextBadges[key] || "").trim() !== badge) {
                nextBadges[key] = badge;
                nextAttempted[key] = true;
                badgesChanged = true;
            }
        });

        if (teamsChanged)
            root.discoveredTeams = nextTeams;
        root.teamDiscoveryRank = nextRank;
        if (badgesChanged) {
            root.badgeByTeam = nextBadges;
            root.attemptedBadgeTeams = nextAttempted;
        }
    }

    function featuredCountryTeams(options) {
        const rows = Array.isArray(options) ? options : [];
        if (rows.length === 0)
            return [];

        const leagueKeys = root.featuredLeagueKeys();
        if (leagueKeys.length === 0)
            return [];

        return rows.filter(option => {
            const leagues = Array.isArray(option && option.leagues) ? option.leagues : [];
            for (let leagueIndex = 0; leagueIndex < leagues.length; leagueIndex += 1) {
                const key = root.leagueMatchKey(leagues[leagueIndex]);
                if (key.length > 0 && leagueKeys.indexOf(key) >= 0)
                    return true;
            }
            return false;
        });
    }

    function featuredLeagueKeys() {
        const leagues = root.prioritizedLeagues().filter(league => root.leaguePriority(league) > 0).slice(0, 4);
        let keys = [];
        leagues.forEach(league => {
            const label = String(league && league.label || "").trim();
            const value = String(league && league.value || "").trim();
            [label, value].forEach(candidate => {
                const key = root.leagueMatchKey(candidate);
                if (key.length > 0 && keys.indexOf(key) < 0)
                    keys.push(key);
            });
        });
        return keys;
    }

    function leagueMatchKey(value) {
        let text = String(value || "").trim().toLowerCase();
        if (text.length === 0)
            return "";

        text = text.replace(/^english\s+/, "");
        text = text.replace(/^scottish\s+/, "");
        text = text.replace(/^welsh\s+/, "");
        text = text.replace(/^northern ireland\s+/, "");
        text = text.replace(/^ireland\s+/, "");
        text = text.replace(/^bulgarian\s+/, "");
        text = text.replace(/^spanish\s+/, "");
        text = text.replace(/^italian\s+/, "");
        text = text.replace(/^french\s+/, "");
        text = text.replace(/^german\s+/, "");
        return text.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
    }

    function discoveredTeamCount() {
        return Object.keys(root.discoveredTeams).length;
    }

    function teamDiscoveryStatusText() {
        if (root.activeDiscoveryLeagues.length === 0)
            return i18nc("@info", "Loading teams from provider...");

        return i18nc("@info", "Loading teams from %1 of %2 competitions...", root.teamDiscoveryDoneLeagues, Math.max(1, root.teamDiscoveryTotalLeagues));
    }

    function seededCountryTeams() {
        const country = String(root.configRoot && root.configRoot.cfg_country || "").trim().toLowerCase();
        const seeds = {
            "england": [
                ["Arsenal", "arsenal"],
                ["Aston Villa", "aston-villa"],
                ["Bournemouth AFC", "bournemouth-afc"],
                ["Brentford", "brentford"],
                ["Brighton Hove Albion", "brighton-hove-albion"],
                ["Burnley", "burnley"],
                ["Chelsea", "chelsea"],
                ["Crystal Palace", "crystal-palace"],
                ["Everton", "everton"],
                ["Fulham", "fulham"],
                ["Leeds United", "leeds-united"],
                ["Liverpool", "liverpool"],
                ["Manchester City", "manchester-city"],
                ["Manchester United", "manchester-united"],
                ["Newcastle United", "newcastle-united"],
                ["Nottingham Forest", "nottingham-forest"],
                ["Sunderland", "sunderland"],
                ["Tottenham Hotspur", "tottenham-hotspur"],
                ["West Ham United", "west-ham-united"],
                ["Wolverhampton Wanderers", "wolverhampton-wanderers"],
                ["Leicester City", "leicester-city"],
                ["Ipswich Town", "ipswich-town"],
                ["Southampton", "southampton"],
                ["Sheffield United", "sheffield-united"],
                ["Coventry City", "coventry-city"],
                ["Middlesbrough", "middlesbrough"],
                ["West Bromwich Albion", "west-bromwich-albion"],
                ["Norwich City", "norwich-city"],
                ["Watford", "watford"],
                ["Swansea City", "swansea-city"],
                ["Queens Park Rangers", "queens-park-rangers"],
                ["Blackburn Rovers", "blackburn-rovers"],
                ["Preston North End", "preston-north-end"],
                ["Stoke City", "stoke-city"],
                ["Millwall", "millwall"],
                ["Bristol City", "bristol-city"],
                ["Hull City", "hull-city"],
                ["Portsmouth", "portsmouth"],
                ["Derby County", "derby-county"],
                ["Oxford United", "oxford-united"]
            ],
            "spain": [
                ["Real Madrid", "real-madrid"],
                ["FC Barcelona", "barcelona"],
                ["Atletico Madrid", "atletico-madrid"],
                ["Athletic Bilbao", "athletic-bilbao"],
                ["Villarreal", "villarreal"],
                ["Real Betis", "real-betis"],
                ["Real Sociedad", "real-sociedad"],
                ["Sevilla", "sevilla"],
                ["Valencia", "valencia"],
                ["Celta Vigo", "celta-vigo"],
                ["Rayo Vallecano", "rayo-vallecano"],
                ["Osasuna", "osasuna"],
                ["Mallorca", "mallorca"],
                ["Getafe", "getafe"],
                ["Espanyol", "espanyol"],
                ["Girona", "girona"],
                ["Alaves", "alaves"],
                ["Levante", "levante"],
                ["Elche", "elche"],
                ["Real Oviedo", "real-oviedo"],
                ["Deportivo La Coruna", "deportivo-la-coruna"],
                ["Granada CF", "granada-cf"],
                ["Las Palmas", "las-palmas"],
                ["Real Zaragoza", "real-zaragoza"],
                ["Sporting Gijon", "sporting-gijon"],
                ["Malaga", "malaga"],
                ["Eibar", "eibar"],
                ["Almeria", "almeria"],
                ["Leganes", "leganes"],
                ["Cadiz", "cadiz"]
            ],
            "italy": [
                ["Inter Milan", "inter-milan"],
                ["AC Milan", "ac-milan"],
                ["Juventus", "juventus"],
                ["Napoli", "napoli"],
                ["AS Roma", "as-roma"],
                ["Lazio", "lazio"],
                ["Atalanta", "atalanta"],
                ["Fiorentina", "fiorentina"],
                ["Bologna", "bologna"],
                ["Torino", "torino"],
                ["Genoa", "genoa"],
                ["Udinese", "udinese"],
                ["Sassuolo", "sassuolo"],
                ["Parma", "parma"],
                ["Cagliari", "cagliari"],
                ["Lecce", "lecce"],
                ["Hellas Verona", "hellas-verona"],
                ["Como", "como"],
                ["Pisa", "pisa"],
                ["Cremonese", "cremonese"],
                ["Palermo", "palermo"],
                ["Sampdoria", "sampdoria"],
                ["Bari", "bari"],
                ["Venezia", "venezia"],
                ["Empoli", "empoli"],
                ["Monza", "monza"],
                ["Frosinone", "frosinone"],
                ["Spezia", "spezia"],
                ["Cesena", "cesena"],
                ["Modena", "modena"]
            ],
            "germany": [
                ["Bayern Munich", "bayern-munich"],
                ["Borussia Dortmund", "borussia-dortmund"],
                ["Bayer Leverkusen", "bayer-leverkusen"],
                ["RB Leipzig", "rb-leipzig"],
                ["Eintracht Frankfurt", "eintracht-frankfurt"],
                ["VfB Stuttgart", "vfb-stuttgart"],
                ["VfL Wolfsburg", "vfl-wolfsburg"],
                ["SC Freiburg", "sc-freiburg"],
                ["TSG Hoffenheim", "tsg-hoffenheim"],
                ["Mainz 05", "mainz-05"],
                ["Werder Bremen", "werder-bremen"],
                ["Augsburg", "augsburg"],
                ["Union Berlin", "union-berlin"],
                ["Borussia Monchengladbach", "borussia-monchengladbach"],
                ["Hamburger SV", "hamburger-sv"],
                ["FC Koln", "fc-koln"],
                ["St Pauli", "st-pauli"],
                ["Heidenheim", "heidenheim"],
                ["Schalke 04", "schalke-04"],
                ["Hertha Berlin", "hertha-berlin"],
                ["Hannover 96", "hannover-96"],
                ["Nurnberg", "nurnberg"],
                ["Kaiserslautern", "kaiserslautern"],
                ["Fortuna Dusseldorf", "fortuna-dusseldorf"],
                ["Darmstadt", "darmstadt"],
                ["Greuther Furth", "greuther-furth"],
                ["Paderborn", "paderborn"],
                ["Holstein Kiel", "holstein-kiel"]
            ],
            "france": [
                ["Paris Saint Germain", "paris-saint-germain"],
                ["PSG", "psg"],
                ["Marseille", "marseille"],
                ["Lyon", "lyon"],
                ["Monaco", "monaco"],
                ["Lille", "lille"],
                ["Lens", "lens"],
                ["Rennes", "rennes"],
                ["Nice", "nice"],
                ["Strasbourg", "strasbourg"],
                ["Toulouse", "toulouse"],
                ["Nantes", "nantes"],
                ["Montpellier", "montpellier"],
                ["Brest", "brest"],
                ["Auxerre", "auxerre"],
                ["Lorient", "lorient"],
                ["Metz", "metz"],
                ["Paris FC", "paris-fc"],
                ["Le Havre", "le-havre"],
                ["Angers", "angers"],
                ["Saint Etienne", "saint-etienne"],
                ["Bordeaux", "bordeaux"],
                ["Caen", "caen"],
                ["Guingamp", "guingamp"],
                ["Nancy", "nancy"],
                ["Dijon", "dijon"]
            ],
            "portugal": [
                ["Benfica", "benfica"],
                ["FC Porto", "fc-porto"],
                ["Sporting CP", "sporting-cp"],
                ["Braga", "braga"],
                ["Vitoria Guimaraes", "vitoria-guimaraes"],
                ["Boavista", "boavista"],
                ["Rio Ave", "rio-ave"],
                ["Famalicao", "famalicao"],
                ["Estoril", "estoril"],
                ["Casa Pia", "casa-pia"]
            ],
            "netherlands": [
                ["Ajax", "ajax"],
                ["PSV Eindhoven", "psv-eindhoven"],
                ["Feyenoord", "feyenoord"],
                ["AZ Alkmaar", "az-alkmaar"],
                ["FC Twente", "fc-twente"],
                ["Utrecht", "utrecht"],
                ["Heerenveen", "heerenveen"],
                ["Groningen", "groningen"],
                ["Sparta Rotterdam", "sparta-rotterdam"],
                ["Vitesse", "vitesse"]
            ],
            "bulgaria": [
                ["Levski Sofia", "levski-sofia"],
                ["Ludogorets Razgrad", "ludogorets-razgrad"],
                ["CSKA 1948 Sofia", "cska-1948-sofia"],
                ["CSKA Sofia", "cska-sofia"],
                ["Lokomotiv Plovdiv", "lokomotiv-plovdiv"],
                ["Cherno More Varna", "cherno-more-varna"],
                ["Arda", "arda"],
                ["Botev Plovdiv", "botev-plovdiv"],
                ["Slavia Sofia", "slavia-sofia"],
                ["Beroe", "beroe"],
                ["Lokomotiv Sofia", "lokomotiv-sofia"],
                ["Botev Vratsa", "botev-vratsa"],
                ["Spartak Varna", "spartak-varna"],
                ["Septemvri Sofia", "septemvri-sofia"],
                ["Dobrudzha", "dobrudzha"],
                ["Montana", "montana"]
            ]
        };
        const rows = seeds[country] || [];
        return rows.map(row => {
            return {
                label: row[0],
                value: row[0],
                teamSlug: row[1],
                badge: row[2] || ""
            };
        });
    }

    function startCountryTeamDiscovery() {
        if (!root.configRoot || !root.isTeamMode())
            return;

        const leagues = root.prioritizedLeagues();
        const token = root.teamDiscoveryToken + 1;
        root.teamDiscoveryToken = token;
        root.teamDiscoveryRunning = true;
        root.teamDiscoveryDoneLeagues = 0;
        root.leagueTableDiscoveryStarted = false;
        root.activeDiscoveryToken = token;
        root.activeDiscoveryLeagues = leagues;
        root.activeDiscoveryIndex = -1;
        const directLeagues = leagues.slice(0, Math.min(root.directTeamDiscoveryLeagueLimit, leagues.length));
        root.teamDiscoveryTotalLeagues = Math.max(1, directLeagues.length);
        const seededTeams = root.seededCountryTeams();
        if (seededTeams.length > 0)
            root.mergeDiscoveredOptions(seededTeams);

        if (directLeagues.length > 0)
            directTeamDiscoveryTimer.restart();

        SportsApi.fetchCountryTeams({
            "provider": root.configRoot.currentProvider,
            "sports": root.configRoot.normalizedSport(),
            "country": root.configRoot.cfg_country || "",
            "leagues": directLeagues
        }, rows => {
            if (token !== root.teamDiscoveryToken)
                return;

            directTeamDiscoveryTimer.stop();
            root.mergeDiscoveredOptions(rows);
            if (root.discoveredTeamCount() > 0) {
                root.teamDiscoveryDoneLeagues = root.teamDiscoveryTotalLeagues;
                root.finishTeamDiscovery(token);
                return;
            }

            if (leagues.length > 0) {
                root.startLeagueTableTeamDiscovery(token, leagues);
            } else {
                root.teamDiscoveryDoneLeagues = root.teamDiscoveryTotalLeagues;
                root.finishTeamDiscovery(token);
            }
        }, () => {
            if (token !== root.teamDiscoveryToken)
                return;

            directTeamDiscoveryTimer.stop();
            if (root.discoveredTeamCount() > 0 || leagues.length === 0) {
                root.teamDiscoveryDoneLeagues = root.teamDiscoveryTotalLeagues;
                root.finishTeamDiscovery(token);
            } else {
                root.startLeagueTableTeamDiscovery(token, leagues);
            }
        });
    }

    function finishTeamDiscovery(token) {
        if (token !== root.teamDiscoveryToken)
            return;

        directTeamDiscoveryTimer.stop();
        root.teamDiscoveryRunning = false;
        root.prefetchVisibleBadges();
    }

    function startLeagueTableTeamDiscovery(token, leagues) {
        if (token !== root.teamDiscoveryToken || root.leagueTableDiscoveryStarted)
            return;

        root.leagueTableDiscoveryStarted = true;
        root.teamDiscoveryRunning = true;
        root.teamDiscoveryDoneLeagues = 0;
        root.teamDiscoveryTotalLeagues = leagues.length;
        root.fetchTeamsFromLeague(token, leagues, 0);
    }

    function fetchTeamsFromLeague(token, leagues, index) {
        if (token !== root.teamDiscoveryToken)
            return;

        if (index >= leagues.length || root.discoveredTeamCount() >= root.teamDiscoveryTargetTeams) {
            teamDiscoveryStepTimer.stop();
            root.activeDiscoveryIndex = -1;
            root.finishTeamDiscovery(token);
            return;
        }

        const league = leagues[index] || {};
        const leagueValue = String(league.value || "").trim();
        if (leagueValue.length === 0) {
            root.teamDiscoveryDoneLeagues = Math.min(root.teamDiscoveryTotalLeagues, index + 1);
            root.fetchTeamsFromLeague(token, leagues, index + 1);
            return;
        }

        root.activeDiscoveryToken = token;
        root.activeDiscoveryLeagues = leagues;
        root.activeDiscoveryIndex = index;
        teamDiscoveryStepTimer.restart();

        SportsApi.fetchLeagueTable({
            "sports": root.configRoot.normalizedSport(),
            "country": root.configRoot.cfg_country || "",
            "league": leagueValue,
            "followMode": "league"
        }, rows => {
            if (token !== root.teamDiscoveryToken || index !== root.activeDiscoveryIndex)
                return;

            teamDiscoveryStepTimer.stop();
            root.mergeDiscoveredRows(rows);
            root.teamDiscoveryDoneLeagues = Math.min(root.teamDiscoveryTotalLeagues, index + 1);
            root.fetchTeamsFromLeague(token, leagues, index + 1);
        }, () => {
            if (token !== root.teamDiscoveryToken || index !== root.activeDiscoveryIndex)
                return;

            teamDiscoveryStepTimer.stop();
            root.teamDiscoveryDoneLeagues = Math.min(root.teamDiscoveryTotalLeagues, index + 1);
            root.fetchTeamsFromLeague(token, leagues, index + 1);
        });
    }

    function setPendingTeam(teamName, pending) {
        const key = root.teamKey(teamName);
        if (key.length === 0)
            return;

        let next = Object.assign({}, root.pendingBadgeTeams);
        next[key] = Boolean(pending);
        root.pendingBadgeTeams = next;
    }

    function setTeamBadge(teamName, badge) {
        const key = root.teamKey(teamName);
        badge = String(badge || "").trim();
        if (key.length === 0)
            return;

        let next = Object.assign({}, root.badgeByTeam);
        next[key] = badge;
        root.badgeByTeam = next;
        let attempted = Object.assign({}, root.attemptedBadgeTeams);
        attempted[key] = true;
        root.attemptedBadgeTeams = attempted;
    }

    function fetchBadgeFromCountryLeagues(teamName, onDone) {
        onDone = onDone || function () {};
        if (!root.configRoot) {
            onDone();
            return;
        }

        const leagues = root.prioritizedLeagues();
        if (!Array.isArray(leagues) || leagues.length === 0) {
            root.setTeamBadge(teamName, "");
            onDone();
            return;
        }

        const maxLookups = Math.min(6, leagues.length);
        let leagueIndex = 0;

        function lookupNextLeague() {
            if (leagueIndex >= maxLookups) {
                root.setTeamBadge(teamName, "");
                onDone();
                return;
            }

            const leagueValue = String(leagues[leagueIndex] && leagues[leagueIndex].value || "").trim();
            leagueIndex += 1;
            if (leagueValue.length === 0) {
                lookupNextLeague();
                return;
            }

            SportsApi.fetchLeagueTable({
                "sports": root.configRoot.normalizedSport(),
                "country": root.configRoot.cfg_country || "",
                "league": leagueValue,
                "favoriteTeam": teamName,
                "followMode": "league"
            }, rows => {
                const tableRows = Array.isArray(rows) ? rows : [];
                for (let rowIndex = 0; rowIndex < tableRows.length; rowIndex += 1) {
                    const row = tableRows[rowIndex] || {};
                    if (SportsApi.sameTeamName(row.team, teamName)) {
                        const crest = String(row.crest || row.team_logo || "").trim();
                        if (crest.length > 0) {
                            root.setTeamBadge(teamName, crest);
                            onDone();
                            return;
                        }
                    }
                }

                lookupNextLeague();
            }, () => {
                lookupNextLeague();
            });
        }

        lookupNextLeague();
    }

    function ensureTeamBadge(teamName, forceRefresh, teamSlug) {
        forceRefresh = Boolean(forceRefresh);
        teamSlug = String(teamSlug || "").trim();
        const key = root.teamKey(teamName);
        if (key.length === 0)
            return;

        const existingBadge = String(root.badgeByTeam[key] || "").trim();
        if (!forceRefresh && existingBadge.length > 0)
            return;

        if (!forceRefresh && Boolean(root.attemptedBadgeTeams[key]))
            return;

        if (Boolean(root.pendingBadgeTeams[key]))
            return;

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
            if (badge.length > 0) {
                root.setTeamBadge(teamName, badge);
                return;
            }

            if (existingBadge.length > 0) {
                root.setPendingTeam(teamName, false);
                return;
            }

            root.fetchBadgeFromCountryLeagues(teamName, () => root.setPendingTeam(teamName, false));
        }, () => {
            if (existingBadge.length > 0) {
                root.setPendingTeam(teamName, false);
                return;
            }

            root.fetchBadgeFromCountryLeagues(teamName, () => root.setPendingTeam(teamName, false));
        });
    }

    function teamBadge(teamName) {
        const key = root.teamKey(teamName);
        if (key.length === 0)
            return "";

        const badge = String(root.badgeByTeam[key] || "").trim();
        return badge;
    }

    function prefetchVisibleBadges() {
        if (!root.configRoot || root.configRoot.cfg_type !== "team")
            return;

        // During discovery we rely on league-table crests to avoid transient wrong badge assignments.
        if (root.teamDiscoveryRunning)
            return;

        const verifyExistingBadges = root.discoveredTeamCount() > 0;
        root.displayedOptions.slice(0, root.badgePrefetchLimit).forEach(option => {
            const teamName = String(option && option.value || "").trim();
            const teamSlug = String(option && (option.teamSlug || option.team_slug) || "").trim();
            if (teamName.length > 0)
                root.ensureTeamBadge(teamName, verifyExistingBadges, teamSlug);
        });
    }

    Repeater {
        model: root.teamDiscoveryRunning ? [] : root.displayedOptions

        delegate: SportChoiceCard {
            title: modelData.label
            iconSource: root.teamBadge(modelData.value)
            iconName: modelData.value.length > 0 ? "im-user" : "edit-none"
            selected: root.configRoot && root.configRoot.isFavoriteTeamSelected(modelData.value)
            onClicked: root.configRoot.selectFavoriteTeam(modelData.value, modelData)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.columnSpan: root.contentColumns
        Layout.alignment: Qt.AlignHCenter
        visible: root.isTeamMode() && root.teamDiscoveryRunning
        spacing: Kirigami.Units.smallSpacing

        BusyIndicator {
            running: parent.visible
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
        }

        Label {
            Layout.alignment: Qt.AlignVCenter
            text: root.teamDiscoveryStatusText()
            color: Kirigami.Theme.disabledTextColor
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.columnSpan: root.contentColumns
        visible: root.displayedOptions.length === 0 && !root.teamDiscoveryRunning
        text: root.configRoot && root.configRoot.cfg_type === "team"
            ? (root.playerMode
                ? i18nc("@info", "No tennis players were found by the provider.")
                : i18nc("@info", "No teams were found for this country yet. Try another country or competition."))
            : ""
        color: Kirigami.Theme.disabledTextColor
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    headerContent: ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        SportChoiceCard {
            Layout.fillWidth: true
            visible: root.configRoot && root.configRoot.cfg_type === "team" && root.configRoot.normalizedSport() === "football"
            title: i18nc("@title:group", "National Teams")
            subtitle: root.configRoot && root.configRoot.selectedNationalTeamValues().length > 0
                ? i18nc("@info", "%1 selected", root.configRoot.selectedNationalTeamValues().length)
                : i18nc("@info", "Optional: add national team variants for this country")
            iconName: "flag"
            selected: root.configRoot && root.configRoot.showNationalTeamStep
            onClicked: {
                if (root.configRoot)
                    root.configRoot.openNationalTeamsStep();
            }
        }

        Frame {
            Layout.fillWidth: true
            visible: root.configRoot && root.configRoot.cfg_type === "competition" && root.configRoot.cfg_favoriteTeam.length > 0

            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.largeSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        Layout.fillWidth: true
                        text: i18nc("@label", "Follow mode")
                        font.bold: true
                    }

                    Label {
                        Layout.fillWidth: true
                        text: followTeamSwitch.checked ? i18nc("@info", "Show this team across competitions; tables can be switched when more competitions are available.") : i18nc("@info", "Show the selected league; the favorite team is highlighted and sorted first.")
                        color: Kirigami.Theme.disabledTextColor
                        wrapMode: Text.WordWrap
                    }
                }

                Switch {
                    id: followTeamSwitch

                    text: checked ? i18nc("@option:check", "Team") : i18nc("@option:check", "League")
                    enabled: root.configRoot && root.configRoot.cfg_favoriteTeam.length > 0
                    checked: root.configRoot && root.configRoot.cfg_followMode === "team"
                    onToggled: {
                        if (root.configRoot)
                            root.configRoot.setFollowMode(checked ? "team" : "league");
                    }
                }
            }
        }
    }
}
