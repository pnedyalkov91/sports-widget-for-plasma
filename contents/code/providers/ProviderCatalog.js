/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library

function isProvider(provider) {
    return ["apisports", "thesportsdb", "football-data", "highlightly", "openligadb", "balldontlie"].indexOf(provider) >= 0;
}

function providerOptions() {
    return [
        { label: "Auto (no API key)", value: "auto" },
        { label: "SportSRC (no API key)", value: "sportsrc" },
        { label: "ESPN (no API key)", value: "espn" },
        { label: "OpenLigaDB (no API key)", value: "openligadb" },
        { label: "TheSportsDB (free key 123)", value: "thesportsdb" },
        { label: "API-SPORTS", value: "apisports" },
        { label: "football-data.org", value: "football-data" },
        { label: "Highlightly", value: "highlightly" },
        { label: "balldontlie", value: "balldontlie" },
        { label: "SportDB.dev", value: "sportdb" }
    ];
}

function displayName(provider) {
    const names = {
        "apisports": "API-SPORTS",
        "thesportsdb": "TheSportsDB",
        "football-data": "football-data.org",
        "highlightly": "Highlightly",
        "openligadb": "OpenLigaDB",
        "balldontlie": "balldontlie"
    };
    return names[provider] || provider;
}

function sportOptions(provider) {
    const football = { label: "Football", value: "football" };
    const options = {
        "apisports": [football],
        "football-data": [football],
        "openligadb": [football],
        "thesportsdb": [football],
        "balldontlie": [{ label: "Basketball", value: "basketball" }],
        "auto": [
            football,
            { label: "Basketball", value: "basketball" },
            { label: "American football", value: "american-football" },
            { label: "Baseball", value: "baseball" },
            { label: "Tennis", value: "tennis" },
            { label: "Hockey", value: "hockey" },
            { label: "Snooker", value: "snooker" }
        ],
        "espn": [
            football,
            { label: "Basketball", value: "basketball" },
            { label: "American football", value: "american-football" },
            { label: "Baseball", value: "baseball" },
            { label: "Tennis", value: "tennis" },
            { label: "Hockey", value: "hockey" }
        ],
        "highlightly": [
            football,
            { label: "Basketball", value: "basketball" },
            { label: "American football", value: "american-football" },
            { label: "Baseball", value: "baseball" },
            { label: "Tennis", value: "tennis" },
            { label: "Hockey", value: "hockey" },
            { label: "Snooker", value: "snooker" },
            { label: "Volleyball", value: "volleyball" }
        ],
        "sportsrc": [
            football,
            { label: "Basketball", value: "basketball" },
            { label: "Tennis", value: "tennis" },
            { label: "Hockey", value: "hockey" },
            { label: "Snooker", value: "snooker" }
        ],
        "sportdb": [
            football,
            { label: "Basketball", value: "basketball" },
            { label: "American football", value: "american-football" },
            { label: "Baseball", value: "baseball" },
            { label: "Tennis", value: "tennis" },
            { label: "Hockey", value: "hockey" },
            { label: "Snooker", value: "snooker" },
            { label: "Volleyball", value: "volleyball" }
        ]
    };
    return options[provider] || options.sportsrc;
}

function leagueOptions(provider, sport) {
    if (sport === "basketball") {
        return [{ label: "NBA", value: "NBA" }];
    }

    if (sport === "american-football") {
        return [{ label: "NFL", value: "NFL" }];
    }

    if (sport === "baseball") {
        return [{ label: "MLB", value: "MLB" }];
    }

    if (sport === "hockey") {
        return [{ label: "NHL", value: "NHL" }];
    }

    if (sport === "tennis") {
        return [{ label: "ATP/WTA", value: "TENNIS" }];
    }

    if (sport === "snooker") {
        return [{ label: "World Snooker Tour", value: "SNOOKER" }];
    }

    if (provider === "openligadb") {
        return [
            { label: "Bundesliga", value: "BL1" },
            { label: "2. Bundesliga", value: "BL2" },
            { label: "3. Liga", value: "BL3" },
            { label: "DFB-Pokal", value: "DFB" }
        ];
    }

    const football = [
        { label: "Premier League", value: "PL" },
        { label: "UEFA Champions League", value: "CL" },
        { label: "La Liga", value: "PD" },
        { label: "Serie A", value: "SA" },
        { label: "Bundesliga", value: "BL1" },
        { label: "Ligue 1", value: "FL1" },
        { label: "Eredivisie", value: "DED" },
        { label: "Championship", value: "ELC" },
        { label: "Primeira Liga", value: "PPL" },
        { label: "Brasileirao Serie A", value: "BSA" },
        { label: "World Cup", value: "WC" },
        { label: "European Championship", value: "EC" }
    ];

    if (provider === "football-data") {
        return football.filter(item => ["PL", "CL", "PD", "SA", "BL1", "FL1", "DED", "ELC", "PPL", "BSA", "WC", "EC"].indexOf(item.value) >= 0);
    }

    return football;
}

