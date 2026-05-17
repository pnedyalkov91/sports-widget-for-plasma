/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library
.import "providers/ProviderCatalog.js" as ProviderCatalog

const REQUEST_TIMEOUT_MS = 12000;
const SOFASCORE_API_BASE_URL = "https://api.sofascore.com/api/v1";
const THESPORTSDB_API_BASE_URL = "https://www.thesportsdb.com/api/v1/json/3";

const SOFASCORE_TOURNAMENTS = {
    "bulgarian-first-league": { id: 247, label: "Bulgarian First League" }
};

const THESPORTSDB_LEAGUES = {
    "bulgarian-first-league": { id: "4626", label: "Bulgarian First League" }
};

function fetchLiveScores(options, onSuccess, onError) {
    const sports = normalizeSports(options.sports);

    if (sports.length === 0) {
        onSuccess([]);
        return;
    }

    const provider = "sportscore";

    function fetchWidgetApi() {
        fetchProviderMatches(provider, "live", Object.assign({}, options, {
            provider,
            baseUrl: ProviderCatalog.defaultBaseUrl(provider)
        }), matches => {
            onSuccess(matches.filter(isLiveMatch));
        }, onError);
    }

    if (isFootballSelection(options)) {
        fetchSportScoreLivePage(options, matches => {
            if (matches.length > 0) {
                onSuccess(matches);
                return;
            }

            fetchWidgetApi();
        }, fetchWidgetApi);
        return;
    }

    fetchWidgetApi();
}

function fetchLeagueTable(options, onSuccess, onError) {
    const provider = "sportscore";
    fetchProviderTable(provider, Object.assign({}, options, {
        provider,
        baseUrl: ProviderCatalog.defaultBaseUrl(provider)
    }), onSuccess, onError);
}

function fetchScoresFixtures(options, onSuccess, onError) {
    const provider = "sportscore";

    function finish(fixtures) {
        if (fixtures.length > 0) {
            onSuccess(fixtures);
            return;
        }

        fetchFallbackFixtures(options, onSuccess, onError);
    }

    function fail(message) {
        fetchFallbackFixtures(options, onSuccess, fallbackMessage => {
            onError(fallbackMessage || message);
        });
    }

    if (canFetchSportScoreTeamFixtures(options)) {
        fetchSportScoreTeamFixtures(options, fixtures => {
            if (fixtures.length > 0) {
                onSuccess(fixtures);
                return;
            }

            fetchSportScoreCompetitionFixturesOrProvider(options, provider, finish, fail);
        }, () => {
            fetchSportScoreCompetitionFixturesOrProvider(options, provider, finish, fail);
        });
        return;
    }

    fetchSportScoreCompetitionFixturesOrProvider(options, provider, finish, fail);
}

function fetchSportScoreCompetitionFixturesOrProvider(options, provider, onSuccess, onError) {
    if (canFetchSportScoreCompetitionFixtures(options)) {
        fetchSportScoreCompetitionFixtures(options, fixtures => {
            if (fixtures.length > 0) {
                onSuccess(fixtures);
                return;
            }

            fetchProviderMatches(provider, "fixtures", Object.assign({}, options, {
                provider,
                baseUrl: ProviderCatalog.defaultBaseUrl(provider)
            }), onSuccess, onError);
        }, () => {
            fetchProviderMatches(provider, "fixtures", Object.assign({}, options, {
                provider,
                baseUrl: ProviderCatalog.defaultBaseUrl(provider)
            }), onSuccess, onError);
        });
        return;
    }

    fetchProviderMatches(provider, "fixtures", Object.assign({}, options, {
        provider,
        baseUrl: ProviderCatalog.defaultBaseUrl(provider)
    }), onSuccess, onError);
}

function fetchLeagueForm(options, onSuccess, onError) {
    const sport = normalizeSports(options.sports)[0] || "football";

    function canUseSportScore() {
        const league = String(options.league || "").trim().toUpperCase();
        const rows = Array.isArray(options.tableRows) ? options.tableRows : [];
        return (sport === "football" || sport === "soccer") && ProviderCatalog.sportScoreSlug(league).length > 0 && rows.length > 0;
    }

    function fetchFromFixtures() {
        fetchScoresFixtures(options, matches => {
            onSuccess(formByTeam(matches));
        }, onError);
    }

    function fetchFromSportScore() {
        fetchSportScoreTeamForms(options, onSuccess, fetchFromFixtures);
    }

    if (canUseSportScore()) {
        fetchFromSportScore();
        return;
    }

    fetchFromFixtures();
}

