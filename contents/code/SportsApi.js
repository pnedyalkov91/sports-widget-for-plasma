/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library
.import "providers/ProviderCatalog.js" as ProviderCatalog
.import "providers/SportScoreSports.js" as SportScoreSports

const SPORTSCORE_BASE_URL = "https://sportscore.com";
const SPORTSCORE_MATCH_LIMIT = 50;
const SPORTSCORE_COUNTRY_COMPETITION_LIMIT = 64;
const SPORTSCORE_COUNTRY_COMPETITION_CONCURRENCY = 6;
const SPORTSCORE_TEAM_LIMIT = 2000;
const REQUEST_TIMEOUT_MS = 14000;

function fetchLiveScores(options, onSuccess, onError) {
    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    let pending = 2;
    let rows = [];
    let errors = [];

    function complete(nextRows, error) {
        rows = rows.concat(arrayValue(nextRows));
        if (stringValue(error).length > 0)
            errors.push(stringValue(error));
        pending -= 1;
        if (pending > 0)
            return;

        rows = sortMatches(dedupeMatchesForSport(rows, options && (options.sports || options.sport)));
        if (rows.length > 0 || errors.length < 2) {
            finish(onSuccess, rows);
        } else {
            finish(onError, errors.join(", "));
        }
    }

    fetchSportScoreGlobalLiveMatches(options, liveRows => complete(liveRows, ""), error => complete([], error));
    if (isTeamRequest(options)) {
        fetchSportScoreTeamMatches(options, "live", liveRows => complete(liveRows, ""), error => complete([], error));
    } else {
        fetchSportScoreCompetitionMatches(options, "live", liveRows => complete(liveRows, ""), error => complete([], error));
    }
}

function fetchScoresFixtures(options, onSuccess, onError) {
    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    if (isTeamRequest(options)) {
        fetchSportScoreTeamMatches(options, "fixtures", onSuccess, onError);
        return;
    }

    fetchSportScoreCompetitionMatches(options, "fixtures", onSuccess, onError);
}

function fetchRecentResults(options, onSuccess, onError) {
    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    if (isTeamRequest(options)) {
        fetchSportScoreTeamMatches(options, "recent", onSuccess, onError);
        return;
    }

    fetchSportScoreCompetitionMatches(options, "recent", onSuccess, onError);
}

function fetchLeagueTable(options, onSuccess, onError) {
    fetchSportScoreLeagueTable(options, onSuccess, onError);
}

function fetchLeagueSeasons(options, onSuccess, onError) {
    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    fetchSportScoreCompetitionPage(options, page => {
        finish(onSuccess, sportScoreSeasonOptionsFromCompetitionPage(page.html));
    }, error => finish(onError, error));
}

function fetchLeagueTableForSeason(options, onSuccess, onError) {
    fetchSportScoreLeagueTable(options, onSuccess, onError);
}

function fetchTeamCompetitions(options, onSuccess, onError) {
    if (!canUseSportScore(options) || !isTeamRequest(options)) {
        finish(onSuccess, []);
        return;
    }

    fetchSportScoreTeamPage(options, page => {
        finish(onSuccess, sportScoreTeamCompetitions(page.html, options));
    }, error => finish(onError, error));
}

function fetchCountryCompetitions(options, onSuccess, onError) {
    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    const country = ProviderCatalog.slugForValue(options && options.country);
    if (country.length === 0) {
        finish(onSuccess, []);
        return;
    }

    const sport = normalizedSport(options && options.sports);
    const sourcePath = SportScoreSports.competitionSourcePath(sport, country);
    const url = sourcePath.length > 0 ? SPORTSCORE_BASE_URL + sourcePath : "";
    if (url.length === 0) {
        finish(onSuccess, []);
        return;
    }
    requestText(cacheBustedUrl(url), html => {
        finish(onSuccess, sportScoreCompetitionLinks(html, country, sport));
    }, error => finish(onError, error || "Unable to load SportScore competitions"));
}

function fetchSportCountries(options, onSuccess, onError) {
    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    const sport = normalizedSport(options && options.sports);
    const defaults = SportScoreSports.defaultCountryOptions(sport);
    if (defaults.length > 0) {
        finish(onSuccess, defaults);
        return;
    }

    requestText(cacheBustedUrl(SPORTSCORE_BASE_URL + SportScoreSports.rootPath(sport)), html => {
        finish(onSuccess, sportScoreCountryOptions(html, sport));
    }, error => finish(onError, error || "Unable to load SportScore countries"));
}

function fetchCountryTeams(options, onSuccess, onError) {
    const provider = stringValue(options && options.provider) || "sportscore";
    const sport = normalizedSport(options && options.sports);
    const country = ProviderCatalog.slugForValue(options && options.country);
    if (provider !== "sportscore" || !SportScoreSports.supports(sport) || country.length === 0) {
        finish(onSuccess, []);
        return;
    }

    fetchSportScoreCountryTeams(sport, country, onSuccess, onError);
}

function fetchTeamProfile(options, onSuccess, onError) {
    if (!canUseSportScore(options) || !isTeamRequest(options)) {
        finish(onSuccess, {});
        return;
    }

    fetchSportScoreTeamPage(options, page => {
        finish(onSuccess, sportScoreTeamProfile(page.html, options));
    }, error => finish(onError, error));
}

function fetchTeamBadge(options, onSuccess, onError) {
    if (!canUseSportScore(options) || !isTeamRequest(options)) {
        finish(onSuccess, "");
        return;
    }

    fetchSportScoreTeamPage(options, page => {
        finish(onSuccess, sportScoreTeamBadge(page.html));
    }, () => finish(onSuccess, ""));
}

function fetchLiveMatchDetails(options, onSuccess, onError) {
    if (!canUseSportScore(options)) {
        finish(onSuccess, emptyLiveMatchDetails());
        return;
    }

    const urls = sportScoreWidgetMatchUrls(options);
    if (urls.length === 0) {
        finish(onSuccess, emptyLiveMatchDetails());
        return;
    }

    fetchSportScoreWidgetMatchDetailsByUrls(urls, 0, options, onSuccess, onError);
}

function fetchSportScoreWidgetMatchDetailsByUrls(urls, index, options, onSuccess, onError) {
    if (index >= urls.length) {
        finish(onSuccess, emptyLiveMatchDetails());
        return;
    }

    const url = urls[index];
    requestText(cacheBustedUrl(url), text => {
        try {
            const payload = JSON.parse(text);
            if (!payload || !payload.match) {
                fetchSportScoreWidgetMatchDetailsByUrls(urls, index + 1, options, onSuccess, onError);
                return;
            }

            finish(onSuccess, normalizeSportScoreWidgetMatchDetails(payload, options));
        } catch (error) {
            fetchSportScoreWidgetMatchDetailsByUrls(urls, index + 1, options, onSuccess, onError);
        }
    }, () => fetchSportScoreWidgetMatchDetailsByUrls(urls, index + 1, options, onSuccess, onError));
}

function isLiveMatch(match) {
    return isLiveStatus(match && match.status);
}

function isFinishedMatch(match) {
    const status = stringValue(match && match.status).toLowerCase();
    return status === "finished" || status === "ft" || status.indexOf("finished") >= 0;
}

function sameTeamName(left, right) {
    const leftName = normalizedTeamName(left);
    const rightName = normalizedTeamName(right);
    if (leftName.length === 0 || rightName.length === 0)
        return false;

    return leftName === rightName;
}

function emptyLiveMatchDetails() {
    return {
        sourceProvider: "",
        statsProvider: "",
        competition: "",
        competitionLogo: "",
        statusText: "",
        updated: "",
        halfTimeScore: "",
        matchInfoRows: [],
        lineups: {},
        homeStats: {},
        awayStats: {},
        summaryRows: [],
        statsRows: [],
        homeEvents: [],
        awayEvents: [],
        events: []
    };
}

function normalizeSportScoreWidgetMatchDetails(payload, options) {
    const match = payload && payload.match ? payload.match : {};
    const sport = normalizedSport(options && (options.sports || options.sport)) || normalizedSport(payload && payload.sport);
    const swapSides = sportScoreWidgetSidesSwapped(match, options);
    const events = sportScoreWidgetIncidents(match && match.incidents, match, options)
        .map(row => swapSides ? sportScoreWidgetSwapEventSide(row) : row);
    const statusParts = [stringValue(match && match.status_text), stringValue(match && match.live_minute)]
        .filter(value => value.length > 0)
        .map(value => sport === "basketball" ? basketballPeriodLabel(value) : value);
    return {
        sourceProvider: "SportScore",
        statsProvider: "SportScore",
        competition: stringValue(match && match.competition) || stringValue(options && options.league),
        competitionLogo: stringValue(match && match.competition_logo),
        statusText: statusParts.join(" · "),
        updated: stringValue(payload && payload.updated),
        halfTimeScore: sportScoreWidgetHalfTimeScore(match, swapSides),
        matchInfoRows: sportScoreWidgetMatchInfoRows(match, payload, swapSides, options),
        lineups: sportScoreWidgetLineups(match && match.lineups, swapSides),
        homeStats: {},
        awayStats: {},
        summaryRows: sportScoreWidgetSummaryRows(events),
        statsRows: sportScoreWidgetStatsRows(match && match.stats, swapSides),
        homeEvents: events.filter(row => row.side === "home"),
        awayEvents: events.filter(row => row.side === "away"),
        events
    };
}

function sportScoreWidgetSidesSwapped(match, options) {
    const endpointHome = stringValue(match && match.home);
    const endpointAway = stringValue(match && match.away);
    const displayHome = stringValue(options && options.homeTeam);
    const displayAway = stringValue(options && options.awayTeam);
    if (endpointHome.length === 0 || endpointAway.length === 0 || displayHome.length === 0 || displayAway.length === 0)
        return false;

    return sameTeamName(endpointHome, displayAway) && sameTeamName(endpointAway, displayHome);
}

function sportScoreWidgetSwapEventSide(row) {
    const copy = Object.assign({}, row || {});
    if (copy.side === "home")
        copy.side = "away";
    else if (copy.side === "away")
        copy.side = "home";
    copy.sideLabel = copy.side === "home" ? "HOME" : copy.side === "away" ? "AWAY" : "";
    return copy;
}

function sportScoreWidgetHalfTimeScore(match, swapSides) {
    const home = stringValue(match && (swapSides ? match.away_ht_score : match.home_ht_score));
    const away = stringValue(match && (swapSides ? match.home_ht_score : match.away_ht_score));
    if (home.length === 0 && away.length === 0)
        return "";

    return (home.length > 0 ? home : "0") + " - " + (away.length > 0 ? away : "0");
}

function sportScoreWidgetMatchInfoRows(match, payload, swapSides, options) {
    let rows = [];
    function append(label, value) {
        value = stringValue(value);
        if (value.length > 0)
            rows.push({ label, value });
    }

    append("Kick-off", stringValue(options && options.startTime) || formatStartTime(match && match.time, options));
    append("Half-time", sportScoreWidgetHalfTimeScore(match, swapSides));
    return rows;
}

function sportScoreWidgetLineups(lineups, swapSides) {
    lineups = lineups || {};
    const homePrefix = swapSides ? "away" : "home";
    const awayPrefix = swapSides ? "home" : "away";
    return {
        confirmed: lineups.confirmed === true,
        homeFormation: stringValue(lineups[homePrefix + "_formation"]),
        awayFormation: stringValue(lineups[awayPrefix + "_formation"]),
        homeCoach: sportScorePersonName(lineups[homePrefix + "_coach"]),
        awayCoach: sportScorePersonName(lineups[awayPrefix + "_coach"]),
        homeStarting: sportScoreWidgetPlayers(lineups[homePrefix + "_xi"]),
        awayStarting: sportScoreWidgetPlayers(lineups[awayPrefix + "_xi"]),
        homeSubstitutes: sportScoreWidgetPlayers(lineups[homePrefix + "_subs"]),
        awaySubstitutes: sportScoreWidgetPlayers(lineups[awayPrefix + "_subs"])
    };
}