function favoriteTeamOptions(leagueCode) {
    const teams = {
        "PL": ["Arsenal", "Manchester City", "Manchester United", "Liverpool", "Chelsea", "Tottenham", "Newcastle", "Aston Villa", "Brighton Hove", "Everton", "West Ham", "Crystal Palace", "Fulham", "Brentford", "Bournemouth", "Nottingham", "Leeds United", "Sunderland", "Burnley", "Wolverhampton"],
        "PD": ["Barcelona", "Real Madrid", "Atletico Madrid", "Girona", "Villarreal", "Real Betis", "Sevilla", "Athletic Bilbao", "Real Sociedad", "Valencia"],
        "SA": ["Inter Milan", "AC Milan", "Juventus", "Napoli", "AS Roma", "Lazio", "Atalanta", "Bologna", "Fiorentina", "Torino"],
        "BL1": ["Bayern Munich", "Borussia Dortmund", "Bayer Leverkusen", "RB Leipzig", "Eintracht Frankfurt", "Stuttgart", "Wolfsburg", "Freiburg"],
        "FL1": ["Paris Saint-Germain", "Marseille", "Lyon", "Monaco", "Lille", "Lens", "Nice", "Rennes"],
        "DED": ["Ajax", "PSV", "Feyenoord", "AZ", "Twente", "Utrecht"],
        "PPL": ["Benfica", "Porto", "Sporting CP", "Braga", "Vitoria SC"],
        "BSA": ["Flamengo", "Palmeiras", "Sao Paulo", "Corinthians", "Santos", "Botafogo"],
        "CL": ["Arsenal", "Manchester City", "Real Madrid", "Barcelona", "Bayern Munich", "Paris Saint-Germain", "Inter Milan", "Borussia Dortmund"],
        "NBA": ["Boston Celtics", "Los Angeles Lakers", "Golden State Warriors", "New York Knicks", "Chicago Bulls", "Dallas Mavericks", "Denver Nuggets", "Miami Heat"],
        "NFL": ["Kansas City Chiefs", "Buffalo Bills", "Philadelphia Eagles", "San Francisco 49ers", "Dallas Cowboys", "Baltimore Ravens"],
        "MLB": ["New York Yankees", "Los Angeles Dodgers", "Boston Red Sox", "Chicago Cubs", "Atlanta Braves", "Houston Astros"],
        "NHL": ["New York Rangers", "Boston Bruins", "Toronto Maple Leafs", "Colorado Avalanche", "Edmonton Oilers", "Vegas Golden Knights"]
    };
    const values = teams[leagueCode] || [];
    const model = [{ label: "No favorite team", value: "" }];
    values.forEach(team => {
        model.push({ label: team, value: team });
    });
    return model;
}

function requiresApiKey(provider) {
    return ["apisports", "football-data", "highlightly", "balldontlie"].indexOf(provider) >= 0;
}

function defaultBaseUrl(provider) {
    const urls = {
        "apisports": "https://v3.football.api-sports.io",
        "thesportsdb": "https://www.thesportsdb.com/api/v1/json",
        "football-data": "https://api.football-data.org/v4",
        "highlightly": "https://sports.highlightly.net",
        "openligadb": "https://www.openligadb.de/api",
        "balldontlie": "https://api.balldontlie.io/v1"
    };
    return urls[provider] || "";
}