function fetchSportScoreTeamForms(options, onSuccess, onError) {
    const sport = normalizeSports(options.sports)[0] || "football";
    const league = String(options.league || "").trim().toUpperCase();
    const rows = Array.isArray(options.tableRows) ? options.tableRows.map(row => {
        const copy = Object.assign({}, row);
        copy.teamSlug = sportScoreTeamSlug(row);
        return copy;
    }).filter(row => stringValue(row.teamSlug).length > 0 && stringValue(row.team).length > 0) : [];
    if ((sport !== "football" && sport !== "soccer") || ProviderCatalog.sportScoreSlug(league).length === 0 || rows.length === 0) {
        onError("SportScore team form is not available for this selection.");
        return;
    }

    let pending = rows.length;
    let forms = {};
    let errors = [];
    const baseUrl = stripTrailingSlash(ProviderCatalog.defaultBaseUrl("sportscore"));

    rows.forEach(row => {
        const url = `${baseUrl}/team/?sport=football&slug=${encodeURIComponent(row.teamSlug)}&limit=5`;
        requestJson(url, payload => {
            const form = sportScoreTeamForm(payload, row.team);
            if (form.length > 0)
                forms[normalizedText(row.team)] = form;

            pending -= 1;
            if (pending === 0) {
                if (Object.keys(forms).length > 0) {
                    onSuccess(forms);
                } else {
                    onError(errors.join(", ") || "SportScore returned no team form.");
                }
            }
        }, message => {
            if (!isHttpNotFound(message))
                errors.push(`${row.team}: ${message}`);

            pending -= 1;
            if (pending === 0) {
                if (Object.keys(forms).length > 0) {
                    onSuccess(forms);
                } else {
                    onError(errors.join(", "));
                }
            }
        });
    });
}

function canFetchSportScoreTeamFixtures(options) {
    const sport = normalizeSports(options.sports)[0] || "football";
    const league = ProviderCatalog.sportScoreSlug(options.league);
    const rows = Array.isArray(options.tableRows) ? options.tableRows : [];
    return (sport === "football" || sport === "soccer") && league.length > 0 && rows.some(row => sportScoreTeamSlug(row).length > 0);
}