function sportScoreWidgetPlayers(players) {
    return arrayValue(players).map(player => ({
        name: sportScorePersonName(player),
        number: stringValue(player && player.number),
        position: sportScorePositionName(player && player.position),
        captain: player && player.captain === true,
        rating: stringValue(player && player.rating)
    })).filter(player => player.name.length > 0);
}

function sportScorePositionName(position) {
    const value = stringValue(position).trim();
    const upper = value.toUpperCase();
    switch (upper) {
    case "G":
    case "GK":
        return "Goalkeeper";
    case "D":
    case "DF":
        return "Defender";
    case "M":
    case "MF":
        return "Midfielder";
    case "F":
    case "FW":
    case "A":
        return "Forward";
    default:
        return value;
    }
}

function sportScoreWidgetStatsRows(stats, swapSides) {
    return arrayValue(stats).map(row => {
        const label = sportScoreStatLabel(row && row.label);
        const suffix = stringValue(row && row.suffix);
        const homeValue = row && (swapSides ? row.away : row.home);
        const awayValue = row && (swapSides ? row.home : row.away);
        const homePctValue = row && (swapSides ? row.away_pct : row.home_pct);
        const awayPctValue = row && (swapSides ? row.home_pct : row.away_pct);
        const home = numberValue(homeValue);
        const away = numberValue(awayValue);
        const homePct = numberValue(homePctValue);
        const awayPct = numberValue(awayPctValue);
        const total = home + away;
        return {
            kind: sportScoreStatKind(label),
            label,
            homeValue: stringValue(homeValue) + suffix,
            awayValue: stringValue(awayValue) + suffix,
            homeRaw: home,
            awayRaw: away,
            homeRatio: homePct > 0 || awayPct > 0 ? homePct / 100 : total > 0 ? home / total : 0,
            awayRatio: homePct > 0 || awayPct > 0 ? awayPct / 100 : total > 0 ? away / total : 0
        };
    });
}

function sportScoreStatLabel(label) {
    const value = stringValue(label);
    if (value.toLowerCase() === "ball possession")
        return "Possession";
    return value;
}