function headers(provider, apiKey, baseUrl) {
    const key = String(apiKey || "").trim();
    const result = {};
    if (provider === "apisports") {
        result["x-apisports-key"] = key;
    } else if (provider === "football-data") {
        result["X-Auth-Token"] = key;
    } else if (provider === "highlightly") {
        result["x-rapidapi-key"] = key;
        if (String(baseUrl || "").indexOf("rapidapi.com") >= 0) {
            result["x-rapidapi-host"] = "sport-highlights-api.p.rapidapi.com";
        }
    } else if (provider === "balldontlie") {
        result["Authorization"] = key;
    }
    return result;
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
    const league = String(options.league || "PL").trim().toUpperCase();
    const season = seasonYear();
    const today = formatDate(new Date());
    const weekAgo = offsetDate(-7);
    const weekAhead = offsetDate(7);

    if (provider === "apisports") {
        const leagueId = apiSportsLeagueId(league);
        if (sport !== "football" && sport !== "soccer")
            return [];

        if (type === "live")
            return [{ url: `${baseUrl}/fixtures?live=all`, sport: "football" }];
        if (type === "table")
            return leagueId > 0 ? [{ url: `${baseUrl}/standings?league=${leagueId}&season=${season}`, sport: "football" }] : [];
        return leagueId > 0 ? [{ url: `${baseUrl}/fixtures?league=${leagueId}&season=${season}&from=${weekAgo}&to=${weekAhead}`, sport: "football" }] : [];
    }

    if (provider === "football-data") {
        if (sport !== "football" && sport !== "soccer")
            return [];

        if (type === "table")
            return [{ url: `${baseUrl}/competitions/${encodeURIComponent(league)}/standings`, sport: "football" }];
        return [{ url: `${baseUrl}/matches?competitions=${encodeURIComponent(league)}&dateFrom=${weekAgo}&dateTo=${weekAhead}`, sport: "football" }];
    }

    if (provider === "thesportsdb") {
        const key = encodeURIComponent(String(options.apiKey || "").trim() || "123");
        const leagueId = theSportsDbLeagueId(league);
        if (leagueId.length === 0 || (sport !== "football" && sport !== "soccer"))
            return [];

        if (type === "table")
            return [{ url: `${baseUrl}/${key}/lookuptable.php?l=${leagueId}&s=${theSportsDbSeason()}`, sport: "football" }];
        return [
            { url: `${baseUrl}/${key}/eventsnextleague.php?id=${leagueId}`, sport: "football" },
            { url: `${baseUrl}/${key}/eventspastleague.php?id=${leagueId}`, sport: "football" }
        ];
    }

    if (provider === "highlightly") {
        const path = highlightlySportPath(sport);
        if (path.length === 0)
            return [];

        if (type === "table")
            return [{ url: `${baseUrl}/${path}/standings?league=${encodeURIComponent(highlightlyLeague(league))}&season=${season}`, sport }];
        return [{ url: `${baseUrl}/${path}/matches?date=${today}&timezone=Etc/UTC&limit=100`, sport }];
    }

    if (provider === "openligadb") {
        const shortcut = openLigaShortcut(league);
        if (shortcut.length === 0 || (sport !== "football" && sport !== "soccer"))
            return [];

        if (type === "table")
            return [{ url: `${baseUrl}/getbltable/${shortcut}/${season}`, sport: "football" }];
        return [{ url: `${baseUrl}/getmatchdata/${shortcut}/${season}`, sport: "football" }];
    }

    if (provider === "balldontlie") {
        if (sport !== "basketball")
            return [];

        if (type === "table")
            return [{ url: `${baseUrl}/standings?season=${season}`, sport: "basketball" }];
        return [{ url: `${baseUrl}/games?dates[]=${today}`, sport: "basketball" }];
    }

    return [];
}