function fetchSportScoreTeamFixtures(options, onSuccess, onError) {
    const rows = (Array.isArray(options.tableRows) ? options.tableRows : []).map(row => {
        const copy = Object.assign({}, row);
        copy.teamSlug = sportScoreTeamSlug(row);
        return copy;
    }).filter(row => stringValue(row.teamSlug).length > 0 && stringValue(row.team).length > 0).slice(0, 24);

    if (rows.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = rows.length;
    let matches = [];
    let errors = [];
    const baseUrl = stripTrailingSlash(ProviderCatalog.defaultBaseUrl("sportscore"));

    rows.forEach(row => {
        const url = `${baseUrl}/team/?sport=football&slug=${encodeURIComponent(row.teamSlug)}&limit=20&src=sports-widget-for-plasma`;
        requestJson(url, payload => {
            matches = matches.concat(ProviderCatalog.normalizeFixtures("sportscore", payload, "football"));
            pending -= 1;
            if (pending === 0)
                finishTeamFixtures(matches, errors, options, onSuccess, onError);
        }, message => {
            if (!isHttpNotFound(message))
                errors.push(`${row.team}: ${message}`);

            pending -= 1;
            if (pending === 0)
                finishTeamFixtures(matches, errors, options, onSuccess, onError);
        });
    });
}

function finishTeamFixtures(matches, errors, options, onSuccess, onError) {
    const rows = dedupeMatches(filterMatchesForSelection(matches, options));
    if (rows.length > 0 || errors.length === 0) {
        onSuccess(sortMatches(rows));
    } else {
        onError(errors.join(", "));
    }
}

function canFetchSportScoreCompetitionFixtures(options) {
    const sport = normalizeSports(options.sports)[0] || "football";
    const country = String(options.country || "").trim();
    const league = ProviderCatalog.sportScoreSlug(options.league);
    return (sport === "football" || sport === "soccer") && country.length > 0 && league.length > 0;
}

function fetchSportScoreCompetitionFixtures(options, onSuccess, onError) {
    const country = String(options.country || "england").trim().toLowerCase();
    const league = ProviderCatalog.sportScoreSlug(options.league);
    const leagueLabel = ProviderCatalog.leagueLabel(options.league);
    const sourceUrl = country === "world" ? "https://sportscore.com/football/competitions/" : `https://sportscore.com/football/country/${encodeURIComponent(country)}/`;

    requestText(sourceUrl, html => {
        const path = sportScoreCompetitionPath(html, country, league);
        if (path.length === 0) {
            onSuccess([]);
            return;
        }

        requestText(`https://sportscore.com${path}`, page => {
            onSuccess(normalizeSportScoreFixturePage(page, leagueLabel));
        }, onError);
    }, onError);
}

function fetchFallbackFixtures(options, onSuccess, onError) {
    let errors = [];

    function remember(message) {
        if (String(message || "").length > 0)
            errors.push(message);
    }

    function fetchFromTheSportsDB() {
        if (!canFetchTheSportsDBFixtures(options)) {
            onError(errors.join(", ") || "No fallback fixture provider is available for this league.");
            return;
        }

        fetchTheSportsDBFixtures(options, fixtures => {
            if (fixtures.length > 0) {
                onSuccess(fixtures);
                return;
            }

            onError(errors.join(", ") || "Fallback providers returned no fixtures.");
        }, message => {
            remember(message);
            onError(errors.join(", "));
        });
    }

    if (canFetchSofaScoreFixtures(options)) {
        fetchSofaScoreFixtures(options, fixtures => {
            if (fixtures.length > 0) {
                onSuccess(fixtures);
                return;
            }

            fetchFromTheSportsDB();
        }, message => {
            remember(message);
            fetchFromTheSportsDB();
        });
        return;
    }

    fetchFromTheSportsDB();
}

function canFetchSofaScoreFixtures(options) {
    return fallbackLeague(SOFASCORE_TOURNAMENTS, options).id > 0 && isFootballSelection(options);
}

function fetchSofaScoreFixtures(options, onSuccess, onError) {
    const league = fallbackLeague(SOFASCORE_TOURNAMENTS, options);
    requestJson(`${SOFASCORE_API_BASE_URL}/unique-tournament/${league.id}/seasons`, payload => {
        const season = arrayValue(payload && payload.seasons)[0];
        const seasonId = numberValue(season && season.id);
        if (seasonId <= 0) {
            onSuccess([]);
            return;
        }

        fetchSofaScoreFixturePage(league, seasonId, 0, [], onSuccess, onError);
    }, onError);
}

function fetchSofaScoreFixturePage(league, seasonId, page, matches, onSuccess, onError) {
    const url = `${SOFASCORE_API_BASE_URL}/unique-tournament/${league.id}/season/${seasonId}/events/next/${page}`;
    requestJson(url, payload => {
        const rows = matches.concat(arrayValue(payload && payload.events).map(event => normalizeSofaScoreFixture(event, league)).filter(hasTeams));
        if (payload && payload.hasNextPage && page < 2) {
            fetchSofaScoreFixturePage(league, seasonId, page + 1, rows, onSuccess, onError);
            return;
        }

        onSuccess(sortMatches(dedupeMatches(rows)));
    }, onError);
}

function normalizeSofaScoreFixture(event, league) {
    const timestamp = numberValue(event && event.startTimestamp) * 1000;
    const homeTeam = event && event.homeTeam ? event.homeTeam : {};
    const awayTeam = event && event.awayTeam ? event.awayTeam : {};
    const status = event && event.status ? event.status : {};
    const homeScore = event && event.homeScore ? event.homeScore : {};
    const awayScore = event && event.awayScore ? event.awayScore : {};
    return {
        id: "sofascore-" + stringValue(event && event.id),
        sport: "football",
        league: league.label,
        homeTeam: stringValue(homeTeam.shortName || homeTeam.name),
        awayTeam: stringValue(awayTeam.shortName || awayTeam.name),
        homeScore: sofaScoreDisplayScore(homeScore),
        awayScore: sofaScoreDisplayScore(awayScore),
        status: statusLabel(status.description || status.type),
        minute: "",
        startTime: timestamp > 0 ? formatStartTime(timestamp) : "",
        timestamp,
        matchday: event && event.roundInfo && event.roundInfo.round ? "Round " + event.roundInfo.round : "",
        stadium: sofaScoreStadium(event && event.venue),
        homeBadge: sofaScoreTeamImage(homeTeam.id),
        awayBadge: sofaScoreTeamImage(awayTeam.id),
        poster: "",
        popular: false
    };
}

function sofaScoreDisplayScore(score) {
    if (score === undefined || score === null)
        return "";

    if (score.display !== undefined && score.display !== null)
        return stringValue(score.display);

    if (score.current !== undefined && score.current !== null)
        return stringValue(score.current);

    return "";
}

function sofaScoreStadium(venue) {
    if (!venue)
        return "";

    return stringValue(venue.stadium && venue.stadium.name) || stringValue(venue.name);
}

function sofaScoreTeamImage(teamId) {
    const id = numberValue(teamId);
    return id > 0 ? `${SOFASCORE_API_BASE_URL}/team/${id}/image` : "";
}

function canFetchTheSportsDBFixtures(options) {
    return stringValue(fallbackLeague(THESPORTSDB_LEAGUES, options).id).length > 0 && isFootballSelection(options);
}

function fetchTheSportsDBFixtures(options, onSuccess, onError) {
    const league = fallbackLeague(THESPORTSDB_LEAGUES, options);
    requestJson(`${THESPORTSDB_API_BASE_URL}/eventsnextleague.php?id=${encodeURIComponent(league.id)}`, payload => {
        onSuccess(sortMatches(dedupeMatches(arrayValue(payload && payload.events).map(event => normalizeTheSportsDBFixture(event, league)).filter(hasTeams))));
    }, onError);
}

function normalizeTheSportsDBFixture(event, league) {
    const timestamp = Date.parse(event && event.strTimestamp ? event.strTimestamp + "Z" : "");
    return {
        id: "thesportsdb-" + stringValue(event && event.idEvent),
        sport: "football",
        league: stringValue(event && event.strLeague) || league.label,
        homeTeam: stringValue(event && event.strHomeTeam),
        awayTeam: stringValue(event && event.strAwayTeam),
        homeScore: stringValue(event && event.intHomeScore),
        awayScore: stringValue(event && event.intAwayScore),
        status: statusLabel(event && event.strStatus),
        minute: "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: event && event.intRound ? "Round " + event.intRound : "",
        stadium: stringValue(event && event.strVenue),
        homeBadge: stringValue(event && event.strHomeTeamBadge),
        awayBadge: stringValue(event && event.strAwayTeamBadge),
        poster: stringValue(event && (event.strPoster || event.strThumb)),
        popular: false
    };
}

function fallbackLeague(map, options) {
    const slug = ProviderCatalog.sportScoreSlug(options.league);
    return map[slug] || {};
}

function isFootballSelection(options) {
    const sport = normalizeSports(options.sports)[0] || "football";
    return sport === "football" || sport === "soccer";
}

function fetchMatchStats(options, onSuccess, onError) {
    onSuccess([]);
}

function fetchProviderMatches(provider, type, options, onSuccess, onError) {
    if (missingProviderKey(provider, options, onError))
        return;

    const requests = type === "fixtures" ? ProviderCatalog.fixtureRequests(provider, options) : ProviderCatalog.liveRequests(provider, options);
    fetchProviderRequests(provider, requests, options, (payload, item) => {
        return type === "fixtures" ? ProviderCatalog.normalizeFixtures(provider, payload, item.sport) : ProviderCatalog.normalizeMatches(provider, payload, item.sport);
    }, matches => {
        onSuccess(sortMatches(filterMatchesForSelection(matches, options)));
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
            if (!item.optional || !isHttpNotFound(message))
                errors.push(`${ProviderCatalog.displayName(provider)}: ${message}`);

            pending -= 1;
            if (pending === 0) {
                if (rows.length > 0 || errors.length === 0) {
                    onSuccess(rows);
                } else {
                    onError(errors.join(", "));
                }
            }
        });
    });
}

