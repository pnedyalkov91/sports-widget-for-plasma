/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library
.import "providers/ProviderCatalog.js" as ProviderCatalog

const REQUEST_TIMEOUT_MS = 12000;

function fetchLiveScores(options, onSuccess, onError) {
    const sports = normalizeSports(options.sports);

    if (sports.length === 0) {
        onSuccess([]);
        return;
    }

    const provider = options.provider || "sportsrc";
    if (provider === "auto") {
        fetchAutoMatches("live", options, onSuccess, onError);
        return;
    }

    if (ProviderCatalog.isProvider(provider)) {
        fetchProviderMatches(provider, "live", options, onSuccess, onError);
        return;
    }

    if (provider === "espn") {
        fetchEspnScoreboards(options, onSuccess, onError);
        return;
    }

    const baseUrl = stripTrailingSlash(options.baseUrl || defaultBaseUrl(provider));
    const apiKey = (options.apiKey || "").trim();
    let pending = sports.length;
    let matches = [];
    let errors = [];

    sports.forEach(sport => {
        const request = new XMLHttpRequest();
        let completed = false;

        function finish(errorMessage) {
            if (completed)
                return;

            completed = true;
            if (errorMessage.length > 0) {
                errors.push(errorMessage);
            } else if (request.status >= 200 && request.status < 300) {
                try {
                    matches = matches.concat(normalizeMatches(JSON.parse(request.responseText), sport, provider));
                } catch (error) {
                    errors.push(`${sport}: ${error}`);
                }
            } else {
                errors.push(`${sport}: HTTP ${request.status}`);
            }

            pending -= 1;
            if (pending === 0) {
                if (matches.length > 0 || errors.length === 0) {
                    onSuccess(sortMatches(matches));
                } else {
                    onError(errors.join(", "));
                }
            }
        }

        request.open("GET", endpointFor(provider, baseUrl, sport));
        request.timeout = REQUEST_TIMEOUT_MS;
        request.setRequestHeader("Accept", "application/json");

        if (provider === "sportdb" && apiKey.length > 0) {
            request.setRequestHeader("X-API-Key", apiKey);
        }

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) {
                return;
            }

            finish("");
        };
        request.ontimeout = function() {
            finish(`${sport}: request timed out`);
        };
        request.onerror = function() {
            finish(`${sport}: network error`);
        };

        request.send();
    });
}

function fetchLeagueTable(options, onSuccess, onError) {
    const provider = options.provider || "sportsrc";
    if (provider === "auto") {
        fetchAutoTable(options, onSuccess, onError);
        return;
    }

    if (ProviderCatalog.isProvider(provider)) {
        fetchProviderTable(provider, options, onSuccess, onError);
        return;
    }

    if (provider === "espn") {
        fetchEspnTable(options, onSuccess, onError);
        return;
    }

    if (provider !== "sportsrc") {
        onSuccess([]);
        return;
    }

    const baseUrl = stripTrailingSlash(options.baseUrl || defaultBaseUrl(provider));
    const league = encodeURIComponent((options.league || "PL").trim() || "PL");
    requestJson(`${baseUrl}/?data=results&category=tables&league=${league}`, payload => {
        const rows = normalizeTable(payload);
        if (rows.length > 0 || !isFootballSelection(options)) {
            onSuccess(rows);
        } else {
            fetchEspnTable(withProvider(options, "espn"), onSuccess, onError);
        }
    }, message => {
        if (isFootballSelection(options)) {
            fetchEspnTable(withProvider(options, "espn"), onSuccess, onError);
        } else {
            onError(message);
        }
    });
}

function fetchScoresFixtures(options, onSuccess, onError) {
    const provider = options.provider || "sportsrc";
    if (provider === "auto") {
        fetchAutoMatches("fixtures", options, onSuccess, onError);
        return;
    }

    if (ProviderCatalog.isProvider(provider)) {
        fetchProviderMatches(provider, "fixtures", options, onSuccess, onError);
        return;
    }

    if (provider === "espn") {
        fetchEspnScoreboards(Object.assign({}, options, {
            "scoreboardRange": true
        }), onSuccess, onError);
        return;
    }

    if (provider !== "sportsrc") {
        onSuccess([]);
        return;
    }

    const baseUrl = stripTrailingSlash(options.baseUrl || defaultBaseUrl(provider));
    const league = encodeURIComponent((options.league || "PL").trim() || "PL");
    requestJson(`${baseUrl}/?data=results&category=scores&league=${league}`, payload => {
        onSuccess(normalizeScoresFixtures(payload));
    }, onError);
}

function fetchLeagueForm(options, onSuccess, onError) {
    const sport = normalizeSports(options.sports)[0] || "football";
    const paths = espnPathsForSport(sport, options.league);
    if (paths.length === 0) {
        fetchScoresFixtures(options, matches => {
            onSuccess(formByTeam(matches));
        }, onError);
        return;
    }

    const baseUrl = stripTrailingSlash(defaultBaseUrl("espn"));
    const path = paths[0];
    requestJson(`${baseUrl}/${path}/scoreboard?limit=1000&dates=${espnSeasonDateRange(path)}`, payload => {
        const form = formByTeam(normalizeEspnScoreboard(payload, sport));
        if (Object.keys(form).length > 0) {
            onSuccess(form);
        } else {
            fetchScoresFixtures(options, matches => {
                onSuccess(formByTeam(matches));
            }, onError);
        }
    }, () => {
        fetchScoresFixtures(options, matches => {
            onSuccess(formByTeam(matches));
        }, onError);
    });
}

function fetchMatchStats(options, onSuccess, onError) {
    const provider = options.provider || "sportsrc";
    const matchId = stringValue(options.matchId).trim();
    if (provider === "auto") {
        fetchMatchStats(Object.assign({}, withProvider(options, "espn"), {
            "matchId": matchId
        }), onSuccess, onError);
        return;
    }

    if (provider !== "espn" || matchId.length === 0) {
        onSuccess([]);
        return;
    }

    const sport = normalizeSports(options.sports)[0] || "football";
    const paths = espnPathsForSport(sport, options.league);
    if (paths.length === 0) {
        onSuccess([]);
        return;
    }

    const baseUrl = stripTrailingSlash(options.baseUrl || defaultBaseUrl(provider));
    requestJson(`${baseUrl}/${paths[0]}/summary?event=${encodeURIComponent(matchId)}`, payload => {
        onSuccess(normalizeEspnMatchStats(payload));
    }, onError);
}

function fetchLegacyLiveScores(options, onSuccess, onError) {
    fetchLiveScores(options, onSuccess, onError);
}

function fetchLegacyLeagueTable(options, onSuccess, onError) {
    fetchLeagueTable(options, onSuccess, onError);
}

function fetchLegacyScoresFixtures(options, onSuccess, onError) {
    fetchScoresFixtures(options, onSuccess, onError);
}