function normalizeMatches(provider, payload, sport) {
    if (provider === "apisports")
        return apiSportsItems(payload).map(normalizeApiSportsMatch).filter(hasTeams);
    if (provider === "football-data")
        return arrayValue(payload && payload.matches).map(normalizeFootballDataMatch).filter(hasTeams);
    if (provider === "thesportsdb")
        return arrayValue(payload && payload.events).map(match => normalizeTheSportsDbMatch(match, sport)).filter(hasTeams);
    if (provider === "highlightly")
        return highlightlyItems(payload).map(match => normalizeHighlightlyMatch(match, sport)).filter(hasTeams);
    if (provider === "openligadb")
        return arrayValue(payload).map(normalizeOpenLigaMatch).filter(hasTeams);
    if (provider === "balldontlie")
        return arrayValue(payload && payload.data).map(normalizeBalldontlieMatch).filter(hasTeams);
    return [];
}

function normalizeTable(provider, payload) {
    if (provider === "apisports")
        return normalizeApiSportsTable(payload);
    if (provider === "football-data")
        return normalizeFootballDataTable(payload);
    if (provider === "thesportsdb")
        return normalizeTheSportsDbTable(payload);
    if (provider === "highlightly")
        return normalizeHighlightlyTable(payload);
    if (provider === "openligadb")
        return normalizeOpenLigaTable(payload);
    if (provider === "balldontlie")
        return normalizeBalldontlieTable(payload);
    return [];
}

function normalizeFixtures(provider, payload, sport) {
    return normalizeMatches(provider, payload, sport).map(match => {
        return {
            homeTeam: match.homeTeam,
            awayTeam: match.awayTeam,
            homeScore: match.homeScore,
            awayScore: match.awayScore,
            status: match.status,
            startTime: match.startTime,
            timestamp: match.timestamp,
            matchday: match.matchday || "",
            homeBadge: match.homeBadge,
            awayBadge: match.awayBadge
        };
    });
}

function normalizeApiSportsMatch(item) {
    const fixture = item.fixture || {};
    const status = fixture.status || {};
    const teams = item.teams || {};
    const goals = item.goals || {};
    return {
        id: stringValue(fixture.id),
        sport: "football",
        league: stringValue(item.league && (item.league.name || item.league.round)),
        homeTeam: stringValue(teams.home && teams.home.name),
        awayTeam: stringValue(teams.away && teams.away.name),
        homeScore: stringValue(goals.home),
        awayScore: stringValue(goals.away),
        status: statusLabel(status.short || status.long),
        minute: status.elapsed ? `${status.elapsed}'` : "",
        startTime: formatMaybeDate(fixture.date),
        timestamp: Date.parse(fixture.date || "") || 0,
        homeBadge: stringValue(teams.home && teams.home.logo),
        awayBadge: stringValue(teams.away && teams.away.logo),
        popular: false
    };
}

function normalizeFootballDataMatch(match) {
    const score = match.score || {};
    const fullTime = score.fullTime || {};
    return {
        id: stringValue(match.id),
        sport: "football",
        league: stringValue(match.competition && match.competition.name),
        homeTeam: stringValue(match.homeTeam && match.homeTeam.name),
        awayTeam: stringValue(match.awayTeam && match.awayTeam.name),
        homeScore: stringValue(fullTime.home ?? fullTime.homeTeam),
        awayScore: stringValue(fullTime.away ?? fullTime.awayTeam),
        status: statusLabel(match.status),
        minute: stringValue(match.minute),
        startTime: formatMaybeDate(match.utcDate),
        timestamp: Date.parse(match.utcDate || "") || 0,
        homeBadge: stringValue(match.homeTeam && match.homeTeam.crest),
        awayBadge: stringValue(match.awayTeam && match.awayTeam.crest),
        matchday: match.matchday ? `MD ${match.matchday}` : "",
        popular: false
    };
}