function isHttpNotFound(message) {
    return String(message || "").indexOf("HTTP 404") >= 0;
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
    requestTextWithHeaders(url, headers, responseText => {
        try {
            onSuccess(JSON.parse(responseText));
        } catch (error) {
            onError(String(error));
        }
    }, onError);
}

function requestText(url, onSuccess, onError) {
    requestTextWithHeaders(url, { "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" }, onSuccess, onError);
}

function requestTextWithHeaders(url, headers, onSuccess, onError) {
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
            onSuccess(request.responseText);
        } else {
            onError(`HTTP ${request.status}`);
        }
    }

    request.open("GET", url);
    request.timeout = REQUEST_TIMEOUT_MS;
    if (!hasHeader(headers, "Accept"))
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

function fetchSportScoreLivePage(options, onSuccess, onError) {
    function fetchGlobalLive() {
        requestText(cacheBustedUrl("https://sportscore.com/football/live/"), html => {
            try {
                onSuccess(normalizeSportScoreLivePage(html, options));
            } catch (error) {
                onError(String(error));
            }
        }, onError);
    }

    if (canFetchSportScoreCompetitionFixtures(options)) {
        const country = String(options.country || "england").trim().toLowerCase();
        const league = ProviderCatalog.sportScoreSlug(options.league);
        const sourceUrl = country === "world" ? "https://sportscore.com/football/competitions/" : `https://sportscore.com/football/country/${encodeURIComponent(country)}/`;

        requestText(cacheBustedUrl(sourceUrl), html => {
            const path = sportScoreCompetitionPath(html, country, league);
            if (path.length === 0) {
                fetchGlobalLive();
                return;
            }

            requestText(cacheBustedUrl(`https://sportscore.com${path}`), page => {
                try {
                    const rows = normalizeSportScoreLivePage(page, options);
                    if (rows.length > 0) {
                        onSuccess(rows);
                    } else {
                        fetchGlobalLive();
                    }
                } catch (error) {
                    fetchGlobalLive();
                }
            }, fetchGlobalLive);
        }, fetchGlobalLive);
        return;
    }

    fetchGlobalLive();
}