function fetchAutoMatches(type, options, onSuccess, onError) {
    const providers = autoMatchProviders(type, options);
    if (providers.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = providers.length;
    let matches = [];
    let errors = [];

    providers.forEach(provider => {
        fetchMatchesFromProvider(provider, type, options, rows => {
            matches = matches.concat(filterMatchesForSelection(rows, options));
            pending -= 1;
            if (pending === 0)
                finishAutoMatches(matches, errors, onSuccess, onError);
        }, message => {
            errors.push(`${providerLabel(provider)}: ${message}`);
            pending -= 1;
            if (pending === 0)
                finishAutoMatches(matches, errors, onSuccess, onError);
        });
    });
}

function fetchAutoTable(options, onSuccess, onError) {
    if (!isFootballSelection(options)) {
        fetchEspnTable(withProvider(options, "espn"), onSuccess, onError);
        return;
    }

    let providers = [
        { "label": "SportSRC", "fetch": fetchSportSrcTable },
        { "label": "TheSportsDB", "fetch": fetchTheSportsDbTable },
        { "label": "ESPN", "fetch": fetchEspnTable }
    ];

    if (ProviderCatalog.leagueOptions("openligadb", "football").some(item => item.value === String(options.league || "").toUpperCase()))
        providers.push({ "label": "OpenLigaDB", "fetch": fetchOpenLigaTable });

    providers.push({ "label": "ESPN Scoreboard", "fetch": fetchEspnComputedTable });
    fetchFirstTable(providers, options, onSuccess, onError);
}

function fetchFirstTable(providers, options, onSuccess, onError) {
    if (providers.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = providers.length;
    let completed = false;
    let errors = [];

    function finishEmpty(label, message) {
        if (completed)
            return;

        errors.push(message.length > 0 ? `${label}: ${message}` : `${label}: no table rows`);
        pending -= 1;
        if (pending === 0) {
            completed = true;
            onError(errors.join(", "));
        }
    }

    providers.forEach(provider => {
        provider.fetch(options, rows => {
            if (completed)
                return;

            rows = Array.isArray(rows) ? rows : [];
            if (rows.length > 0) {
                completed = true;
                onSuccess(rows);
                return;
            }

            finishEmpty(provider.label, "");
        }, message => {
            finishEmpty(provider.label, message);
        });
    });
}

function fetchTableChain(providers, options, onSuccess, onError, errors) {
    if (providers.length === 0) {
        onError(errors.join(", "));
        return;
    }

    const provider = providers[0];
    provider.fetch(options, rows => {
        if (rows.length > 0) {
            onSuccess(rows);
        } else {
            fetchTableChain(providers.slice(1), options, onSuccess, onError, errors.concat([`${provider.label}: no table rows`]));
        }
    }, message => {
        fetchTableChain(providers.slice(1), options, onSuccess, onError, errors.concat([`${provider.label}: ${message}`]));
    });
}

function fetchMatchesFromProvider(provider, type, options, onSuccess, onError) {
    const providerOptions = withProvider(options, provider);
    if (ProviderCatalog.isProvider(provider)) {
        fetchProviderMatches(provider, type, providerOptions, onSuccess, onError);
        return;
    }

    if (provider === "espn") {
        fetchEspnScoreboards(Object.assign({}, providerOptions, {
            "scoreboardRange": type === "fixtures"
        }), onSuccess, onError);
        return;
    }

    if (type === "fixtures") {
        fetchLegacyScoresFixtures(providerOptions, onSuccess, onError);
    } else {
        fetchLegacyLiveScores(providerOptions, onSuccess, onError);
    }
}

function fetchTableFromProvider(provider, options, onSuccess, onError) {
    const providerOptions = withProvider(options, provider);
    if (ProviderCatalog.isProvider(provider)) {
        fetchProviderTable(provider, providerOptions, onSuccess, onError);
        return;
    }

    if (provider === "espn") {
        fetchEspnTable(providerOptions, onSuccess, onError);
        return;
    }

    fetchLegacyLeagueTable(providerOptions, onSuccess, onError);
}

function fetchEspnTable(options, onSuccess, onError) {
    const endpoint = espnStandingsEndpoint(options);
    if (endpoint.length === 0) {
        onSuccess([]);
        return;
    }

    requestJson(endpoint, payload => {
        onSuccess(normalizeEspnTable(payload));
    }, onError);
}

function fetchSportSrcTable(options, onSuccess, onError) {
    const league = encodeURIComponent(String(options.league || "PL").trim() || "PL");
    requestJson(`https://api.sportsrc.org/?data=results&category=tables&league=${league}`, payload => {
        onSuccess(normalizeTable(payload));
    }, onError);
}

function fetchTheSportsDbTable(options, onSuccess, onError) {
    const leagueId = ProviderCatalog.theSportsDbLeagueId(String(options.league || "PL").trim().toUpperCase());
    if (leagueId.length === 0) {
        onSuccess([]);
        return;
    }

    requestJson(`https://www.thesportsdb.com/api/v1/json/123/lookuptable.php?l=${leagueId}&s=${ProviderCatalog.theSportsDbSeason()}`, payload => {
        onSuccess(ProviderCatalog.normalizeTable("thesportsdb", payload));
    }, onError);
}

function fetchOpenLigaTable(options, onSuccess, onError) {
    fetchProviderTable("openligadb", withProvider(options, "openligadb"), onSuccess, onError);
}

function fetchEspnComputedTable(options, onSuccess, onError) {
    const sport = normalizeSports(options.sports)[0] || "football";
    const paths = espnPathsForSport(sport, options.league);
    if (paths.length === 0) {
        onSuccess([]);
        return;
    }

    const baseUrl = stripTrailingSlash(defaultBaseUrl("espn"));
    const path = paths[0];
    requestJson(`${baseUrl}/${path}/scoreboard?limit=1000&dates=${espnSeasonDateRange(path)}`, payload => {
        onSuccess(computeTableFromMatches(normalizeEspnScoreboard(payload, sport)));
    }, onError);
}

function autoMatchProviders(type, options) {
    const sports = normalizeSports(options.sports);
    const sport = sports[0] || "football";
    const providers = ["espn"];
    if (sport === "football" || sport === "soccer") {
        providers.push("thesportsdb");
        if (ProviderCatalog.leagueOptions("openligadb", sport).some(item => item.value === String(options.league || "").toUpperCase()))
            providers.push("openligadb");
    } else if (sport === "snooker") {
        providers.push("sportsrc");
    }
    return uniqueValues(providers);
}

function autoTableProviders(options) {
    const sports = normalizeSports(options.sports);
    const sport = sports[0] || "football";
    let providers = [];
    if (sport === "football" || sport === "soccer") {
        providers.push("sportsrc");
        providers.push("thesportsdb");
        if (ProviderCatalog.leagueOptions("openligadb", sport).some(item => item.value === String(options.league || "").toUpperCase()))
            providers.push("openligadb");
        providers.push("espn");
    } else {
        providers.push("espn");
    }
    return uniqueValues(providers);
}

function finishAutoMatches(matches, errors, onSuccess, onError) {
    const rows = sortMatches(dedupeMatches(matches));
    if (rows.length > 0 || errors.length === 0) {
        onSuccess(rows);
    } else {
        onError(errors.join(", "));
    }
}

function filterMatchesForSelection(matches, options) {
    const sports = normalizeSports(options.sports);
    const sport = sports[0] || "football";
    const league = String(options.league || "").trim().toUpperCase();
    return matches.filter(match => {
        if (!matchesSport(match, sport))
            return false;

        if ((sport === "football" || sport === "soccer") && league.length > 0)
            return matchesLeague(match, league);

        return true;
    });
}

function matchesSport(match, selectedSport) {
    const sport = normalizedText(match.sport);
    const selected = normalizedText(selectedSport);
    if (selected === "football" || selected === "soccer")
        return sport.length === 0 || sport === "football" || sport === "soccer";

    return sport.length === 0 || sport === selected;
}

function isFootballSelection(options) {
    const sport = normalizeSports(options.sports)[0] || "football";
    return sport === "football" || sport === "soccer";
}

function matchesLeague(match, selectedLeague) {
    const league = normalizedText(match.league);
    if (league.length === 0)
        return true;

    const candidates = leagueAliases(selectedLeague).map(normalizedText);
    for (let index = 0; index < candidates.length; index += 1) {
        if (league === candidates[index] || league.indexOf(candidates[index]) >= 0)
            return true;

    }
    return false;
}

function leagueAliases(code) {
    const aliases = {
        "BL1": ["BL1", "Bundesliga", "German Bundesliga", "GER.1"],
        "BSA": ["BSA", "Brasileirao Serie A", "Brazil Serie A", "BRA.1"],
        "CL": ["CL", "UEFA Champions League", "Champions League", "UEFA.CHAMPIONS"],
        "DED": ["DED", "Eredivisie", "Dutch Eredivisie", "NED.1"],
        "EC": ["EC", "European Championship", "UEFA European Championship", "UEFA Euro", "UEFA.EURO"],
        "ELC": ["ELC", "Championship", "English League Championship", "ENG.2"],
        "FL1": ["FL1", "Ligue 1", "French Ligue 1", "FRA.1"],
        "PD": ["PD", "La Liga", "LaLiga", "Spanish LALIGA", "ESP.1"],
        "PL": ["PL", "Premier League", "English Premier League", "ENG.1"],
        "PPL": ["PPL", "Primeira Liga", "POR.1"],
        "SA": ["SA", "Serie A", "Italian Serie A", "ITA.1"],
        "WC": ["WC", "World Cup", "FIFA World Cup", "FIFA.WORLD"]
    };
    return aliases[code] || [code];
}

function withProvider(options, provider) {
    const copy = Object.assign({}, options);
    copy.provider = provider;
    copy.baseUrl = defaultBaseUrl(provider);
    return copy;
}

function providerLabel(provider) {
    if (ProviderCatalog.isProvider(provider))
        return ProviderCatalog.displayName(provider);
    if (provider === "espn")
        return "ESPN";
    if (provider === "sportdb")
        return "SportDB.dev";
    if (provider === "sportsrc")
        return "SportSRC";
    return provider;
}

function fetchProviderMatches(provider, type, options, onSuccess, onError) {
    if (missingProviderKey(provider, options, onError))
        return;

    const requests = type === "fixtures" ? ProviderCatalog.fixtureRequests(provider, options) : ProviderCatalog.liveRequests(provider, options);
    fetchProviderRequests(provider, requests, options, (payload, item) => {
        return type === "fixtures" ? ProviderCatalog.normalizeFixtures(provider, payload, item.sport) : ProviderCatalog.normalizeMatches(provider, payload, item.sport);
    }, matches => {
        onSuccess(type === "fixtures" ? sortMatches(matches) : sortMatches(matches));
    }, onError);
}

function fetchProviderTable(provider, options, onSuccess, onError) {
    if (missingProviderKey(provider, options, onError))
        return;

    const requests = ProviderCatalog.tableRequests(provider, options);
    fetchProviderRequests(provider, requests, options, payload => {
        return ProviderCatalog.normalizeTable(provider, payload);
    }, onSuccess, onError);
}

function fetchProviderRequests(provider, requests, options, normalize, onSuccess, onError) {
    if (requests.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = requests.length;
    let rows = [];
    let errors = [];
    const headers = ProviderCatalog.headers(provider, options.apiKey, options.baseUrl);

    requests.forEach(item => {
        requestJsonWithHeaders(item.url, headers, payload => {
            rows = rows.concat(normalize(payload, item));
            pending -= 1;
            if (pending === 0) {
                if (rows.length > 0 || errors.length === 0) {
                    onSuccess(rows);
                } else {
                    onError(errors.join(", "));
                }
            }
        }, message => {
            errors.push(`${ProviderCatalog.displayName(provider)}: ${message}`);
            pending -= 1;
            if (pending === 0) {
                if (rows.length > 0) {
                    onSuccess(rows);
                } else {
                    onError(errors.join(", "));
                }
            }
        });
    });
}

function missingProviderKey(provider, options, onError) {
    if (!ProviderCatalog.requiresApiKey(provider))
        return false;

    if (String(options.apiKey || "").trim().length > 0)
        return false;

    onError(`${ProviderCatalog.displayName(provider)} requires an API key.`);
    return true;
}

function requestJson(url, onSuccess, onError) {
    requestJsonWithHeaders(url, {}, onSuccess, onError);
}

function requestJsonWithHeaders(url, headers, onSuccess, onError) {
    const request = new XMLHttpRequest();
    let completed = false;

    function finish(errorMessage) {
        if (completed)
            return;

        completed = true;
        if (errorMessage.length > 0) {
            onError(errorMessage);
            return;
        }

        if (request.status >= 200 && request.status < 300) {
            try {
                onSuccess(JSON.parse(request.responseText));
            } catch (error) {
                onError(String(error));
            }
        } else {
            onError(`HTTP ${request.status}`);
        }
    }

    request.open("GET", url);
    request.timeout = REQUEST_TIMEOUT_MS;
    request.setRequestHeader("Accept", "application/json");
    Object.keys(headers || {}).forEach(header => {
        if (headers[header] !== undefined && headers[header] !== null && String(headers[header]).length > 0) {
            request.setRequestHeader(header, headers[header]);
        }
    });
    request.onreadystatechange = function() {
        if (request.readyState !== XMLHttpRequest.DONE) {
            return;
        }

        finish("");
    };
    request.ontimeout = function() {
        finish("request timed out");
    };
    request.onerror = function() {
        finish("network error");
    };
    request.send();
}

function normalizeSports(value) {
    if (Array.isArray(value)) {
        return value.map(sport => String(sport).trim().toLowerCase()).filter(Boolean);
    }

    return String(value || "")
        .split(",")
        .map(sport => sport.trim().toLowerCase())
        .filter(Boolean);
}

function normalizeMatches(payload, sport, provider) {
    const list = extractList(payload);
    return list.map(match => provider === "sportsrc" ? normalizeSportSrcMatch(match, sport) : normalizeSportDbMatch(match, sport))
        .filter(match => match.homeTeam && match.awayTeam);
}

function demoMatches() {
    return [
        {
            sport: "football",
            league: "Premier League",
            homeTeam: "Arsenal",
            awayTeam: "Chelsea",
            homeScore: "2",
            awayScore: "1",
            status: "Live",
            minute: "72'",
            startTime: "",
            homeBadge: "",
            awayBadge: "",
            poster: "",
            popular: true
        },
        {
            sport: "basketball",
            league: "NBA",
            homeTeam: "Boston Celtics",
            awayTeam: "New York Knicks",
            homeScore: "88",
            awayScore: "83",
            status: "Q4",
            minute: "08:14",
            startTime: "",
            homeBadge: "",
            awayBadge: "",
            poster: "",
            popular: true
        },
        {
            sport: "hockey",
            league: "NHL",
            homeTeam: "New York Rangers",
            awayTeam: "Boston Bruins",
            homeScore: "1",
            awayScore: "1",
            status: "2nd",
            minute: "12:31",
            startTime: "",
            homeBadge: "",
            awayBadge: "",
            poster: "",
            popular: false
        }
    ];
}

function demoTable() {
    return [
        { position: 1, team: "Arsenal", played: 36, won: 24, draw: 7, lost: 5, goalsFor: 68, goalsAgainst: 26, points: 79, goalDifference: 42, form: "W,L,L,W,W", crest: "https://sportsrc.org/img/score/57.png" },
        { position: 2, team: "Man City", played: 35, won: 22, draw: 8, lost: 5, goalsFor: 72, goalsAgainst: 32, points: 74, goalDifference: 40, form: "W,D,W,W,W", crest: "https://sportsrc.org/img/score/65.png" },
        { position: 3, team: "Man United", played: 36, won: 18, draw: 11, lost: 7, goalsFor: 63, goalsAgainst: 48, points: 65, goalDifference: 15, form: "D,L,W,W,W", crest: "https://sportsrc.org/img/score/66.png" },
        { position: 4, team: "Liverpool", played: 36, won: 17, draw: 8, lost: 11, goalsFor: 60, goalsAgainst: 48, points: 59, goalDifference: 12, form: "D,L,W,W,W", crest: "https://sportsrc.org/img/score/64.png" },
        { position: 5, team: "Aston Villa", played: 36, won: 17, draw: 8, lost: 11, goalsFor: 50, goalsAgainst: 46, points: 59, goalDifference: 4, form: "D,L,L,W,D", crest: "https://sportsrc.org/img/score/58.png" },
        { position: 6, team: "Bournemouth", played: 36, won: 13, draw: 16, lost: 7, goalsFor: 56, goalsAgainst: 52, points: 55, goalDifference: 4, form: "D,W,W,D,W", crest: "https://sportsrc.org/img/score/bournemouth.png" },
        { position: 7, team: "Brighton Hove", played: 36, won: 14, draw: 11, lost: 11, goalsFor: 52, goalsAgainst: 42, points: 53, goalDifference: 10, form: "W,W,D,W,L", crest: "https://sportsrc.org/img/score/397.png" },
        { position: 8, team: "Brentford", played: 36, won: 14, draw: 9, lost: 13, goalsFor: 52, goalsAgainst: 49, points: 51, goalDifference: 3, form: "D,D,D,L,W", crest: "https://sportsrc.org/img/score/402.png" },
        { position: 9, team: "Chelsea", played: 36, won: 13, draw: 10, lost: 13, goalsFor: 55, goalsAgainst: 49, points: 49, goalDifference: 6, form: "L,L,L,L,L", crest: "https://sportsrc.org/img/score/61.png" },
        { position: 10, team: "Everton", played: 36, won: 13, draw: 10, lost: 13, goalsFor: 46, goalsAgainst: 46, points: 49, goalDifference: 0, form: "W,D,L,L,D", crest: "https://sportsrc.org/img/score/62.png" },
        { position: 11, team: "Fulham", played: 36, won: 14, draw: 6, lost: 16, goalsFor: 44, goalsAgainst: 50, points: 48, goalDifference: -6, form: "W,L,D,W,L", crest: "https://sportsrc.org/img/score/63.png" },
        { position: 12, team: "Sunderland", played: 36, won: 12, draw: 12, lost: 12, goalsFor: 37, goalsAgainst: 46, points: 48, goalDifference: -9, form: "W,W,D,L,L", crest: "https://sportsrc.org/img/score/71.png" },
        { position: 13, team: "Newcastle", played: 36, won: 13, draw: 7, lost: 16, goalsFor: 50, goalsAgainst: 52, points: 46, goalDifference: -2, form: "L,W,D,L,W", crest: "https://sportsrc.org/img/score/67.png" },
        { position: 14, team: "Leeds United", played: 36, won: 10, draw: 14, lost: 12, goalsFor: 48, goalsAgainst: 53, points: 44, goalDifference: -5, form: "D,W,L,D,W", crest: "https://sportsrc.org/img/score/341.png" },
        { position: 15, team: "Crystal Palace", played: 35, won: 11, draw: 11, lost: 13, goalsFor: 38, goalsAgainst: 44, points: 44, goalDifference: -6, form: "D,W,L,W,L", crest: "https://sportsrc.org/img/score/354.png" },
        { position: 16, team: "Nottingham", played: 36, won: 11, draw: 10, lost: 15, goalsFor: 45, goalsAgainst: 47, points: 43, goalDifference: -2, form: "D,L,W,L,D", crest: "https://sportsrc.org/img/score/351.png" },
        { position: 17, team: "Tottenham", played: 36, won: 9, draw: 11, lost: 16, goalsFor: 46, goalsAgainst: 55, points: 38, goalDifference: -9, form: "D,W,W,D,L", crest: "https://sportsrc.org/img/score/73.png" },
        { position: 18, team: "West Ham", played: 36, won: 9, draw: 9, lost: 18, goalsFor: 42, goalsAgainst: 62, points: 36, goalDifference: -20, form: "L,L,W,D,W", crest: "https://sportsrc.org/img/score/563.png" },
        { position: 19, team: "Burnley", played: 36, won: 4, draw: 9, lost: 23, goalsFor: 37, goalsAgainst: 73, points: 21, goalDifference: -36, form: "D,L,L,L,L", crest: "https://sportsrc.org/img/score/328.png" },
        { position: 20, team: "Wolverhampton", played: 36, won: 3, draw: 9, lost: 24, goalsFor: 25, goalsAgainst: 66, points: 18, goalDifference: -41, form: "L,D,L,L,L", crest: "https://sportsrc.org/img/score/76.png" }
    ];
}

function demoFixtures() {
    return [
        { homeTeam: "Liverpool", awayTeam: "Chelsea", homeScore: "1", awayScore: "1", status: "Finished", startTime: "09.05 14:30", matchday: "MD 36", homeBadge: "", awayBadge: "" },
        { homeTeam: "Manchester City", awayTeam: "Brentford", homeScore: "3", awayScore: "0", status: "Finished", startTime: "09.05 19:30", matchday: "MD 36", homeBadge: "", awayBadge: "" },
        { homeTeam: "Tottenham", awayTeam: "Leeds United", homeScore: "1", awayScore: "1", status: "Finished", startTime: "11.05 22:00", matchday: "MD 36", homeBadge: "", awayBadge: "" }
    ];
}

function extractList(payload) {
    if (Array.isArray(payload)) {
        return payload;
    }

    const candidates = [
        payload && payload.matches,
        payload && payload.events,
        payload && payload.fixtures,
        payload && payload.games,
        payload && payload.data,
        payload && payload.result,
        payload && payload.live
    ];

    for (let index = 0; index < candidates.length; index += 1) {
        if (Array.isArray(candidates[index])) {
            return candidates[index];
        }
    }

    if (payload && payload.data && Array.isArray(payload.data.matches)) {
        return payload.data.matches;
    }

    return [];
}

function normalizeSportSrcMatch(match, sport) {
    const home = (match.teams && match.teams.home) || match.home || {};
    const away = (match.teams && match.teams.away) || match.away || {};
    const date = numberValue(match.date);
    const status = statusFromDate(date);

    return {
        id: stringValue(match.id),
        sport: stringValue(match.category || sport),
        league: stringValue(match.league || match.competition || ""),
        homeTeam: teamName(home) || teamFromTitle(match.title, 0),
        awayTeam: teamName(away) || teamFromTitle(match.title, 1),
        homeScore: stringValue(match.homeScore ?? match.home_score ?? ""),
        awayScore: stringValue(match.awayScore ?? match.away_score ?? ""),
        status: status.label,
        minute: status.detail,
        startTime: date > 0 ? formatStartTime(date) : "",
        timestamp: date,
        homeBadge: stringValue(home.badge || ""),
        awayBadge: stringValue(away.badge || ""),
        poster: stringValue(match.poster || ""),
        popular: Boolean(match.popular)
    };
}

function normalizeSportDbMatch(match, sport) {
    const home = match.homeTeam || match.home_team || match.home || match.localTeam || match.team_home || {};
    const away = match.awayTeam || match.away_team || match.away || match.visitorTeam || match.team_away || {};
    const score = match.score || match.scores || {};
    const status = match.status || match.match_status || match.state || match.period || "";

    return {
        sport,
        league: value(match.league, ["name", "title"]) || value(match.competition, ["name", "title"]) || match.league_name || match.competition_name || "",
        homeTeam: teamName(home) || match.home_name || match.homeTeamName || match.localteam_name || "",
        awayTeam: teamName(away) || match.away_name || match.awayTeamName || match.visitorteam_name || "",
        homeScore: stringValue(match.homeScore ?? match.home_score ?? score.home ?? score.home_score ?? value(home, ["score", "goals", "points"])),
        awayScore: stringValue(match.awayScore ?? match.away_score ?? score.away ?? score.away_score ?? value(away, ["score", "goals", "points"])),
        status: statusText(status),
        minute: stringValue(match.minute ?? match.time ?? match.clock ?? match.elapsed ?? match.current_minute),
        startTime: stringValue(match.startTime ?? match.start_time ?? match.kickoff ?? match.date ?? match.datetime),
        timestamp: 0,
        homeBadge: stringValue(value(home, ["badge", "logo", "image"])),
        awayBadge: stringValue(value(away, ["badge", "logo", "image"])),
        poster: stringValue(match.poster || match.thumbnail || ""),
        popular: Boolean(match.popular)
    };
}

function fetchEspnScoreboards(options, onSuccess, onError) {
    const urls = espnScoreboardUrls(options);
    if (urls.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = urls.length;
    let matches = [];
    let errors = [];

    urls.forEach(item => {
        requestJson(item.url, payload => {
            matches = matches.concat(normalizeEspnScoreboard(payload, item.sport));
            pending -= 1;
            if (pending === 0) {
                onSuccess(sortMatches(matches));
            }
        }, message => {
            errors.push(`${item.label}: ${message}`);
            pending -= 1;
            if (pending === 0) {
                if (matches.length > 0) {
                    onSuccess(sortMatches(matches));
                } else {
                    onError(errors.join(", "));
                }
            }
        });
    });
}

function normalizeEspnScoreboard(payload, sport) {
    const leagueName = espnLeagueName(payload, sport);
    const events = Array.isArray(payload && payload.events) ? payload.events : [];
    let matches = [];

    events.forEach(event => {
        if (Array.isArray(event.competitions)) {
            event.competitions.forEach(competition => {
                const match = normalizeEspnCompetition(event, competition, sport, leagueName);
                if (match.homeTeam && match.awayTeam) {
                    matches.push(match);
                }
            });
        }

        if (Array.isArray(event.groupings)) {
            event.groupings.forEach(group => {
                const competitions = Array.isArray(group && group.competitions) ? group.competitions : [];
                competitions.forEach(competition => {
                    const match = normalizeEspnCompetition(event, competition, sport, event.shortName || event.name || leagueName);
                    if (match.homeTeam && match.awayTeam) {
                        matches.push(match);
                    }
                });
            });
        }
    });

    return matches;
}

function normalizeEspnCompetition(event, competition, sport, leagueName) {
    const competitors = Array.isArray(competition && competition.competitors) ? competition.competitors : [];
    const home = espnCompetitor(competitors, "home", 0);
    const away = espnCompetitor(competitors, "away", 1);
    const status = espnStatus(competition.status || event.status || {});
    const timestamp = Date.parse(competition.date || competition.startDate || event.date || "");

    return {
        id: stringValue(competition.id || event.id),
        sport: stringValue(sport),
        league: stringValue(leagueName),
        homeTeam: espnCompetitorName(home),
        awayTeam: espnCompetitorName(away),
        homeTeamAliases: espnCompetitorAliases(home),
        awayTeamAliases: espnCompetitorAliases(away),
        homeScore: status.scheduled ? "" : stringValue(home.score),
        awayScore: status.scheduled ? "" : stringValue(away.score),
        status: status.label,
        minute: status.detail,
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        homeBadge: espnCompetitorLogo(home),
        awayBadge: espnCompetitorLogo(away),
        poster: "",
        statsProvider: "espn",
        statsRows: normalizeEspnCompetitionStats(home, away),
        popular: Boolean(event.major)
    };
}

function normalizeEspnCompetitionStats(home, away) {
    const homeStats = statMap(home.statistics);
    const awayStats = statMap(away.statistics);
    const rows = [];

    addStatRow(rows, "Shots on target", statValue(homeStats, "shotsOnTarget"), statValue(awayStats, "shotsOnTarget"));
    addStatRow(rows, "Shots off target", shotsOffTarget(homeStats), shotsOffTarget(awayStats));
    addStatRow(rows, "Possession (%)", statValue(homeStats, "possessionPct"), statValue(awayStats, "possessionPct"));
    addStatRow(rows, "Corner Kicks", statValue(homeStats, "wonCorners"), statValue(awayStats, "wonCorners"));
    addStatRow(rows, "Fouls", statValue(homeStats, "foulsCommitted"), statValue(awayStats, "foulsCommitted"));
    addStatRow(rows, "Goals", statValue(homeStats, "totalGoals"), statValue(awayStats, "totalGoals"));
    addStatRow(rows, "Shots", statValue(homeStats, "totalShots"), statValue(awayStats, "totalShots"));
    return rows;
}

function normalizeEspnTable(payload) {
    let entries = [];
    const children = Array.isArray(payload && payload.children) ? payload.children : [];

    children.forEach((child, groupIndex) => {
        const standings = child && child.standings ? child.standings : {};
        if (Array.isArray(standings.entries)) {
            entries = entries.concat(standings.entries.map(entry => {
                return {
                    entry,
                    group: tableGroupName(child, groupIndex, children.length),
                    groupIndex
                };
            }));
        }
    });

    if (entries.length === 0 && payload && payload.standings && Array.isArray(payload.standings.entries)) {
        entries = payload.standings.entries.map(entry => {
            return {
                entry,
                group: "",
                groupIndex: 0
            };
        });
    }

    return entries.map(item => {
        const entry = item.entry || {};
        const team = entry.team || {};
        const stats = Array.isArray(entry.stats) ? entry.stats : [];
        return {
            position: numberValue(espnStat(stats, ["rank"])),
            team: stringValue(team.shortDisplayName || team.displayName || team.name || team.location),
            group: item.group,
            groupIndex: item.groupIndex,
            played: numberValue(espnStat(stats, ["gamesPlayed", "gamesplayed"])),
            won: numberValue(espnStat(stats, ["wins"])),
            draw: numberValue(espnStat(stats, ["ties", "draws"])),
            lost: numberValue(espnStat(stats, ["losses"])),
            goalsFor: numberValue(espnStat(stats, ["pointsFor", "pointsfor"])),
            goalsAgainst: numberValue(espnStat(stats, ["pointsAgainst", "pointsagainst"])),
            points: numberValue(espnStat(stats, ["points"])),
            goalDifference: numberValue(espnStat(stats, ["pointDifferential", "pointdifferential"])),
            form: espnForm(entry),
            crest: espnLogo(team)
        };
    }).filter(row => row.team.length > 0)
        .sort((left, right) => left.groupIndex - right.groupIndex || left.position - right.position);
}

function normalizeEspnMatchStats(payload) {
    const teams = Array.isArray(payload && payload.boxscore && payload.boxscore.teams) ? payload.boxscore.teams.slice() : [];
    if (teams.length < 2) {
        return [];
    }

    teams.sort((left, right) => numberValue(left.displayOrder) - numberValue(right.displayOrder));
    const home = teams.find(team => team.homeAway === "home") || teams[0];
    const away = teams.find(team => team.homeAway === "away") || teams[1];
    const homeStats = statMap(home.statistics);
    const awayStats = statMap(away.statistics);
    const rows = [];

    addStatRow(rows, "Shots on target", statValue(homeStats, "shotsOnTarget"), statValue(awayStats, "shotsOnTarget"));
    addStatRow(rows, "Shots off target", shotsOffTarget(homeStats), shotsOffTarget(awayStats));
    addStatRow(rows, "Blocked Shots", statValue(homeStats, "blockedShots"), statValue(awayStats, "blockedShots"));
    addStatRow(rows, "Possession (%)", statValue(homeStats, "possessionPct"), statValue(awayStats, "possessionPct"));
    addStatRow(rows, "Corner Kicks", statValue(homeStats, "wonCorners"), statValue(awayStats, "wonCorners"));
    addStatRow(rows, "Offsides", statValue(homeStats, "offsides"), statValue(awayStats, "offsides"));
    addStatRow(rows, "Fouls", statValue(homeStats, "foulsCommitted"), statValue(awayStats, "foulsCommitted"));
    addStatRow(rows, "Yellow cards", statValue(homeStats, "yellowCards"), statValue(awayStats, "yellowCards"));
    addStatRow(rows, "Crosses", statValue(homeStats, "totalCrosses"), statValue(awayStats, "totalCrosses"));
    addStatRow(rows, "Goalkeeper saves", statValue(homeStats, "saves"), statValue(awayStats, "saves"));
    addStatRow(rows, "Passes", statValue(homeStats, "totalPasses"), statValue(awayStats, "totalPasses"));
    addStatRow(rows, "Accurate passes", statValue(homeStats, "accuratePasses"), statValue(awayStats, "accuratePasses"));
    addStatRow(rows, "Tackles", statValue(homeStats, "totalTackles"), statValue(awayStats, "totalTackles"));
    addStatRow(rows, "Interceptions", statValue(homeStats, "interceptions"), statValue(awayStats, "interceptions"));
    addStatRow(rows, "Clearances", statValue(homeStats, "totalClearance"), statValue(awayStats, "totalClearance"));

    return rows;
}

function normalizeTable(payload) {
    const data = payload && payload.data ? payload.data : payload;
    const standings = data && Array.isArray(data.standings) ? data.standings : [];
    let rows = [];
    standings.forEach((standing, groupIndex) => {
        const group = tableGroupName(standing, groupIndex, standings.length);
        const table = Array.isArray(standing && standing.table) ? standing.table : [];
        rows = rows.concat(table.map(row => {
            const team = row.team || {};
            return {
                position: numberValue(row.position),
                team: stringValue(team.shortName || team.name || row.teamName),
                group,
                groupIndex,
                played: numberValue(row.playedGames),
                won: numberValue(row.won),
                draw: numberValue(row.draw),
                lost: numberValue(row.lost),
                goalsFor: numberValue(row.goalsFor ?? row.for),
                goalsAgainst: numberValue(row.goalsAgainst ?? row.against),
                points: numberValue(row.points),
                goalDifference: numberValue(row.goalDifference),
                form: stringValue(row.form),
                crest: stringValue(team.crest || team.badge || "")
            };
        }));
    });

    return rows.filter(row => row.team.length > 0)
        .sort((left, right) => left.groupIndex - right.groupIndex || left.position - right.position);
}

function normalizeScoresFixtures(payload) {
    const data = payload && payload.data ? payload.data : payload;
    const live = Array.isArray(data && data.live) ? data.live : [];
    const upcoming = Array.isArray(data && data.upcoming) ? data.upcoming : [];
    const scheduled = Array.isArray(data && data.scheduled) ? data.scheduled : [];
    const finished = Array.isArray(data && data.finished) ? data.finished : [];
    return live.concat(upcoming).concat(scheduled).concat(finished)
        .map(normalizeScoreFixture)
        .filter(match => match.homeTeam && match.awayTeam);
}

function tableGroupName(item, index, count) {
    const explicitName = stringValue(item && (item.name || item.groupName || item.group || item.abbreviation || item.shortName || item.displayName));
    if (explicitName.length > 0 && explicitName.toUpperCase() !== "ALL")
        return explicitName;

    if (count > 1)
        return `Group ${String.fromCharCode(65 + index)}`;

    return "";
}

function normalizeScoreFixture(match) {
    const home = match.homeTeam || match.home || {};
    const away = match.awayTeam || match.away || {};
    const fullTime = match.score && match.score.fullTime ? match.score.fullTime : {};
    const timestamp = match.utcDate ? Date.parse(match.utcDate) : numberValue(match.date);
    const status = scoreStatus(match.status, timestamp);

    return {
        homeTeam: teamName(home) || match.home_name || "",
        awayTeam: teamName(away) || match.away_name || "",
        homeScore: stringValue(fullTime.home ?? match.homeScore ?? match.home_score ?? ""),
        awayScore: stringValue(fullTime.away ?? match.awayScore ?? match.away_score ?? ""),
        status: status.label,
        startTime: timestamp > 0 ? formatStartTime(timestamp) : "",
        timestamp,
        matchday: match.matchday ? "MD " + match.matchday : "",
        homeBadge: stringValue(home.crest || home.badge || ""),
        awayBadge: stringValue(away.crest || away.badge || "")
    };
}

function scoreStatus(status, timestamp) {
    const normalized = stringValue(status).toUpperCase();
    if (normalized.indexOf("FINISHED") >= 0) {
        return { label: "Finished" };
    }
    if (normalized.indexOf("LIVE") >= 0 || normalized.indexOf("IN_PLAY") >= 0) {
        return { label: "Live" };
    }
    return statusFromDate(timestamp);
}

function sortMatches(matches) {
    return matches.sort((left, right) => {
        if (left.status === "Live" && right.status !== "Live") {
            return -1;
        }

        if (right.status === "Live" && left.status !== "Live") {
            return 1;
        }

        if (left.timestamp > 0 && right.timestamp > 0 && left.timestamp !== right.timestamp) {
            return left.timestamp - right.timestamp;
        }

        if (left.sport === right.sport) {
            return left.league.localeCompare(right.league) || left.homeTeam.localeCompare(right.homeTeam);
        }

        return left.sport.localeCompare(right.sport);
    });
}

function dedupeMatches(matches) {
    let seen = {};
    let rows = [];
    matches.forEach(match => {
        const key = [
            normalizedText(match.sport),
            normalizedText(match.homeTeam),
            normalizedText(match.awayTeam),
            String(match.timestamp || match.startTime || match.status || "")
        ].join("|");
        if (seen[key])
            return;

        seen[key] = true;
        rows.push(match);
    });
    return rows;
}

function computeTableFromMatches(matches) {
    let teams = {};
    const finished = matches.filter(match => match.status === "Finished" && Number.isFinite(Number(match.homeScore)) && Number.isFinite(Number(match.awayScore)))
        .sort((left, right) => numberValue(left.timestamp) - numberValue(right.timestamp));

    function row(name, crest) {
        const key = normalizedText(name);
        if (!teams[key]) {
            teams[key] = {
                position: 0,
                team: stringValue(name),
                played: 0,
                won: 0,
                draw: 0,
                lost: 0,
                goalsFor: 0,
                goalsAgainst: 0,
                points: 0,
                goalDifference: 0,
                form: "",
                crest: stringValue(crest),
                formItems: []
            };
        } else if (teams[key].crest.length === 0 && crest) {
            teams[key].crest = stringValue(crest);
        }
        return teams[key];
    }

    function applyResult(team, goalsFor, goalsAgainst) {
        team.played += 1;
        team.goalsFor += goalsFor;
        team.goalsAgainst += goalsAgainst;
        if (goalsFor > goalsAgainst) {
            team.won += 1;
            team.points += 3;
            team.formItems.push("W");
        } else if (goalsFor === goalsAgainst) {
            team.draw += 1;
            team.points += 1;
            team.formItems.push("D");
        } else {
            team.lost += 1;
            team.formItems.push("L");
        }
        team.goalDifference = team.goalsFor - team.goalsAgainst;
    }

    finished.forEach(match => {
        const homeGoals = numberValue(match.homeScore);
        const awayGoals = numberValue(match.awayScore);
        const home = row(match.homeTeam, match.homeBadge);
        const away = row(match.awayTeam, match.awayBadge);
        applyResult(home, homeGoals, awayGoals);
        applyResult(away, awayGoals, homeGoals);
    });

    return Object.keys(teams).map(key => {
        const item = teams[key];
        item.form = item.formItems.slice(-5).join(",");
        delete item.formItems;
        return item;
    }).filter(item => item.played > 0)
        .sort((left, right) => right.points - left.points || right.goalDifference - left.goalDifference || right.goalsFor - left.goalsFor || left.team.localeCompare(right.team))
        .map((item, index) => {
            item.position = index + 1;
            return item;
        });
}

function formByTeam(matches) {
    let result = {};
    const finished = (matches || []).filter(match => match.status === "Finished" && Number.isFinite(Number(match.homeScore)) && Number.isFinite(Number(match.awayScore)))
        .sort((left, right) => numberValue(left.timestamp) - numberValue(right.timestamp));

    function append(teamName, value) {
        const key = normalizedText(teamName);
        if (key.length === 0)
            return;

        if (!result[key])
            result[key] = [];

        result[key].push(value);
    }

    function appendAll(teamName, aliases, value) {
        let seen = {};
        const names = [teamName].concat(Array.isArray(aliases) ? aliases : []);
        names.forEach(name => {
            const key = normalizedText(name);
            if (key.length === 0 || seen[key])
                return;

            seen[key] = true;
            append(name, value);
        });
    }

    finished.forEach(match => {
        const homeGoals = numberValue(match.homeScore);
        const awayGoals = numberValue(match.awayScore);
        if (homeGoals > awayGoals) {
            appendAll(match.homeTeam, match.homeTeamAliases, "W");
            appendAll(match.awayTeam, match.awayTeamAliases, "L");
        } else if (homeGoals < awayGoals) {
            appendAll(match.homeTeam, match.homeTeamAliases, "L");
            appendAll(match.awayTeam, match.awayTeamAliases, "W");
        } else {
            appendAll(match.homeTeam, match.homeTeamAliases, "D");
            appendAll(match.awayTeam, match.awayTeamAliases, "D");
        }
    });

    Object.keys(result).forEach(key => {
        result[key] = result[key].slice(-5).join(",");
    });
    return result;
}

function formForTeam(formMap, teamName) {
    const key = normalizedText(teamName);
    if (formMap[key])
        return formMap[key];

    const compact = compactTeamName(teamName);
    const alias = teamAliasKey(teamName);
    const keys = Object.keys(formMap || {});
    for (let index = 0; index < keys.length; index += 1) {
        const itemCompact = compactTeamName(keys[index]);
        const itemAlias = teamAliasKey(keys[index]);
        if (alias.length > 0 && alias === itemAlias)
            return formMap[keys[index]];

        if (compact.length > 0 && itemCompact.indexOf(compact) >= 0)
            return formMap[keys[index]];

        if (compact.length > 0 && compact.indexOf(itemCompact) >= 0)
            return formMap[keys[index]];
    }
    return "";
}

function compactTeamName(value) {
    return normalizedText(value)
        .replace(/\b(fc|cf|afc|ac|sc|ss|ssc|bc|calcio|club|de|la|the)\b/g, "")
        .replace(/[^a-z0-9]+/g, "");
}

function teamAliasKey(value) {
    const compact = compactTeamName(value);
    const aliases = {
        "athletic": "athleticbilbao",
        "athleticbilbao": "athleticbilbao",
        "athleticclub": "athleticbilbao",
        "atleti": "atleticomadrid",
        "atleticomadrid": "atleticomadrid",
        "atletico": "atleticomadrid",
        "atleticodemadrid": "atleticomadrid",
        "barca": "barcelona",
        "barcelona": "barcelona",
        "bayern": "bayernmunich",
        "bayernmunich": "bayernmunich",
        "brighton": "brightonhove",
        "brightonhove": "brightonhove",
        "brightonandhovealbion": "brightonhove",
        "cpalace": "crystalpalace",
        "crystalpalace": "crystalpalace",
        "internazionale": "intermilan",
        "inter": "intermilan",
        "intermilan": "intermilan",
        "manchester": "manchesterunited",
        "manchestercity": "manchestercity",
        "manchesterunited": "manchesterunited",
        "mancity": "manchestercity",
        "manunited": "manchesterunited",
        "manutd": "manchesterunited",
        "milan": "acmilan",
        "acmilan": "acmilan",
        "newcastle": "newcastleunited",
        "newcastleunited": "newcastleunited",
        "nottingham": "nottinghamforest",
        "nottinghamforest": "nottinghamforest",
        "nottmforest": "nottinghamforest",
        "psg": "parissaintgermain",
        "parissaintgermain": "parissaintgermain",
        "real": "realmadrid",
        "realmadrid": "realmadrid",
        "sociedad": "realsociedad",
        "realsociedad": "realsociedad",
        "spurs": "tottenham",
        "tottenham": "tottenham",
        "tottenhamhotspur": "tottenham",
        "westham": "westhamunited",
        "westhamunited": "westhamunited",
        "wolves": "wolverhampton",
        "wolverhampton": "wolverhampton",
        "wolverhamptonwanderers": "wolverhampton"
    };
    return aliases[compact] || compact;
}

function uniqueValues(values) {
    let seen = {};
    let rows = [];
    values.forEach(value => {
        if (seen[value])
            return;

        seen[value] = true;
        rows.push(value);
    });
    return rows;
}

function normalizedText(value) {
    return stripDiacritics(stringValue(value)).toLowerCase().replace(/\s+/g, " ").trim();
}

function stripDiacritics(value) {
    try {
        return String(value).normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    } catch (error) {
        return String(value);
    }
}

function defaultBaseUrl(provider) {
    if (ProviderCatalog.isProvider(provider)) {
        return ProviderCatalog.defaultBaseUrl(provider);
    }

    if (provider === "sportdb") {
        return "https://api.sportdb.dev";
    }

    if (provider === "espn") {
        return "https://site.api.espn.com/apis/site/v2/sports";
    }

    return "https://api.sportsrc.org";
}

function endpointFor(provider, baseUrl, sport) {
    if (provider === "sportdb") {
        return `${baseUrl}/api/${encodeURIComponent(sport)}/live`;
    }

    return `${baseUrl}/?data=matches&category=${encodeURIComponent(sport)}`;
}

function espnScoreboardUrls(options) {
    const baseUrl = stripTrailingSlash(options.baseUrl || defaultBaseUrl("espn"));
    const sports = normalizeSports(options.sports);
    let urls = [];
    const dates = options.scoreboardRange ? `&dates=${espnDateRange(-14, 21)}` : "";

    sports.forEach(sport => {
        espnPathsForSport(sport, options.league).forEach(path => {
            urls.push({
                sport,
                label: path,
                url: `${baseUrl}/${path}/scoreboard?limit=1000${dates}`
            });
        });
    });

    return urls;
}

function espnDateRange(daysBack, daysForward) {
    return `${espnDate(offsetDateObject(daysBack))}-${espnDate(offsetDateObject(daysForward))}`;
}

function espnSeasonDateRange(path) {
    const season = espnSeasonYear(path);
    return `${season}0801-${season + 1}0630`;
}

function espnDate(date) {
    return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}`;
}

function offsetDateObject(offset) {
    const date = new Date();
    date.setDate(date.getDate() + offset);
    return date;
}

function espnStandingsEndpoint(options) {
    const sports = normalizeSports(options.sports);
    const sport = sports.length > 0 ? sports[0] : "football";
    const paths = espnPathsForSport(sport, options.league);
    if (paths.length === 0 || sport === "tennis") {
        return "";
    }

    return `https://site.web.api.espn.com/apis/v2/sports/${paths[0]}/standings?region=us&lang=en&contentorigin=espn&season=${espnSeasonYear(paths[0])}`;
}

function espnPathsForSport(sport, leagueCode) {
    if (sport === "football" || sport === "soccer") {
        return espnSoccerPaths(leagueCode);
    }

    const sportPaths = {
        "american-football": ["football/nfl"],
        "baseball": ["baseball/mlb"],
        "basketball": ["basketball/nba"],
        "hockey": ["hockey/nhl"],
        "tennis": ["tennis/atp", "tennis/wta"]
    };

    return sportPaths[sport] || [];
}

function espnSoccerPaths(leagueCode) {
    const leaguePaths = {
        "BL1": ["soccer/ger.1"],
        "BSA": ["soccer/bra.1"],
        "CL": ["soccer/uefa.champions"],
        "DED": ["soccer/ned.1"],
        "EC": ["soccer/uefa.euro"],
        "ELC": ["soccer/eng.2"],
        "FL1": ["soccer/fra.1"],
        "PD": ["soccer/esp.1"],
        "PL": ["soccer/eng.1"],
        "PPL": ["soccer/por.1"],
        "SA": ["soccer/ita.1"],
        "WC": ["soccer/fifa.world"]
    };

    return leaguePaths[String(leagueCode || "PL").trim().toUpperCase()] || leaguePaths.PL;
}

function espnSeasonYear(path) {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth();
    const fallToSpring = path.indexOf("soccer/") === 0 || path === "basketball/nba" || path === "basketball/wnba" || path === "hockey/nhl";
    return fallToSpring && month < 6 ? year - 1 : year;
}

function espnLeagueName(payload, fallback) {
    const leagues = Array.isArray(payload && payload.leagues) ? payload.leagues : [];
    if (leagues.length === 0) {
        return fallback;
    }

    return stringValue(leagues[0].abbreviation || leagues[0].name || fallback);
}

function espnCompetitor(competitors, homeAway, fallbackIndex) {
    const matched = competitors.find(competitor => competitor.homeAway === homeAway);
    if (matched) {
        return matched;
    }

    const sorted = competitors.slice().sort((left, right) => numberValue(left.order) - numberValue(right.order));
    return sorted[fallbackIndex] || {};
}

function espnCompetitorName(competitor) {
    const team = competitor.team || {};
    const athlete = competitor.athlete || {};
    const roster = competitor.roster || {};
    return stringValue(team.shortDisplayName || team.displayName || team.name || athlete.shortName || athlete.displayName || athlete.fullName || roster.shortDisplayName || roster.displayName);
}

function espnCompetitorAliases(competitor) {
    const team = competitor.team || {};
    const athlete = competitor.athlete || {};
    const roster = competitor.roster || {};
    const candidates = [
        team.displayName,
        team.shortDisplayName,
        team.name,
        team.location,
        team.abbreviation,
        athlete.displayName,
        athlete.shortName,
        athlete.fullName,
        roster.displayName,
        roster.shortDisplayName
    ];
    return uniqueValues(candidates.map(stringValue).filter(value => value.length > 0));
}

function espnCompetitorLogo(competitor) {
    return espnLogo(competitor.team || competitor.athlete || {});
}

function espnLogo(item) {
    if (!item || typeof item !== "object") {
        return "";
    }

    if (item.logo) {
        return stringValue(item.logo);
    }

    if (item.headshot) {
        return stringValue(item.headshot);
    }

    const logos = Array.isArray(item.logos) ? item.logos : [];
    return logos.length > 0 ? stringValue(logos[0].href) : "";
}

function espnStatus(status) {
    const type = status.type || {};
    const state = stringValue(type.state).toLowerCase();
    const completed = Boolean(type.completed);
    const detail = stringValue(type.shortDetail || type.detail || status.displayClock || "");

    if (completed || state === "post") {
        return { label: "Finished", detail: "FT", scheduled: false };
    }

    if (state === "in" || state === "live") {
        return { label: "Live", detail: detail || "Live", scheduled: false };
    }

    return { label: "Upcoming", detail, scheduled: true };
}

function espnStat(stats, names) {
    const normalized = names.map(name => name.toLowerCase());
    for (let index = 0; index < stats.length; index += 1) {
        const stat = stats[index];
        const name = stringValue(stat.name || stat.type).toLowerCase();
        if (normalized.indexOf(name) >= 0) {
            return stat.value !== undefined ? stat.value : stat.displayValue;
        }
    }

    return 0;
}

function espnForm(entry) {
    const stats = Array.isArray(entry && entry.stats) ? entry.stats : [];
    const value = espnStat(stats, ["form", "streak", "lastFive", "lastfive"]);
    if (value)
        return stringValue(value);

    return stringValue(entry && (entry.form || entry.streak));
}

function statMap(stats) {
    const map = {};
    if (!Array.isArray(stats)) {
        return map;
    }

    stats.forEach(stat => {
        const name = stringValue(stat.name);
        if (name.length > 0) {
            map[name] = numberValue(stat.value !== undefined ? stat.value : stat.displayValue);
        }
    });
    return map;
}

function statValue(stats, name) {
    return stats[name] !== undefined ? stats[name] : 0;
}

function shotsOffTarget(stats) {
    return Math.max(0, statValue(stats, "totalShots") - statValue(stats, "shotsOnTarget") - statValue(stats, "blockedShots"));
}

function addStatRow(rows, label, homeValue, awayValue) {
    const home = Number(homeValue);
    const away = Number(awayValue);
    const total = Math.max(1, home + away);
    if (home === 0 && away === 0) {
        return;
    }

    rows.push({
        label,
        homeValue: formattedStatValue(home),
        awayValue: formattedStatValue(away),
        homeRatio: home / total,
        awayRatio: away / total,
        homeHighlight: home > away,
        awayHighlight: away > home
    });
}

function formattedStatValue(value) {
    return Number.isInteger(value) ? String(value) : value.toFixed(1);
}

function stripTrailingSlash(value) {
    return String(value).replace(/\/+$/, "");
}

function teamName(team) {
    if (typeof team === "string") {
        return team;
    }

    return value(team, ["name", "title", "shortName", "displayName"]);
}

function teamFromTitle(title, index) {
    const parts = stringValue(title).split(/\s+vs\.?\s+|\s+-\s+/i);
    return parts.length > index ? parts[index].trim() : "";
}

function value(object, keys) {
    if (!object || typeof object !== "object") {
        return "";
    }

    for (let index = 0; index < keys.length; index += 1) {
        const candidate = object[keys[index]];
        if (candidate !== undefined && candidate !== null && String(candidate).length > 0) {
            return candidate;
        }
    }

    return "";
}

function statusText(status) {
    if (!status || typeof status === "string") {
        return stringValue(status || "Live");
    }

    return stringValue(status.name || status.description || status.type || "Live");
}

function stringValue(value) {
    if (value === undefined || value === null) {
        return "";
    }

    return String(value);
}

function numberValue(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
}

function statusFromDate(timestamp) {
    if (timestamp <= 0) {
        return { label: "Scheduled", detail: "" };
    }

    const now = Date.now();
    const liveWindowMs = 3 * 60 * 60 * 1000;
    if (now >= timestamp && now <= timestamp + liveWindowMs) {
        return { label: "Live", detail: "Live" };
    }

    if (now > timestamp + liveWindowMs) {
        return { label: "Finished", detail: "FT" };
    }

    return { label: "Upcoming", detail: formatStartTime(timestamp) };
}

function formatStartTime(timestamp) {
    const date = new Date(timestamp);
    const today = new Date();
    const tomorrow = new Date();
    tomorrow.setDate(today.getDate() + 1);

    const time = pad(date.getHours()) + ":" + pad(date.getMinutes());
    if (sameDay(date, today)) {
        return time;
    }

    if (sameDay(date, tomorrow)) {
        return "Tomorrow " + time;
    }

    return pad(date.getDate()) + "." + pad(date.getMonth() + 1) + " " + time;
}

function sameDay(left, right) {
    return left.getFullYear() === right.getFullYear() &&
        left.getMonth() === right.getMonth() &&
        left.getDate() === right.getDate();
}

function pad(value) {
    return value < 10 ? "0" + value : String(value);
}