function normalizeTheSportsDbMatch(match, sport) {
    const timestamp = Date.parse(`${match.dateEvent || ""}T${match.strTime || "00:00:00"}Z`);
    return {
        id: stringValue(match.idEvent),
        sport: sport || "football",
        league: stringValue(match.strLeague),
        homeTeam: stringValue(match.strHomeTeam),
        awayTeam: stringValue(match.strAwayTeam),
        homeScore: stringValue(match.intHomeScore),
        awayScore: stringValue(match.intAwayScore),
        status: statusLabel(match.strStatus || match.strProgress),
        minute: stringValue(match.strProgress),
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : stringValue(match.dateEvent),
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        homeBadge: stringValue(match.strHomeTeamBadge),
        awayBadge: stringValue(match.strAwayTeamBadge),
        poster: stringValue(match.strThumb),
        matchday: match.intRound ? `MD ${match.intRound}` : "",
        popular: false
    };
}

function normalizeHighlightlyMatch(match, sport) {
    const home = match.homeTeam || match.home || {};
    const away = match.awayTeam || match.away || {};
    const state = match.state || match.status || {};
    const score = state.score || match.score || {};
    const timestamp = Date.parse(match.date || match.startTime || "");
    return {
        id: stringValue(match.id),
        sport: sport || stringValue(match.sport),
        league: stringValue((match.league && (match.league.name || match.league)) || match.competition),
        homeTeam: teamLabel(home),
        awayTeam: teamLabel(away),
        homeScore: stringValue(score.home ?? score.homeTeam ?? match.homeScore),
        awayScore: stringValue(score.away ?? score.awayTeam ?? match.awayScore),
        status: statusLabel(state.description || state.status || state.name || match.status),
        minute: stringValue(state.minute || state.clock),
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        homeBadge: logoValue(home),
        awayBadge: logoValue(away),
        popular: false
    };
}

function normalizeOpenLigaMatch(match) {
    const result = openLigaResult(match);
    const timestamp = Date.parse(match.matchDateTimeUTC || match.matchDateTime || "");
    return {
        id: stringValue(match.matchID),
        sport: "football",
        league: stringValue(match.leagueName || match.leagueShortcut),
        homeTeam: stringValue(match.team1 && match.team1.teamName),
        awayTeam: stringValue(match.team2 && match.team2.teamName),
        homeScore: stringValue(result.home),
        awayScore: stringValue(result.away),
        status: match.matchIsFinished ? "Finished" : statusFromTimestamp(timestamp),
        minute: "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        homeBadge: stringValue(match.team1 && match.team1.teamIconUrl),
        awayBadge: stringValue(match.team2 && match.team2.teamIconUrl),
        matchday: match.group && match.group.groupName ? stringValue(match.group.groupName) : "",
        popular: false
    };
}

function normalizeBalldontlieMatch(match) {
    const timestamp = Date.parse(match.datetime || match.date || "");
    return {
        id: stringValue(match.id),
        sport: "basketball",
        league: "NBA",
        homeTeam: teamLabel(match.home_team),
        awayTeam: teamLabel(match.visitor_team || match.away_team),
        homeScore: stringValue(match.home_team_score),
        awayScore: stringValue(match.visitor_team_score ?? match.away_team_score),
        status: statusLabel(match.status),
        minute: stringValue(match.time),
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        homeBadge: "",
        awayBadge: "",
        popular: false
    };
}

function normalizeApiSportsTable(payload) {
    const response = apiSportsItems(payload);
    const standings = response.length > 0 && response[0].league ? response[0].league.standings : [];
    const table = Array.isArray(standings) && standings.length > 0 ? standings[0] : [];
    return table.map(row => ({
        position: numberValue(row.rank),
        team: stringValue(row.team && row.team.name),
        played: numberValue(row.all && row.all.played),
        won: numberValue(row.all && row.all.win),
        draw: numberValue(row.all && row.all.draw),
        lost: numberValue(row.all && row.all.lose),
        goalsFor: numberValue(row.all && row.all.goals && row.all.goals.for),
        goalsAgainst: numberValue(row.all && row.all.goals && row.all.goals.against),
        points: numberValue(row.points),
        goalDifference: numberValue(row.goalsDiff),
        form: stringValue(row.form),
        crest: stringValue(row.team && row.team.logo)
    })).filter(row => row.team.length > 0);
}