function normalizeSportScoreLivePage(html, options) {
    const section = sportScoreLiveSection(html);
    const schema = sportScoreLiveSchemaMap(html);
    let rows = normalizeSportScoreGlobalLiveRows(section, schema);
    if (rows.length === 0)
        rows = normalizeSportScoreCompetitionLiveRows(section, schema);

    return sortMatches(dedupeMatches(filterMatchesForSelection(rows, options).filter(isLiveMatch)));
}

function normalizeSportScoreGlobalLiveRows(section, schema) {
    const pattern = /<div class="d-flex align-items-center"\s+data-match-id="([^"]+)"\s+data-live-row>([\s\S]*?)(?=\n\s*<div class="d-flex align-items-center"\s+data-match-id="[^"]+"\s+data-live-row>|\n\s*<div class="table-active d-flex align-items-center">|\n\s*<\/section>|$)/g;
    let rows = [];
    let match = pattern.exec(section);
    while (match) {
        const context = section.slice(Math.max(0, match.index - 6000), match.index);
        const row = normalizeSportScoreLiveRow(match[1], match[0], context, schema);
        if (hasTeams(row))
            rows.push(row);

        match = pattern.exec(section);
    }
    return rows;
}

function normalizeSportScoreCompetitionLiveRows(section, schema) {
    const pattern = /<div class="football-match-table-container w-100 nostyle sc-row-stretched">([\s\S]*?)(?=\n\s*<div class="football-match-table-container w-100 nostyle sc-row-stretched">|\n\s*<h2 class="match-state-header|$)/g;
    let rows = [];
    let match = pattern.exec(section);
    while (match) {
        const context = section.slice(Math.max(0, match.index - 2000), match.index);
        const row = normalizeSportScoreLiveRow("", match[0], context, schema);
        if (hasTeams(row))
            rows.push(row);

        match = pattern.exec(section);
    }
    return rows;
}

function normalizeSportScoreLiveRow(id, block, context, schema) {
    const label = sportScoreLiveAriaLabel(block);
    const labelParts = label.split(" — ");
    const teamLabel = htmlDecode(labelParts[0] || "");
    const teamParts = splitSportScoreTeams(teamLabel);
    const path = sportScoreMatchPath(block);
    const details = schema[path] || {};
    const logos = sportScoreLiveLogos(block);
    const timestamp = Date.parse(htmlAttribute(block, "data-utc"));
    const minute = htmlText(sportScoreLiveValue(block, "status"));
    const league = htmlDecode(labelParts.slice(1).join(" — ")) || sportScoreLastCompetition(context);

    return {
        id: "sportscore-live-" + stringValue(id || path || teamLabel),
        sport: "football",
        league,
        homeTeam: teamParts.home,
        awayTeam: teamParts.away,
        homeScore: htmlText(sportScoreLiveValue(block, "home-score")),
        awayScore: htmlText(sportScoreLiveValue(block, "away-score")),
        status: "Live",
        minute,
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: sportScoreLastRound(context),
        stadium: stringValue(details.stadium),
        homeBadge: logos[0] || stringValue(details.homeBadge),
        awayBadge: logos[1] || stringValue(details.awayBadge),
        poster: "",
        popular: false
    };
}

function sportScoreLiveSection(html) {
    const marker = 'data-section="live"';
    const start = stringValue(html).indexOf(marker);
    if (start < 0)
        return sportScoreCompetitionLiveSection(html);

    const nextUpcoming = html.indexOf('data-section="upcoming"', start + marker.length);
    const nextFinished = html.indexOf('data-section="finished"', start + marker.length);
    const candidates = [nextUpcoming, nextFinished].filter(index => index > start);
    const end = candidates.length > 0 ? Math.min.apply(Math, candidates) : html.length;
    return html.slice(start, end);
}

function sportScoreCompetitionLiveSection(html) {
    const value = stringValue(html);
    const headerPattern = /<h2 class="match-state-header[^"]*is-live[^"]*"[\s\S]*?<\/h2>/;
    const match = headerPattern.exec(value);
    if (!match)
        return value;

    const start = match.index;
    const next = value.indexOf('<h2 class="match-state-header', start + match[0].length);
    return next > start ? value.slice(start, next) : value.slice(start);
}

function sportScoreLiveAriaLabel(block) {
    const stretched = /class="sc-stretched-link"[\s\S]{0,240}?aria-label="([^"]+)"/.exec(block);
    if (stretched)
        return htmlDecode(stretched[1]);

    return htmlAttribute(block, "aria-label");
}

