/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library
.import "SportScoreLeagues.js" as SportScoreLeagues

function isProvider(provider) {
    return provider === "sportscore";
}

function providerOptions() {
    return [
        { label: "SportScore (no API key)", value: "sportscore" }
    ];
}

function displayName(provider) {
    const names = {
        "sportscore": "SportScore"
    };
    return names[provider] || provider;
}

function sportOptions(provider) {
    const football = { label: "Football", value: "football" };
    const basketball = { label: "Basketball", value: "basketball" };
    const cricket = { label: "Cricket", value: "cricket" };
    const tennis = { label: "Tennis", value: "tennis" };
    return [football, basketball, cricket, tennis];
}

function countryOptions(provider, sport) {
    if (sport === "football" || sport === "soccer")
        return SportScoreLeagues.countryOptions();

    return [{ label: "All countries", value: "all" }];
}

function defaultCountry(provider, sport) {
    if (sport === "football" || sport === "soccer")
        return "england";

    return "all";
}

function leagueOptions(provider, sport, country) {
    if (sport === "basketball") {
        return [{ label: "All basketball", value: "BASKETBALL" }];
    }

    if (sport === "cricket") {
        return [{ label: "All cricket", value: "CRICKET" }];
    }

    if (sport === "tennis") {
        return [{ label: "All tennis", value: "TENNIS" }];
    }

    return SportScoreLeagues.leagueOptions(country || defaultCountry(provider, sport));
}

function resolveFootballLeagueCode(countryCode, labelOrCode) {
    const direct = sportScoreSlug(labelOrCode);
    if (SportScoreLeagues.leagueLabel(direct).length > 0)
        return direct;

    const wanted = normalizeLeagueText(labelOrCode);
    if (wanted.length === 0)
        return direct;

    const country = String(countryCode || "").trim().toLowerCase();
    const countryCandidates = country.length > 0 ? [country] : [];
    if (countryCandidates.indexOf("world") < 0)
        countryCandidates.push("world");

    let best = "";
    let bestScore = 0;
    countryCandidates.forEach(code => {
        const options = SportScoreLeagues.leagueOptions(code);
        options.forEach(option => {
            const normalized = normalizeLeagueText(option.label);
            let score = leagueLabelMatchScore(wanted, normalized);
            if (score <= 0)
                return;

            // Prefer the explicitly selected country over world/other buckets.
            if (code === country)
                score += 3;

            if (score > bestScore) {
                bestScore = score;
                best = String(option.value || "").trim();
            }
        });
    });

    return best.length > 0 ? best : direct;
}

function leagueLabel(leagueCode) {
    const mapped = sportScoreSlug(leagueCode);
    const generated = SportScoreLeagues.leagueLabel(mapped);
    if (generated.length > 0)
        return generated;

    const labels = {
        "BASKETBALL": "All basketball",
        "CRICKET": "All cricket",
        "TENNIS": "All tennis"
    };
    const explicit = labels[String(leagueCode || "").trim().toUpperCase()];
    if (explicit)
        return explicit;

    if (mapped.length === 0)
        return "";

    return mapped.split("-")
        .map(part => part.length > 0 ? part.charAt(0).toUpperCase() + part.slice(1) : "")
        .join(" ")
        .trim();
}

function countryLabel(countryCode) {
    return SportScoreLeagues.countryLabel(countryCode);
}

function countryCodeForLeague(leagueCode) {
    return SportScoreLeagues.leagueCountryCode(sportScoreSlug(leagueCode));
}

function hasKnownFootballLeague(leagueCode) {
    return SportScoreLeagues.leagueLabel(sportScoreSlug(leagueCode)).length > 0;
}