function normalizeFootballDataTable(payload) {
    const standings = arrayValue(payload && payload.standings);
    const total = standings.find(row => row.type === "TOTAL") || standings[0] || {};
    return arrayValue(total.table).map(row => ({
        position: numberValue(row.position),
        team: stringValue(row.team && (row.team.shortName || row.team.name)),
        played: numberValue(row.playedGames),
        won: numberValue(row.won),
        draw: numberValue(row.draw),
        lost: numberValue(row.lost),
        goalsFor: numberValue(row.goalsFor),
        goalsAgainst: numberValue(row.goalsAgainst),
        points: numberValue(row.points),
        goalDifference: numberValue(row.goalDifference),
        form: stringValue(row.form),
        crest: stringValue(row.team && row.team.crest)
    })).filter(row => row.team.length > 0);
}

function normalizeTheSportsDbTable(payload) {
    return arrayValue(payload && payload.table).map(row => ({
        position: numberValue(row.intRank),
        team: stringValue(row.strTeam),
        played: numberValue(row.intPlayed),
        won: numberValue(row.intWin),
        draw: numberValue(row.intDraw),
        lost: numberValue(row.intLoss),
        goalsFor: numberValue(row.intGoalsFor),
        goalsAgainst: numberValue(row.intGoalsAgainst),
        points: numberValue(row.intPoints),
        goalDifference: numberValue(row.intGoalDifference),
        form: stringValue(row.strForm),
        crest: stringValue(row.strTeamBadge || row.strBadge)
    })).filter(row => row.team.length > 0);
}

function normalizeHighlightlyTable(payload) {
    const rows = highlightlyItems(payload);
    return rows.map((row, index) => {
        const team = row.team || {};
        const stats = row.stats || row;
        return {
            position: numberValue(row.position || row.rank || index + 1),
            team: teamLabel(team) || stringValue(row.teamName),
            played: numberValue(stats.played || stats.gamesPlayed),
            won: numberValue(stats.won || stats.wins),
            draw: numberValue(stats.draw || stats.ties),
            lost: numberValue(stats.lost || stats.losses),
            goalsFor: numberValue(stats.goalsFor || stats.pointsFor),
            goalsAgainst: numberValue(stats.goalsAgainst || stats.pointsAgainst),
            points: numberValue(stats.points),
            goalDifference: numberValue(stats.goalDifference || stats.goalsDiff),
            form: stringValue(row.form || stats.form),
            crest: logoValue(team)
        };
    }).filter(row => row.team.length > 0);
}

function normalizeOpenLigaTable(payload) {
    return arrayValue(payload).map(row => ({
        position: numberValue(row.place),
        team: stringValue(row.teamName || row.shortName),
        played: numberValue(row.matches),
        won: numberValue(row.won),
        draw: numberValue(row.draw),
        lost: numberValue(row.lost),
        goalsFor: numberValue(row.goals),
        goalsAgainst: numberValue(row.opponentGoals),
        points: numberValue(row.points),
        goalDifference: numberValue(row.goalDiff),
        form: stringValue(row.form),
        crest: stringValue(row.teamIconUrl)
    })).filter(row => row.team.length > 0);
}

function normalizeBalldontlieTable(payload) {
    return arrayValue(payload && payload.data).map((row, index) => {
        const team = row.team || {};
        return {
            position: numberValue(row.conference_rank || row.rank || index + 1),
            team: teamLabel(team),
            played: numberValue(row.wins) + numberValue(row.losses),
            won: numberValue(row.wins),
            draw: 0,
            lost: numberValue(row.losses),
            goalsFor: 0,
            goalsAgainst: 0,
            points: numberValue(row.wins),
            goalDifference: 0,
            form: stringValue(row.form),
            crest: ""
        };
    }).filter(row => row.team.length > 0);
}

function apiSportsItems(payload) {
    return arrayValue(payload && payload.response);
}

function highlightlyItems(payload) {
    if (Array.isArray(payload))
        return payload;
    if (Array.isArray(payload && payload.data))
        return payload.data;
    if (Array.isArray(payload && payload.matches))
        return payload.matches;
    if (Array.isArray(payload && payload.standings))
        return payload.standings;
    return [];
}