function splitSportScoreTeams(label) {
    const separators = [" vs ", " v "];
    for (let index = 0; index < separators.length; index += 1) {
        const separator = separators[index];
        const position = label.indexOf(separator);
        if (position > 0) {
            return {
                home: label.slice(0, position).trim(),
                away: label.slice(position + separator.length).trim()
            };
        }
    }

    return { home: "", away: "" };
}

function sportScoreLiveValue(block, name) {
    const pattern = new RegExp('data-live="' + escapeRegExp(name) + '"[^>]*>([\\s\\S]*?)<\\/[^>]+>', "i");
    const match = pattern.exec(block);
    return match ? match[1] : "";
}

function sportScoreLiveLogos(block) {
    let result = [];
    let seen = {};
    const pattern = /<img\b[^>]*>/g;
    let match = pattern.exec(block);
    while (match) {
        const tag = match[0];
        const alt = normalizedText(htmlAttribute(tag, "alt"));
        const source = htmlAttribute(tag, "src");
        if (alt.indexOf("logo") >= 0 && source.length > 0 && !seen[source]) {
            seen[source] = true;
            result.push(source);
        }

        match = pattern.exec(block);
    }
    return result;
}

function sportScoreMatchPath(block) {
    const match = /href="(\/football\/match\/[^"]+)"/.exec(block);
    return match ? match[1] : "";
}

function sportScoreLastCompetition(html) {
    const pattern = /<a class="competition-name[^"]*"[^>]*>([\s\S]*?)<\/a>/g;
    let result = "";
    let match = pattern.exec(html);
    while (match) {
        result = htmlText(match[1]);
        match = pattern.exec(html);
    }
    return result;
}

function sportScoreLastRound(html) {
    const pattern = /class="competition-round[^"]*"[^>]*>([\s\S]*?)<\/span>/g;
    let result = "";
    let match = pattern.exec(html);
    while (match) {
        result = htmlText(match[1]);
        match = pattern.exec(html);
    }
    return result;
}

function sportScoreLiveSchemaMap(html) {
    let result = {};
    const lists = sportScoreJsonLdLists(html);
    lists.forEach(list => {
        if (normalizedText(list && list.name).indexOf("live football") < 0)
            return;

        arrayValue(list.itemListElement).forEach(item => {
            const event = item && item.item ? item.item : {};
            const path = sportScorePathFromUrl(event.url || event["@id"]);
            if (path.length === 0)
                return;

            const images = arrayValue(event.image);
            result[path] = {
                stadium: schemaPlaceName(event.location),
                homeBadge: stringValue(images[0]),
                awayBadge: stringValue(images[1])
            };
        });
    });
    return result;
}