function sportScoreStatKind(label) {
    const lower = stringValue(label).toLowerCase();
    if (lower.indexOf("possession") >= 0)
        return "possession";
    if (lower.indexOf("attack") >= 0 && lower.indexOf("danger") < 0)
        return "attacks";
    if (lower.indexOf("corner") >= 0)
        return "corners";
    return lower.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

function sportScoreWidgetIncidents(incidents, match, options) {
    const home = stringValue(match && match.home) || stringValue(options && options.homeTeam);
    const away = stringValue(match && match.away) || stringValue(options && options.awayTeam);
    return arrayValue(incidents).map(row => {
        const side = sportScoreIncidentSide(row, home, away);
        const kind = sportScoreIncidentKind(row);
        const player = sportScoreIncidentPlayer(row);
        const label = sportScoreIncidentLabel(row, player, kind);
        return {
            side,
            kind,
            minute: sportScoreIncidentMinute(row),
            label,
            player,
            sideLabel: side === "home" ? "HOME" : side === "away" ? "AWAY" : ""
        };
    }).filter(row => row.label.length > 0 || row.player.length > 0 || row.kind.length > 0);
}

function sportScoreIncidentSide(row, homeTeam, awayTeam) {
    const side = stringValue(row && (row.side || row.team_side || row.home_away)).toLowerCase();
    if (side === "home" || side === "away")
        return side;
    if (row && (row.is_home === true || row.home === true))
        return "home";
    if (row && (row.is_away === true || row.away === true))
        return "away";
    const team = stringValue(row && (row.team || row.team_name || row.teamName));
    if (sameTeamName(team, homeTeam))
        return "home";
    if (sameTeamName(team, awayTeam))
        return "away";
    return "";
}

function sportScoreIncidentKind(row) {
    const value = stringValue(row && (row.kind || row.type || row.incident_type || row.name || row.event));
    const lower = value.toLowerCase();
    if (lower.indexOf("substitution") >= 0 || lower.indexOf("substitute") >= 0)
        return "substitution";
    if (lower.indexOf("yellow") >= 0)
        return "yellow";
    if (lower.indexOf("red") >= 0)
        return "red";
    if (lower.indexOf("corner") >= 0)
        return "corners";
    if (lower.indexOf("pen") >= 0)
        return "penalty";
    if (lower.indexOf("goal") >= 0)
        return "goal";
    return value;
}

function sportScoreIncidentMinute(row) {
    const value = stringValue(row && (row.minute || row.time || row.match_time || row.incident_time));
    return value.replace(/'$/, "");
}

function sportScoreIncidentPlayer(row) {
    const substitution = sportScoreSubstitutionLabel(row);
    if (substitution.length > 0)
        return substitution;

    const player = row && (row.player || row.player_name || row.playerName || row.name);
    if (!player)
        return "";
    if (typeof player === "object")
        return titleCasePersonName(player.name || player.short_name || player.display_name);
    return titleCasePersonName(player);
}

function sportScoreIncidentLabel(row, player, kind) {
    const value = stringValue(row && (row.label || row.text || row.description || row.detail || row.type));
    if (kind === "substitution" && player.length > 0)
        return player;
    if (value.length > 0 && value.toLowerCase() !== stringValue(player).toLowerCase())
        return titleCaseEventLabel(value, kind);
    return stringValue(kind);
}

function sportScoreSubstitutionLabel(row) {
    const outPlayer = sportScorePersonName(row && (row.player_out || row.out_player || row.playerOut || row.outPlayer || row.player_off || row.playerOff));
    const inPlayer = sportScorePersonName(row && (row.player_in || row.in_player || row.playerIn || row.inPlayer || row.player_on || row.playerOn));
    if (outPlayer.length > 0 && inPlayer.length > 0)
        return outPlayer + " -> " + inPlayer;
    return outPlayer || inPlayer;
}

function sportScorePersonName(value) {
    if (!value)
        return "";
    if (typeof value === "object")
        return titleCasePersonName(value.name || value.short_name || value.display_name || value.player_name);
    return titleCasePersonName(value);
}

function titleCasePersonName(value) {
    return stringValue(value).trim().split(/\s+/).map(part => {
        return part.split(/([-'’])/).map(piece => {
            if (piece === "-" || piece === "'" || piece === "’")
                return piece;

            if (piece.length === 0)
                return piece;

            if (/^[A-Za-z]\.$/.test(piece))
                return piece.toUpperCase();

            return piece.charAt(0).toUpperCase() + piece.slice(1).toLowerCase();
        }).join("");
    }).join(" ");
}

function titleCaseEventLabel(value, kind) {
    const text = stringValue(value).trim();
    if (text.length === 0)
        return "";

    const lower = text.toLowerCase();
    if (kind === "goal" && lower.indexOf("goal") >= 0) {
        const suffix = /\s*\((?:goal|penalty goal)\)\s*$/i.exec(text);
        if (suffix)
            return titleCasePersonName(text.slice(0, suffix.index)) + suffix[0];
        return titleCasePersonName(text);
    }

    return text.split(/\s*(->|→)\s*/).map(part => {
        if (part === "->" || part === "→")
            return "->";
        return titleCasePersonName(part);
    }).join(" ");
}

function sportScoreWidgetSummaryRows(events) {
    function count(kind, side) {
        return arrayValue(events).filter(row => row.side === side && stringValue(row.kind).toLowerCase().indexOf(kind) >= 0).length;
    }
    return [
        { kind: "corners", homeValue: String(count("corner", "home")), awayValue: String(count("corner", "away")) },
        { kind: "red", homeValue: String(count("red", "home")), awayValue: String(count("red", "away")) },
        { kind: "yellow", homeValue: String(count("yellow", "home")), awayValue: String(count("yellow", "away")) }
    ];
}

function canUseSportScore(options) {
    const provider = stringValue(options && options.provider) || "sportscore";
    return provider === "sportscore" && SportScoreSports.supports(options && (options.sports || options.sport));
}

function isTeamRequest(options) {
    return stringValue(options && options.followMode) === "team"
        || stringValue(options && options.favoriteTeam).length > 0
        || stringValue(options && options.teamPath).length > 0;
}

function fetchSportScoreTeamPage(options, onSuccess, onError) {
    resolveSportScoreTeamPath(options, path => {
        if (path.length === 0) {
            finish(onError, "No SportScore team page found");
            return;
        }

        const url = absoluteSportScoreUrl(path);
        requestText(cacheBustedUrl(url), html => {
            finish(onSuccess, {
                html,
                url,
                path: sportScorePathFromUrl(url)
            });
        }, onError);
    }, onError);
}

function resolveSportScoreTeamPath(options, onSuccess, onError) {
    const sport = normalizedSport(options && (options.sports || options.sport));
    const direct = sportScorePathFromUrl(options && (options.teamPath || options.teamUrl));
    if (isCanonicalSportScoreTeamPath(direct, sport)) {
        finish(onSuccess, direct);
        return;
    }

    const team = stringValue(options && options.favoriteTeam);
    const teamSlug = ProviderCatalog.slugForValue(options && options.teamSlug);
    const country = ProviderCatalog.slugForValue(options && options.country);
    if (country.length === 0) {
        finish(onSuccess, "");
        return;
    }

    fetchSportScoreCountryTeams(sport, country, rows => {
        const match = (Array.isArray(rows) ? rows : []).find(row => {
            const rowSlug = ProviderCatalog.slugForValue(row && row.teamSlug);
            return (teamSlug.length > 0 && rowSlug === teamSlug) || sameTeamName(row && (row.value || row.label), team);
        });
        finish(onSuccess, sportScorePathFromUrl(match && match.teamPath));
    }, onError);
}

function isCanonicalSportScoreTeamPath(path, sport) {
    return SportScoreSports.isParticipantPath(sportScorePathFromUrl(path), sport);
}

function fetchSportScoreTeamMatches(options, mode, onSuccess, onError) {
    if (mode === "fixtures") {
        fetchSportScoreTeamWidgetMatches(options, rows => {
            if (rows.length > 0) {
                finish(onSuccess, sortUpcomingMatches(dedupeMatches(filterSportScoreMatchesForMode(rows, "fixtures"))));
                return;
            }

            fetchSportScoreTeamMatchesFromPages(options, mode, onSuccess, onError);
        }, () => fetchSportScoreTeamMatchesFromPages(options, mode, onSuccess, onError));
        return;
    }

    fetchSportScoreTeamMatchesFromPages(options, mode, onSuccess, onError);
}

function fetchSportScoreTeamMatchesFromPages(options, mode, onSuccess, onError) {
    fetchSportScoreTeamPage(options, page => {
        const teamName = stringValue(options && options.favoriteTeam) || stringValue(sportScoreTeamProfile(page.html, options).label);
        const teamRows = filterSportScoreMatchesForMode(
            normalizeSportScoreMatchPage(page.html, "", options).filter(match => matchBelongsToTeam(match, teamName)),
            mode
        );

        if (mode === "recent") {
            finish(onSuccess, sortRecentMatches(dedupeMatches(teamRows)).slice(0, numberValue(options && options.recentResultsPerTeam) || 80));
            return;
        }

        const competitions = sportScoreTeamCompetitions(page.html, options)
            .filter(row => stringValue(row && row.path).length > 0)
            .slice(0, 10);
        if (competitions.length === 0) {
            finish(onSuccess, sortMatches(dedupeMatches(teamRows)));
            return;
        }

        fetchSportScoreCompetitionPagesByRows(competitions, pages => {
            let rows = teamRows.slice();
            pages.forEach(competitionPage => {
                const label = stringValue(competitionPage && competitionPage.label);
                rows = rows.concat(normalizeSportScoreMatchPage(competitionPage.html, label, options)
                    .filter(match => matchBelongsToTeam(match, teamName)));
            });
            finish(onSuccess, (mode === "live" ? sortMatches : sortUpcomingMatches)(dedupeMatches(filterSportScoreMatchesForMode(rows, mode))));
        });
    }, onError);
}

function fetchSportScoreTeamWidgetMatches(options, onSuccess, onError) {
    const url = sportScoreTeamWidgetUrl(options);
    if (url.length === 0) {
        finish(onSuccess, []);
        return;
    }

    requestText(cacheBustedUrl(url), text => {
        try {
            const payload = JSON.parse(text);
            finish(onSuccess, normalizeSportScoreTeamWidgetMatches(payload, options));
        } catch (error) {
            finish(onError, String(error));
        }
    }, onError);
}

function sportScoreTeamWidgetUrl(options) {
    const sport = normalizedSport(options && (options.sports || options.sport));
    let slug = ProviderCatalog.slugForValue(options && options.teamSlug);
    if (slug.length === 0)
        slug = sportScoreTeamSlugFromPath(options && (options.teamPath || options.teamUrl), sport);
    if (slug.length === 0)
        slug = ProviderCatalog.slugForValue(options && options.favoriteTeam);
    if (slug.length === 0)
        return "";

    const limit = numberValue(options && (options.fixtureLimit || options.limit)) || 50;
    return SPORTSCORE_BASE_URL + "/api/widget/team/?sport=" + encodeURIComponent(sport) + "&slug=" + encodeURIComponent(slug) + "&limit=" + encodeURIComponent(String(limit));
}

function normalizeSportScoreTeamWidgetMatches(payload, options) {
    return arrayValue(payload && payload.matches)
        .map(match => normalizeSportScoreTeamWidgetMatch(match, options))
        .filter(hasTeams);
}

function normalizeSportScoreTeamWidgetMatch(match, options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    const timestamp = Date.parse(stringValue(match && match.time));
    const path = sportScorePathFromUrl(match && match.url);
    const statusText = stringValue(match && match.status_text);
    const status = sportScoreMatchStatus(statusText || stringValue(match && match.status), match && match.home_score, match && match.away_score, match && match.status);
    const minute = sportScoreLiveMinute(match, status, sport);
    return {
        id: "sportscore-" + stringValue(path || match && match.url),
        sport,
        league: stringValue(match && match.competition),
        homeTeam: stringValue(match && match.home),
        awayTeam: stringValue(match && match.away),
        homeScore: status === "Upcoming" ? "" : stringValue(match && match.home_score),
        awayScore: status === "Upcoming" ? "" : stringValue(match && match.away_score),
        status,
        statusText,
        minute,
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp, options) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: "",
        group: "",
        stadium: "",
        homeBadge: absoluteSportScoreUrl(match && match.home_logo),
        awayBadge: absoluteSportScoreUrl(match && match.away_logo),
        poster: "",
        popular: false,
        matchPath: path,
        liveUrl: sportScoreWidgetMatchUrlFromPath(path, sport),
        detailsProvider: "sportscore",
        statsProvider: "sportscore",
        sourceProvider: "SportScore"
    };
}

function fetchSportScoreCompetitionMatches(options, mode, onSuccess, onError) {
    fetchSportScoreCompetitionPage(options, page => {
        const rows = filterSportScoreMatchesForMode(normalizeSportScoreMatchPage(page.html, sportScoreLeagueLabel(options), options), mode);
        finish(onSuccess, mode === "recent" ? sortRecentMatches(dedupeMatches(rows)) : sortMatches(dedupeMatches(rows)));
    }, onError);
}

function fetchSportScoreGlobalLiveMatches(options, onSuccess, onError) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    if (sport === "basketball") {
        fetchSportScoreBasketballGlobalLiveMatches(options, onSuccess, onError);
        return;
    }

    requestText(cacheBustedUrl(SPORTSCORE_BASE_URL + SportScoreSports.rootPath(sport)), html => {
        const rows = filterSportScoreMatchesForMode(normalizeSportScoreMatchPage(html, "", options), "live");
        finish(onSuccess, sortMatches(dedupeMatches(rows)));
    }, onError);
}

function fetchSportScoreBasketballGlobalLiveMatches(options, onSuccess, onError) {
    const url = SPORTSCORE_BASE_URL + "/api/widget/matches/?sport=basketball&limit=" + SPORTSCORE_MATCH_LIMIT;
    let pending = 2;
    let rows = [];
    let errors = [];

    function complete(nextRows, error) {
        rows = rows.concat(arrayValue(nextRows));
        if (stringValue(error).length > 0)
            errors.push(stringValue(error));
        pending -= 1;
        if (pending > 0)
            return;

        rows = sortMatches(dedupeMatchesForSport(filterSportScoreMatchesForMode(rows, "live"), "basketball"));
        if (rows.length > 0 || errors.length < 2) {
            finish(onSuccess, rows);
        } else {
            finish(onError, errors.join(", "));
        }
    }

    requestText(cacheBustedUrl(url), text => {
        try {
            const payload = JSON.parse(text);
            complete(normalizeSportScoreTeamWidgetMatches(payload, options), "");
        } catch (error) {
            complete([], String(error));
        }
    }, error => complete([], error));

    requestText(cacheBustedUrl(SPORTSCORE_BASE_URL + SportScoreSports.rootPath("basketball")), html => {
        complete(normalizeSportScoreMatchPage(html, "", options), "");
    }, error => complete([], error));
}

function fetchSportScoreCompetitionPagesByRows(competitions, onDone) {
    let pages = [];
    let pending = competitions.length;
    if (pending === 0) {
        finish(onDone, pages);
        return;
    }

    competitions.forEach(row => {
        requestText(cacheBustedUrl(absoluteSportScoreUrl(row.path)), html => {
            pages.push(Object.assign({}, row, { html }));
            pending -= 1;
            if (pending === 0)
                finish(onDone, pages);
        }, () => {
            pending -= 1;
            if (pending === 0)
                finish(onDone, pages);
        });
    });
}

function fetchSportScoreLeagueTable(options, onSuccess, onError) {
    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    function fetchFromCompetitionPage() {
        fetchSportScoreCompetitionPage(options, page => {
            finish(onSuccess, normalizeSportScoreCompetitionTablePage(page.html, sportScoreLeagueLabel(options), options));
        }, error => finish(onError, error));
    }

    function fetchCompetitionPageForComparison(apiRows) {
        fetchSportScoreCompetitionPage(options, page => {
            const htmlRows = normalizeSportScoreCompetitionTablePage(page.html, sportScoreLeagueLabel(options), options);
            finish(onSuccess, shouldPreferSportScoreHtmlStandings(apiRows, htmlRows) ? htmlRows : mergeSportScoreHtmlFormsIntoStandings(apiRows, htmlRows));
        }, () => finish(onSuccess, apiRows));
    }

    if (!canUseSportScoreWidgetStandings(options)) {
        fetchFromCompetitionPage();
        return;
    }

    fetchSportScoreWidgetStandings(options, rows => {
        if (rows.length > 0) {
            fetchCompetitionPageForComparison(rows);
            return;
        }

        fetchFromCompetitionPage();
    }, fetchFromCompetitionPage);
}

function shouldPreferSportScoreHtmlStandings(apiRows, htmlRows) {
    apiRows = arrayValue(apiRows);
    htmlRows = arrayValue(htmlRows);
    if (htmlRows.length === 0)
        return false;
    if (apiRows.length === 0)
        return true;

    return maxSportScoreTablePoints(htmlRows) > maxSportScoreTablePoints(apiRows);
}

function maxSportScoreTablePoints(rows) {
    return arrayValue(rows).reduce((maxPoints, row) => Math.max(maxPoints, numberValue(row && row.points)), 0);
}

function mergeSportScoreHtmlFormsIntoStandings(apiRows, htmlRows) {
    const htmlByTeam = {};
    arrayValue(htmlRows).forEach(row => {
        const key = normalizedTeamName(row && row.team);
        if (key.length > 0)
            htmlByTeam[key] = row;
    });

    return arrayValue(apiRows).map(row => {
        const copy = Object.assign({}, row || {});
        const htmlRow = htmlByTeam[normalizedTeamName(copy.team)] || {};
        const form = sportScoreFormValues(htmlRow.form);
        const canonicalTeamPath = sportScorePathFromUrl(htmlRow.teamPath);
        if (form.length > 0)
            copy.form = form.join(",");
        if (isCanonicalSportScoreTeamPath(canonicalTeamPath))
            copy.teamPath = canonicalTeamPath;
        if (stringValue(htmlRow.teamSlug).length > 0)
            copy.teamSlug = htmlRow.teamSlug;
        if (stringValue(htmlRow.crest).length > 0)
            copy.crest = htmlRow.crest;
        return copy;
    });
}

function canUseSportScoreWidgetStandings(options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    if (sport !== "football")
        return false;

    const slug = ProviderCatalog.slugForValue(options && options.league);
    if (slug.length === 0)
        return false;

    const hasSeasonSelection = sportScoreSeasonMatchKey(options && (options.seasonKey || options.seasonLabel)).length > 0
        || stringValue(options && options.seasonId).length > 0;
    if (!hasSeasonSelection)
        return true;

    return Boolean(options && options.seasonIsDefault);
}

function fetchSportScoreWidgetStandings(options, onSuccess, onError) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    const slug = ProviderCatalog.slugForValue(options && options.league);
    if (slug.length === 0) {
        finish(onSuccess, []);
        return;
    }

    const url = SPORTSCORE_BASE_URL + "/api/widget/standings/?sport=" + encodeURIComponent(sport) + "&slug=" + encodeURIComponent(slug);
    requestText(cacheBustedUrl(url), text => {
        try {
            const payload = JSON.parse(text);
            finish(onSuccess, normalizeSportScoreWidgetStandings(payload, options));
        } catch (error) {
            finish(onError, String(error));
        }
    }, onError);
}

function normalizeSportScoreWidgetStandings(payload, options) {
    const tables = arrayValue(payload && payload.tables);
    const league = stringValue(payload && payload.competition) || sportScoreLeagueLabel(options);
    let rows = [];
    tables.forEach((table, tableIndex) => {
        const group = stringValue(table && table.group) || (tables.length > 1 ? "Group " + (tableIndex + 1) : "");
        arrayValue(table && table.rows).forEach(row => {
            rows.push({
                position: numberValue(row && row.pos),
                team: stringValue(row && row.team),
                group,
                groupIndex: tableIndex,
                played: numberValue(row && row.p),
                won: numberValue(row && row.w),
                draw: numberValue(row && row.d),
                lost: numberValue(row && row.l),
                goalsFor: numberValue(row && row.gf),
                goalsAgainst: numberValue(row && row.ga),
                goalDifference: numberValue(row && row.gd),
                points: numberValue(row && row.pts),
                form: "",
                crest: absoluteSportScoreUrl(row && row.team_logo),
                teamPath: sportScorePathFromUrl(row && row.team_url),
                teamSlug: ProviderCatalog.slugForValue(row && row.team_slug),
                league
            });
        });
    });

    return rows.filter(row => stringValue(row.team).length > 0)
        .sort((left, right) => numberValue(left.groupIndex) - numberValue(right.groupIndex)
            || numberValue(left.position) - numberValue(right.position)
            || stringValue(left.team).localeCompare(stringValue(right.team)));
}

function fetchSportScoreCompetitionPage(options, onSuccess, onError) {
    resolveSportScoreCompetitionPath(options, path => {
        if (path.length === 0) {
            finish(onSuccess, { html: "", path: "", url: "" });
            return;
        }

        const requestedSeasonPath = sportScoreRequestedSeasonPath(path, options);
        requestText(cacheBustedUrl(absoluteSportScoreUrl(requestedSeasonPath || path)), html => {
            finish(onSuccess, {
                html,
                path: requestedSeasonPath || path,
                url: absoluteSportScoreUrl(requestedSeasonPath || path)
            });
        }, onError);
    }, onError);
}

