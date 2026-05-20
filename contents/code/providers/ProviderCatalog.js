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
    return labels[String(leagueCode || "").trim().toUpperCase()] || "";
}

function favoriteTeamOptions(leagueCode) {
    const teams = {
        "english-premier-league": ["Arsenal", "Manchester City", "Manchester United", "Liverpool", "Chelsea", "Tottenham", "Newcastle", "Aston Villa", "Brighton Hove", "Everton", "West Ham", "Crystal Palace", "Fulham", "Brentford", "Bournemouth", "Nottingham", "Leeds United", "Sunderland", "Burnley", "Wolverhampton"],
        "spanish-la-liga": ["Barcelona", "Real Madrid", "Atletico Madrid", "Girona", "Villarreal", "Real Betis", "Sevilla", "Athletic Bilbao", "Real Sociedad", "Valencia"],
        "italian-serie-a": ["Inter Milan", "AC Milan", "Juventus", "Napoli", "AS Roma", "Lazio", "Atalanta", "Bologna", "Fiorentina", "Torino"],
        "bundesliga": ["Bayern Munich", "Borussia Dortmund", "Bayer Leverkusen", "RB Leipzig", "Eintracht Frankfurt", "Stuttgart", "Wolfsburg", "Freiburg"],
        "french-ligue-1": ["Paris Saint-Germain", "Marseille", "Lyon", "Monaco", "Lille", "Lens", "Nice", "Rennes"],
        "netherlands-eredivisie": ["Ajax", "PSV", "Feyenoord", "AZ", "Twente", "Utrecht"],
        "portuguese-primera-liga": ["Benfica", "Porto", "Sporting CP", "Braga", "Vitoria SC"],
        "brazilian-serie-a": ["Flamengo", "Palmeiras", "Sao Paulo", "Corinthians", "Santos", "Botafogo"],
        "bulgarian-first-league": ["Levski Sofia", "Ludogorets Razgrad", "CSKA Sofia", "CSKA 1948", "Lokomotiv Plovdiv", "Botev Plovdiv", "Cherno More Varna", "Slavia Sofia", "Arda Kardzhali", "Beroe", "Lokomotiv Sofia", "Septemvri Sofia", "Spartak Varna"],
        "bulgarian-cup": ["Levski Sofia", "Ludogorets Razgrad", "CSKA Sofia", "CSKA 1948", "Lokomotiv Plovdiv", "Botev Plovdiv", "Cherno More Varna", "Slavia Sofia", "Arda Kardzhali", "Beroe"],
        "uefa-champions-league": ["Arsenal", "Manchester City", "Real Madrid", "Barcelona", "Bayern Munich", "Paris Saint-Germain", "Inter Milan", "Borussia Dortmund"],
        "NBA": ["Boston Celtics", "Los Angeles Lakers", "Golden State Warriors", "New York Knicks", "Chicago Bulls", "Dallas Mavericks", "Denver Nuggets", "Miami Heat"],
        "NFL": ["Kansas City Chiefs", "Buffalo Bills", "Philadelphia Eagles", "San Francisco 49ers", "Dallas Cowboys", "Baltimore Ravens"],
        "MLB": ["New York Yankees", "Los Angeles Dodgers", "Boston Red Sox", "Chicago Cubs", "Atlanta Braves", "Houston Astros"],
        "NHL": ["New York Rangers", "Boston Bruins", "Toronto Maple Leafs", "Colorado Avalanche", "Edmonton Oilers", "Vegas Golden Knights"]
    };
    const values = teams[sportScoreSlug(leagueCode)] || teams[String(leagueCode || "").trim().toUpperCase()] || [];
    const model = [{ label: "No favorite team", value: "" }];
    values.forEach(team => {
        model.push({ label: team, value: team });
    });
    return model;
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
    const league = String(options.league || "PL").trim().toUpperCase();

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

    if (/^\d+$/.test(raw))
        return "Round " + raw;

    return raw;
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
        "EC": "uefa-european-championship",
        "ELC": "english-football-league-championship",
        "FL1": "french-ligue-1",
        "PD": "spanish-la-liga",
        "PL": "english-premier-league",
        "PPL": "portuguese-primera-liga",
        "SA": "italian-serie-a",
        "WC": "fifa-world-cup"
    };
    return slugs[normalized] || raw.toLowerCase();
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