function sportScorePathFromUrl(url) {
    const value = stringValue(url);
    const match = /^https?:\/\/[^/]+(\/football\/match\/[^?#]+\/?)/.exec(value);
    return match ? match[1] : value;
}

function schemaPlaceName(place) {
    if (!place)
        return "";

    if (typeof place === "string")
        return place;

    return stringValue(place.name);
}

function cacheBustedUrl(url) {
    const separator = stringValue(url).indexOf("?") >= 0 ? "&" : "?";
    return url + separator + "_=" + Date.now();
}

function hasHeader(headers, headerName) {
    const normalized = String(headerName || "").toLowerCase();
    return Object.keys(headers || {}).some(header => header.toLowerCase() === normalized);
}

function sportScoreCompetitionPath(html, country, league) {
    const escapedCountry = escapeRegExp(country);
    const escapedLeague = escapeRegExp(league);
    const exact = new RegExp(`href="(/football/competition/${escapedCountry}/${escapedLeague}/[^"]+/)"`);
    let match = exact.exec(html);
    if (match)
        return match[1];

    const fallback = new RegExp(`href="(/football/competition/[^/]+/${escapedLeague}/[^"]+/)"`);
    match = fallback.exec(html);
    return match ? match[1] : "";
}

function normalizeSportScoreFixturePage(html, leagueLabel) {
    const lists = sportScoreJsonLdLists(html);
    let selected = null;
    for (let index = 0; index < lists.length; index += 1) {
        const name = normalizedText(lists[index].name);
        if (name.indexOf("upcoming fixtures") >= 0) {
            selected = lists[index];
            break;
        }
    }

    if (!selected)
        return [];

    const listItems = arrayValue(selected.itemListElement);
    return listItems.map(item => normalizeSchemaFixture(item && item.item, leagueLabel))
        .filter(hasTeams)
        .sort((left, right) => numberValue(left.timestamp) - numberValue(right.timestamp));
}

function sportScoreJsonLdLists(html) {
    let result = [];
    const pattern = /<script type="application\/ld\+json">([\s\S]*?)<\/script>/g;
    let match = pattern.exec(html);
    while (match) {
        try {
            collectJsonLdLists(JSON.parse(match[1]), result);
        } catch (error) {
        }
        match = pattern.exec(html);
    }
    return result;
}

function collectJsonLdLists(value, result) {
    if (!value)
        return;

    if (Array.isArray(value)) {
        value.forEach(item => collectJsonLdLists(item, result));
        return;
    }

    if (typeof value !== "object")
        return;

    if (value["@type"] === "ItemList")
        result.push(value);

    collectJsonLdLists(value["@graph"], result);
}

function normalizeSchemaFixture(event, leagueLabel) {
    if (!event)
        return {};

    const timestamp = Date.parse(event.startDate || "");
    const images = arrayValue(event.image);
    return {
        id: stringValue(event["@id"] || event.url),
        sport: "football",
        league: leagueLabel,
        homeTeam: schemaTeamName(event.homeTeam),
        awayTeam: schemaTeamName(event.awayTeam),
        homeScore: "",
        awayScore: "",
        status: "Upcoming",
        minute: "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : stringValue(event.startDate),
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: "",
        homeBadge: stringValue(images[0]),
        awayBadge: stringValue(images[1]),
        poster: "",
        popular: false
    };
}

function schemaTeamName(team) {
    if (!team)
        return "";
    if (typeof team === "string")
        return team;
    return stringValue(team.name);
}

function escapeRegExp(value) {
    return String(value || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
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

function normalizeSportScoreMatch(match, sport) {
    const timestamp = Date.parse(match.time || match.date || "");
    return {
        sport: sport || "football",
        league: stringValue(match.competition),
        homeTeam: stringValue(match.home),
        awayTeam: stringValue(match.away),
        homeScore: stringValue(match.home_score),
        awayScore: stringValue(match.away_score),
        status: statusLabel(match.status_text || match.status),
        minute: "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        homeBadge: stringValue(match.home_logo),
        awayBadge: stringValue(match.away_logo),
        popular: false
    };
}

function sportScoreTeamForm(payload, teamName) {
    const scopedTeamName = stringValue(payload && payload.team && payload.team.name) || teamName;
    const matches = arrayValue(payload && payload.matches)
        .map(match => normalizeSportScoreMatch(match, "football"))
        .filter(match => match.status === "Finished" && Number.isFinite(Number(match.homeScore)) && Number.isFinite(Number(match.awayScore)))
        .slice(0, 5);
    let form = [];

    matches.forEach(match => {
        const home = sameTeamName(match.homeTeam, scopedTeamName) || sameTeamName(match.homeTeam, teamName);
        const away = sameTeamName(match.awayTeam, scopedTeamName) || sameTeamName(match.awayTeam, teamName);
        if (!home && !away)
            return;

        const goalsFor = home ? numberValue(match.homeScore) : numberValue(match.awayScore);
        const goalsAgainst = home ? numberValue(match.awayScore) : numberValue(match.homeScore);
        if (goalsFor > goalsAgainst) {
            form.push("W");
        } else if (goalsFor < goalsAgainst) {
            form.push("L");
        } else {
            form.push("D");
        }
    });

    return form.join(",");
}

function sportScoreTeamSlug(row) {
    const explicit = stringValue(row && row.teamSlug).trim();
    if (explicit.length > 0)
        return explicit;

    return normalizedText(row && row.team)
        .replace(/&/g, "and")
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "");
}

function dedupeMatches(matches) {
    let seen = {};
    let result = [];
    (Array.isArray(matches) ? matches : []).forEach(match => {
        const key = [
            normalizedText(match.league),
            normalizedText(match.homeTeam),
            normalizedText(match.awayTeam),
            String(match.timestamp || match.startTime || "")
        ].join("|");
        if (seen[key])
            return;

        seen[key] = true;
        result.push(match);
    });
    return result;
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

function isLiveMatch(match) {
    const status = normalizedText(match && match.status);
    if (status.indexOf("live") >= 0 || status.indexOf("in play") >= 0 || status.indexOf("in_play") >= 0 || status === "1h" || status === "2h" || status === "ht" || status.indexOf("half") >= 0)
        return true;

    if (status === "started" || /^\d+\+?$/.test(status))
        return true;

    if (/^q[1-4]$/.test(status) || status.indexOf("quarter") >= 0 || status.indexOf("period") >= 0 || status.indexOf("set ") >= 0)
        return true;

    if (status.indexOf("finish") >= 0 || status.indexOf("final") >= 0 || status === "ended" || status.indexOf("upcoming") >= 0 || status.indexOf("scheduled") >= 0 || status.indexOf("not started") >= 0)
        return false;

    return stringValue(match && match.homeScore).length > 0 && stringValue(match && match.awayScore).length > 0 && status.length > 0;
}

function filterMatchesForSelection(matches, options) {
    const sport = normalizeSports(options.sports)[0] || "football";
    if (sport !== "football" && sport !== "soccer")
        return matches;

    const league = ProviderCatalog.sportScoreSlug(options.league);
    if (league.length === 0)
        return matches;

    const label = ProviderCatalog.leagueLabel(options.league);
    const candidates = [league, label].map(normalizedText).filter(value => value.length > 0);
    if (candidates.length === 0)
        return matches;

    return matches.filter(match => {
        const matchLeague = normalizedText(match.league);
        if (matchLeague.length === 0)
            return true;

        for (let index = 0; index < candidates.length; index += 1) {
            if (matchLeague === candidates[index] || matchLeague.indexOf(candidates[index]) >= 0 || candidates[index].indexOf(matchLeague) >= 0)
                return true;
        }
        return false;
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

function sameTeamName(left, right) {
    const leftText = normalizedText(left);
    const rightText = normalizedText(right);
    if (leftText.length === 0 || rightText.length === 0)
        return false;

    if (leftText === rightText)
        return true;

    const leftAlias = teamAliasKey(left);
    const rightAlias = teamAliasKey(right);
    if (leftAlias.length > 0 && rightAlias.length > 0 && leftAlias === rightAlias)
        return true;

    const leftCompact = compactTeamName(left);
    const rightCompact = compactTeamName(right);
    return leftCompact.length > 0 && rightCompact.length > 0 && (leftCompact.indexOf(rightCompact) >= 0 || rightCompact.indexOf(leftCompact) >= 0);
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

function stripTrailingSlash(value) {
    return String(value).replace(/\/+$/, "");
}

function htmlAttribute(html, name) {
    const pattern = new RegExp(escapeRegExp(name) + '="([^"]*)"', "i");
    const match = pattern.exec(stringValue(html));
    return match ? htmlDecode(match[1]) : "";
}

function htmlText(html) {
    return htmlDecode(stringValue(html).replace(/<[^>]*>/g, " "))
        .replace(/\s+/g, " ")
        .trim();
}

function htmlDecode(value) {
    return stringValue(value)
        .replace(/&#x([0-9a-f]+);/gi, (match, code) => String.fromCharCode(parseInt(code, 16)))
        .replace(/&#(\d+);/g, (match, code) => String.fromCharCode(parseInt(code, 10)))
        .replace(/&nbsp;/g, " ")
        .replace(/&middot;/g, "·")
        .replace(/&amp;/g, "&")
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&apos;/g, "'");
}

function statusLabel(value) {
    const status = stringValue(value).toUpperCase();
    if (status.indexOf("LIVE") >= 0 || status.indexOf("IN_PLAY") >= 0 || status === "STARTED" || status.indexOf("1H") >= 0 || status.indexOf("2H") >= 0)
        return "Live";
    if (status.indexOf("FINISH") >= 0 || status === "ENDED" || status.indexOf("FT") >= 0 || status.indexOf("AET") >= 0)
        return "Finished";
    if (status.indexOf("SCHEDULE") >= 0 || status.indexOf("TIMED") >= 0 || status.indexOf("NOT_STARTED") >= 0 || status.indexOf("NOT STARTED") >= 0 || status.indexOf("UPCOMING") >= 0)
        return "Upcoming";
    return stringValue(value || "Upcoming");
}

function stringValue(value) {
    if (value === undefined || value === null) {
        return "";
    }

    return String(value);
}

function arrayValue(value) {
    return Array.isArray(value) ? value : [];
}

function hasTeams(match) {
    return stringValue(match && match.homeTeam).length > 0 && stringValue(match && match.awayTeam).length > 0;
}

function numberValue(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
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