function resolveSportScoreCompetitionPath(options, onSuccess, onError) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    const direct = sportScorePathFromUrl(options && (options.competitionPath || options.leaguePath));
    if (SportScoreSports.isCompetitionPath(direct, sport)) {
        finish(onSuccess, direct);
        return;
    }

    const league = ProviderCatalog.slugForValue(options && options.league);
    if (league.length === 0) {
        finish(onSuccess, "");
        return;
    }

    const sources = sportScoreCompetitionSourceUrls(options);
    let index = 0;
    function next() {
        if (index >= sources.length) {
            finish(onSuccess, "");
            return;
        }

        const source = sources[index];
        index += 1;
        requestText(cacheBustedUrl(source.url), html => {
            const path = sportScoreCompetitionPath(html, source.country, league, sport);
            if (path.length > 0) {
                finish(onSuccess, path);
                return;
            }
            next();
        }, next);
    }
    next();
}

function sportScoreCompetitionSourceUrls(options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    const primary = ProviderCatalog.slugForValue(options && options.country);
    const candidates = [];
    const seen = {};
    function add(code) {
        code = ProviderCatalog.slugForValue(code);
        if (code.length === 0 || seen[code])
            return;
        seen[code] = true;
        candidates.push(code);
    }

    add(primary);
    add("world");
    return candidates.map(code => ({
        country: code,
        url: SPORTSCORE_BASE_URL + SportScoreSports.competitionSourcePath(sport, code)
    }));
}

function sportScoreCompetitionPath(html, country, league, sport) {
    const page = stringValue(html);
    const sportValue = normalizedSport(sport) || "football";
    const wantedCountry = ProviderCatalog.slugForValue(country);
    const wantedLeague = ProviderCatalog.slugForValue(league);
    if (wantedLeague.length === 0)
        return "";

    const pattern = new RegExp("href=[\"'](\\/" + escapeRegExp(sportValue) + "\\/competition\\/([^\\/\"']+)\\/([^\\/\"']+)\\/[^\"']+\\/)[\"']", "g");
    let fallback = "";
    let match;
    while ((match = pattern.exec(page)) !== null) {
        const path = htmlDecode(match[1]);
        const rowCountry = ProviderCatalog.slugForValue(match[2]);
        const rowLeague = ProviderCatalog.slugForValue(match[3]);
        if (rowLeague !== wantedLeague)
            continue;
        if (wantedCountry.length === 0 || rowCountry === wantedCountry)
            return path;
        if (fallback.length === 0)
            fallback = path;
    }

    return fallback;
}

function sportScoreRequestedSeasonPath(competitionPath, options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    const seasonId = sportScorePathFromUrl(options && options.seasonId);
    if (SportScoreSports.isCompetitionPath(seasonId, sport))
        return seasonId;

    const key = sportScoreSeasonMatchKey(options && (options.seasonKey || options.seasonLabel));
    if (key.length === 0)
        return "";

    return sportScorePathWithoutSeason(competitionPath) + key + "/";
}

function sportScorePathWithoutSeason(path) {
    return sportScorePathFromUrl(path).replace(/\/\d{4}(?:-\d{4})?\/?$/, "/");
}

function sportScoreLeagueLabel(options) {
    return stringValue(options && options.leagueLabel) || ProviderCatalog.leagueLabel(options && options.league);
}