function openLigaResult(match) {
    const results = arrayValue(match && match.matchResults);
    const finalResult = results.find(result => result.resultTypeID === 2) || results[results.length - 1] || {};
    return {
        home: finalResult.pointsTeam1,
        away: finalResult.pointsTeam2
    };
}

function hasTeams(match) {
    return match.homeTeam && match.awayTeam;
}

function statusLabel(value) {
    const status = stringValue(value).toUpperCase();
    if (status.indexOf("LIVE") >= 0 || status.indexOf("IN_PLAY") >= 0 || status.indexOf("1H") >= 0 || status.indexOf("2H") >= 0)
        return "Live";
    if (status.indexOf("FINISH") >= 0 || status.indexOf("FT") >= 0 || status.indexOf("AET") >= 0)
        return "Finished";
    if (status.indexOf("SCHEDULE") >= 0 || status.indexOf("TIMED") >= 0 || status.indexOf("NOT_STARTED") >= 0)
        return "Upcoming";
    return stringValue(value || "Upcoming");
}

function statusFromTimestamp(timestamp) {
    if (!Number.isFinite(timestamp) || timestamp <= 0)
        return "Upcoming";
    const now = Date.now();
    if (now >= timestamp && now <= timestamp + 3 * 60 * 60 * 1000)
        return "Live";
    if (now > timestamp)
        return "Finished";
    return "Upcoming";
}

function firstSport(value) {
    const sports = Array.isArray(value) ? value : String(value || "").split(",");
    return String(sports[0] || "football").trim().toLowerCase();
}

function teamLabel(team) {
    if (!team)
        return "";
    if (typeof team === "string")
        return team;
    return stringValue(team.displayName || team.name || team.full_name || team.shortName || team.abbreviation);
}

function logoValue(team) {
    if (!team || typeof team !== "object")
        return "";
    return stringValue(team.logo || team.crest || team.badge || team.image);
}

function apiSportsLeagueId(code) {
    const ids = { "BL1": 78, "BSA": 71, "CL": 2, "DED": 88, "EC": 4, "ELC": 40, "FL1": 61, "PD": 140, "PL": 39, "PPL": 94, "SA": 135, "WC": 1 };
    return ids[code] || 0;
}

function theSportsDbLeagueId(code) {
    const ids = { "BL1": "4331", "CL": "4480", "DED": "4337", "ELC": "4329", "FL1": "4334", "PD": "4335", "PL": "4328", "PPL": "4344", "SA": "4332", "WC": "4429" };
    return ids[code] || "";
}

function highlightlyLeague(code) {
    const names = { "BL1": "Bundesliga", "BSA": "Brasileirao Serie A", "CL": "UEFA Champions League", "DED": "Eredivisie", "EC": "UEFA European Championship", "ELC": "Championship", "FL1": "Ligue 1", "PD": "LaLiga", "PL": "Premier League", "PPL": "Primeira Liga", "SA": "Serie A", "WC": "FIFA World Cup" };
    return names[code] || "Premier League";
}

function openLigaShortcut(code) {
    const shortcuts = { "BL1": "bl1", "BL2": "bl2", "BL3": "bl3", "DFB": "dfb" };
    return shortcuts[code] || (code === "PL" ? "" : "");
}

function highlightlySportPath(sport) {
    const paths = {
        "american-football": "american-football",
        "baseball": "baseball",
        "basketball": "basketball",
        "football": "football",
        "hockey": "hockey",
        "tennis": "tennis",
        "snooker": "snooker",
        "volleyball": "volleyball"
    };
    return paths[sport] || "";
}

function theSportsDbSeason() {
    const year = seasonYear();
    return `${year}-${year + 1}`;
}

function seasonYear() {
    const now = new Date();
    return now.getMonth() < 6 ? now.getFullYear() - 1 : now.getFullYear();
}

function offsetDate(offset) {
    const date = new Date();
    date.setDate(date.getDate() + offset);
    return formatDate(date);
}

function formatDate(date) {
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function formatMaybeDate(value) {
    const timestamp = Date.parse(value || "");
    return Number.isFinite(timestamp) ? formatStartTime(timestamp) : "";
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