function normalizeLeagueText(value) {
    return String(value || "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, " ")
        .trim();
}

function leagueLabelMatchScore(left, right) {
    if (left.length === 0 || right.length === 0)
        return 0;

    if (left === right)
        return 10;

    if (left.indexOf(right) >= 0 || right.indexOf(left) >= 0)
        return 8;

    const leftTokens = left.split(" ").filter(Boolean);
    const rightTokens = right.split(" ").filter(Boolean);
    if (leftTokens.length === 0 || rightTokens.length === 0)
        return 0;

    let shared = 0;
    leftTokens.forEach(token => {
        if (rightTokens.indexOf(token) >= 0)
            shared += 1;
    });
    if (shared === 0)
        return 0;

    const ratio = shared / Math.max(leftTokens.length, rightTokens.length);
    if (ratio >= 0.8)
        return 6;
    if (ratio >= 0.6)
        return 4;
    if (ratio >= 0.5)
        return 2;
    return 0;
}

function favoriteTeamOptions(leagueCode) {
    const model = [{ label: "No favorite team", value: "" }];
    return model;
}

function countryTeamOptions(provider, sport, countryCode) {
    return [];
}

function requiresApiKey(provider) {
    return false;
}

function defaultBaseUrl(provider) {
    const urls = {
        "sportscore": "https://sportscore.com/api/widget"
    };
    return urls[provider] || "";
}

function headers(provider, apiKey, baseUrl) {
    return {};
}

function liveRequests(provider, options) {
    return requestList(provider, options, "live");
}

function tableRequests(provider, options) {
    return requestList(provider, options, "table");
}

function fixtureRequests(provider, options) {
    return requestList(provider, options, "fixtures");
}

function requestList(provider, options, type) {
    const baseUrl = stripTrailingSlash(options.baseUrl || defaultBaseUrl(provider));
    const sport = firstSport(options.sports);
    const sportScoreSportValue = sportScoreSport(sport);
    const league = String(options && options.league || "").trim();

    if (provider === "sportscore") {
        const slug = sportScoreSlug(league);
        if (sportScoreSportValue.length === 0)
            return [];

        if (type === "table" && slug.length > 0 && sportScoreSportValue === "football")
            return [{ url: `${baseUrl}/standings/?sport=football&slug=${encodeURIComponent(slug)}&src=sports-widget-for-plasma`, sport: "football", optional: true }];

        if (type === "live" || type === "fixtures")
            return [{ url: `${baseUrl}/matches/?sport=${encodeURIComponent(sportScoreSportValue)}&limit=50&src=sports-widget-for-plasma`, sport: sportScoreSportValue }];

        return [];
    }

    return [];
}

function normalizeMatches(provider, payload, sport) {
    if (provider === "sportscore")
        return arrayValue(payload && payload.matches).map(match => normalizeSportScoreMatch(match, sport)).filter(hasTeams);
    return [];
}

function normalizeTable(provider, payload) {
    if (provider === "sportscore")
        return normalizeSportScoreTable(payload);
    return [];
}

function normalizeFixtures(provider, payload, sport) {
    return normalizeMatches(provider, payload, sport).map(match => {
        return {
            id: match.id || "",
            sport: match.sport || sport,
            league: match.league || "",
            homeTeam: match.homeTeam,
            awayTeam: match.awayTeam,
            homeScore: match.homeScore,
            awayScore: match.awayScore,
            status: match.status,
            minute: match.minute || "",
            startTime: match.startTime,
            timestamp: match.timestamp,
            matchday: match.matchday || "",
            stadium: match.stadium || "",
            homeBadge: match.homeBadge,
            awayBadge: match.awayBadge,
            poster: match.poster || "",
            popular: Boolean(match.popular)
        };
    });
}

function normalizeSportScoreMatch(match, sport) {
    const timestamp = Date.parse(match.time || match.date || "");
    return {
        id: sportScoreMatchId(match),
        sport: sport || stringValue(match.sport) || "football",
        league: stringValue(match.competition),
        homeTeam: stringValue(match.home),
        awayTeam: stringValue(match.away),
        homeScore: stringValue(match.home_score),
        awayScore: stringValue(match.away_score),
        status: statusLabel(match.status_text || match.status),
        minute: "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: sportScoreMatchday(match),
        stadium: stringValue(match.venue || match.stadium || match.ground),
        homeBadge: stringValue(match.home_logo),
        awayBadge: stringValue(match.away_logo),
        popular: false
    };
}

function sportScoreMatchId(match) {
    return stringValue(match && (match.id || match.match_id || match.slug || match.url));
}

function sportScoreMatchday(match) {
    const raw = stringValue(match && (match.round || match.round_name || match.matchday || match.match_day || match.week || match.stage));
    if (raw.length === 0)
        return "";

    return roundLabelFromText(raw);
}

function roundLabelFromText(value) {
    const text = stringValue(value).replace(/[_-]+/g, " ").replace(/\s+/g, " ").trim();
    if (text.length === 0)
        return "";

    const normalized = text.toLowerCase();
    if (normalized === "matches" || normalized.indexOf("recent results") >= 0 || normalized.indexOf("upcoming fixtures") >= 0)
        return "";

    if (/^\d+$/.test(text))
        return "Round " + text;

    if (normalized === "final")
        return "Final";
    if (normalized.indexOf("semi") >= 0)
        return "Semi-finals";
    if (normalized.indexOf("quarter") >= 0)
        return "Quarter-finals";
    if (normalized.indexOf("round of 16") >= 0 || normalized.indexOf("1/8") >= 0)
        return "Round of 16";
    if (normalized.indexOf("round of 32") >= 0 || normalized.indexOf("1/16") >= 0)
        return "Round of 32";

    return titleCaseRoundLabel(text);
}

function titleCaseRoundLabel(value) {
    return stringValue(value)
        .split(" ")
        .filter(part => part.length > 0)
        .map((part, index) => {
            const lower = part.toLowerCase();
            if (index > 0 && (lower === "of" || lower === "and" || lower === "the"))
                return lower;

            return lower.charAt(0).toUpperCase() + lower.slice(1);
        })
        .join(" ");
}

function normalizeSportScoreTable(payload) {
    let rows = [];
    const tables = arrayValue(payload && payload.tables);
    tables.forEach((table, groupIndex) => {
        const group = stringValue(table.group);
        rows = rows.concat(arrayValue(table.rows).map(row => ({
            position: numberValue(row.pos),
            team: stringValue(row.team),
            group,
            groupIndex,
            played: numberValue(row.p),
            won: numberValue(row.w),
            draw: numberValue(row.d),
            lost: numberValue(row.l),
            goalsFor: numberValue(row.gf),
            goalsAgainst: numberValue(row.ga),
            points: numberValue(row.pts),
            goalDifference: numberValue(row.gd),
            form: stringValue(row.form || row.last5),
            crest: stringValue(row.team_logo),
            teamSlug: stringValue(row.team_slug)
        })));
    });

    return rows.filter(row => row.team.length > 0)
        .sort((left, right) => left.groupIndex - right.groupIndex || left.position - right.position);
}

function hasTeams(match) {
    return match.homeTeam && match.awayTeam;
}

function statusLabel(value) {
    const status = stringValue(value).toUpperCase();
    if (status.indexOf("LIVE") >= 0 || status.indexOf("IN_PLAY") >= 0 || status.indexOf("1H") >= 0 || status.indexOf("2H") >= 0)
        return "Live";
    if (status.indexOf("FINISH") >= 0 || status === "ENDED" || status.indexOf("FT") >= 0 || status.indexOf("AET") >= 0)
        return "Finished";
    if (status.indexOf("SCHEDULE") >= 0 || status.indexOf("TIMED") >= 0 || status.indexOf("NOT_STARTED") >= 0 || status.indexOf("NOT STARTED") >= 0)
        return "Upcoming";
    return stringValue(value || "Upcoming");
}

function firstSport(value) {
    const sports = Array.isArray(value) ? value : String(value || "").split(",");
    return String(sports[0] || "football").trim().toLowerCase();
}

function sportScoreSlug(code) {
    const raw = String(code || "").trim();
    if (raw.length === 0)
        return "";

    const normalized = raw.toUpperCase();
    const slugs = {
        "BG1": "bulgarian-first-league",
        "BGC": "bulgarian-cup",
        "BL1": "bundesliga",
        "BSA": "brazilian-serie-a",
        "CL": "uefa-champions-league",
        "DED": "netherlands-eredivisie",
        "CARABAO CUP": "english-football-league-cup",
        "EC": "uefa-european-championship",
        "EFL CUP": "english-football-league-cup",
        "ELC": "english-football-league-championship",
        "ENGLISH PREMIER LEAGUE": "english-premier-league",
        "ENGLISH LEAGUE CUP": "english-football-league-cup",
        "FL1": "french-ligue-1",
        "FRENCH LIGUE 1": "french-ligue-1",
        "PARVA LIGA": "bulgarian-first-league",
        "EFBET LIGA": "bulgarian-first-league",
        "BULGARIAN FIRST LEAGUE": "bulgarian-first-league",
        "BULGARIAN FIRST PROFESSIONAL LEAGUE": "bulgarian-first-league",
        "FIRST PROFESSIONAL FOOTBALL LEAGUE": "bulgarian-first-league",
        "FIRST PROFESSIONAL LEAGUE": "bulgarian-first-league",
        "ITALIAN SERIE A": "italian-serie-a",
        "LA LIGA": "spanish-la-liga",
        "PD": "spanish-la-liga",
        "PREMIER LEAGUE": "english-premier-league",
        "PL": "english-premier-league",
        "PPL": "portuguese-primera-liga",
        "SA": "italian-serie-a",
        "SERIE A": "italian-serie-a",
        "SPANISH LA LIGA": "spanish-la-liga",
        "UEFA CONFERENCE LEAGUE": "uefa-europa-conference-league",
        "UEFA EUROPA CONFERENCE LEAGUE": "uefa-europa-conference-league",
        "WC": "fifa-world-cup"
    };
    return slugs[normalized] || raw.toLowerCase()
        .replace(/&/g, "and")
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "");
}

function sportScoreSport(sport) {
    const normalized = String(sport || "").trim().toLowerCase();
    const sports = {
        "basketball": "basketball",
        "cricket": "cricket",
        "football": "football",
        "soccer": "football",
        "tennis": "tennis"
    };
    return sports[normalized] || "";
}

function formatStartTime(timestamp) {
    const date = new Date(timestamp);
    return `${pad(date.getDate())}.${pad(date.getMonth() + 1)} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function stripTrailingSlash(value) {
    return String(value || "").replace(/\/+$/, "");
}

function arrayValue(value) {
    return Array.isArray(value) ? value : [];
}

function stringValue(value) {
    if (value === undefined || value === null)
        return "";
    return String(value);
}

function numberValue(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
}

function pad(value) {
    return value < 10 ? "0" + value : String(value);
}