function normalizeSportScoreMatchPage(html, leagueLabel, options) {
    const page = stringValue(html);
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    let rows = [];

    function appendPattern(pattern) {
        let match;
        while ((match = pattern.exec(page)) !== null) {
            const context = page.slice(Math.max(0, match.index - 800), match.index);
            const row = normalizeSportScoreMatchRow(match[0], context, leagueLabel, options);
            if (hasTeams(row))
                rows.push(row);
        }
    }

    if (sport === "cricket") {
        rows = rows.concat(sportScoreCricketMatchRows(page, leagueLabel, options));
    } else if (sport === "tennis") {
        rows = rows.concat(sportScoreTennisMatchRows(page, leagueLabel, options));
    } else {
        appendPattern(/<div class="football-match-table-container w-100 nostyle sc-row-stretched">([\s\S]*?)(?=<div class="d-flex d-md-none|<div class="football-match-table-container w-100 nostyle sc-row-stretched">|<\/section>|$)/g);
        appendPattern(/<a\b[^>]*class="[^"]*\bfootball-match-table-container\b[^"]*\bnostyle\b[^"]*"[^>]*>[\s\S]*?<\/a>/g);
    }
    rows = rows.concat(sportScoreJsonLdUpcomingMatches(page, leagueLabel, options));
    return dedupeMatches(rows);
}

function sportScoreTennisMatchRows(page, leagueLabel, options) {
    let rows = [];
    const pattern = /<a\b[^>]*href=["'](\/tennis\/match\/[^"']+\/?)["'][^>]*class=["'][^"']*\bfootball-match-table-container\b[^"']*\bnostyle\b[^"']*["'][^>]*>([\s\S]*?)<\/a>/g;
    let match;
    while ((match = pattern.exec(stringValue(page))) !== null) {
        const block = match[0];
        const context = stringValue(page).slice(Math.max(0, match.index - 900), match.index);
        const players = sportScoreTennisPlayers(block);
        if (players.length < 2)
            continue;

        const scoreText = htmlText((/<div\b[^>]*class=["'][^"']*\btennis-score-col\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i.exec(block) || [])[1]);
        const scoreMatch = /(\d+)\s*-\s*(\d+)/.exec(scoreText);
        const statusText = htmlText((/<div\b[^>]*class=["'][^"']*\bfootball-match-table-time-str\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i.exec(block) || [])[1]);
        const liveSection = /match-state-header[^>]*\bis-live\b/i.test(context.slice(context.lastIndexOf("match-state-header")));
        const rawStatus = liveSection ? "Live" : statusText;
        const status = sportScoreMatchStatus(rawStatus, scoreMatch && scoreMatch[1], scoreMatch && scoreMatch[2]);
        const timestamp = Date.parse(firstDataUtc(block));
        const path = sportScorePathFromUrl(match[1]);
        rows.push({
            id: "sportscore-" + path,
            sport: "tennis",
            league: leagueLabel || sportScoreCompetitionLabelFromContext(context),
            homeTeam: players[0].name,
            awayTeam: players[1].name,
            homeScore: status === "Upcoming" ? "" : stringValue(scoreMatch && scoreMatch[1]),
            awayScore: status === "Upcoming" ? "" : stringValue(scoreMatch && scoreMatch[2]),
            status,
            minute: "",
            startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp, options) : "",
            timestamp: Number.isFinite(timestamp) ? timestamp : 0,
            matchday: "",
            group: "",
            stadium: "",
            homeBadge: players[0].badge,
            awayBadge: players[1].badge,
            poster: "",
            popular: false,
            matchPath: path,
            liveUrl: sportScoreWidgetMatchUrlFromPath(path, "tennis"),
            detailsProvider: "sportscore",
            statsProvider: "sportscore",
            sourceProvider: "SportScore"
        });
    }
    return rows;
}

function sportScoreTennisPlayers(block) {
    let players = [];
    const imagePattern = /<img\b[^>]*>/g;
    let imageMatch;
    while ((imageMatch = imagePattern.exec(stringValue(block))) !== null) {
        const name = htmlAttribute(imageMatch[0], "alt").replace(/\s+headshot$/i, "").trim();
        const badge = absoluteSportScoreUrl(htmlAttribute(imageMatch[0], "src"));
        if (name.length === 0 || players.some(player => normalizedTeamName(player.name) === normalizedTeamName(name)))
            continue;
        players.push({ name, badge });
        if (players.length === 2)
            break;
    }
    return players;
}

function sportScoreCricketMatchRows(page, leagueLabel, options) {
    let rows = [];
    const pattern = /<a\b[^>]*href=["'](\/cricket\/match\/[^"']+\/?)["'][^>]*class=["'][^"']*\bcricket-match-table-container\b[^"']*\bnostyle\b[^"']*["'][^>]*>([\s\S]*?)<\/a>/g;
    let match;
    while ((match = pattern.exec(stringValue(page))) !== null) {
        const block = match[0];
        const context = stringValue(page).slice(Math.max(0, match.index - 900), match.index);
        const teams = sportScoreCricketTeams(block);
        if (teams.length < 2)
            continue;

        const scores = sportScoreCricketScores(block);
        const rawStatus = sportScoreCricketStatus(block);
        const status = sportScoreMatchStatus(rawStatus, scores[0], scores[1]);
        const timestamp = Date.parse(firstDataUtc(block));
        const path = sportScorePathFromUrl(match[1]);
        rows.push({
            id: "sportscore-" + path,
            sport: "cricket",
            league: leagueLabel || sportScoreCompetitionLabelFromContext(context),
            homeTeam: teams[0].name,
            awayTeam: teams[1].name,
            homeScore: status === "Upcoming" ? "" : stringValue(scores[0]),
            awayScore: status === "Upcoming" ? "" : stringValue(scores[1]),
            status,
            minute: isLiveStatus(status) ? rawStatus : "",
            startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp, options) : "",
            timestamp: Number.isFinite(timestamp) ? timestamp : 0,
            matchday: "",
            group: "",
            stadium: "",
            homeBadge: teams[0].badge,
            awayBadge: teams[1].badge,
            poster: "",
            popular: false,
            matchPath: path,
            liveUrl: sportScoreWidgetMatchUrlFromPath(path, "cricket"),
            detailsProvider: "sportscore",
            statsProvider: "sportscore",
            sourceProvider: "SportScore"
        });
    }
    return rows;
}

function sportScoreCricketTeams(block) {
    let teams = [];
    const imagePattern = /<img\b[^>]*>/g;
    let imageMatch;
    while ((imageMatch = imagePattern.exec(stringValue(block))) !== null) {
        const name = htmlAttribute(imageMatch[0], "alt").replace(/\s+logo$/i, "").trim();
        const badge = absoluteSportScoreUrl(htmlAttribute(imageMatch[0], "src"));
        if (name.length === 0 || teams.some(team => normalizedTeamName(team.name) === normalizedTeamName(name)))
            continue;
        teams.push({ name, badge });
        if (teams.length === 2)
            break;
    }
    return teams;
}

function sportScoreCricketScores(block) {
    const scoreBlockMatch = /<div\b[^>]*class=["'][^"']*\bcricket-match-score-center\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i.exec(stringValue(block));
    if (!scoreBlockMatch)
        return [];

    let scores = [];
    const boldPattern = /<b\b[^>]*>([\s\S]*?)<\/b>/g;
    let boldMatch;
    while ((boldMatch = boldPattern.exec(scoreBlockMatch[1])) !== null)
        scores.push(htmlText(boldMatch[1]));
    return scores.slice(0, 2);
}

function sportScoreCricketStatus(block) {
    const statusMatch = /<div\b[^>]*class=["'][^"']*\bcricket-match-table-time-str\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i.exec(stringValue(block));
    return statusMatch ? htmlText(statusMatch[1]) : "";
}

function normalizeSportScoreRecentResultPage(html, leagueLabel, options) {
    return filterSportScoreMatchesForMode(normalizeSportScoreMatchPage(html, leagueLabel, options), "recent");
}

function normalizeSportScoreMatchRow(block, context, leagueLabel, options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    const label = sportScoreLiveAriaLabel(block);
    const labelParts = label.split(" — ");
    const teams = splitSportScoreTeams(htmlDecode(labelParts[0] || ""));
    const league = htmlDecode(labelParts.slice(1).join(" — ")) || leagueLabel || sportScoreCompetitionLabelFromContext(context);
    const timestamp = Date.parse(firstDataUtc(block));
    const rawStatus = htmlText(sportScoreLiveValue(block, "status"));
    const homeScore = htmlText(sportScoreLiveValue(block, "home-score"));
    const awayScore = htmlText(sportScoreLiveValue(block, "away-score"));
    const path = sportScoreMatchPath(block, sport);
    const logos = sportScoreLiveLogos(block);
    const status = sportScoreMatchStatus(rawStatus, homeScore, awayScore);
    const liveStatus = sport === "basketball" ? basketballPeriodLabel(rawStatus) : rawStatus;

    return {
        id: "sportscore-" + stringValue(path || label),
        sport,
        league,
        homeTeam: teams.home,
        awayTeam: teams.away,
        homeScore: status === "Upcoming" ? "" : homeScore,
        awayScore: status === "Upcoming" ? "" : awayScore,
        status,
        statusText: rawStatus,
        minute: isLiveStatus(status) ? liveStatus : "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp, options) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: sportScoreLastRound(context),
        group: sportScoreLastRound(context),
        stadium: "",
        homeBadge: logos[0] || "",
        awayBadge: logos[1] || "",
        poster: "",
        popular: false,
        matchPath: path,
        liveUrl: sportScoreWidgetMatchUrlFromPath(path, sport),
        detailsProvider: "sportscore",
        statsProvider: "sportscore",
        sourceProvider: "SportScore"
    };
}

function filterSportScoreMatchesForMode(matches, mode) {
    const now = Date.now();
    return (Array.isArray(matches) ? matches : []).filter(match => {
        if (mode === "live")
            return isLiveMatch(match);
        if (mode === "fixtures")
            return !isFinishedMatch(match) && !isLiveMatch(match) && (numberValue(match && match.timestamp) === 0 || numberValue(match.timestamp) >= now - 3 * 60 * 60 * 1000);
        if (mode === "recent")
            return isFinishedMatch(match);
        return true;
    });
}

function sportScoreMatchStatus(rawStatus, homeScore, awayScore, rawState) {
    const status = statusLabel(rawStatus);
    const lower = status.toLowerCase();
    if (lower === "ft" || lower === "finished" || lower === "ended" || lower === "complete" || lower === "completed" || lower.indexOf("finished") >= 0)
        return "Finished";
    if (stringValue(rawState).toLowerCase() === "live")
        return "Live";
    if (isLiveStatus(status))
        return "Live";
    if (stringValue(homeScore).length > 0 && stringValue(awayScore).length > 0)
        return "Finished";
    return "Upcoming";
}

function isLiveStatus(status) {
    const lower = stringValue(status).toLowerCase();
    if (lower.length === 0)
        return false;
    if (lower.indexOf("live") >= 0 || lower.indexOf("in play") >= 0)
        return true;
    if (lower === "ht" || lower === "half-time" || lower === "halftime" || lower === "1h" || lower === "2h")
        return true;
    if (/^(?:q[1-4]|[1-4](?:st|nd|rd|th)\s+quarter|quarter\s+[1-4]|ot\d*|overtime|half time|break)$/.test(lower))
        return true;
    return normalizedLiveMinute(lower).length > 0;
}

function basketballPeriodLabel(value) {
    const text = stringValue(value);
    const lower = text.toLowerCase().replace(/\s+/g, " ").trim();
    let match = /^([1-4])(?:st|nd|rd|th)\s+quarter$/.exec(lower);
    if (!match)
        match = /^quarter\s+([1-4])$/.exec(lower);
    if (match)
        return "Q" + match[1];
    if (/^q[1-4]$/.test(lower))
        return lower.toUpperCase();
    if (lower === "half-time" || lower === "half time" || lower === "halftime" || lower === "ht" || lower === "break")
        return "HT";
    match = /^(?:overtime|ot)\s*(\d*)$/.exec(lower);
    if (match)
        return "OT" + match[1];
    return text;
}

function liveStatusText(sport, value) {
    if (normalizedSport(sport) === "basketball")
        return basketballPeriodLabel(value);
    return stringValue(value);
}

function normalizedLiveMinute(value) {
    const compact = stringValue(value)
        .replace(/[’′`]/g, "'")
        .replace(/\s+/g, "");
    let match = /^(\d{1,3})'\+(\d{0,2})'?$/.exec(compact);
    if (!match)
        match = /^(\d{1,3})\+(\d{0,2})'?$/.exec(compact);
    if (match)
        return match[1] + "+" + match[2];

    match = /^(\d{1,3})'?$/.exec(compact);
    return match ? match[1] : "";
}

function sportScoreLiveMinute(match, status, sport) {
    if (!isLiveStatus(status))
        return "";

    const minute = stringValue(match && match.live_minute);
    const statusText = stringValue(match && (match.status_text || match.status));
    if (normalizedSport(sport) === "basketball")
        return basketballPeriodLabel(statusText || minute);
    const normalizedMinute = normalizedLiveMinute(minute);
    if (normalizedMinute.length > 0)
        return normalizedMinute;
    const normalizedStatus = normalizedLiveMinute(statusText);
    if (normalizedStatus.length > 0)
        return normalizedStatus;
    if (/^(ht|half-time|halftime|1h|2h)$/i.test(statusText))
        return statusText;
    return minute || statusText;
}

function sportScoreLiveAriaLabel(block) {
    const linkMatch = /<a\b[^>]*class="[^"]*\bsc-stretched-link\b[^"]*"[^>]*>/i.exec(stringValue(block));
    if (linkMatch)
        return htmlAttribute(linkMatch[0], "aria-label");
    return htmlAttribute(block, "aria-label");
}

function sportScoreLiveValue(block, name) {
    const expression = new RegExp("<[^>]+data-live=[\"']" + escapeRegExp(name) + "[\"'][^>]*>([\\s\\S]*?)<\\/[^>]+>", "i");
    const match = expression.exec(stringValue(block));
    return match ? match[1] : "";
}

function sportScoreMatchPath(block, sport) {
    const sportValue = normalizedSport(sport) || "football";
    const match = new RegExp("href=[\"'](\\/" + escapeRegExp(sportValue) + "\\/match\\/[^\"']+\\/?)", "i").exec(stringValue(block));
    return match ? htmlDecode(match[1]) : "";
}

function sportScoreWidgetMatchUrl(options) {
    const urls = sportScoreWidgetMatchUrls(options);
    return urls.length > 0 ? urls[0] : "";
}

function sportScoreWidgetMatchUrls(options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    let urls = [];
    function append(url) {
        const value = absoluteSportScoreUrl(url);
        if (value.length > 0 && urls.indexOf(value) < 0)
            urls.push(value);
    }

    const direct = stringValue(options && options.liveUrl);
    if (direct.indexOf("/api/widget/match/") >= 0 || direct.indexOf("sportscore.com/api/widget/match/") >= 0)
        append(direct);

    const fromPath = sportScoreWidgetMatchUrlFromPath(options && options.matchPath, sport);
    if (fromPath.length > 0)
        append(fromPath);

    const home = ProviderCatalog.slugForValue(options && options.homeTeam);
    const away = ProviderCatalog.slugForValue(options && options.awayTeam);
    if (home.length > 0 && away.length > 0) {
        append(sportScoreWidgetMatchUrlFromSlug(home + "-vs-" + away, sport));
        append(sportScoreWidgetMatchUrlFromSlug(away + "-vs-" + home, sport));
    }

    return urls;
}

function sportScoreWidgetMatchUrlFromPath(path, sport) {
    const sportValue = normalizedSport(sport) || sportScoreSportFromPath(path) || "football";
    const match = new RegExp("\\/" + escapeRegExp(sportValue) + "\\/match\\/([^\\/?#]+)\\/?", "i").exec(sportScorePathFromUrl(path));
    return match ? sportScoreWidgetMatchUrlFromSlug(match[1], sportValue) : "";
}

function sportScoreWidgetMatchUrlFromSlug(slug, sport) {
    const value = ProviderCatalog.slugForValue(slug);
    const sportValue = normalizedSport(sport) || "football";
    return value.length > 0 ? SPORTSCORE_BASE_URL + "/api/widget/match/?sport=" + encodeURIComponent(sportValue) + "&slug=" + encodeURIComponent(value) : "";
}

function sportScoreLiveLogos(block) {
    const rows = [];
    const pattern = /<img\b[^>]*>/g;
    let match;
    while ((match = pattern.exec(stringValue(block))) !== null) {
        const tag = match[0];
        const alt = htmlAttribute(tag, "alt").toLowerCase();
        if (alt.indexOf("logo") < 0)
            continue;
        const source = absoluteSportScoreUrl(htmlAttribute(tag, "src"));
        if (source.length > 0 && rows.indexOf(source) < 0)
            rows.push(source);
        if (rows.length >= 2)
            break;
    }
    return rows;
}

function splitSportScoreTeams(value) {
    const text = stringValue(value).replace(/\s+v\s+/i, " vs ");
    const parts = text.split(/\s+vs\s+/i);
    return {
        home: stringValue(parts[0]),
        away: stringValue(parts.slice(1).join(" vs "))
    };
}

function firstDataUtc(block) {
    const match = /\bdata-utc=["']([^"']+)["']/i.exec(stringValue(block));
    return match ? htmlDecode(match[1]) : "";
}

function sportScoreLastRound(context) {
    const headers = stringValue(context).match(/<h2\b[^>]*>([\s\S]*?)<\/h2>/g) || [];
    if (headers.length === 0)
        return "";
    const text = htmlText(headers[headers.length - 1]);
    return roundLabelFromText(text);
}

function sportScoreCompetitionLabelFromContext(context) {
    const links = stringValue(context).match(/<a\b[^>]*href="\/(?:football|basketball|cricket|tennis)\/competition\/[^"]+"[^>]*>([\s\S]*?)<\/a>/g) || [];
    if (links.length === 0)
        return "";
    return htmlText(links[links.length - 1]);
}

function hasTeams(match) {
    return stringValue(match && match.homeTeam).length > 0 && stringValue(match && match.awayTeam).length > 0;
}

function matchBelongsToTeam(match, teamName) {
    return sameTeamName(match && match.homeTeam, teamName) || sameTeamName(match && match.awayTeam, teamName);
}

function sportScoreJsonLdUpcomingMatches(html, leagueLabel, options) {
    let rows = [];
    sportScoreJsonLdLists(html).forEach(list => {
        const name = normalizedText(list && list.name);
        if (name.indexOf("upcoming") < 0 && name.indexOf("fixture") < 0)
            return;
        arrayValue(list.itemListElement).forEach(item => {
            const row = normalizeSchemaFixture(item && item.item, leagueLabel, options);
            if (hasTeams(row))
                rows.push(row);
        });
    });
    return rows;
}

function sportScoreJsonLdLists(html) {
    let rows = [];
    const pattern = /<script type="application\/ld\+json">([\s\S]*?)<\/script>/g;
    let match;
    while ((match = pattern.exec(stringValue(html))) !== null) {
        try {
            collectJsonLdLists(JSON.parse(match[1]), rows);
        } catch (error) {
        }
    }
    return rows;
}

function collectJsonLdLists(value, rows) {
    if (!value)
        return;
    if (Array.isArray(value)) {
        value.forEach(item => collectJsonLdLists(item, rows));
        return;
    }
    if (typeof value !== "object")
        return;
    if (value["@type"] === "ItemList")
        rows.push(value);
    collectJsonLdLists(value["@graph"], rows);
}

function normalizeSchemaFixture(event, leagueLabel, options) {
    if (!event)
        return {};
    const sport = normalizedSport(options && (options.sports || options.sport)) || sportScoreSportFromPath(event.url) || "football";
    const timestamp = Date.parse(event.startDate || "");
    const images = arrayValue(event.image);
    const descriptionLeague = sportScoreLeagueFromDescription(event.description);
    return {
        id: stringValue(event["@id"] || event.url),
        sport,
        league: descriptionLeague || leagueLabel,
        homeTeam: schemaTeamName(event.homeTeam),
        awayTeam: schemaTeamName(event.awayTeam),
        homeScore: "",
        awayScore: "",
        status: "Upcoming",
        minute: "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : stringValue(event.startDate),
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: "",
        stadium: stringValue(event && event.location && event.location.name),
        homeBadge: stringValue(images[0]),
        awayBadge: stringValue(images[1]),
        poster: "",
        popular: false,
        matchPath: sportScorePathFromUrl(event.url),
        liveUrl: sportScoreWidgetMatchUrlFromPath(sportScorePathFromUrl(event.url), sport),
        detailsProvider: "sportscore",
        statsProvider: "sportscore",
        sourceProvider: "SportScore"
    };
}

function schemaTeamName(team) {
    if (!team)
        return "";
    if (typeof team === "string")
        return team;
    return stringValue(team.name);
}

function sportScoreLeagueFromDescription(value) {
    const text = stringValue(value);
    const match = /—\s*(.*?)\s+football match/i.exec(text);
    return match ? stringValue(match[1]) : "";
}

function sportScoreTeamCompetitions(html, options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    const section = sportScoreTeamCompetitionsSection(html);
    const rows = [];
    const seen = {};
    const pattern = new RegExp("<a\\b[^>]*href=[\"'](\\/" + escapeRegExp(sport) + "\\/competition\\/([^\\/\"']+)\\/([^\\/\"']+)\\/[^\"']+\\/)[\"'][^>]*>([\\s\\S]*?)<\\/a>", "g");
    let match;
    while ((match = pattern.exec(section)) !== null) {
        const labelHtml = stringValue(match[4]).replace(/<span\b[^>]*class="[^"]*\bcountry\b[^"]*"[^>]*>[\s\S]*?<\/span>/ig, "");
        const label = htmlText(labelHtml);
        const slug = ProviderCatalog.slugForValue(match[3]);
        const country = ProviderCatalog.slugForValue(match[2]) || ProviderCatalog.slugForValue(options && options.country);
        const key = slug + "|" + country;
        if (slug.length === 0 || label.length === 0 || seen[key])
            continue;
        seen[key] = true;
        rows.push({
            label,
            slug,
            value: slug,
            country,
            path: htmlDecode(match[1]),
            url: absoluteSportScoreUrl(match[1])
        });
    }

    rows.sort((left, right) => competitionPriority(left.label) === competitionPriority(right.label)
        ? stringValue(left.label).localeCompare(stringValue(right.label))
        : competitionPriority(right.label) - competitionPriority(left.label));
    return rows;
}

function sportScoreTeamCompetitionsSection(html) {
    const page = stringValue(html);
    const heading = /<h2\b[^>]*class="[^"]*\bteam-section-header\b[^"]*"[^>]*>\s*Competitions\s*<\/h2>/i.exec(page);
    if (!heading)
        return page;

    const listStart = page.indexOf("<ul", heading.index);
    if (listStart < 0)
        return "";
    const listEnd = page.indexOf("</ul>", listStart);
    if (listEnd < 0)
        return page.slice(listStart);
    return page.slice(listStart, listEnd + 5);
}

function sportScoreTeamProfile(html, options) {
    const json = sportScoreTeamJsonLd(html);
    const label = stringValue(json && json.name) || stringValue(options && options.favoriteTeam);
    return {
        label,
        value: label,
        badge: stringValue(json && json.logo) || sportScoreTeamBadge(html),
        country: ProviderCatalog.slugForValue(json && json.location && json.location.name) || ProviderCatalog.slugForValue(options && options.country),
        league: stringValue(json && json.memberOf && json.memberOf.name),
        leaguePath: sportScorePathFromUrl(json && json.memberOf && json.memberOf.url)
    };
}

function sportScoreTeamBadge(html) {
    const json = sportScoreTeamJsonLd(html);
    if (stringValue(json && json.logo).length > 0)
        return stringValue(json.logo);
    const bigLogo = /<img\b[^>]*class="[^"]*\bteam-logo-big\b[^"]*"[^>]*>/i.exec(stringValue(html));
    return bigLogo ? absoluteSportScoreUrl(htmlAttribute(bigLogo[0], "src")) : "";
}

function sportScoreTeamJsonLd(html) {
    const pattern = /<script type="application\/ld\+json">([\s\S]*?)<\/script>/g;
    let match;
    while ((match = pattern.exec(stringValue(html))) !== null) {
        try {
            const value = JSON.parse(match[1]);
            if (value && (value["@type"] === "SportsTeam" || value["@type"] === "Person"))
                return value;
        } catch (error) {
        }
    }
    return {};
}

function sportScoreSeasonOptionsFromCompetitionPage(html) {
    const page = stringValue(html);
    let rows = [];
    let seen = {};
    const pattern = /<option[^>]*value="([^"]+\/\d{4}(?:-\d{4})?\/?)"[^>]*>([^<]+)<\/option>/g;
    let match;
    while ((match = pattern.exec(page)) !== null) {
        const path = sportScorePathFromUrl(match[1]);
        const rawLabel = htmlText(match[2]);
        const key = sportScoreSeasonMatchKey(rawLabel || path);
        if (path.length === 0 || key.length === 0 || seen[key])
            continue;
        seen[key] = true;
        rows.push({
            key,
            id: path,
            path,
            label: normalizeSeasonLabelDisplay(rawLabel || key),
            provider: "sportscore",
            yearScore: sportScoreSeasonSortScore(key),
            isDefault: false
        });
    }

    rows.sort((left, right) => numberValue(right.yearScore) - numberValue(left.yearScore));
    if (rows.length > 0)
        rows[0].isDefault = true;
    return rows;
}

function sportScoreSeasonMatchKey(value) {
    const text = stringValue(value).trim();
    const direct = text.match(/(\d{4})\D+(\d{4})/);
    if (direct)
        return direct[1] + "-" + direct[2];
    const single = text.match(/(?:^|\/|\s)(\d{4})(?:\/|\s|$)/);
    if (single)
        return single[1];
    const short = text.match(/(\d{2})\D+(\d{2})/);
    if (short)
        return (2000 + numberValue(short[1])) + "-" + (2000 + numberValue(short[2]));
    return "";
}

function sportScoreSeasonSortScore(label) {
    const key = sportScoreSeasonMatchKey(label) || stringValue(label);
    const range = /^(\d{4})-(\d{4})$/.exec(key);
    if (range)
        return numberValue(range[1]) * 10000 + numberValue(range[2]);

    const single = /^(\d{4})$/.exec(key);
    return single ? numberValue(single[1]) * 10000 + numberValue(single[1]) : 0;
}

function normalizeSeasonLabelDisplay(label) {
    const key = sportScoreSeasonMatchKey(label);
    const match = /^(\d{4})-(\d{4})$/.exec(key);
    if (match)
        return match[1] + "/" + match[2];

    return /^(\d{4})$/.test(key) ? key : stringValue(label);
}

function normalizeSportScoreCompetitionTablePage(html, leagueLabel, options) {
    const tableSection = sportScoreStandingsTableSection(html);
    if (tableSection.length === 0)
        return [];

    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    const schema = SportScoreSports.standingsHtmlSchema(sport);
    let rows = [];
    const rowPattern = /<tr\b[^>]*>([\s\S]*?)<\/tr>/g;
    let rowMatch;
    while ((rowMatch = rowPattern.exec(tableSection)) !== null) {
        const rowHtml = rowMatch[1];
        const cells = [];
        const cellPattern = /<td\b[^>]*>([\s\S]*?)<\/td>/g;
        let cellMatch;
        while ((cellMatch = cellPattern.exec(rowHtml)) !== null)
            cells.push(htmlText(cellMatch[1]));

        if (cells.length < numberValue(schema.minimumCells))
            continue;

        const teamAnchor = /<td class="team-col">[\s\S]*?<a[^>]*href="([^"]+)"/.exec(rowHtml);
        const crestMatch = /<td class="team-col">[\s\S]*?<img[^>]*src="([^"]+)"/.exec(rowHtml);
        const formCell = numberValue(schema.formCell);
        const form = sportScoreTableRowForm(rowHtml, formCell >= 0 ? cells[formCell] : "");
        let row = {
            position: numberValue(cells[0]),
            team: stringValue(cells[1]),
            group: sportScoreTableGroupForRow(rowHtml),
            groupIndex: 0,
            form,
            crest: crestMatch ? absoluteSportScoreUrl(htmlDecode(crestMatch[1])) : "",
            teamPath: sportScorePathFromUrl(teamAnchor ? htmlDecode(teamAnchor[1]) : ""),
            teamSlug: sportScoreTeamSlugFromPath(teamAnchor ? htmlDecode(teamAnchor[1]) : "", sport),
            league: stringValue(leagueLabel),
            sport
        };
        Object.keys(schema.fields || {}).forEach(field => {
            const index = numberValue(schema.fields[field]);
            const value = stringValue(cells[index]);
            row[field] = field === "percentage" ? value : numberValue(value);
        });
        rows.push(row);
    }

    return rows.filter(row => stringValue(row.team).length > 0)
        .sort((left, right) => numberValue(left.position) - numberValue(right.position) || stringValue(left.team).localeCompare(stringValue(right.team)));
}

function sportScoreStandingsTableSection(html) {
    const value = stringValue(html);
    const tableStart = value.indexOf('<table class="standings-table"');
    if (tableStart < 0)
        return "";
    const bodyStart = value.indexOf("<tbody", tableStart);
    if (bodyStart < 0)
        return "";
    const bodyOpenEnd = value.indexOf(">", bodyStart);
    const bodyEnd = value.indexOf("</tbody>", bodyOpenEnd + 1);
    if (bodyOpenEnd < 0 || bodyEnd < 0)
        return "";
    return value.slice(bodyOpenEnd + 1, bodyEnd);
}

function sportScoreTableRowForm(rowHtml, fallback) {
    let values = [];
    const pattern = /form-pill\s+([WDL])\b/g;
    let match;
    while ((match = pattern.exec(stringValue(rowHtml))) !== null)
        values.push(match[1]);
    if (values.length === 0)
        values = (stringValue(fallback).match(/[WDL]/g) || []);
    return values.slice(0, 5).join(",");
}

function sportScoreTableGroupForRow(rowHtml) {
    const match = /data-group="([^"]+)"/i.exec(stringValue(rowHtml));
    return match ? htmlDecode(match[1]) : "";
}

function sportScoreTeamSlugFromPath(path, sport) {
    const sportValue = normalizedSport(sport) || sportScoreSportFromPath(path) || "football";
    const participant = SportScoreSports.usesPlayers(sportValue) ? "player" : "team";
    const match = new RegExp("\\/" + escapeRegExp(sportValue) + "\\/" + participant + "\\/([^\\/]+)\\/").exec(stringValue(path));
    return match ? ProviderCatalog.slugForValue(match[1]) : "";
}

function sportScoreFormValues(value) {
    if (Array.isArray(value))
        return value.filter(item => /^[WDL]$/.test(stringValue(item))).slice(0, 5);

    return (stringValue(value).match(/[WDL]/g) || []).slice(0, 5);
}

function sportScoreCountryOptions(html, sport) {
    const sportValue = normalizedSport(sport);
    if (!SportScoreSports.supports(sportValue))
        return [];

    let countries = {};
    const pattern = new RegExp("\\/" + escapeRegExp(sportValue) + "\\/competition\\/([^\\/\"']+)\\/", "g");
    let match;
    while ((match = pattern.exec(stringValue(html))) !== null) {
        const value = ProviderCatalog.slugForValue(match[1]);
        if (value.length === 0)
            continue;
        countries[value] = true;
    }

    return Object.keys(countries)
        .map(value => ({
            label: value === "world" ? "International Tournaments" : ProviderCatalog.leagueLabel(value),
            value,
            icon: value === "world" ? "globe" : "",
            infoText: value === "world" ? "Worldwide competitions" : ""
        }))
        .sort((left, right) => {
            if (left.value === "world")
                return -1;
            if (right.value === "world")
                return 1;
            return stringValue(left.label).localeCompare(stringValue(right.label));
        });
}

function sportScoreSportFromPath(path) {
    const match = /^\/(football|basketball|cricket|tennis)\//.exec(sportScorePathFromUrl(path));
    return match ? match[1] : "";
}

function fetchSportScoreCountryTeams(sport, country, onSuccess, onError) {
    const sportValue = normalizedSport(sport) || "football";
    const sourcePath = SportScoreSports.usesPlayers(sportValue)
        ? SportScoreSports.rootPath(sportValue)
        : SportScoreSports.competitionSourcePath(sportValue, country);
    requestText(SPORTSCORE_BASE_URL + sourcePath, html => {
        let rows = teamsFromSportScoreCountryPage(html, country, sportValue);
        if (SportScoreSports.usesPlayers(sportValue)) {
            finish(onSuccess, dedupeTeamRows(rows).slice(0, SPORTSCORE_TEAM_LIMIT));
            return;
        }

        const competitions = sportScoreCompetitionLinks(html, country, sportValue).slice(0, SPORTSCORE_COUNTRY_COMPETITION_LIMIT);
        if (competitions.length === 0) {
            finish(onSuccess, dedupeTeamRows(rows));
            return;
        }

        fetchSportScoreCompetitionTeamPages(competitions, 0, pages => {
            pages.forEach(page => {
                rows = rows.concat(teamsFromSportScoreCompetitionPage(page.html, page.competition, page.index, sportValue));
            });
            finish(onSuccess, dedupeTeamRows(rows).slice(0, SPORTSCORE_TEAM_LIMIT));
        });
    }, error => {
        finish(onError, error || "Unable to load SportScore country teams");
    });
}

function fetchSportScoreCompetitionTeamPages(competitions, startIndex, onDone) {
    let pages = [];
    let nextIndex = startIndex;
    let pending = 0;

    function launchNext() {
        while (pending < SPORTSCORE_COUNTRY_COMPETITION_CONCURRENCY && nextIndex < competitions.length) {
            const index = nextIndex;
            const competition = competitions[index];
            nextIndex += 1;
            pending += 1;
            requestText(competition.url, competitionHtml => {
                pages.push({
                    competition,
                    index,
                    html: competitionHtml
                });
                pending -= 1;
                launchNext();
            }, () => {
                pending -= 1;
                launchNext();
            });
        }

        if (pending === 0 && nextIndex >= competitions.length)
            finish(onDone, pages);
    }

    launchNext();
}

function sportScoreCompetitionLinks(html, country, sport) {
    const page = stringValue(html);
    const sportValue = normalizedSport(sport) || "football";
    let rows = [];
    let seen = {};
    const expression = new RegExp("<a\\b[^>]*href=[\"'](\\/" + escapeRegExp(sportValue) + "\\/competition\\/([^\\/\"']+)\\/([^\\/\"']+)\\/[^\"']+\\/)[\"'][^>]*(?:title=[\"']([^\"']*)[\"'])?[^>]*>([\\s\\S]*?)<\\/a>", "g");
    let match;
    while ((match = expression.exec(page)) !== null) {
        if (country !== "world" && ProviderCatalog.slugForValue(match[2]) !== country)
            continue;

        const path = htmlDecode(match[1]);
        if (seen[path])
            continue;

        const label = ProviderCatalog.normalizedCompetitionLabel(
            sportScoreCompetitionLabel(match[5], match[4], match[3]),
            match[3]
        );
        if (label.length === 0)
            continue;

        seen[path] = true;
        rows.push({
            label,
            value: ProviderCatalog.slugForValue(match[3]),
            slug: ProviderCatalog.slugForValue(match[3]),
            country: ProviderCatalog.slugForValue(match[2]),
            sport: sportValue,
            path,
            url: absoluteSportScoreUrl(path),
            priority: competitionPriority(label)
        });
    }

    rows.sort((left, right) => {
        if (left.priority !== right.priority)
            return right.priority - left.priority;
        return stringValue(left.label).localeCompare(stringValue(right.label));
    });
    return rows;
}

function sportScoreCompetitionLabel(anchorHtml, title, slug) {
    const block = stringValue(anchorHtml);
    const worldCupMatch = /<span\b[^>]*class="[^"]*\bfifa-wc26__name\b[^"]*"[^>]*>([\s\S]*?)<\/span>/i.exec(block);
    if (worldCupMatch)
        return htmlText(worldCupMatch[1]);

    const nameMatch = /<span\b[^>]*class="[^"]*\bname\b[^"]*"[^>]*>([\s\S]*?)<\/span>/i.exec(block);
    if (nameMatch)
        return htmlText(nameMatch[1]);

    const sidebarMatch = /<span\b[^>]*class="[^"]*\bsidebar-item_p\b[^"]*"[^>]*>([\s\S]*?)<\/span>/i.exec(block);
    if (sidebarMatch)
        return htmlText(sidebarMatch[1]);

    const raw = htmlText(block)
        .replace(/\b\d+\s+matches?\b/ig, "")
        .replace(/\bleague hub\b/ig, "")
        .replace(/\s+/g, " ")
        .trim();
    return raw || stringValue(htmlDecode(title)) || ProviderCatalog.leagueLabel(slug);
}

function competitionPriority(label) {
    const text = stringValue(label).toLowerCase();
    if (text.length === 0)
        return -500;

    let score = 0;
    if (text.indexOf("premier") >= 0 || text.indexOf("super league") >= 0 || text.indexOf("division 1") >= 0 || text.indexOf("serie a") >= 0 || text.indexOf("bundesliga") >= 0 || text.indexOf("la liga") >= 0 || text.indexOf("ligue 1") >= 0 || text.indexOf("eredivisie") >= 0 || text.indexOf("primera") >= 0)
        score += 80;
    if (text.indexOf("championship") >= 0 || text.indexOf("league one") >= 0 || text.indexOf("league two") >= 0 || text.indexOf("division 2") >= 0 || text.indexOf("serie b") >= 0 || text.indexOf("segunda") >= 0 || text.indexOf("ligue 2") >= 0 || text.indexOf("2.liga") >= 0 || text.indexOf("2 liga") >= 0)
        score += 55;
    if (text.indexOf("league") >= 0 || text.indexOf("liga") >= 0)
        score += 18;
    if (text.indexOf("cup") >= 0 || text.indexOf("shield") >= 0 || text.indexOf("playoff") >= 0 || text.indexOf("play-off") >= 0 || text.indexOf("qualif") >= 0)
        score -= 24;
    if (text.indexOf("women") >= 0 || text.indexOf("womens") >= 0 || text.indexOf("ladies") >= 0)
        score -= 34;
    if (text.indexOf("reserve") >= 0 || text.indexOf("reserves") >= 0 || text.indexOf("youth") >= 0 || /\bu[0-9]{1,2}\b/.test(text))
        score -= 38;
    if (text.indexOf("amateur") >= 0 || text.indexOf("regional") >= 0 || text.indexOf("county") >= 0)
        score -= 24;
    if (text.indexOf("friendly") >= 0 || text.indexOf("friendlies") >= 0 || text.indexOf("virtual") >= 0 || text.indexOf("esoccer") >= 0)
        score -= 90;

    return score;
}

function teamsFromSportScoreCountryPage(html, country, sport) {
    const rows = [];
    const page = stringValue(html);
    const sportValue = normalizedSport(sport) || "football";
    if (sportValue === "football") {
        const nationalTeam = sportScoreTeamLinkFromBlock(page, new RegExp("<span\\s+class=\"nat-name\">([\\s\\S]*?)<\\/span>", "i"), sportValue);
        if (nationalTeam.label.length > 0)
            rows.push(nationalTeam);
    }

    const popularStart = page.search(/<h2>Popular (?:teams|players)/i);
    if (popularStart >= 0) {
        const block = boundedHtmlBlock(page.slice(popularStart), "<h2>", "</div>");
        extractSportScoreTeamLinks(block, sportValue).forEach(row => rows.push(row));
    }

    if (SportScoreSports.usesPlayers(sportValue) && rows.length === 0)
        extractSportScoreTeamLinks(page, sportValue).forEach(row => rows.push(row));

    return rows.map((row, index) => withTeamRank(row, index));
}

function teamsFromSportScoreCompetitionPage(html, competition, competitionIndex, sport) {
    const page = stringValue(html);
    const sportValue = normalizedSport(sport) || "football";
    let rows = [];
    const teamsAnchor = page.indexOf("id=\"teams\"");
    if (teamsAnchor >= 0) {
        const teamBlock = boundedHtmlBlock(page.slice(teamsAnchor), "<div class=\"side-card\"", "</div>");
        rows = extractSportScoreTeamLinks(teamBlock, sportValue);
    }

    if (rows.length === 0) {
        const standingsAnchor = page.indexOf("standings");
        const source = standingsAnchor >= 0 ? boundedHtmlBlock(page.slice(standingsAnchor), "<table", "</table>") : page;
        rows = extractSportScoreTeamLinks(source, sportValue);
    }

    const leagueLabel = stringValue(competition && competition.label);
    const rankOffset = competitionIndex * 100;
    return rows.map((row, index) => {
        const next = withTeamRank(row, rankOffset + index);
        next.leagues = leagueLabel.length > 0 ? [leagueLabel] : [];
        return next;
    });
}

function sportScoreTeamLinkFromBlock(html, expression, sport) {
    const match = expression.exec(stringValue(html));
    if (!match)
        return {};

    const rows = extractSportScoreTeamLinks(match[1], sport);
    return rows.length > 0 ? rows[0] : {};
}

function extractSportScoreTeamLinks(html, sport) {
    const block = stringValue(html);
    const sportValue = normalizedSport(sport) || "football";
    const participant = SportScoreSports.usesPlayers(sportValue) ? "player" : "team";
    let rows = [];
    const expression = new RegExp("<a\\b[^>]*href=[\"'](\\/" + escapeRegExp(sportValue) + "\\/" + participant + "\\/([^\\/\"']+)\\/[^\"']+\\/)[\"'][^>]*>([\\s\\S]*?)<\\/a>", "g");
    let match;
    while ((match = expression.exec(block)) !== null) {
        const label = htmlText(match[3]);
        if (!isUsefulTeamLabel(label))
            continue;

        const before = block.slice(Math.max(0, match.index - 700), match.index);
        const itemHtml = surroundingListItemHtml(block, match.index);
        rows.push({
            label,
            value: label,
            teamSlug: ProviderCatalog.slugForValue(match[2]),
            teamPath: htmlDecode(match[1]),
            badge: firstImageSource(itemHtml) || firstImageSource(before)
        });
    }

    return rows;
}

function surroundingListItemHtml(block, index) {
    const text = stringValue(block);
    const start = text.lastIndexOf("<li", index);
    if (start < 0)
        return "";

    const end = text.indexOf("</li>", index);
    if (end < 0)
        return "";

    return text.slice(start, end + 5);
}

function isUsefulTeamLabel(label) {
    const text = stringValue(label);
    if (text.length < 2)
        return false;

    const lower = text.toLowerCase();
    if (lower === "view team" || lower === "free player" || lower.indexOf("home ground") >= 0)
        return false;

    return true;
}

function withTeamRank(row, rank) {
    const next = Object.assign({}, row || {});
    next.rank = Number(rank);
    return next;
}

function dedupeTeamRows(rows) {
    let byTeam = {};
    (Array.isArray(rows) ? rows : []).forEach(row => {
        const label = stringValue(row && (row.value || row.label));
        const key = normalizedTeamName(label);
        if (key.length === 0)
            return;

        if (!byTeam[key]) {
            byTeam[key] = Object.assign({}, row, {
                label: stringValue(row && row.label) || label,
                value: label,
                rank: Number.isFinite(Number(row && row.rank)) ? Number(row.rank) : 9999
            });
            return;
        }

        const current = byTeam[key];
        if (stringValue(current.badge).length === 0 && stringValue(row && row.badge).length > 0)
            current.badge = stringValue(row.badge);
        if (stringValue(current.teamPath).length === 0 && stringValue(row && row.teamPath).length > 0)
            current.teamPath = stringValue(row.teamPath);
        if (stringValue(current.teamSlug).length === 0 && stringValue(row && row.teamSlug).length > 0)
            current.teamSlug = stringValue(row.teamSlug);
        current.rank = Math.min(Number(current.rank), Number(row && row.rank) || 9999);
        current.leagues = mergeUniqueStrings(current.leagues, row && row.leagues);
    });

    return Object.keys(byTeam)
        .map(key => byTeam[key])
        .sort((left, right) => {
            if (left.rank !== right.rank)
                return left.rank - right.rank;
            return stringValue(left.label).localeCompare(stringValue(right.label));
        });
}

function mergeUniqueStrings(left, right) {
    let values = [];
    function append(items) {
        (Array.isArray(items) ? items : []).forEach(item => {
            const value = stringValue(item);
            if (value.length > 0 && values.indexOf(value) < 0)
                values.push(value);
        });
    }

    append(left);
    append(right);
    return values;
}

function requestText(url, onSuccess, onError) {
    const xhr = new XMLHttpRequest();
    xhr.open("GET", url);
    xhr.timeout = REQUEST_TIMEOUT_MS;
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return;

        if (xhr.status >= 200 && xhr.status < 300) {
            finish(onSuccess, xhr.responseText || "");
        } else {
            finish(onError, "HTTP " + xhr.status + " for " + url);
        }
    };
    xhr.ontimeout = function () {
        finish(onError, "Timeout for " + url);
    };
    xhr.onerror = function () {
        finish(onError, "Network error for " + url);
    };
    xhr.send();
}

function boundedHtmlBlock(source, startNeedle, endNeedle) {
    const text = stringValue(source);
    const start = text.indexOf(startNeedle);
    if (start < 0)
        return text;

    const afterStart = text.slice(start);
    const end = afterStart.indexOf(endNeedle, startNeedle.length);
    if (end < 0)
        return afterStart;

    return afterStart.slice(0, end + endNeedle.length);
}

function firstImageSource(html) {
    const matches = stringValue(html).match(/<img\b[^>]*src="([^"]+)"/g) || [];
    if (matches.length === 0)
        return "";

    const last = matches[matches.length - 1];
    const source = htmlAttribute(last, "src");
    return absoluteSportScoreUrl(source);
}

function htmlAttribute(tag, name) {
    const expression = new RegExp("\\b" + name + "=(?:\"([^\"]*)\"|'([^']*)')", "i");
    const match = expression.exec(stringValue(tag));
    return match ? htmlDecode(match[1] || match[2]) : "";
}

function htmlText(value) {
    return htmlDecode(stringValue(value).replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim());
}

function htmlDecode(value) {
    return stringValue(value)
        .replace(/&amp;/g, "&")
        .replace(/&quot;/g, "\"")
        .replace(/&#x27;/g, "'")
        .replace(/&#39;/g, "'")
        .replace(/&ndash;/g, "-")
        .replace(/&mdash;/g, "-")
        .replace(/&nbsp;/g, " ")
        .replace(/&trade;|&#8482;/g, "™")
        .replace(/&reg;|&#174;/g, "®")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">");
}

function absoluteSportScoreUrl(value) {
    const url = stringValue(value);
    if (url.indexOf("//") === 0)
        return "https:" + url;
    if (/^https?:\/\//.test(url))
        return url;
    if (url.charAt(0) === "/")
        return SPORTSCORE_BASE_URL + url;
    return url;
}

function sportScorePathFromUrl(value) {
    const url = stringValue(value);
    if (url.length === 0)
        return "";
    const match = /^https?:\/\/[^\/]+(\/.*)$/.exec(url);
    const path = match ? match[1] : url;
    return path.charAt(0) === "/" ? path : "";
}

function cacheBustedUrl(url) {
    const value = stringValue(url);
    if (value.length === 0)
        return value;

    const separator = value.indexOf("?") >= 0 ? "&" : "?";
    return value + separator + "src=sports-widget-for-plasma&t=" + Date.now();
}

function sortMatches(matches) {
    return arrayValue(matches).slice().sort((left, right) => {
        const leftOrder = numberValue(left && left.scopeOrder);
        const rightOrder = numberValue(right && right.scopeOrder);
        if (leftOrder !== rightOrder)
            return leftOrder - rightOrder;
        return numberValue(left && left.timestamp) - numberValue(right && right.timestamp);
    });
}

function sortUpcomingMatches(matches) {
    return sortMatches(matches).filter(match => numberValue(match && match.timestamp) === 0 || numberValue(match.timestamp) >= Date.now() - 3 * 60 * 60 * 1000);
}

function sortRecentMatches(matches) {
    return arrayValue(matches).slice().sort((left, right) => {
        const leftOrder = numberValue(left && left.scopeOrder);
        const rightOrder = numberValue(right && right.scopeOrder);
        if (leftOrder !== rightOrder)
            return leftOrder - rightOrder;
        return numberValue(right && right.timestamp) - numberValue(left && left.timestamp);
    });
}

function dedupeMatches(matches) {
    let rows = [];
    let seen = {};
    arrayValue(matches).forEach(match => {
        const key = [
            normalizedTeamName(match && match.homeTeam),
            normalizedTeamName(match && match.awayTeam),
            ProviderCatalog.slugForValue(match && match.league),
            numberValue(match && match.timestamp) || stringValue(match && match.startTime),
            stringValue(match && match.homeScore),
            stringValue(match && match.awayScore)
        ].join("|");
        if (key.replace(/\|/g, "").length === 0 || seen[key])
            return;
        seen[key] = true;
        rows.push(match);
    });
    return rows;
}

function dedupeMatchesForSport(matches, sport) {
    if (normalizedSport(sport) !== "basketball")
        return dedupeMatches(matches);

    let rows = [];
    let indexes = {};
    arrayValue(matches).forEach(match => {
        const path = sportScorePathFromUrl(match && (match.matchPath || match.liveUrl));
        const key = path.length > 0 ? path : [
            normalizedTeamName(match && match.homeTeam),
            normalizedTeamName(match && match.awayTeam),
            ProviderCatalog.slugForValue(match && match.league),
            numberValue(match && match.timestamp) || stringValue(match && match.startTime)
        ].join("|");
        if (key.replace(/\|/g, "").length === 0)
            return;

        if (indexes[key] === undefined) {
            indexes[key] = rows.length;
            rows.push(match);
            return;
        }

        const index = indexes[key];
        const current = rows[index] || {};
        const currentTotal = numberValue(current.homeScore) + numberValue(current.awayScore);
        const nextTotal = numberValue(match && match.homeScore) + numberValue(match && match.awayScore);
        const preferred = nextTotal >= currentTotal ? Object.assign({}, current, match) : Object.assign({}, match, current);
        const currentOrder = Number(current.scopeOrder);
        const nextOrder = Number(match && match.scopeOrder);
        if (Number.isFinite(currentOrder) && Number.isFinite(nextOrder))
            preferred.scopeOrder = Math.min(currentOrder, nextOrder);
        rows[index] = preferred;
    });
    return rows;
}

function statusLabel(value) {
    const text = stringValue(value);
    if (text.length === 0)
        return "";
    const normalized = text.toLowerCase();
    if (normalized === "ft")
        return "Finished";
    if (normalized === "ht")
        return "HT";
    return text.charAt(0).toUpperCase() + text.slice(1);
}

function roundLabelFromText(value) {
    const text = stringValue(value)
        .replace(/\b(recent results|upcoming fixtures|fixtures|results)\b/ig, "")
        .replace(/\s+/g, " ")
        .trim();
    return text;
}

function normalizedText(value) {
    return stringValue(value)
        .toLowerCase()
        .replace(/&/g, "and")
        .replace(/[^a-z0-9]+/g, " ")
        .replace(/\s+/g, " ")
        .trim();
}

function formatStartTime(value, options) {
    let timestamp = Number(value);
    if (!Number.isFinite(timestamp))
        timestamp = Date.parse(value);
    if (!Number.isFinite(timestamp) || timestamp <= 0)
        return "";

    const date = new Date(timestamp);
    const dateText = formatConfiguredDateValue(date, options);
    const timeText = formatConfiguredTimeValue(date, options);
    return [dateText, timeText].filter(part => part.length > 0).join(" ");
}

function formatConfiguredDateValue(date, options) {
    const format = stringValue(options && options.matchDateFormat) || "dd.MM";
    if (format === "locale-short")
        return date.toLocaleDateString();
    if (format === "locale-long")
        return date.toLocaleDateString(undefined, { dateStyle: "long" });
    return formatDateWithPattern(date, format);
}

function formatConfiguredTimeValue(date, options) {
    const format = stringValue(options && options.matchTimeFormat) || "HH:mm";
    if (format === "locale")
        return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    return formatTimeWithPattern(date, format);
}

function formatDateWithPattern(date, pattern) {
    const monthShort = date.toLocaleDateString(undefined, { month: "short" });
    return stringValue(pattern).replace(/yyyy|yy|MMM|MM|M|dd|d/g, token => {
        switch (token) {
        case "yyyy": return String(date.getFullYear());
        case "yy": return String(date.getFullYear()).slice(-2);
        case "MMM": return monthShort;
        case "MM": return pad(date.getMonth() + 1);
        case "M": return String(date.getMonth() + 1);
        case "dd": return pad(date.getDate());
        case "d": return String(date.getDate());
        default: return token;
        }
    });
}

function formatTimeWithPattern(date, pattern) {
    const hours24 = date.getHours();
    const hours12 = ((hours24 + 11) % 12) + 1;
    const ampm = hours24 >= 12 ? "PM" : "AM";
    return stringValue(pattern).replace(/HH|H|hh|h|mm|ss|AP|ap/g, token => {
        switch (token) {
        case "HH": return pad(hours24);
        case "H": return String(hours24);
        case "hh": return pad(hours12);
        case "h": return String(hours12);
        case "mm": return pad(date.getMinutes());
        case "ss": return pad(date.getSeconds());
        case "AP": return ampm;
        case "ap": return ampm.toLowerCase();
        default: return token;
        }
    });
}

function pad(value) {
    const text = String(Math.max(0, Number(value) || 0));
    return text.length >= 2 ? text : "0" + text;
}

function normalizedSport(value) {
    const sport = stringValue(value)
        .toLowerCase()
        .replace(/&/g, "and")
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "");
    return sport === "soccer" ? "football" : sport;
}

function normalizedTeamName(value) {
    return stringValue(value)
        .toLowerCase()
        .replace(/&/g, "and")
        .replace(/[^a-z0-9]+/g, " ")
        .replace(/\b(fc|sc|cf|afc|club)\b/g, "")
        .replace(/\s+/g, " ")
        .trim();
}

function finish(callback, value) {
    if (typeof callback === "function")
        callback(value);
}

function arrayValue(value) {
    return Array.isArray(value) ? value : [];
}

function numberValue(value) {
    if (value === undefined || value === null)
        return 0;
    const normalized = String(value).replace(/[^\d.-]/g, "");
    const number = Number(normalized);
    return Number.isFinite(number) ? number : 0;
}

function escapeRegExp(value) {
    return String(value || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function stringValue(value) {
    if (value === undefined || value === null)
        return "";

    return String(value).trim();
}
