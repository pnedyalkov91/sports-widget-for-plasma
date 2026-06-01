/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library
.import "providers/ProviderCatalog.js" as ProviderCatalog

const REQUEST_TIMEOUT_MS = 65000;
const LIVE_CACHE_TTL_MS = 120000;
const RECENT_RESULTS_LIMIT = 40;
const RECENT_RESULTS_TEAM_LIMIT = 30;
const RECENT_RESULTS_ROUND_LIMIT = 6;
const FORM_RESULTS_LIMIT = 5;
const FORM_TEAM_MATCH_LIMIT = 30;
const FORM_CACHE_TTL_MS = 10 * 60 * 1000;
const ESPN_SOCCER_API_BASE_URL = "https://site.api.espn.com/apis/site/v2/sports/soccer";
const ESPN_SOCCER_COMPETITIONS_URL = "https://www.espn.com/soccer/competitions";
const SOFASCORE_API_BASE_URL = "https://api.sofascore.com/api/v1";
const THESPORTSDB_API_BASE_URL = "https://www.thesportsdb.com/api/v1/json/3";
const ESPN_LEAGUE_CATALOG_CACHE_TTL_MS = 12 * 60 * 60 * 1000;
let sportScoreLiveCache = {
    timestamp: 0,
    rows: []
};
let sofaScoreLeagueCache = {};
let sofaScoreTeamFormCache = {};
let theSportsDBLeagueCache = {};
let espnLeagueCatalogCache = {
    timestamp: 0,
    rows: []
};
let espnLeagueSlugCache = {};

const ESPN_SOCCER_LEAGUES = {
    "english-premier-league": "eng.1",
    "english-football-league-championship": "eng.2",
    "english-football-league-one": "eng.3",
    "english-football-league-two": "eng.4",
    "english-fa-cup": "eng.fa",
    "english-football-league-cup": "eng.league_cup",
    "spanish-la-liga": "esp.1",
    "spanish-segunda-division": "esp.2",
    "spanish-copa-del-rey": "esp.copa_del_rey",
    "italian-serie-a": "ita.1",
    "italian-serie-b": "ita.2",
    "french-ligue-1": "fra.1",
    "french-ligue-2": "fra.2",
    "bundesliga": "ger.1",
    "german-bundesliga-2": "ger.2",
    "german-dfb-pokal": "ger.dfb_pokal",
    "portuguese-primera-liga": "por.1",
    "uefa-champions-league": "uefa.champions",
    "uefa-europa-league": "uefa.europa",
    "uefa-europa-conference-league": "uefa.europa.conf",
    "fifa-world-cup": "fifa.world"
};

const SOFASCORE_TOURNAMENTS = {
    "english-premier-league": { id: 17, label: "Premier League" },
    "premier-league": { id: 17, label: "Premier League" },
    "bulgarian-cup": { id: 365, label: "Bulgarian Cup" },
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
        if (canFetchEspnFootball(options)) {
            let finished = false;
            let sportScoreDone = false;
            let sportScoreError = "";
            let espnDone = false;
            let espnMatches = [];

            function finishWith(matches) {
                if (finished)
                    return;

                finished = true;
                onSuccess(matches);
            }

            function finishWithError(message) {
                if (finished)
                    return;

                finished = true;
                onError(message);
            }

            function finishWhenBothFallbacksAreReady() {
                if (finished || !sportScoreDone || !espnDone)
                    return;

                if (espnMatches.length > 0) {
                    finishWith(espnMatches);
                    return;
                }

                if (sportScoreError.length > 0) {
                    finishWithError(sportScoreError);
                    return;
                }

                finishWith([]);
            }

            fetchEspnLiveScores(options, matches => {
                espnDone = true;
                espnMatches = matches;
                finishWhenBothFallbacksAreReady();
            }, () => {
                espnDone = true;
                espnMatches = [];
                finishWhenBothFallbacksAreReady();
            });

            fetchSportScoreLivePage(options, matches => {
                sportScoreDone = true;
                if (matches.length > 0) {
                    finishWith(matches);
                    return;
                }

                finishWhenBothFallbacksAreReady();
            }, message => {
                sportScoreDone = true;
                sportScoreError = message;
                finishWhenBothFallbacksAreReady();
            });
            return;
        }

        fetchSportScoreLivePage(options, matches => {
            if (matches.length > 0) {
                onSuccess(matches);
                return;
            }

            fetchEspnLiveScores(options, onSuccess, () => {
                onSuccess([]);
            });
        }, message => {
            fetchEspnLiveScores(options, onSuccess, () => {
                onError(message);
            });
        });
        return;
    }

    fetchWidgetApi();
}

function fetchLiveMatchDetails(options, onSuccess, onError) {
    if (canFetchEspnMatchDetails(options)) {
        fetchEspnMatchDetails(options, onSuccess, onError);
        return;
    }

    const liveUrl = sportScoreLiveDetailsUrl(options);
    if (liveUrl.length === 0) {
        onSuccess(emptyLiveMatchDetails());
        return;
    }

    requestJson(cacheBustedUrl(liveUrl), payload => {
        try {
            onSuccess(normalizeSportScoreLiveDetails(payload));
        } catch (error) {
            onError(String(error));
        }
    }, onError);
}

function fetchLeagueTable(options, onSuccess, onError) {
    const provider = "sportscore";
    function fetchFromWidgetApi() {
        fetchProviderTable(provider, Object.assign({}, options, {
        provider,
        baseUrl: ProviderCatalog.defaultBaseUrl(provider)
    }), onSuccess, onError);
    }

    if (!canFetchSportScoreCompetitionFixtures(options)) {
        fetchFromWidgetApi();
        return;
    }

    fetchSportScoreCompetitionTable(options, rows => {
        if (rows.length > 0) {
            onSuccess(rows);
            return;
        }

        fetchFromWidgetApi();
    }, () => {
        fetchFromWidgetApi();
    });
}

function fetchLeagueSeasons(options, onSuccess, onError) {
    if (!isFootballSelection(options) || ProviderCatalog.sportScoreSlug(options && options.league).length === 0) {
        onSuccess([]);
        return;
    }

    function finish(rows) {
        const seasons = selectDefaultSeasonOptions(rows);
        onSuccess(seasons);
    }

    function fetchFromTheSportsDB() {
        fetchTheSportsDBLeagueSeasons(options, rows => {
            finish(rows);
        }, onError);
    }

    function fetchFromSofaScore() {
        fetchSofaScoreLeagueSeasons(options, rows => {
            if (rows.length > 0) {
                finish(rows);
                return;
            }

            fetchFromTheSportsDB();
        }, fetchFromTheSportsDB);
    }

    fetchSportScoreLeagueSeasons(options, rows => {
        if (rows.length > 0) {
            finish(rows);
            return;
        }

        fetchFromSofaScore();
    }, fetchFromSofaScore);
}

function fetchLeagueTableForSeason(options, onSuccess, onError) {
    const seasonId = stringValue(options && options.seasonId).trim();
    const seasonLabel = stringValue(options && options.seasonLabel).trim();
    const providerHint = stringValue(options && options.seasonProvider).trim().toLowerCase();
    if (seasonId.length === 0 && seasonLabel.length === 0) {
        fetchLeagueTable(options, onSuccess, onError);
        return;
    }

    if (canFetchSportScoreCompetitionFixtures(options) && seasonLabel.length > 0) {
        fetchSportScoreCompetitionTableForSeasonLabel(options, rows => {
            if (rows.length > 0) {
                onSuccess(rows);
                return;
            }

            fetchLeagueTableForSeasonFallback(options, seasonId, providerHint, onSuccess, onError);
        }, () => {
            fetchLeagueTableForSeasonFallback(options, seasonId, providerHint, onSuccess, onError);
        });
        return;
    }

    fetchLeagueTableForSeasonFallback(options, seasonId, providerHint, onSuccess, onError);
}

function fetchLeagueTableForSeasonFallback(options, seasonId, providerHint, onSuccess, onError) {
    if (seasonId.length === 0) {
        fetchLeagueTable(options, onSuccess, onError);
        return;
    }

    function fetchFromSportScore() {
        fetchLeagueTable(options, onSuccess, onError);
    }

    function fetchFromTheSportsDB() {
        fetchTheSportsDBTableForSeason(options, rows => {
            if (rows.length > 0) {
                onSuccess(rows);
                return;
            }

            fetchFromSportScore();
        }, fetchFromSportScore);
    }

    function fetchFromSofaScore() {
        fetchSofaScoreTableForSeason(options, rows => {
            if (rows.length > 0) {
                onSuccess(rows);
                return;
            }

            fetchFromTheSportsDB();
        }, fetchFromTheSportsDB);
    }

    if (providerHint === "sofascore") {
        fetchFromSofaScore();
        return;
    }

    if (providerHint === "thesportsdb") {
        fetchFromTheSportsDB();
        return;
    }

    if (canFetchSportScoreCompetitionFixtures(options)) {
        fetchSportScoreCompetitionTable(options, rows => {
            if (rows.length > 0) {
                onSuccess(rows);
                return;
            }

            fetchFromSofaScore();
        }, () => {
            fetchFromSofaScore();
        });
        return;
    }

    fetchFromSofaScore();
}

function fetchSportScoreCompetitionTableForSeasonLabel(options, onSuccess, onError) {
    const country = String(options.country || "england").trim().toLowerCase();
    const league = ProviderCatalog.sportScoreSlug(options.league);
    const leagueLabel = ProviderCatalog.leagueLabel(options.league);
    const seasonSegment = sportScoreSeasonSegmentFromLabel(options && options.seasonLabel);
    if (seasonSegment.length === 0) {
        onSuccess([]);
        return;
    }

    const sourceUrl = country === "world" ? "https://sportscore.com/football/competitions/" : `https://sportscore.com/football/country/${encodeURIComponent(country)}/`;
    requestText(cacheBustedUrl(sourceUrl), html => {
        const competitionPath = sportScoreCompetitionPath(html, country, league);
        if (competitionPath.length === 0) {
            onSuccess([]);
            return;
        }

        const seasonPath = `${stripTrailingSlash(competitionPath)}/${seasonSegment}/`;
        requestText(cacheBustedUrl(`https://sportscore.com${seasonPath}`), seasonPage => {
            onSuccess(normalizeSportScoreCompetitionTablePage(seasonPage, leagueLabel));
        }, onError);
    }, onError);
}

function fetchSportScoreLeagueSeasons(options, onSuccess, onError) {
    if (!canFetchSportScoreCompetitionFixtures(options)) {
        onSuccess([]);
        return;
    }

    fetchSportScoreCompetitionPathWithFallback(options, competitionPath => {
        if (competitionPath.length === 0) {
            onSuccess([]);
            return;
        }

        requestText(cacheBustedUrl(`https://sportscore.com${competitionPath}`), competitionPage => {
            const rows = sportScoreSeasonOptionsFromCompetitionPage(competitionPage)
                .map((season, index) => normalizeSportScoreSeasonOption(season, index))
                .filter(option => stringValue(option && option.key).length > 0)
                .sort((left, right) => seasonSortScore(right) - seasonSortScore(left));
            onSuccess(rows);
        }, onError);
    }, () => {
        onSuccess([]);
    });
}

function normalizeSportScoreSeasonOption(season, index) {
    season = season || {};
    const label = stringValue(season.label).trim();
    const path = stringValue(season.path).trim();
    const keyBase = sportScoreSeasonMatchKey(label.length > 0 ? label : path);
    if (keyBase.length === 0)
        return {};

    const yearScore = parseSeasonYearValue(keyBase) || (1000 - numberValue(index));
    return {
        id: "",
        key: `sportscore:${keyBase}`,
        provider: "sportscore",
        label: normalizeSeasonLabelDisplay(label.length > 0 ? label : keyBase),
        isCurrent: false,
        isOngoing: false,
        isCompleted: false,
        yearScore
    };
}

function sportScoreSeasonSegmentFromLabel(label) {
    const key = sportScoreSeasonMatchKey(label);
    const direct = /^(\d{4})-(\d{4})$/.exec(key);
    if (direct)
        return `${direct[1]}-${direct[2]}`;

    const short = /^(\d{2})\/(\d{2})$/.exec(stringValue(label).trim());
    if (short)
        return `${Number(short[1]) + 2000}-${Number(short[2]) + 2000}`;

    return "";
}

function fetchTeamCompetitions(options, onSuccess, onError) {
    const favoriteTeam = stringValue(options && options.favoriteTeam);
    if (!isFootballSelection(options) || favoriteTeam.length === 0) {
        onSuccess([]);
        return;
    }

    if (canFetchSportScoreTeamFixtures(options)) {
        fetchSportScoreTeamCompetitions(options, competitions => {
            const primary = mergeCompetitionOptions(competitions);
            // SportScore can return a narrow rolling window for some teams.
            // Always try to enrich with TheSportsDB and dedupe the merged list.
            fetchTheSportsDBTeamCompetitions(options, fallbackCompetitions => {
                const merged = mergeCompetitionOptions(primary.concat(fallbackCompetitions));
                if (merged.length > 0) {
                    onSuccess(merged);
                    return;
                }

                onSuccess(primary);
            }, () => {
                onSuccess(primary);
            });
        }, message => {
            const primaryError = stringValue(message);
            fetchTheSportsDBTeamCompetitions(options, fallbackCompetitions => {
                const merged = mergeCompetitionOptions(fallbackCompetitions);
                if (merged.length > 0) {
                    onSuccess(merged);
                    return;
                }

                onError(primaryError.length > 0 ? primaryError : "No competitions found for this team.");
            }, fallbackMessage => {
                const fallbackError = stringValue(fallbackMessage);
                onError(primaryError.length > 0 ? primaryError : fallbackError.length > 0 ? fallbackError : "No competitions found for this team.");
            });
        });
        return;
    }

    // Fallback only when SportScore team fixtures are unavailable.
    fetchTheSportsDBTeamCompetitions(options, competitions => {
        onSuccess(mergeCompetitionOptions(competitions));
    }, message => {
        onError(stringValue(message));
    });
}

function fetchTeamBadge(options, onSuccess, onError) {
    const favoriteTeam = stringValue(options && options.favoriteTeam);
    const teamSlug = sportScoreTeamSlug({
        team: favoriteTeam,
        teamSlug: options && options.teamSlug
    });
    if (!isFootballSelection(options) || favoriteTeam.length === 0) {
        onSuccess("");
        return;
    }

    if (teamSlug.length === 0) {
        onSuccess("");
        return;
    }

    const baseUrl = stripTrailingSlash(ProviderCatalog.defaultBaseUrl("sportscore"));
    const url = `${baseUrl}/team/?sport=football&slug=${encodeURIComponent(teamSlug)}&limit=1&src=sports-widget-for-plasma`;
    requestJson(url, payload => {
        const team = payload && payload.team || {};
        const matchesRequestedTeam = sportScoreTeamMatchesRequest(team, favoriteTeam, teamSlug);
        const badge = stringValue(team.logo || team.badge || team.crest || team.image);
        if (matchesRequestedTeam && badge.length > 0) {
            onSuccess(badge);
            return;
        }

        onSuccess("");
    }, () => {
        onSuccess("");
    });
}

function fetchTeamProfile(options, onSuccess, onError) {
    const favoriteTeam = stringValue(options && options.favoriteTeam);
    const teamSlug = sportScoreTeamSlug({
        team: favoriteTeam,
        teamSlug: options && options.teamSlug
    });
    if (!isFootballSelection(options) || favoriteTeam.length === 0 || teamSlug.length === 0) {
        onSuccess({});
        return;
    }

    const baseUrl = stripTrailingSlash(ProviderCatalog.defaultBaseUrl("sportscore"));
    const url = `${baseUrl}/team/?sport=football&slug=${encodeURIComponent(teamSlug)}&limit=1&src=sports-widget-for-plasma`;
    requestJson(url, payload => {
        const team = payload && payload.team || {};
        const matchesRequestedTeam = sportScoreTeamMatchesRequest(team, favoriteTeam, teamSlug);
        if (!matchesRequestedTeam) {
            onSuccess({});
            return;
        }

        onSuccess({
            name: stringValue(team.name || team.team || team.shortName || team.displayName),
            badge: stringValue(team.logo || team.badge || team.crest || team.image),
            teamSlug: stringValue(team.slug || team.teamSlug || team.team_slug)
        });
    }, () => {
        if (typeof onError === "function")
            onError("");
        else
            onSuccess({});
    });
}

function sportScoreTeamMatchesRequest(team, favoriteTeam, expectedSlug) {
    team = team || {};
    const requestedName = stringValue(favoriteTeam).trim();
    const requestedSlug = stringValue(expectedSlug).trim().toLowerCase();
    if (requestedName.length === 0 && requestedSlug.length === 0)
        return false;

    const candidateNames = [
        team.name,
        team.team,
        team.shortName,
        team.short_name,
        team.displayName,
        team.title
    ];
    let hasCandidateName = false;
    for (let index = 0; index < candidateNames.length; index += 1) {
        const candidate = stringValue(candidateNames[index]).trim();
        if (candidate.length === 0)
            continue;

        hasCandidateName = true;
        if (requestedName.length > 0 && sameTeamName(candidate, requestedName))
            return true;
    }

    // When we know the requested team name, never trust slug-only matches.
    // Some providers can echo the requested slug while returning another team payload.
    if (requestedName.length > 0)
        return false;

    const candidateSlugs = [
        team.slug,
        team.teamSlug,
        team.team_slug
    ];
    for (let index = 0; index < candidateSlugs.length; index += 1) {
        const candidateSlug = stringValue(candidateSlugs[index]).trim().toLowerCase();
        if (candidateSlug.length === 0)
            continue;

        if (requestedSlug.length > 0 && candidateSlug === requestedSlug && !hasCandidateName)
            return true;
    }

    return false;
}

function fetchScoresFixtures(options, onSuccess, onError) {
    const provider = "sportscore";
    const favoriteTeam = stringValue(options && options.favoriteTeam).trim();
    const teamFollowMode = stringValue(options && options.followMode).trim().toLowerCase() === "team";

    function fetchTeamFallbacks(next) {
        if (!teamFollowMode || favoriteTeam.length === 0) {
            next();
            return;
        }

        fetchSofaScoreTeamFixtures(options, teamFixtures => {
            if (teamFixtures.length > 0 && hasSchedulableFixture(teamFixtures)) {
                onSuccess(teamFixtures);
                return;
            }

            fetchTeamCompetitionFixturesFallback(options, fallbackFixtures => {
                if (fallbackFixtures.length > 0 && hasSchedulableFixture(fallbackFixtures)) {
                    onSuccess(fallbackFixtures);
                    return;
                }

                next();
            }, () => {
                next();
            });
        }, () => {
            fetchTeamCompetitionFixturesFallback(options, fallbackFixtures => {
                if (fallbackFixtures.length > 0 && hasSchedulableFixture(fallbackFixtures)) {
                    onSuccess(fallbackFixtures);
                    return;
                }

                next();
            }, () => {
                next();
            });
        });
    }

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
            if (fixtures.length > 0 && hasSchedulableFixture(fixtures)) {
                onSuccess(fixtures);
                return;
            }

            fetchTeamFallbacks(() => {
                fetchSportScoreCompetitionFixturesOrProvider(options, provider, finish, fail);
            });
        }, () => {
            fetchTeamFallbacks(() => {
                fetchSportScoreCompetitionFixturesOrProvider(options, provider, finish, fail);
            });
        });
        return;
    }

    fetchTeamFallbacks(() => {
        fetchSportScoreCompetitionFixturesOrProvider(options, provider, finish, fail);
    });
}

function teamMatchIncludesFavorite(match, favoriteTeam) {
    const team = stringValue(favoriteTeam).trim();
    if (team.length === 0)
        return false;

    return sameTeamName(match && match.homeTeam, team) || sameTeamName(match && match.awayTeam, team);
}

function teamLeagueFallbackPriority(league) {
    const label = normalizedText(league && league.label);
    if (label.length === 0)
        return -200;

    let score = 0;
    if (label.indexOf("first") >= 0 || label.indexOf("premier") >= 0 || label.indexOf("super league") >= 0 || label.indexOf("championship") >= 0 || label.indexOf("liga") >= 0 || label.indexOf("league") >= 0)
        score += 40;

    if (label.indexOf("cup") >= 0 || label.indexOf("playoff") >= 0 || label.indexOf("play-off") >= 0)
        score += 15;

    if (label.indexOf("women") >= 0 || label.indexOf("u21") >= 0 || label.indexOf("u20") >= 0 || label.indexOf("u19") >= 0 || label.indexOf("youth") >= 0 || label.indexOf("reserve") >= 0 || label.indexOf("friendly") >= 0)
        score -= 35;

    return score;
}

function fetchCountryLeagueFixturesFallback(options, onSuccess, onError) {
    const favoriteTeam = stringValue(options && options.favoriteTeam).trim();
    const country = stringValue(options && options.country).trim();
    if (favoriteTeam.length === 0 || country.length === 0 || normalizedText(country) === "world" || normalizedText(country) === "all") {
        onSuccess([]);
        return;
    }

    let leagues = arrayValue(ProviderCatalog.leagueOptions("sportscore", "football", country))
        .filter(league => stringValue(league && league.value).trim().length > 0);
    leagues.sort((left, right) => teamLeagueFallbackPriority(right) - teamLeagueFallbackPriority(left));
    leagues = leagues.slice(0, 10);

    if (leagues.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = leagues.length;
    let matches = [];
    let errors = [];

    function finish() {
        if (pending > 0)
            return;

        const filtered = dedupeMatches(matches).filter(match => teamMatchIncludesFavorite(match, favoriteTeam));
        if (filtered.length > 0 || errors.length === 0) {
            onSuccess(sortMatches(filtered));
        } else {
            onError(errors.join(", "));
        }
    }

    leagues.forEach(league => {
        const slug = stringValue(league && league.value).trim();
        if (slug.length === 0) {
            pending -= 1;
            finish();
            return;
        }

        fetchSportScoreCompetitionFixturesOrProvider(Object.assign({}, options, {
            "league": slug,
            "followMode": "league"
        }), "sportscore", fixtures => {
            matches = matches.concat(arrayValue(fixtures));
            pending -= 1;
            finish();
        }, message => {
            if (!isHttpNotFound(message))
                errors.push(message);

            pending -= 1;
            finish();
        });
    });
}

function fetchTeamCompetitionFixturesFallback(options, onSuccess, onError) {
    const favoriteTeam = stringValue(options && options.favoriteTeam).trim();
    if (favoriteTeam.length === 0) {
        onSuccess([]);
        return;
    }

    fetchTeamCompetitions(options, competitions => {
        const rows = mergeCompetitionOptions(competitions).slice(0, 8);
        if (rows.length === 0) {
            fetchCountryLeagueFixturesFallback(options, onSuccess, onError);
            return;
        }

        let pending = rows.length;
        let matches = [];
        let errors = [];

        function finish() {
            const filtered = dedupeMatches(matches).filter(match => teamMatchIncludesFavorite(match, favoriteTeam));
            if (pending > 0)
                return;

            if (filtered.length > 0) {
                onSuccess(sortMatches(filtered));
            } else if (errors.length > 0) {
                onError(errors.join(", "));
            } else {
                fetchCountryLeagueFixturesFallback(options, onSuccess, onError);
            }
        }

        rows.forEach(competition => {
            const slug = stringValue(competition && competition.slug).trim();
            if (slug.length === 0) {
                pending -= 1;
                finish();
                return;
            }

            fetchSportScoreCompetitionFixturesOrProvider(Object.assign({}, options, {
                "league": slug,
                "followMode": "league"
            }), "sportscore", fixtures => {
                matches = matches.concat(arrayValue(fixtures));
                pending -= 1;
                finish();
            }, message => {
                if (!isHttpNotFound(message))
                    errors.push(message);

                pending -= 1;
                finish();
            });
        });
    }, onError);
}

function fetchRecentResults(options, onSuccess, onError) {
    if (isSeasonScopedRequest(options)) {
        fetchSportScoreCompetitionRecentResultsOrFallback(options, onSuccess, onError);
        return;
    }

    if ((Boolean(options && options.preferTeamRecentResults) || Array.isArray(options && options.tableRows)) && canFetchSportScoreTeamFixtures(options)) {
        fetchSportScoreTeamRecentResults(options, results => {
            if (results.length > 0) {
                fetchSportScoreCompetitionRecentResults(options, competitionResults => {
                    onSuccess(mergeRecentResultSources(competitionResults, results));
                }, () => {
                    onSuccess(results);
                });
                return;
            }

            fetchSportScoreCompetitionRecentResultsOrFallback(options, onSuccess, onError);
        }, () => {
            fetchSportScoreCompetitionRecentResultsOrFallback(options, onSuccess, onError);
        });
        return;
    }

    if (canFetchTheSportsDBRecentResults(options)) {
        fetchTheSportsDBRecentResults(options, results => {
            if (results.length > 0) {
                onSuccess(results);
                return;
            }

            fetchSportScoreCompetitionRecentResultsOrFallback(options, onSuccess, onError);
        }, () => {
            fetchSportScoreCompetitionRecentResultsOrFallback(options, onSuccess, onError);
        });
        return;
    }

    fetchSportScoreCompetitionRecentResultsOrFallback(options, onSuccess, onError);
}

function fetchSportScoreCompetitionRecentResultsOrFallback(options, onSuccess, onError) {
    if (canFetchSportScoreCompetitionFixtures(options)) {
        fetchSportScoreCompetitionRecentResults(options, results => {
            if (results.length > 0) {
                fetchRecentResultStageMetadata(options, stageResults => {
                    const merged = mergeRecentResultSources(results, stageResults);
                    onSuccess(merged.length > 0 ? merged : results);
                }, () => {
                    onSuccess(results);
                });
                return;
            }

            fetchFallbackRecentResults(options, onSuccess, onError);
        }, () => {
            fetchFallbackRecentResults(options, onSuccess, onError);
        });
        return;
    }

    fetchFallbackRecentResults(options, onSuccess, onError);
}

function fetchRecentResultStageMetadata(options, onSuccess, onError) {
    function finish(results) {
        onSuccess((Array.isArray(results) ? results : []).filter(hasMatchday));
    }

    function fetchFromTheSportsDB() {
        if (!canFetchTheSportsDBRecentResults(options)) {
            onError("");
            return;
        }

        fetchTheSportsDBRecentResults(options, results => {
            if (results.some(hasMatchday)) {
                finish(results);
                return;
            }

            onError("");
        }, onError);
    }

    if (canFetchSofaScoreRecentResults(options)) {
        fetchSofaScoreRecentResults(options, results => {
            if (results.some(hasMatchday)) {
                finish(results);
                return;
            }

            fetchFromTheSportsDB();
        }, fetchFromTheSportsDB);
        return;
    }

    fetchFromTheSportsDB();
}

function hasMatchday(match) {
    return stringValue(match && match.matchday).length > 0;
}

function fetchFallbackRecentResults(options, onSuccess, onError) {
    if (canFetchEspnFootball(options)) {
        fetchEspnRecentResults(options, results => {
            if (results.length > 0) {
                onSuccess(results);
                return;
            }

            fetchFromTheSportsDB();
        }, fetchFromTheSportsDB);
        return;
    }

    function fetchFromSportScoreWidget() {
        fetchProviderMatches("sportscore", "live", Object.assign({}, options, {
            provider: "sportscore",
            baseUrl: ProviderCatalog.defaultBaseUrl("sportscore")
        }), matches => {
            onSuccess(sortRecentMatches(dedupeMatches(filterMatchesForSelection(matches, options).filter(isFinishedMatch))));
        }, onError);
    }

    function fetchFromSofaScore() {
        if (canFetchSofaScoreRecentResults(options)) {
            fetchSofaScoreRecentResults(options, results => {
                if (results.length > 0) {
                    onSuccess(results);
                    return;
                }

                fetchFromSportScoreWidget();
            }, fetchFromSportScoreWidget);
            return;
        }

        fetchFromSportScoreWidget();
    }

    function fetchFromTheSportsDB() {
        if (!canFetchTheSportsDBRecentResults(options)) {
            fetchFromSofaScore();
            return;
        }

        fetchTheSportsDBRecentResults(options, results => {
            if (results.length > 0) {
                onSuccess(results);
                return;
            }

            fetchFromSofaScore();
        }, fetchFromSofaScore);
    }

    fetchFromTheSportsDB();
}

function canFetchTheSportsDBRecentResults(options) {
    return canFetchTheSportsDBFixtures(options);
}

function fetchTheSportsDBRecentResults(options, onSuccess, onError) {
    resolveTheSportsDBLeague(options, league => {
        if (stringValue(league && league.id).length === 0) {
            onSuccess([]);
            return;
        }

        requestJson(`${THESPORTSDB_API_BASE_URL}/eventspastleague.php?id=${encodeURIComponent(league.id)}`, payload => {
            const events = arrayValue(payload && payload.events);
            const wantedSeason = theSportsDBSeasonFromOptions(options);
            const seasonEvents = wantedSeason.length > 0
                ? events.filter(event => stringValue(event && event.strSeason) === wantedSeason)
                : events;
            const seed = seasonEvents.map(event => normalizeTheSportsDBResult(event, league)).filter(isFinishedMatch);
            const latestEvent = seasonEvents[0] || events[0] || {};
            const season = wantedSeason.length > 0 ? wantedSeason : stringValue(latestEvent.strSeason);
            const latestRound = numberValue(latestEvent.intRound);

            if (season.length === 0 || latestRound <= 0) {
                onSuccess(sortRecentMatches(dedupeMatches(seed)).slice(0, RECENT_RESULTS_LIMIT));
                return;
            }

            fetchTheSportsDBRecentRounds(league, season, latestRound, seed, onSuccess, onError);
        }, onError);
    }, onError);
}

function theSportsDBSeasonFromOptions(options) {
    const direct = stringValue(options && options.seasonId).trim();
    if (/^\d{4}-\d{4}$/.test(direct))
        return direct;

    const fromLabel = sportScoreSeasonSegmentFromLabel(options && options.seasonLabel);
    if (/^\d{4}-\d{4}$/.test(fromLabel))
        return fromLabel;

    return "";
}

function fetchTheSportsDBRecentRounds(league, season, latestRound, seed, onSuccess, onError) {
    let rounds = [];
    for (let round = latestRound; round > 0 && round > latestRound - RECENT_RESULTS_ROUND_LIMIT; round -= 1)
        rounds.push(round);

    if (rounds.length === 0) {
        onSuccess(sortRecentMatches(dedupeMatches(seed)));
        return;
    }

    let pending = rounds.length;
    let matches = seed.slice();
    let errors = [];

    function finish() {
        const rows = sortRecentMatches(dedupeMatches(matches.filter(isFinishedMatch))).slice(0, RECENT_RESULTS_LIMIT);
        if (rows.length > 0 || errors.length === 0) {
            onSuccess(rows);
        } else {
            onError(errors.join(", "));
        }
    }

    rounds.forEach(round => {
        const url = `${THESPORTSDB_API_BASE_URL}/eventsround.php?id=${encodeURIComponent(league.id)}&r=${encodeURIComponent(round)}&s=${encodeURIComponent(season)}`;
        requestJson(url, payload => {
            const events = arrayValue(payload && payload.events);
            matches = matches.concat(events.map(event => normalizeTheSportsDBResult(event, league)));
            pending -= 1;
            if (pending === 0)
                finish();
        }, message => {
            errors.push(`TheSportsDB: ${message}`);
            pending -= 1;
            if (pending === 0)
                finish();
        });
    });
}

function normalizeTheSportsDBResult(event, league) {
    const match = normalizeTheSportsDBFixture(event, league);
    if (stringValue(event && event.intHomeScore).length > 0 && stringValue(event && event.intAwayScore).length > 0)
        match.status = "Finished";

    return match;
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
    const seasonScopedRequest = isSeasonScopedRequest(options);

    function canUseSportScore() {
        const league = String(options.league || "").trim().toUpperCase();
        const rows = Array.isArray(options.tableRows) ? options.tableRows : [];
        return (sport === "football" || sport === "soccer") && ProviderCatalog.sportScoreSlug(league).length > 0 && rows.length > 0;
    }

    function fetchFromLeagueRecentResults(primaryForms) {
        const primary = primaryForms || {};
        const requestOptions = Object.assign({}, options, {
            preferTeamRecentResults: false,
            skipLeagueFilter: false,
            recentResultsLimit: seasonScopedRequest ? 320 : 160
        });
        delete requestOptions.tableRows;
        function finishWithMatches(matches) {
            const seasonalForms = formByTeam(matches, requestOptions);
            const merged = mergeFormMapsWithPreference(primary, seasonalForms, seasonScopedRequest);
            onSuccess(merged);
        }

        fetchRecentResults(requestOptions, matches => {
            if (canFetchSofaScoreRecentResults(requestOptions)) {
                fetchSofaScoreRecentResults(requestOptions, sofaMatches => {
                    const combined = sortRecentMatches(dedupeRecentMatches(arrayValue(matches).concat(arrayValue(sofaMatches))))
                        .slice(0, recentResultsLimitValue(requestOptions));
                    finishWithMatches(combined);
                }, () => {
                    finishWithMatches(matches);
                });
                return;
            }

            finishWithMatches(matches);
        }, () => {
            if (canFetchSofaScoreRecentResults(requestOptions)) {
                fetchSofaScoreRecentResults(requestOptions, finishWithMatches, () => {
                    if (Object.keys(primary).length > 0)
                        onSuccess(primary);
                    else
                        onError("No season results returned for form.");
                });
                return;
            }

            if (Object.keys(primary).length > 0)
                onSuccess(primary);
            else
                onError("No season results returned for form.");
        });
    }

    function formMapFromTableRows(rows) {
        const result = {};
        arrayValue(rows).forEach(row => {
            const key = normalizedText(row && row.team);
            const values = formValues(row && row.form);
            if (key.length === 0 || values.length === 0)
                return;

            result[key] = formEntry(values, []);
        });
        return result;
    }

    function fetchFromSofaScoreSeasonTable(primaryForms) {
        const primary = primaryForms || {};
        if (!seasonScopedRequest) {
            fetchFromLeagueRecentResults(primary);
            return;
        }

        const rows = rowsNeedingForm(options.tableRows, primary);
        if (rows.length === 0) {
            onSuccess(primary);
            return;
        }

        fetchSofaScoreTableForSeason(options, tableRows => {
            const tableForms = formMapFromTableRows(tableRows);
            const merged = mergeFormMaps(primary, tableForms);
            if (rowsNeedingForm(options.tableRows, merged).length === 0) {
                onSuccess(merged);
                return;
            }

            fetchFromLeagueRecentResults(merged);
        }, () => {
            fetchFromLeagueRecentResults(primary);
        });
    }

    function fetchFromSofaScoreTeamRows(primaryForms) {
        const primary = primaryForms || {};
        const rows = rowsNeedingForm(options.tableRows, primary);
        if (rows.length === 0) {
            onSuccess(primary);
            return;
        }

        fetchSofaScoreTeamForms(options, rows, sofaForms => {
            const merged = mergeFormMaps(primary, sofaForms);
            if (Object.keys(merged).length > 0) {
                fetchFromSofaScoreSeasonTable(merged);
            } else {
                fetchFromSofaScoreSeasonTable({});
            }
        }, () => {
            if (Object.keys(primary).length > 0) {
                fetchFromSofaScoreSeasonTable(primary);
            } else {
                fetchFromSofaScoreSeasonTable({});
            }
        });
    }

    function fetchFromSportScore() {
        // Team endpoints are "latest/current" oriented and can short-circuit old-season
        // enrichment with non-season data. In season scope, always derive form from the
        // requested season pipeline.
        if (seasonScopedRequest) {
            fetchFromSofaScoreSeasonTable({});
            return;
        }

        fetchSportScoreTeamForms(options, forms => {
            fetchFromSofaScoreTeamRows(forms);
        }, () => {
            fetchFromSofaScoreTeamRows({});
        });
    }

    if (canUseSportScore()) {
        fetchFromSportScore();
        return;
    }

    fetchFromLeagueRecentResults();
}

function rowsNeedingForm(tableRows, forms) {
    const rows = Array.isArray(tableRows) ? tableRows : [];
    return rows.filter(row => {
        const entry = formEntryForTeam(forms || {}, row && row.team);
        const values = formValues(entry);
        if (values.length < FORM_RESULTS_LIMIT)
            return true;

        const detailsCount = formDetails(entry).length;
        return detailsCount < Math.min(values.length, FORM_RESULTS_LIMIT);
    });
}

function mergeFormMaps(primaryForms, fallbackForms) {
    return mergeFormMapsWithPreference(primaryForms, fallbackForms, false);
}

function mergeFormMapsWithPreference(primaryForms, fallbackForms, preferFallbackWhenEqual) {
    const merged = Object.assign({}, primaryForms || {});
    Object.keys(fallbackForms || {}).forEach(key => {
        const currentEntry = merged[key];
        const fallbackEntry = fallbackForms[key];
        const current = normalizedFormString(currentEntry);
        const fallback = normalizedFormString(fallbackEntry);
        const currentCount = formValues(current).length;
        const fallbackCount = formValues(fallback).length;
        const currentDetailsCount = formDetails(currentEntry).length;
        const fallbackDetailsCount = formDetails(fallbackEntry).length;
        const betterDetails = fallbackDetailsCount > currentDetailsCount;
        const equalCounts = fallbackCount === currentCount;
        const preferByPolicy = Boolean(preferFallbackWhenEqual)
            && fallbackCount > 0
            && equalCounts
            && (fallbackDetailsCount > 0 || currentDetailsCount === 0);
        if (fallbackCount > currentCount || (equalCounts && betterDetails) || preferByPolicy)
            merged[key] = fallbackForms[key];
    });

    return merged;
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
        const url = `${baseUrl}/team/?sport=football&slug=${encodeURIComponent(row.teamSlug)}&limit=${FORM_TEAM_MATCH_LIMIT}&src=sports-widget-for-plasma`;
        requestJson(url, payload => {
            const formEntry = sportScoreTeamForm(payload, row.team, options);
            if (formValues(formEntry).length > 0)
                forms[normalizedText(row.team)] = formEntry;

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

function fetchSofaScoreTeamForms(options, tableRows, onSuccess, onError) {
    if (!isFootballSelection(options)) {
        onError("SofaScore team form is not available for this selection.");
        return;
    }

    let seenTeams = {};
    const rows = (Array.isArray(tableRows) ? tableRows : [])
        .filter(row => stringValue(row && row.team).length > 0)
        .filter(row => {
            const key = normalizedText(row.team);
            if (key.length === 0 || seenTeams[key])
                return false;

            seenTeams[key] = true;
            return true;
        });
    if (rows.length === 0) {
        onSuccess({});
        return;
    }

    let active = 0;
    let nextIndex = 0;
    let completed = 0;
    let forms = {};
    let errors = [];
    const concurrency = Math.min(4, rows.length);

    function finish() {
        if (Object.keys(forms).length > 0) {
            onSuccess(forms);
        } else {
            onError(errors.join(", ") || "SofaScore returned no team form.");
        }
    }

    function complete() {
        active -= 1;
        completed += 1;
        if (completed === rows.length) {
            finish();
            return;
        }

        pump();
    }

    function pump() {
        while (active < concurrency && nextIndex < rows.length) {
            const row = rows[nextIndex];
            nextIndex += 1;
            active += 1;
            fetchRow(row);
        }
    }

    function fetchRow(row) {
        fetchSofaScoreTeamForm(options, row, formEntry => {
            if (formValues(formEntry).length > 0)
                forms[normalizedText(row.team)] = formEntry;

            complete();
        }, message => {
            errors.push(`${row.team}: ${message}`);
            complete();
        });
    }

    pump();
}

function fetchSofaScoreTeamForm(options, row, onSuccess, onError) {
    const cacheKey = formCacheKey(options, row && row.team);
    const cached = sofaScoreTeamFormCache[cacheKey];
    const now = Date.now();
    if (cached && now - numberValue(cached.timestamp) < FORM_CACHE_TTL_MS) {
        onSuccess(cached.entry || "");
        return;
    }

    searchSofaScoreTeam(options, row, team => {
        const teamId = numberValue(team && team.id);
        if (teamId <= 0) {
            onError("team not found");
            return;
        }

        requestJson(`${SOFASCORE_API_BASE_URL}/team/${teamId}/events/last/0`, payload => {
            const matches = arrayValue(payload && payload.events)
                .map(event => normalizeSofaScoreFixture(event, {
                    label: stringValue(event && event.tournament && event.tournament.name)
                }))
                .filter(hasTeams)
                .filter(match => Number.isFinite(Number(match.homeScore)) && Number.isFinite(Number(match.awayScore)))
                .filter(isFinishedMatch);
            const entry = teamFormFromMatches(matches, row.team, team.name, options);
            sofaScoreTeamFormCache[cacheKey] = {
                timestamp: now,
                entry
            };
            onSuccess(entry);
        }, onError);
    }, onError);
}

function searchSofaScoreTeam(options, row, onSuccess, onError) {
    const url = `${SOFASCORE_API_BASE_URL}/search/all?q=${encodeURIComponent(row.team)}`;
    requestJson(url, payload => {
        const team = selectSofaScoreTeam(payload, row, options);
        if (numberValue(team && team.id) > 0) {
            onSuccess(team);
        } else {
            onError("team not found");
        }
    }, onError);
}

function selectSofaScoreTeam(payload, row, options) {
    const wantedTeam = stringValue(row && row.team);
    const wantedCountry = normalizedText(ProviderCatalog.countryLabel(options && options.country));
    const results = arrayValue(payload && payload.results);
    let best = {};
    let bestScore = 0;

    results.forEach(result => {
        if (stringValue(result && result.type) !== "team")
            return;

        const entity = result && result.entity ? result.entity : {};
        const sport = entity && entity.sport ? entity.sport : {};
        if (normalizedText(sport.slug || sport.name) !== "football")
            return;

        const name = stringValue(entity.name);
        let score = sameTeamName(name, wantedTeam) ? 10 : similarityScore(name, wantedTeam);
        if (score <= 0)
            return;

        if (stringValue(entity.gender).toUpperCase() === "M")
            score += 1;

        const country = entity && entity.country ? entity.country : {};
        const countryName = normalizedText(country.name || country.slug);
        if (wantedCountry.length > 0 && wantedCountry !== "international tournaments" && countryName.length > 0) {
            if (countryName === wantedCountry || wantedCountry.indexOf(countryName) >= 0 || countryName.indexOf(wantedCountry) >= 0) {
                score += 2;
            } else {
                score -= 1;
            }
        }

        if (numberValue(result && result.score) > 0)
            score += 0.5;

        if (score > bestScore) {
            bestScore = score;
            best = {
                id: numberValue(entity.id),
                name
            };
        }
    });

    return best;
}

function uniqueTextValues(values) {
    let seen = {};
    let rows = [];
    arrayValue(values).forEach(value => {
        const normalized = stringValue(value).trim().toLowerCase();
        if (normalized.length === 0 || seen[normalized])
            return;

        seen[normalized] = true;
        rows.push(normalized);
    });
    return rows;
}

function sportScoreTeamSlugCandidates(teamName, explicitSlug) {
    const rawName = stringValue(teamName).trim();
    const rawSlug = stringValue(explicitSlug).trim();
    let names = [];
    if (rawName.length > 0)
        names.push(rawName);

    const strippedPrefix = rawName.replace(/^(pfc|fc|fk|sk|nk|ac|sc|cf)\s+/i, "").trim();
    if (strippedPrefix.length > 0 && strippedPrefix.toLowerCase() !== rawName.toLowerCase())
        names.push(strippedPrefix);

    const parts = strippedPrefix.split(/\s+/).filter(part => part.length > 0);
    if (parts.length >= 2)
        names.push(parts.slice(0, parts.length - 1).join(" "));

    let slugs = [];
    if (rawSlug.length > 0)
        slugs.push(rawSlug);

    uniqueTextValues(names).forEach(name => {
        const slug = sportScoreTeamSlug({ "team": name });
        if (slug.length === 0)
            return;

        slugs.push(slug);
        slugs.push("pfc-" + slug);
        slugs.push("fc-" + slug);
        slugs.push("fk-" + slug);
        slugs.push("sk-" + slug);
    });

    return uniqueTextValues(slugs).slice(0, 8);
}

function buildSportScoreTeamRows(options, limit) {
    let rows = [];
    const sourceRows = Array.isArray(options && options.tableRows) ? options.tableRows : [];
    sourceRows.forEach(row => {
        const team = stringValue(row && row.team).trim();
        const slugs = sportScoreTeamSlugCandidates(team, row && row.teamSlug);
        if (team.length === 0 || slugs.length === 0)
            return;

        rows.push({
            team,
            teamSlugs: slugs
        });
    });

    if (rows.length === 0) {
        const favoriteTeam = stringValue(options && options.favoriteTeam).trim();
        const slugs = sportScoreTeamSlugCandidates(favoriteTeam, "");
        if (favoriteTeam.length > 0 && slugs.length > 0) {
            rows.push({
                team: favoriteTeam,
                teamSlugs: slugs
            });
        }
    }

    return rows.slice(0, Math.max(1, numberValue(limit) || 24));
}

function requestSportScoreTeamPayload(baseUrl, teamSlug, limit, onSuccess, onError) {
    const url = `${baseUrl}/team/?sport=football&slug=${encodeURIComponent(teamSlug)}&limit=${encodeURIComponent(limit)}&src=sports-widget-for-plasma`;
    requestJson(url, onSuccess, onError);
}

function fetchSportScoreTeamPayloadForRow(baseUrl, row, limit, onSuccess, onError) {
    const slugs = arrayValue(row && row.teamSlugs).map(value => stringValue(value).trim()).filter(value => value.length > 0);
    if (slugs.length === 0) {
        onSuccess({});
        return;
    }

    let index = 0;

    function tryNext(lastError) {
        if (index >= slugs.length) {
            if (stringValue(lastError).length > 0)
                onError(lastError);
            else
                onSuccess({});
            return;
        }

        const slug = slugs[index];
        index += 1;
        requestSportScoreTeamPayload(baseUrl, slug, limit, payload => {
            const team = payload && payload.team || {};
            if (!sportScoreTeamMatchesRequest(team, row && row.team, slug)) {
                tryNext(lastError);
                return;
            }

            onSuccess(payload || {});
        }, message => {
            if (isHttpNotFound(message)) {
                tryNext(lastError);
                return;
            }

            onError(message);
        });
    }

    tryNext("");
}

function canFetchSportScoreTeamFixtures(options) {
    const sport = normalizeSports(options.sports)[0] || "football";
    const rows = buildSportScoreTeamRows(options, 1);
    return (sport === "football" || sport === "soccer") && rows.length > 0;
}

function fetchSportScoreTeamFixtures(options, onSuccess, onError) {
    const rows = buildSportScoreTeamRows(options, 24);

    if (rows.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = rows.length;
    let matches = [];
    let errors = [];
    const baseUrl = stripTrailingSlash(ProviderCatalog.defaultBaseUrl("sportscore"));

    rows.forEach(row => {
        fetchSportScoreTeamPayloadForRow(baseUrl, row, 20, payload => {
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

function fetchSportScoreTeamRecentResults(options, onSuccess, onError) {
    const rows = buildSportScoreTeamRows(options, 16);

    if (rows.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = rows.length;
    let active = 0;
    let nextIndex = 0;
    let completed = 0;
    let settled = false;
    let matches = [];
    let errors = [];
    const baseUrl = stripTrailingSlash(ProviderCatalog.defaultBaseUrl("sportscore"));
    const concurrency = Math.min(4, rows.length);
    const targetResults = Math.min(80, Math.max(20, numberValue(options && options.recentResultsLimit) || RECENT_RESULTS_LIMIT));
    const teamLimit = Math.min(50, Math.max(12, numberValue(options && options.recentResultsPerTeam) || RECENT_RESULTS_TEAM_LIMIT));

    function currentRows() {
        return sortRecentMatches(dedupeMatches(filterMatchesForSelection(matches, options).filter(isFinishedMatch))).slice(0, targetResults);
    }

    function finishIfReady(force) {
        if (settled)
            return true;

        const rows = currentRows();
        if (rows.length > 0 && (force || rows.length >= targetResults)) {
            settled = true;
            onSuccess(rows);
            return true;
        }

        if (pending === 0) {
            settled = true;
            if (rows.length > 0 || errors.length === 0) {
                onSuccess(rows);
            } else {
                onError(errors.join(", "));
            }
            return true;
        }

        return false;
    }

    function requestRow(row) {
        fetchSportScoreTeamPayloadForRow(baseUrl, row, teamLimit, payload => {
            active -= 1;
            completed += 1;
            matches = matches.concat(ProviderCatalog.normalizeFixtures("sportscore", payload, "football"));
            pending -= 1;
            if (!finishIfReady(false))
                launchNext();
        }, message => {
            active -= 1;
            completed += 1;
            if (!isHttpNotFound(message))
                errors.push(`${row.team}: ${message}`);

            pending -= 1;
            if (!finishIfReady(false))
                launchNext();
        });
    }

    function launchNext() {
        while (!settled && active < concurrency && nextIndex < rows.length) {
            const row = rows[nextIndex];
            nextIndex += 1;
            active += 1;
            requestRow(row);
        }
    }

    launchNext();
}

function fetchSportScoreTeamCompetitions(options, onSuccess, onError) {
    const rows = buildSportScoreTeamRows(options, 16);

    if (rows.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = rows.length;
    let competitions = [];
    let errors = [];
    const baseUrl = stripTrailingSlash(ProviderCatalog.defaultBaseUrl("sportscore"));

    rows.forEach(row => {
        fetchSportScoreTeamPayloadForRow(baseUrl, row, 50, payload => {
            competitions = competitions.concat(teamCompetitionOptionsFromMatches(arrayValue(payload && payload.matches), stringValue(payload && payload.team && payload.team.logo)));
            pending -= 1;
            if (pending === 0)
                finishSportScoreTeamCompetitions(competitions, errors, onSuccess, onError);
        }, message => {
            if (!isHttpNotFound(message))
                errors.push(`${row.team}: ${message}`);

            pending -= 1;
            if (pending === 0)
                finishSportScoreTeamCompetitions(competitions, errors, onSuccess, onError);
        });
    });
}

function finishSportScoreTeamCompetitions(competitions, errors, onSuccess, onError) {
    const rows = mergeCompetitionOptions(competitions);
    if (rows.length > 0 || errors.length === 0) {
        onSuccess(rows);
    } else {
        onError(errors.join(", "));
    }
}

function fetchTheSportsDBTeamCompetitions(options, onSuccess, onError) {
    const favoriteTeam = stringValue(options && options.favoriteTeam);
    if (favoriteTeam.length === 0) {
        onSuccess([]);
        return;
    }

    const url = `${THESPORTSDB_API_BASE_URL}/searchteams.php?t=${encodeURIComponent(favoriteTeam)}`;
    requestJson(url, payload => {
        const team = selectTheSportsDBTeam(payload, options);
        onSuccess(teamCompetitionOptionsFromTheSportsDBTeam(team));
    }, onError);
}

function selectTheSportsDBTeam(payload, options) {
    const teams = arrayValue(payload && payload.teams);
    const favoriteTeam = normalizedText(options && options.favoriteTeam);
    const selectedCountry = normalizedText(ProviderCatalog.countryLabel(options && options.country));
    let best = {};
    let bestScore = 0;

    teams.forEach(team => {
        const sport = normalizedText(team && team.strSport);
        if (sport.length > 0 && sport !== "soccer" && sport !== "football")
            return;

        const name = normalizedText(team && team.strTeam);
        if (name.length === 0)
            return;

        let score = similarityScore(name, favoriteTeam);
        if (name === favoriteTeam)
            score += 5;

        const country = normalizedText(team && team.strCountry);
        if (selectedCountry.length > 0 && selectedCountry !== "international tournaments") {
            if (country === selectedCountry)
                score += 2;
            else if (country.length > 0)
                score -= 1;
        }

        if (score > bestScore) {
            bestScore = score;
            best = team || {};
        }
    });

    return bestScore >= 4 ? best : {};
}

function teamCompetitionOptionsFromTheSportsDBTeam(team) {
    let rows = [];
    if (!team)
        return rows;

    const badge = stringValue(team && (team.strBadge || team.strLogo || team.strTeamBadge));
    for (let index = 1; index <= 7; index += 1) {
        const key = index === 1 ? "strLeague" : `strLeague${index}`;
        const label = stringValue(team && team[key]);
        if (label.length > 0)
            rows.push(competitionOption(label, label, badge));
    }

    return mergeCompetitionOptions(rows);
}

function teamCompetitionOptionsFromMatches(matches, teamBadge) {
    return mergeCompetitionOptions(arrayValue(matches).map(match => {
        const label = stringValue(match && (match.competition || match.league));
        return competitionOption(label, label, teamBadge);
    }));
}

function competitionOption(label, slug, teamBadge) {
    const normalizedSlug = ProviderCatalog.sportScoreSlug(slug || label);
    if (normalizedSlug.length === 0)
        return {};

    return {
        label: stringValue(label) || ProviderCatalog.leagueLabel(normalizedSlug) || normalizedSlug,
        slug: normalizedSlug,
        teamBadge: stringValue(teamBadge)
    };
}

function mergeCompetitionOptions(competitions) {
    let seen = {};
    let rows = [];
    arrayValue(competitions).forEach(option => {
        const slug = ProviderCatalog.sportScoreSlug(option && option.slug || option && option.label);
        if (slug.length === 0 || seen[slug])
            return;

        seen[slug] = true;
        rows.push({
            label: stringValue(option && option.label) || ProviderCatalog.leagueLabel(slug) || slug,
            slug,
            teamBadge: stringValue(option && option.teamBadge)
        });
    });

    return rows;
}

function finishTeamFixtures(matches, errors, options, onSuccess, onError) {
    const rows = dedupeMatches(filterMatchesForSelection(matches, options));
    if (rows.length > 0 || errors.length === 0) {
        onSuccess(sortMatches(rows));
    } else {
        onError(errors.join(", "));
    }
}

function finishTeamRecentResults(matches, errors, options, onSuccess, onError) {
    const rows = sortRecentMatches(dedupeMatches(filterMatchesForSelection(matches, options).filter(isFinishedMatch)));
    if (rows.length > 0 || errors.length === 0) {
        onSuccess(rows);
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

    requestText(cacheBustedUrl(sourceUrl), html => {
        const competitionPath = sportScoreCompetitionPath(html, country, league);
        if (competitionPath.length === 0) {
            onSuccess([]);
            return;
        }

        requestText(cacheBustedUrl(`https://sportscore.com${competitionPath}`), competitionPage => {
            const seasonPath = sportScorePreferredSeasonPath(competitionPage, options);
            const finalPath = seasonPath.length > 0 ? seasonPath : competitionPath;
            if (finalPath === competitionPath) {
                onSuccess(normalizeSportScoreFixturePage(competitionPage, leagueLabel));
                return;
            }

            requestText(cacheBustedUrl(`https://sportscore.com${finalPath}`), seasonPage => {
                onSuccess(normalizeSportScoreFixturePage(seasonPage, leagueLabel));
            }, () => {
                onSuccess(normalizeSportScoreFixturePage(competitionPage, leagueLabel));
            });
        }, onError);
    }, onError);
}

function fetchSportScoreCompetitionRecentResults(options, onSuccess, onError) {
    const country = String(options.country || "england").trim().toLowerCase();
    const league = ProviderCatalog.sportScoreSlug(options.league);
    const leagueLabel = ProviderCatalog.leagueLabel(options.league);
    const sourceUrl = country === "world" ? "https://sportscore.com/football/competitions/" : `https://sportscore.com/football/country/${encodeURIComponent(country)}/`;

    requestText(cacheBustedUrl(sourceUrl), html => {
        const competitionPath = sportScoreCompetitionPath(html, country, league);
        if (competitionPath.length === 0) {
            onSuccess([]);
            return;
        }

        requestText(cacheBustedUrl(`https://sportscore.com${competitionPath}`), competitionPage => {
            const seasonPath = sportScorePreferredSeasonPath(competitionPage, options);
            const finalPath = seasonPath.length > 0 ? seasonPath : competitionPath;
            if (finalPath === competitionPath) {
                onSuccess(normalizeSportScoreRecentResultPage(competitionPage, leagueLabel));
                return;
            }

            requestText(cacheBustedUrl(`https://sportscore.com${finalPath}`), seasonPage => {
                onSuccess(normalizeSportScoreRecentResultPage(seasonPage, leagueLabel));
            }, () => {
                onSuccess(normalizeSportScoreRecentResultPage(competitionPage, leagueLabel));
            });
        }, onError);
    }, onError);
}

function fetchSportScoreCompetitionTable(options, onSuccess, onError) {
    const country = String(options.country || "england").trim().toLowerCase();
    const league = ProviderCatalog.sportScoreSlug(options.league);
    const leagueLabel = ProviderCatalog.leagueLabel(options.league);
    const sourceUrl = country === "world" ? "https://sportscore.com/football/competitions/" : `https://sportscore.com/football/country/${encodeURIComponent(country)}/`;

    requestText(cacheBustedUrl(sourceUrl), html => {
        const competitionPath = sportScoreCompetitionPath(html, country, league);
        if (competitionPath.length === 0) {
            onSuccess([]);
            return;
        }

        requestText(cacheBustedUrl(`https://sportscore.com${competitionPath}`), competitionPage => {
            const seasonPath = sportScorePreferredSeasonPath(competitionPage, options);
            const finalPath = seasonPath.length > 0 ? seasonPath : competitionPath;
            if (finalPath === competitionPath) {
                onSuccess(normalizeSportScoreCompetitionTablePage(competitionPage, leagueLabel));
                return;
            }

            requestText(cacheBustedUrl(`https://sportscore.com${finalPath}`), seasonPage => {
                onSuccess(normalizeSportScoreCompetitionTablePage(seasonPage, leagueLabel));
            }, () => {
                onSuccess(normalizeSportScoreCompetitionTablePage(competitionPage, leagueLabel));
            });
        }, onError);
    }, onError);
}

function sportScorePreferredSeasonPath(html, options) {
    const seasons = sportScoreSeasonOptionsFromCompetitionPage(html);
    if (seasons.length === 0)
        return "";

    const wanted = sportScoreSeasonMatchKey(stringValue(options && options.seasonLabel).trim());
    if (wanted.length > 0) {
        for (let index = 0; index < seasons.length; index += 1) {
            const row = seasons[index];
            if (sportScoreSeasonMatchKey(row.label) === wanted)
                return row.path;
        }
    }

    // Choose the newest season by label key when no explicit season is requested.
    let best = seasons[0];
    let bestScore = sportScoreSeasonSortScore(best && best.label);
    for (let index = 1; index < seasons.length; index += 1) {
        const candidate = seasons[index];
        const score = sportScoreSeasonSortScore(candidate && candidate.label);
        if (score > bestScore) {
            best = candidate;
            bestScore = score;
        }
    }

    return stringValue(best && best.path);
}

function sportScoreSeasonOptionsFromCompetitionPage(html) {
    const text = stringValue(html);
    let rows = [];
    const seen = {};

    const pattern = /<option[^>]*value="([^"]+\/\d{4}-\d{4}\/?)"[^>]*>([^<]+)<\/option>/g;
    let match = pattern.exec(text);
    while (match) {
        const path = sportScorePathFromUrl(match[1]);
        const label = htmlText(match[2]);
        const key = sportScoreSeasonMatchKey(label.length > 0 ? label : path);
        if (path.length > 0 && key.length > 0 && !seen[key]) {
            seen[key] = true;
            rows.push({ path, label });
        }

        match = pattern.exec(text);
    }

    // Some pages render history links outside of <select>; accept direct season links too.
    const linkPattern = /href="(\/football\/competition\/[^"]+\/(\d{4}-\d{4})\/?)"/g;
    match = linkPattern.exec(text);
    while (match) {
        const path = sportScorePathFromUrl(match[1]);
        const key = sportScoreSeasonMatchKey(match[2]);
        if (path.length > 0 && key.length > 0 && !seen[key]) {
            seen[key] = true;
            rows.push({ path, label: match[2] });
        }
        match = linkPattern.exec(text);
    }

    return rows;
}

function sportScoreSeasonMatchKey(value) {
    const text = stringValue(value).trim();
    if (text.length === 0)
        return "";

    const direct = text.match(/(\d{4})\D+(\d{4})/);
    if (direct)
        return `${direct[1]}-${direct[2]}`;

    const short = text.match(/(\d{2})\D+(\d{2})/);
    if (short) {
        const start = Number(short[1]);
        const end = Number(short[2]);
        if (Number.isFinite(start) && Number.isFinite(end))
            return `${start + 2000}-${end + 2000}`;
    }

    return normalizedText(text);
}

function sportScoreSeasonSortScore(label) {
    const key = sportScoreSeasonMatchKey(label);
    const direct = /^(\d{4})-(\d{4})$/.exec(key);
    if (direct)
        return numberValue(direct[1]) * 10000 + numberValue(direct[2]);

    const single = /^(\d{4})$/.exec(key);
    if (single)
        return numberValue(single[1]) * 10000;

    return 0;
}

function normalizeSportScoreCompetitionTablePage(html, leagueLabel) {
    const tableSection = sportScoreStandingsTableSection(html);
    if (tableSection.length === 0)
        return [];

    let rows = [];
    const rowPattern = /<tr>([\s\S]*?)<\/tr>/g;
    let rowMatch = rowPattern.exec(tableSection);
    while (rowMatch) {
        const rowHtml = rowMatch[1];
        const cells = [];
        const cellPattern = /<td\b[^>]*>([\s\S]*?)<\/td>/g;
        let cellMatch = cellPattern.exec(rowHtml);
        while (cellMatch) {
            cells.push(htmlText(cellMatch[1]));
            cellMatch = cellPattern.exec(rowHtml);
        }

        if (cells.length >= 10) {
            const teamAnchor = /<td class="team-col">[\s\S]*?<a[^>]*href="([^"]+)"/.exec(rowHtml);
            const crestMatch = /<td class="team-col">[\s\S]*?<img[^>]*src="([^"]+)"/.exec(rowHtml);
            const formRaw = String(cells[10] || "").trim();
            const form = formRaw.length > 0
                ? formRaw.split(/\s+/).map(value => String(value || "").trim().toUpperCase()).filter(value => value === "W" || value === "D" || value === "L").join(",")
                : "";

            rows.push({
                position: numberValue(cells[0]),
                team: stringValue(cells[1]),
                group: "",
                groupIndex: 0,
                played: numberValue(cells[2]),
                won: numberValue(cells[3]),
                draw: numberValue(cells[4]),
                lost: numberValue(cells[5]),
                goalsFor: numberValue(cells[6]),
                goalsAgainst: numberValue(cells[7]),
                goalDifference: numberValue(cells[8]),
                points: numberValue(cells[9]),
                form,
                crest: crestMatch ? htmlDecode(crestMatch[1]) : "",
                teamSlug: sportScoreTeamSlug({
                    team: stringValue(cells[1]),
                    teamPath: teamAnchor ? htmlDecode(teamAnchor[1]) : ""
                }),
                league: stringValue(leagueLabel)
            });
        }

        rowMatch = rowPattern.exec(tableSection);
    }

    return rows
        .filter(row => stringValue(row.team).length > 0)
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
    if (bodyOpenEnd < 0)
        return "";

    const bodyEnd = value.indexOf("</tbody>", bodyOpenEnd + 1);
    if (bodyEnd < 0)
        return "";

    return value.slice(bodyOpenEnd + 1, bodyEnd);
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

    function fetchFromSofaScore() {
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

    if (canFetchEspnFixtures(options)) {
        fetchEspnFixtures(options, fixtures => {
            if (fixtures.length > 0) {
                onSuccess(fixtures);
                return;
            }

            fetchFromSofaScore();
        }, message => {
            remember(message);
            fetchFromSofaScore();
        });
        return;
    }

    fetchFromSofaScore();
}

function canFetchEspnFootball(options) {
    return isFootballSelection(options) && ProviderCatalog.leagueLabel(options && options.league).length > 0;
}

function canFetchEspnFixtures(options) {
    return canFetchEspnFootball(options);
}

function canFetchEspnMatchDetails(options) {
    return stringValue(options && options.espnEventId).length > 0 && stringValue(options && options.espnLeagueSlug).length > 0;
}

function fetchEspnLiveScores(options, onSuccess, onError) {
    if (!canFetchEspnFootball(options)) {
        onSuccess([]);
        return;
    }

    resolveEspnSoccerSlug(options, leagueSlug => {
        if (leagueSlug.length === 0) {
            onSuccess([]);
            return;
        }

        fetchEspnScoreboards(leagueSlug, options, espnLiveDates(), payloads => {
            try {
                const matches = normalizeEspnScoreboards(payloads, options, leagueSlug).filter(isLiveMatch);
                onSuccess(filterSportScoreLiveRows(matches, options));
            } catch (error) {
                onError(String(error));
            }
        }, onError);
    }, onError);
}

function fetchEspnFixtures(options, onSuccess, onError) {
    if (!canFetchEspnFixtures(options)) {
        onSuccess([]);
        return;
    }

    resolveEspnSoccerSlug(options, leagueSlug => {
        if (leagueSlug.length === 0) {
            onSuccess([]);
            return;
        }

        fetchEspnScoreboards(leagueSlug, options, espnFixtureDates(options), payloads => {
            try {
                const now = Date.now();
                const matches = normalizeEspnScoreboards(payloads, options, leagueSlug).filter(match => {
                    if (isLiveMatch(match))
                        return true;

                    if (match.status === "Finished")
                        return false;

                    return numberValue(match.timestamp) === 0 || numberValue(match.timestamp) >= now - 3 * 60 * 60 * 1000;
                });
                onSuccess(sortMatches(dedupeMatches(filterMatchesForSelection(matches, options))));
            } catch (error) {
                onError(String(error));
            }
        }, onError);
    }, onError);
}

function fetchEspnRecentResults(options, onSuccess, onError) {
    if (!canFetchEspnFootball(options)) {
        onSuccess([]);
        return;
    }

    resolveEspnSoccerSlug(options, leagueSlug => {
        if (leagueSlug.length === 0) {
            onSuccess([]);
            return;
        }

        fetchEspnScoreboards(leagueSlug, options, espnRecentDates(options), payloads => {
            try {
                const matches = normalizeEspnScoreboards(payloads, options, leagueSlug).filter(isFinishedMatch);
                onSuccess(sortRecentMatches(dedupeMatches(filterMatchesForSelection(matches, options))));
            } catch (error) {
                onError(String(error));
            }
        }, onError);
    }, onError);
}

function fetchEspnMatchDetails(options, onSuccess, onError) {
    const leagueSlug = stringValue(options && options.espnLeagueSlug);
    const eventId = stringValue(options && options.espnEventId);
    if (leagueSlug.length === 0 || eventId.length === 0) {
        onSuccess(emptyLiveMatchDetails());
        return;
    }

    const url = `${ESPN_SOCCER_API_BASE_URL}/${encodeURIComponent(leagueSlug)}/summary?event=${encodeURIComponent(eventId)}`;
    requestJson(cacheBustedUrl(url), payload => {
        try {
            onSuccess(normalizeEspnLiveDetails(payload, options));
        } catch (error) {
            onError(String(error));
        }
    }, onError);
}

function fetchEspnScoreboards(leagueSlug, options, dates, onSuccess, onError) {
    const uniqueDates = uniqueStringValues(dates);
    let urls = uniqueDates.map(date => {
        return `${ESPN_SOCCER_API_BASE_URL}/${encodeURIComponent(leagueSlug)}/scoreboard?dates=${encodeURIComponent(date)}`;
    });

    if (Boolean(options && options.includeEspnDefaultScoreboard))
        urls.unshift(`${ESPN_SOCCER_API_BASE_URL}/${encodeURIComponent(leagueSlug)}/scoreboard`);

    urls = uniqueStringValues(urls);
    if (urls.length === 0) {
        onSuccess([]);
        return;
    }

    let pending = urls.length;
    let payloads = [];
    let errors = [];
    urls.forEach(url => {
        requestJson(cacheBustedUrl(url), payload => {
            payloads.push(payload);
            pending -= 1;
            if (pending === 0)
                finishEspnScoreboards(payloads, errors, onSuccess, onError);
        }, message => {
            if (!isHttpNotFound(message))
                errors.push(`ESPN: ${message}`);

            pending -= 1;
            if (pending === 0)
                finishEspnScoreboards(payloads, errors, onSuccess, onError);
        });
    });
}

function finishEspnScoreboards(payloads, errors, onSuccess, onError) {
    if (payloads.length > 0 || errors.length === 0) {
        onSuccess(payloads);
    } else {
        onError(errors.join(", "));
    }
}

function normalizeEspnScoreboards(payloads, options, leagueSlug) {
    let matches = [];
    arrayValue(payloads).forEach(payload => {
        const leagueLabel = espnLeagueLabel(payload, options);
        matches = matches.concat(arrayValue(payload && payload.events).map(event => {
            return normalizeEspnMatch(event, leagueSlug, leagueLabel);
        }).filter(hasTeams));
    });
    return sortMatches(dedupeMatches(matches));
}

function normalizeEspnMatch(event, leagueSlug, leagueLabel) {
    event = event || {};
    const competition = arrayValue(event.competitions)[0] || {};
    const competitors = arrayValue(competition.competitors);
    const home = espnCompetitor(competitors, "home");
    const away = espnCompetitor(competitors, "away");
    const timestamp = Date.parse(event.date || competition.date || "");
    const status = espnMatchStatus(competition.status || event.status);
    const minute = status === "Live" ? espnMatchMinute(competition.status || event.status) : "";

    return {
        id: "espn-" + stringValue(event.id || competition.id),
        sport: "football",
        league: stringValue(leagueLabel),
        homeTeam: espnTeamName(home),
        awayTeam: espnTeamName(away),
        homeScore: stringValue(home.score),
        awayScore: stringValue(away.score),
        status,
        minute,
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: espnRoundLabel(event, competition),
        stadium: espnVenueName(competition.venue || event.venue),
        homeBadge: espnTeamLogo(home),
        awayBadge: espnTeamLogo(away),
        poster: "",
        popular: false,
        detailsProvider: "espn",
        statsProvider: "espn",
        espnLeagueSlug: leagueSlug,
        espnEventId: stringValue(event.id || competition.id)
    };
}

function normalizeEspnLiveDetails(payload, options) {
    payload = payload || {};
    const details = emptyLiveMatchDetails();
    const competition = espnSummaryCompetition(payload);
    const competitors = arrayValue(competition && competition.competitors);
    const homeCompetitor = espnCompetitor(competitors, "home");
    const awayCompetitor = espnCompetitor(competitors, "away");
    const boxTeams = arrayValue(payload && payload.boxscore && payload.boxscore.teams);
    const homeBox = espnBoxscoreTeam(boxTeams, homeCompetitor, options && options.homeTeam, 0);
    const awayBox = espnBoxscoreTeam(boxTeams, awayCompetitor, options && options.awayTeam, 1);
    const homeStats = espnStatsMap(homeBox && homeBox.statistics);
    const awayStats = espnStatsMap(awayBox && awayBox.statistics);
    const status = competition && competition.status ? competition.status : {};

    details.ok = true;
    details.statusLabel = espnMatchStatus(status);
    details.homeScore = stringValue(homeCompetitor.score !== undefined ? homeCompetitor.score : options && options.homeScore);
    details.awayScore = stringValue(awayCompetitor.score !== undefined ? awayCompetitor.score : options && options.awayScore);
    details.updatedAt = stringValue(payload.lastUpdated);
    details.summaryRows = [
        liveSummaryRow("corners", i18ncShim("Corners"), espnStatNumber(homeStats, ["wonCorners", "cornerKicks", "corners"]), espnStatNumber(awayStats, ["wonCorners", "cornerKicks", "corners"])),
        liveSummaryRow("yellow", i18ncShim("Yellow cards"), espnStatNumber(homeStats, ["yellowCards"]), espnStatNumber(awayStats, ["yellowCards"])),
        liveSummaryRow("red", i18ncShim("Red cards"), espnStatNumber(homeStats, ["redCards"]), espnStatNumber(awayStats, ["redCards"]))
    ];
    details.statsRows = [
        liveStatRow(i18ncShim("Possession"), espnStatNumber(homeStats, ["possessionPct", "possession"]), espnStatNumber(awayStats, ["possessionPct", "possession"]), true),
        liveStatRow(i18ncShim("Shots"), espnStatNumber(homeStats, ["totalShots", "shotsTotal"]), espnStatNumber(awayStats, ["totalShots", "shotsTotal"]), false),
        liveStatRow(i18ncShim("Shots on target"), espnStatNumber(homeStats, ["shotsOnTarget"]), espnStatNumber(awayStats, ["shotsOnTarget"]), false),
        liveStatRow(i18ncShim("Fouls"), espnStatNumber(homeStats, ["foulsCommitted", "fouls"]), espnStatNumber(awayStats, ["foulsCommitted", "fouls"]), false),
        liveStatRow(i18ncShim("Offsides"), espnStatNumber(homeStats, ["offsides"]), espnStatNumber(awayStats, ["offsides"]), false),
        liveStatRow(i18ncShim("Saves"), espnStatNumber(homeStats, ["saves", "goalkeeperSaves"]), espnStatNumber(awayStats, ["saves", "goalkeeperSaves"]), false)
    ];
    details.events = arrayValue(payload.keyEvents).map(normalizeEspnKeyEvent).filter(event => event.label.length > 0 || event.kind.length > 0);
    details.hasRealtimeStats = details.statsRows.some(row => numberValue(row.homeRaw) > 0 || numberValue(row.awayRaw) > 0) ||
        details.summaryRows.some(row => numberValue(row.homeValue) > 0 || numberValue(row.awayValue) > 0);

    return details;
}

function espnLiveDates() {
    return espnDatesAroundToday(-1, 1);
}

function espnFixtureDates(options) {
    const days = Math.max(1, Math.min(21, numberValue(options && options.scoreboardDaysForward) || 14));
    return espnDatesAroundToday(0, days);
}

function espnRecentDates(options) {
    const days = Math.max(1, Math.min(30, numberValue(options && options.scoreboardDaysBack) || 14));
    return espnDatesAroundToday(-days, 0);
}

function espnDatesAroundToday(fromOffset, toOffset) {
    let dates = [];
    const today = new Date();
    for (let offset = fromOffset; offset <= toOffset; offset += 1) {
        dates.push(espnDateString(new Date(today.getFullYear(), today.getMonth(), today.getDate() + offset)));
    }
    return dates;
}

function espnDateString(date) {
    return String(date.getFullYear()) + pad(date.getMonth() + 1) + pad(date.getDate());
}

function espnSoccerSlug(options) {
    const league = ProviderCatalog.sportScoreSlug(options && options.league);
    return stringValue(ESPN_SOCCER_LEAGUES[league]);
}

function resolveEspnSoccerSlug(options, onSuccess, onError) {
    const mappedSlug = espnSoccerSlug(options);
    if (mappedSlug.length > 0) {
        onSuccess(mappedSlug);
        return;
    }

    const cacheKey = fallbackCacheKey(options);
    if (espnLeagueSlugCache[cacheKey] !== undefined) {
        onSuccess(stringValue(espnLeagueSlugCache[cacheKey]));
        return;
    }

    fetchEspnLeagueCatalog(rows => {
        const resolved = selectEspnCatalogLeagueSlug(rows, options);
        espnLeagueSlugCache[cacheKey] = resolved;
        onSuccess(resolved);
    }, onError);
}

function fetchEspnLeagueCatalog(onSuccess, onError) {
    const now = Date.now();
    if (espnLeagueCatalogCache.timestamp > 0
        && (now - espnLeagueCatalogCache.timestamp) < ESPN_LEAGUE_CATALOG_CACHE_TTL_MS
        && arrayValue(espnLeagueCatalogCache.rows).length > 0) {
        onSuccess(espnLeagueCatalogCache.rows);
        return;
    }

    requestText(cacheBustedUrl(ESPN_SOCCER_COMPETITIONS_URL), html => {
        try {
            const rows = parseEspnLeagueCatalog(html);
            espnLeagueCatalogCache = {
                timestamp: now,
                rows
            };
            onSuccess(rows);
        } catch (error) {
            onError(String(error));
        }
    }, onError);
}

function parseEspnLeagueCatalog(html) {
    const payload = parseEspnFittPayload(html);
    if (!payload)
        return [];

    let rows = [];
    collectEspnLeagueCatalogRows(payload, rows);

    let deduped = [];
    let seen = {};
    rows.forEach(row => {
        const slug = stringValue(row && row.slug);
        const label = stringValue(row && row.label);
        if (slug.length === 0 || label.length === 0 || seen[slug])
            return;

        seen[slug] = true;
        deduped.push({
            slug,
            label
        });
    });

    return deduped;
}

function parseEspnFittPayload(html) {
    const value = stringValue(html);
    const markers = [
        "window['__espnfitt__']",
        "window[\"__espnfitt__\"]"
    ];
    let markerIndex = -1;
    let markerLength = 0;
    markers.forEach(marker => {
        if (markerIndex >= 0)
            return;

        const index = value.indexOf(marker);
        if (index >= 0) {
            markerIndex = index;
            markerLength = marker.length;
        }
    });
    if (markerIndex < 0)
        return null;

    const equalsIndex = value.indexOf("=", markerIndex + markerLength);
    if (equalsIndex < 0)
        return null;

    const start = value.indexOf("{", equalsIndex + 1);
    if (start < 0)
        return null;

    let depth = 0;
    let inString = false;
    let escaped = false;
    for (let index = start; index < value.length; index += 1) {
        const char = value.charAt(index);
        if (inString) {
            if (escaped) {
                escaped = false;
                continue;
            }

            if (char === "\\") {
                escaped = true;
                continue;
            }

            if (char === "\"")
                inString = false;
            continue;
        }

        if (char === "\"") {
            inString = true;
            continue;
        }

        if (char === "{")
            depth += 1;
        else if (char === "}")
            depth -= 1;

        if (depth === 0) {
            const jsonText = value.slice(start, index + 1);
            return JSON.parse(jsonText);
        }
    }

    return null;
}

function collectEspnLeagueCatalogRows(node, rows) {
    if (!node || typeof node !== "object")
        return;

    if (Array.isArray(node)) {
        node.forEach(item => collectEspnLeagueCatalogRows(item, rows));
        return;
    }

    const links = arrayValue(node.lk);
    links.forEach(link => {
        const url = stringValue(link && link.u);
        const slug = espnLeagueSlugFromUrl(url);
        if (slug.length === 0)
            return;

        const label = stringValue(node.n || node.name || node.t || link && (link.t || link.n || link.name));
        if (label.length === 0)
            return;

        rows.push({
            slug,
            label
        });
    });

    Object.keys(node).forEach(key => {
        collectEspnLeagueCatalogRows(node[key], rows);
    });
}

function espnLeagueSlugFromUrl(url) {
    const value = stringValue(url);
    const match = /\/soccer\/league\/_\/name\/([^/?#]+)/.exec(value);
    return match ? stringValue(match[1]) : "";
}

function selectEspnCatalogLeagueSlug(rows, options) {
    const wantedLabel = ProviderCatalog.leagueLabel(options && options.league);
    const wantedSlug = ProviderCatalog.sportScoreSlug(options && options.league).replace(/-/g, " ");
    let bestSlug = "";
    let bestScore = 0;

    rows.forEach(row => {
        const label = stringValue(row && row.label);
        const score = Math.max(similarityScore(label, wantedLabel), similarityScore(label, wantedSlug));
        if (score > bestScore) {
            bestScore = score;
            bestSlug = stringValue(row && row.slug);
        }
    });

    return bestScore > 0 ? bestSlug : "";
}

function espnLeagueLabel(payload, options) {
    const configured = ProviderCatalog.leagueLabel(options && options.league);
    if (configured.length > 0)
        return configured;

    const league = payload && payload.leagues ? arrayValue(payload.leagues)[0] : {};
    return stringValue(league && (league.name || league.abbreviation || league.slug));
}

function espnCompetitor(competitors, homeAway) {
    const wanted = stringValue(homeAway).toLowerCase();
    for (let index = 0; index < competitors.length; index += 1) {
        if (stringValue(competitors[index] && competitors[index].homeAway).toLowerCase() === wanted)
            return competitors[index];
    }

    return wanted === "home" ? (competitors[0] || {}) : (competitors[1] || {});
}

function espnTeamName(competitor) {
    const team = competitor && competitor.team ? competitor.team : {};
    return stringValue(team.shortDisplayName || team.displayName || team.name || competitor && competitor.displayName);
}

function espnTeamLogo(competitor) {
    const team = competitor && competitor.team ? competitor.team : {};
    const logos = arrayValue(team.logos);
    if (logos.length > 0)
        return stringValue(logos[0].href);

    return stringValue(team.logo);
}

function espnMatchStatus(status) {
    status = status || {};
    const type = status.type || {};
    const state = stringValue(type.state || status.state).toLowerCase();
    if (state === "in")
        return "Live";

    if (state === "post" || Boolean(type.completed || status.completed))
        return "Finished";

    if (state === "pre")
        return "Upcoming";

    return statusLabel(type.description || type.detail || type.shortDetail || status.description || status.detail);
}

function espnMatchMinute(status) {
    status = status || {};
    const type = status.type || {};
    const displayClock = stringValue(status.displayClock);
    if (displayClock.length > 0)
        return displayClock;

    return stringValue(type.shortDetail || type.detail);
}

function espnRoundLabel(event, competition) {
    const week = event && event.week ? event.week : competition && competition.week;
    const label = roundLabelFromText(week && (week.text || week.label || week.displayName || week.name));
    if (label.length > 0)
        return label;

    if (week && numberValue(week.number) > 0)
        return "Round " + numberValue(week.number);

    return "";
}

function roundLabelFromText(value) {
    const text = stringValue(value).replace(/[_-]+/g, " ").replace(/\s+/g, " ").trim();
    if (text.length === 0)
        return "";

    const normalized = normalizedText(text);
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

function espnVenueName(venue) {
    venue = venue || {};
    return stringValue(venue.fullName || venue.displayName || venue.name);
}

function espnSummaryCompetition(payload) {
    const header = payload && payload.header ? payload.header : {};
    return arrayValue(header.competitions)[0] || {};
}

function espnBoxscoreTeam(boxTeams, competitor, fallbackName, fallbackIndex) {
    const competitorTeam = competitor && competitor.team ? competitor.team : {};
    const wantedId = stringValue(competitorTeam.id);
    const wantedName = stringValue(fallbackName || espnTeamName(competitor));

    for (let index = 0; index < boxTeams.length; index += 1) {
        const boxTeam = boxTeams[index] || {};
        const team = boxTeam.team || {};
        if (wantedId.length > 0 && stringValue(team.id) === wantedId)
            return boxTeam;

        if (wantedName.length > 0 && sameTeamName(team.displayName || team.shortDisplayName || team.name, wantedName))
            return boxTeam;
    }

    return boxTeams[fallbackIndex] || {};
}

function espnStatsMap(statistics) {
    let result = {};
    arrayValue(statistics).forEach(stat => {
        const name = stringValue(stat && stat.name);
        if (name.length === 0)
            return;

        result[name] = stat;
    });
    return result;
}

function espnStatNumber(stats, names) {
    for (let index = 0; index < names.length; index += 1) {
        const stat = stats[names[index]];
        if (!stat)
            continue;

        if (stat.value !== undefined && stat.value !== null)
            return numberValue(stat.value);

        const display = stringValue(stat.displayValue || stat.summary || stat.shortDisplayValue);
        if (display.length > 0)
            return numberValue(display.replace(/[^0-9.-]/g, ""));
    }

    return 0;
}

function normalizeEspnKeyEvent(event) {
    event = event || {};
    const type = event.type || {};
    return {
        minute: stringValue(event.clock && event.clock.displayValue || event.displayTime || event.timeElapsed),
        kind: espnEventKind(type),
        side: "",
        label: stringValue(event.text || type.text || type.displayName || type.name),
        player: stringValue(event.athlete && (event.athlete.displayName || event.athlete.shortName)),
        inPlayer: "",
        outPlayer: ""
    };
}

function espnEventKind(type) {
    const value = normalizedText(type && (type.id || type.name || type.text || type.displayName));
    if (value.indexOf("goal") >= 0)
        return "goal";

    if (value.indexOf("yellow") >= 0)
        return "yellow";

    if (value.indexOf("red") >= 0)
        return "red";

    if (value.indexOf("sub") >= 0)
        return "sub";

    return value;
}

function uniqueStringValues(values) {
    let seen = {};
    let result = [];
    arrayValue(values).forEach(value => {
        const text = stringValue(value);
        if (text.length === 0 || seen[text])
            return;

        seen[text] = true;
        result.push(text);
    });
    return result;
}

function similarityScore(left, right) {
    left = normalizedText(left);
    right = normalizedText(right);
    if (left.length === 0 || right.length === 0)
        return 0;

    if (left === right)
        return 8;

    if (left.indexOf(right) >= 0 || right.indexOf(left) >= 0)
        return 5;

    const leftTokens = left.split(" ").filter(token => token.length > 1);
    const rightTokens = right.split(" ").filter(token => token.length > 1);
    if (leftTokens.length === 0 || rightTokens.length === 0)
        return 0;

    let shared = 0;
    rightTokens.forEach(token => {
        if (leftTokens.indexOf(token) >= 0)
            shared += 1;
    });

    const ratio = shared / Math.max(leftTokens.length, rightTokens.length);
    if (ratio >= 0.75)
        return 4;

    if (ratio >= 0.5)
        return 2;

    return 0;
}

function canFetchSofaScoreFixtures(options) {
    return isFootballSelection(options) && ProviderCatalog.sportScoreSlug(options && options.league).length > 0;
}

function fetchSofaScoreLeagueSeasons(options, onSuccess, onError) {
    resolveSofaScoreLeague(options, league => {
        const leagueId = numberValue(league && league.id);
        if (leagueId <= 0) {
            onSuccess([]);
            return;
        }

        requestJson(`${SOFASCORE_API_BASE_URL}/unique-tournament/${leagueId}/seasons`, payload => {
            const now = Date.now();
            const rows = arrayValue(payload && payload.seasons)
                .map((season, index) => normalizeSofaScoreSeasonOption(season, league, index, now))
                .filter(option => stringValue(option && option.id).length > 0)
                .sort((left, right) => seasonSortScore(right) - seasonSortScore(left));
            onSuccess(rows);
        }, onError);
    }, onError);
}

function normalizeSofaScoreSeasonOption(season, league, index, now) {
    season = season || {};
    const id = numberValue(season.id);
    if (id <= 0)
        return {};

    const seasonLabel = sofaScoreSeasonLabel(season);
    const startTimestamp = numberValue(season.startDateTimestamp) * 1000;
    const endTimestamp = numberValue(season.endDateTimestamp) * 1000;
    const current = Boolean(season.current);
    const ongoing = current || (startTimestamp > 0 && endTimestamp > 0 && now >= startTimestamp && now <= endTimestamp) || (startTimestamp > 0 && endTimestamp === 0 && now >= startTimestamp);
    const completed = endTimestamp > 0 && endTimestamp < now;
    const yearScore = sofaScoreSeasonYearScore(season, startTimestamp, endTimestamp, index);

    return {
        id: stringValue(id),
        key: `sofascore:${id}`,
        provider: "sofascore",
        label: normalizeSeasonLabelDisplay(seasonLabel.length > 0 ? seasonLabel : stringValue(id)),
        isCurrent: current,
        isOngoing: ongoing,
        isCompleted: completed,
        yearScore
    };
}

function sofaScoreSeasonYearScore(season, startTimestamp, endTimestamp, index) {
    const yearValue = stringValue(season && season.year);
    const fromYear = parseSeasonYearValue(yearValue);
    if (fromYear > 0)
        return fromYear;

    if (endTimestamp > 0)
        return new Date(endTimestamp).getFullYear();

    if (startTimestamp > 0)
        return new Date(startTimestamp).getFullYear();

    return 1000 - index;
}

function sofaScoreSeasonLabel(season) {
    const direct = stringValue(season && (season.year || season.name || season.slug));
    if (direct.length > 0)
        return direct;

    const startTimestamp = numberValue(season && season.startDateTimestamp) * 1000;
    const endTimestamp = numberValue(season && season.endDateTimestamp) * 1000;
    if (startTimestamp > 0 && endTimestamp > 0) {
        const startYear = new Date(startTimestamp).getFullYear();
        const endYear = new Date(endTimestamp).getFullYear();
        if (startYear === endYear)
            return stringValue(startYear);

        return `${startYear}/${String(endYear).slice(-2)}`;
    }

    return "";
}

function fetchSofaScoreTableForSeason(options, onSuccess, onError) {
    resolveSofaScoreLeague(options, league => {
        const leagueId = numberValue(league && league.id);
        if (leagueId <= 0) {
            onSuccess([]);
            return;
        }

        requestJson(`${SOFASCORE_API_BASE_URL}/unique-tournament/${leagueId}/seasons`, payload => {
            const seasons = arrayValue(payload && payload.seasons);
            const seasonId = selectSofaScoreSeasonIdForOptions(options, seasons);
            if (seasonId <= 0) {
                onSuccess([]);
                return;
            }

            const candidates = [
                `${SOFASCORE_API_BASE_URL}/unique-tournament/${leagueId}/season/${seasonId}/standings/total`,
                `${SOFASCORE_API_BASE_URL}/unique-tournament/${leagueId}/season/${seasonId}/standings`
            ];
            requestSofaScoreTableCandidates(candidates, league, onSuccess, onError);
        }, onError);
    }, onError);
}

function requestSofaScoreTableCandidates(urls, league, onSuccess, onError, index) {
    const currentIndex = numberValue(index);
    if (currentIndex >= urls.length) {
        onError("SofaScore returned no standings for this season.");
        return;
    }

    requestJson(urls[currentIndex], payload => {
        const rows = normalizeSofaScoreTable(payload, league);
        if (rows.length > 0) {
            onSuccess(rows);
            return;
        }

        requestSofaScoreTableCandidates(urls, league, onSuccess, onError, currentIndex + 1);
    }, () => {
        requestSofaScoreTableCandidates(urls, league, onSuccess, onError, currentIndex + 1);
    });
}

function normalizeSofaScoreTable(payload, league) {
    const standings = arrayValue(payload && payload.standings);
    let rows = [];

    standings.forEach((standing, groupIndex) => {
        const group = stringValue(standing && (standing.name || standing.groupName || standing.description));
        const tableRows = arrayValue(standing && (standing.rows || standing.table));
        tableRows.forEach(row => {
            const team = row && row.team ? row.team : {};
            const teamName = stringValue(team.shortName || team.name || row && row.teamName);
            if (teamName.length === 0)
                return;

            const teamId = numberValue(team.id || row && row.teamId);
            rows.push({
                position: numberValue(row && (row.position || row.rank || row.pos)),
                team: teamName,
                group,
                groupIndex,
                played: numberValue(row && (row.matches || row.played || row.p)),
                won: numberValue(row && (row.wins || row.win || row.w)),
                draw: numberValue(row && (row.draws || row.draw || row.d)),
                lost: numberValue(row && (row.losses || row.lost || row.l)),
                goalsFor: numberValue(row && (row.scoresFor || row.goalsFor || row.gf || row.goals_scored)),
                goalsAgainst: numberValue(row && (row.scoresAgainst || row.goalsAgainst || row.ga || row.goals_conceded)),
                points: numberValue(row && (row.points || row.pts)),
                goalDifference: numberValue(row && (row.scoreDiffFormatted || row.scoreDiff || row.goalDifference || row.gd)),
                form: stringValue(row && row.form),
                crest: teamId > 0 ? sofaScoreTeamImage(teamId) : "",
                teamSlug: ProviderCatalog.sportScoreSlug(teamName),
                league: stringValue(league && league.label)
            });
        });
    });

    rows = rows
        .filter(row => row.team.length > 0)
        .sort((left, right) => left.groupIndex - right.groupIndex || left.position - right.position || left.team.localeCompare(right.team));

    return consolidateSofaScoreStandings(rows);
}

function consolidateSofaScoreStandings(rows) {
    rows = arrayValue(rows);
    if (rows.length === 0)
        return [];

    let byTeam = {};
    rows.forEach(row => {
        const key = normalizedText(row && row.team);
        if (key.length === 0)
            return;

        const current = byTeam[key];
        if (!current || sofaScoreStandingRowScore(row) > sofaScoreStandingRowScore(current))
            byTeam[key] = row;
    });

    const uniqueRows = Object.keys(byTeam).map(key => byTeam[key]);
    if (uniqueRows.length === rows.length)
        return uniqueRows;

    const sorted = uniqueRows.sort((left, right) => {
        return numberValue(right.points) - numberValue(left.points)
            || numberValue(right.goalDifference) - numberValue(left.goalDifference)
            || numberValue(right.goalsFor) - numberValue(left.goalsFor)
            || numberValue(right.won) - numberValue(left.won)
            || stringValue(left.team).localeCompare(stringValue(right.team));
    });

    return sorted.map((row, index) => {
        const copy = Object.assign({}, row);
        copy.position = index + 1;
        copy.group = "";
        copy.groupIndex = 0;
        return copy;
    });
}

function sofaScoreStandingRowScore(row) {
    row = row || {};
    const played = numberValue(row.played);
    const points = numberValue(row.points);
    const goalDifference = numberValue(row.goalDifference);
    const group = normalizedText(row.group);
    const stageBonus = group.indexOf("round") >= 0 ? 1000000 : 0;
    return stageBonus + played * 10000 + points * 100 + goalDifference;
}

function canFetchSofaScoreTeamFixtures(options) {
    return isFootballSelection(options) && stringValue(options && options.favoriteTeam).trim().length > 0;
}

function fetchSofaScoreTeamFixtures(options, onSuccess, onError) {
    if (!canFetchSofaScoreTeamFixtures(options)) {
        onSuccess([]);
        return;
    }

    const row = {
        team: stringValue(options && options.favoriteTeam).trim()
    };
    if (row.team.length === 0) {
        onSuccess([]);
        return;
    }

    searchSofaScoreTeam(options, row, team => {
        const teamId = numberValue(team && team.id);
        if (teamId <= 0) {
            onSuccess([]);
            return;
        }

        fetchSofaScoreTeamFixturePage(options, row, team, 0, [], onSuccess, onError);
    }, onError);
}

function fetchSofaScoreTeamFixturePage(options, row, team, page, matches, onSuccess, onError) {
    const teamId = numberValue(team && team.id);
    if (teamId <= 0) {
        onSuccess(sortMatches(dedupeMatches(arrayValue(matches).filter(hasTeams))));
        return;
    }

    const url = `${SOFASCORE_API_BASE_URL}/team/${teamId}/events/next/${page}`;
    requestJson(url, payload => {
        const sourceTeam = stringValue(team && team.name).trim() || stringValue(row && row.team).trim();
        const rows = arrayValue(payload && payload.events)
            .map(event => normalizeSofaScoreFixture(event, {
                label: stringValue(event && event.tournament && event.tournament.uniqueTournament && event.tournament.uniqueTournament.name) || stringValue(event && event.tournament && event.tournament.name)
            }))
            .filter(hasTeams)
            .filter(match => teamMatchIncludesFavorite(match, sourceTeam) || teamMatchIncludesFavorite(match, row && row.team));
        const combined = dedupeMatches(arrayValue(matches).concat(rows));
        if (payload && payload.hasNextPage && page < 2 && combined.length < 40) {
            fetchSofaScoreTeamFixturePage(options, row, team, page + 1, combined, onSuccess, onError);
            return;
        }

        onSuccess(sortMatches(combined));
    }, onError);
}

function fetchSofaScoreFixtures(options, onSuccess, onError) {
    resolveSofaScoreLeague(options, league => {
        if (numberValue(league && league.id) <= 0) {
            onSuccess([]);
            return;
        }

        requestJson(`${SOFASCORE_API_BASE_URL}/unique-tournament/${league.id}/seasons`, payload => {
            const season = arrayValue(payload && payload.seasons)[0];
            const seasonId = numberValue(season && season.id);
            if (seasonId <= 0) {
                onSuccess([]);
                return;
            }

            fetchSofaScoreFixturePage(league, seasonId, 0, [], onSuccess, onError);
        }, onError);
    }, onError);
}

function canFetchSofaScoreRecentResults(options) {
    return canFetchSofaScoreFixtures(options);
}

function fetchSofaScoreRecentResults(options, onSuccess, onError) {
    resolveSofaScoreLeague(options, league => {
        if (numberValue(league && league.id) <= 0) {
            onSuccess([]);
            return;
        }

        requestJson(`${SOFASCORE_API_BASE_URL}/unique-tournament/${league.id}/seasons`, payload => {
            const seasons = arrayValue(payload && payload.seasons);
            const seasonId = selectSofaScoreSeasonIdForOptions(options, seasons);
            if (seasonId <= 0) {
                onSuccess([]);
                return;
            }

            const limit = recentResultsLimitValue(options);
            fetchSofaScoreRecentPage(league, seasonId, 0, [], limit, onSuccess, onError);
        }, onError);
    }, onError);
}

function isSeasonScopedRequest(options) {
    const seasonKey = stringValue(options && options.seasonKey).trim();
    const seasonLabel = stringValue(options && options.seasonLabel).trim();
    const seasonId = stringValue(options && options.seasonId).trim();
    return seasonKey.length > 0 || seasonLabel.length > 0 || seasonId.length > 0;
}

function selectSofaScoreSeasonIdForOptions(options, seasons) {
    const rows = arrayValue(seasons);
    if (rows.length === 0)
        return 0;

    const wantedId = numberValue(options && options.seasonId);
    if (wantedId > 0) {
        const exact = rows.find(season => numberValue(season && season.id) === wantedId);
        if (exact)
            return wantedId;
    }

    const wantedLabel = sportScoreSeasonMatchKey(options && options.seasonLabel);
    if (wantedLabel.length > 0) {
        const byLabel = rows.find(season => sportScoreSeasonMatchKey(sofaScoreSeasonLabel(season)) === wantedLabel);
        if (byLabel)
            return numberValue(byLabel && byLabel.id);
    }

    return numberValue(rows[0] && rows[0].id);
}

function resolveSofaScoreLeague(options, onSuccess, onError) {
    const mapped = fallbackLeague(SOFASCORE_TOURNAMENTS, options);
    if (numberValue(mapped && mapped.id) > 0) {
        onSuccess(mapped);
        return;
    }

    const cacheKey = fallbackCacheKey(options);
    if (sofaScoreLeagueCache[cacheKey] !== undefined) {
        onSuccess(sofaScoreLeagueCache[cacheKey]);
        return;
    }

    searchSofaScoreLeague(options, league => {
        sofaScoreLeagueCache[cacheKey] = league || {};
        onSuccess(league);
    }, onError);
}

function searchSofaScoreLeague(options, onSuccess, onError) {
    const label = sofaScoreLeagueSearchLabel(options);
    if (label.length === 0) {
        onSuccess({});
        return;
    }

    const url = `${SOFASCORE_API_BASE_URL}/search/unique-tournaments?q=${encodeURIComponent(label)}`;
    requestJson(url, payload => {
        const league = selectSofaScoreLeague(payload, options);
        onSuccess(league);
    }, () => {
        const fallbackUrl = `${SOFASCORE_API_BASE_URL}/search/all?q=${encodeURIComponent(label)}`;
        requestJson(fallbackUrl, payload => {
            const league = selectSofaScoreLeague(payload, options);
            onSuccess(league);
        }, onError);
    });
}

function sofaScoreLeagueSearchLabel(options) {
    return ProviderCatalog.leagueLabel(options && options.league);
}

function selectSofaScoreLeague(payload, options) {
    const wantedLeague = sofaScoreLeagueSearchLabel(options);
    const hasCatalogLeague = ProviderCatalog.hasKnownFootballLeague(options && options.league);
    const wantedCountry = hasCatalogLeague ? ProviderCatalog.countryLabel(options && options.country) : "";
    const wantedSport = normalizeSports(options && options.sports)[0] || "football";
    const candidates = sofaScoreTournamentCandidates(payload);
    let best = {};
    let bestScore = 0;

    candidates.forEach(candidate => {
        const score = sofaScoreCandidateScore(candidate, wantedLeague, wantedCountry, wantedSport);
        if (score > bestScore) {
            bestScore = score;
            best = candidate;
        }
    });

    return bestScore > 0 ? best : {};
}

function sofaScoreTournamentCandidates(payload) {
    let result = [];
    let seen = {};

    function add(entity) {
        const id = numberValue(entity && entity.id);
        const name = stringValue(entity && entity.name);
        if (id <= 0 || name.length === 0 || seen[id])
            return;

        seen[id] = true;
        const category = entity && entity.category ? entity.category : {};
        result.push({
            id,
            label: name,
            country: stringValue(category.name || category.country && category.country.name || entity.country && entity.country.name),
            sport: normalizedText(category && category.sport && (category.sport.slug || category.sport.name) || entity && entity.sport && (entity.sport.slug || entity.sport.name))
        });
    }

    function walk(value, depth) {
        if (!value || depth > 6)
            return;

        if (Array.isArray(value)) {
            value.forEach(item => walk(item, depth + 1));
            return;
        }

        if (typeof value !== "object")
            return;

        add(value.entity || value.uniqueTournament || value.tournament || value);
        Object.keys(value).forEach(key => walk(value[key], depth + 1));
    }

    walk(payload, 0);
    return result;
}

function sofaScoreCandidateScore(candidate, leagueLabel, countryLabel, wantedSport) {
    const candidateName = normalizedText(candidate && candidate.label);
    const wantedName = normalizedText(leagueLabel);
    if (candidateName.length === 0 || wantedName.length === 0)
        return 0;

    const requestedSport = normalizedText(wantedSport);
    const candidateSport = normalizedText(candidate && candidate.sport);
    if (requestedSport === "football" || requestedSport === "soccer") {
        if (candidateSport.length > 0 && candidateSport !== "football" && candidateSport !== "soccer")
            return 0;
    }

    let score = similarityScore(candidateName, wantedName);
    if (score <= 0)
        return 0;

    const wantedCountry = normalizedText(countryLabel);
    const candidateCountry = normalizedText(candidate && candidate.country);
    if (wantedCountry.length > 0 && wantedCountry !== "international tournaments") {
        if (candidateCountry.length > 0 && (candidateCountry === wantedCountry || wantedCountry.indexOf(candidateCountry) >= 0 || candidateCountry.indexOf(wantedCountry) >= 0)) {
            score += 3;
        } else if (candidateCountry.length > 0) {
            score -= 2;
        }
    }

    return score;
}

function fetchSofaScoreRecentPage(league, seasonId, page, matches, limit, onSuccess, onError) {
    const target = Math.max(RECENT_RESULTS_LIMIT, numberValue(limit));
    const maxPages = Math.max(4, Math.ceil(target / 20));
    const url = `${SOFASCORE_API_BASE_URL}/unique-tournament/${league.id}/season/${seasonId}/events/last/${page}`;
    requestJson(url, payload => {
        const pageEvents = arrayValue(payload && payload.events);
        const rows = matches.concat(pageEvents
            .map(event => normalizeSofaScoreFixture(event, league))
            .filter(hasTeams)
            .filter(isFinishedMatch));
        const hasExplicitNextPage = payload && Object.prototype.hasOwnProperty.call(payload, "hasNextPage");
        const canContinue = hasExplicitNextPage ? Boolean(payload && payload.hasNextPage) : pageEvents.length > 0;
        if (canContinue && page < maxPages && rows.length < target) {
            fetchSofaScoreRecentPage(league, seasonId, page + 1, rows, target, onSuccess, onError);
            return;
        }

        onSuccess(sortRecentMatches(dedupeMatches(rows)).slice(0, target));
    }, onError);
}

function fetchSofaScoreFixturePage(league, seasonId, page, matches, onSuccess, onError) {
    const url = `${SOFASCORE_API_BASE_URL}/unique-tournament/${league.id}/season/${seasonId}/events/next/${page}`;
    requestJson(url, payload => {
        const pageEvents = arrayValue(payload && payload.events);
        const rows = matches.concat(pageEvents.map(event => normalizeSofaScoreFixture(event, league)).filter(hasTeams));
        const hasExplicitNextPage = payload && Object.prototype.hasOwnProperty.call(payload, "hasNextPage");
        const canContinue = hasExplicitNextPage ? Boolean(payload && payload.hasNextPage) : pageEvents.length > 0;
        if (canContinue && page < 2) {
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
        homeTeamAliases: uniqueStringValues([homeTeam.name, homeTeam.shortName]),
        awayTeam: stringValue(awayTeam.shortName || awayTeam.name),
        awayTeamAliases: uniqueStringValues([awayTeam.name, awayTeam.shortName]),
        homeScore: sofaScoreDisplayScore(homeScore),
        awayScore: sofaScoreDisplayScore(awayScore),
        status: statusLabel(status.description || status.type),
        minute: "",
        startTime: timestamp > 0 ? formatStartTime(timestamp) : "",
        timestamp,
        matchday: sofaScoreRoundLabel(event && event.roundInfo),
        stadium: sofaScoreStadium(event && event.venue),
        homeBadge: sofaScoreTeamImage(homeTeam.id),
        awayBadge: sofaScoreTeamImage(awayTeam.id),
        poster: "",
        popular: false
    };
}

function sofaScoreRoundLabel(roundInfo) {
    const label = roundLabelFromText(roundInfo && (roundInfo.name || roundInfo.slug || roundInfo.roundName || roundInfo.description));
    if (label.length > 0)
        return label;

    const round = numberValue(roundInfo && roundInfo.round);
    return round > 0 ? "Round " + round : "";
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

function fetchTheSportsDBLeagueSeasons(options, onSuccess, onError) {
    resolveTheSportsDBLeague(options, league => {
        const leagueId = stringValue(league && league.id);
        if (leagueId.length === 0) {
            onSuccess([]);
            return;
        }

        requestJson(`${THESPORTSDB_API_BASE_URL}/search_all_seasons.php?id=${encodeURIComponent(leagueId)}`, payload => {
            const seasons = normalizeTheSportsDBSeasonOptions(payload, league);
            if (seasons.length > 0) {
                onSuccess(seasons);
                return;
            }

            fetchTheSportsDBSeasonFallbackFromEvents(league, onSuccess, onError);
        }, () => {
            fetchTheSportsDBSeasonFallbackFromEvents(league, onSuccess, onError);
        });
    }, onError);
}

function fetchTheSportsDBSeasonFallbackFromEvents(league, onSuccess, onError) {
    const leagueId = stringValue(league && league.id);
    if (leagueId.length === 0) {
        onSuccess([]);
        return;
    }

    requestJson(`${THESPORTSDB_API_BASE_URL}/eventspastleague.php?id=${encodeURIComponent(leagueId)}`, payload => {
        const events = arrayValue(payload && payload.events);
        const seasons = {};
        events.forEach(event => {
            const season = stringValue(event && event.strSeason);
            if (season.length > 0)
                seasons[season] = true;
        });
        const rows = Object.keys(seasons).map((season, index) => {
            const yearScore = parseSeasonYearValue(season) || (1000 - index);
            return {
                id: season,
                key: `thesportsdb:${season}`,
                provider: "thesportsdb",
                label: normalizeSeasonLabelDisplay(season),
                isCurrent: false,
                isOngoing: false,
                isCompleted: true,
                yearScore
            };
        }).sort((left, right) => seasonSortScore(right) - seasonSortScore(left));
        onSuccess(rows);
    }, onError);
}

function normalizeTheSportsDBSeasonOptions(payload, league) {
    const rows = arrayValue(payload && payload.seasons).map((season, index) => {
        const label = stringValue(season && (season.strSeason || season.season));
        if (label.length === 0)
            return {};

        const yearScore = parseSeasonYearValue(label) || (1000 - index);
        return {
            id: label,
            key: `thesportsdb:${label}`,
            provider: "thesportsdb",
            label: normalizeSeasonLabelDisplay(label),
            isCurrent: false,
            isOngoing: false,
            isCompleted: true,
            yearScore
        };
    }).filter(row => stringValue(row && row.id).length > 0);

    return rows.sort((left, right) => seasonSortScore(right) - seasonSortScore(left));
}

function fetchTheSportsDBTableForSeason(options, onSuccess, onError) {
    const seasonId = stringValue(options && options.seasonId).trim();
    if (seasonId.length === 0) {
        onSuccess([]);
        return;
    }

    resolveTheSportsDBLeague(options, league => {
        const leagueId = stringValue(league && league.id);
        if (leagueId.length === 0) {
            onSuccess([]);
            return;
        }

        const url = `${THESPORTSDB_API_BASE_URL}/lookuptable.php?l=${encodeURIComponent(leagueId)}&s=${encodeURIComponent(seasonId)}`;
        requestJson(url, payload => {
            const rows = normalizeTheSportsDBTable(payload, league);
            if (rows.length > 0) {
                onSuccess(rows);
                return;
            }

            requestJson(`${THESPORTSDB_API_BASE_URL}/lookuptable.php?l=${encodeURIComponent(leagueId)}`, fallbackPayload => {
                onSuccess(normalizeTheSportsDBTable(fallbackPayload, league));
            }, onError);
        }, onError);
    }, onError);
}

function normalizeTheSportsDBTable(payload, league) {
    const rows = arrayValue(payload && payload.table).map(row => {
        const team = stringValue(row && row.strTeam);
        if (team.length === 0)
            return {};

        return {
            position: numberValue(row && (row.intRank || row.rank)),
            team,
            group: stringValue(row && (row.strGroup || row.strSubdivision || row.strDivision)),
            groupIndex: 0,
            played: numberValue(row && (row.intPlayed || row.played)),
            won: numberValue(row && (row.intWin || row.win)),
            draw: numberValue(row && (row.intDraw || row.draw)),
            lost: numberValue(row && (row.intLoss || row.loss)),
            goalsFor: numberValue(row && (row.intGoalsFor || row.goalsfor)),
            goalsAgainst: numberValue(row && (row.intGoalsAgainst || row.goalsagainst)),
            points: numberValue(row && (row.intPoints || row.points)),
            goalDifference: numberValue(row && (row.intGoalDifference || row.goaldifference)),
            form: stringValue(row && (row.strForm || row.form)),
            crest: stringValue(row && (row.strTeamBadge || row.strBadge)),
            teamSlug: ProviderCatalog.sportScoreSlug(team),
            league: stringValue(league && league.label)
        };
    }).filter(row => stringValue(row && row.team).length > 0);

    return rows.sort((left, right) => numberValue(left.position) - numberValue(right.position) || stringValue(left.team).localeCompare(stringValue(right.team)));
}

function canFetchTheSportsDBFixtures(options) {
    return isFootballSelection(options) && ProviderCatalog.leagueLabel(options && options.league).length > 0;
}

function fetchTheSportsDBFixtures(options, onSuccess, onError) {
    resolveTheSportsDBLeague(options, league => {
        if (stringValue(league && league.id).length === 0) {
            onSuccess([]);
            return;
        }

        requestJson(`${THESPORTSDB_API_BASE_URL}/eventsnextleague.php?id=${encodeURIComponent(league.id)}`, payload => {
            onSuccess(sortMatches(dedupeMatches(arrayValue(payload && payload.events).map(event => normalizeTheSportsDBFixture(event, league)).filter(hasTeams))));
        }, onError);
    }, onError);
}

function resolveTheSportsDBLeague(options, onSuccess, onError) {
    const mapped = fallbackLeague(THESPORTSDB_LEAGUES, options);
    if (stringValue(mapped && mapped.id).length > 0) {
        onSuccess(mapped);
        return;
    }

    const cacheKey = fallbackCacheKey(options);
    if (theSportsDBLeagueCache[cacheKey] !== undefined) {
        onSuccess(theSportsDBLeagueCache[cacheKey]);
        return;
    }

    searchTheSportsDBLeague(options, league => {
        theSportsDBLeagueCache[cacheKey] = league || {};
        onSuccess(league);
    }, onError);
}

function searchTheSportsDBLeague(options, onSuccess, onError) {
    const country = ProviderCatalog.countryLabel(options && options.country);
    function searchAcrossSoccer() {
        requestJson(`${THESPORTSDB_API_BASE_URL}/search_all_leagues.php?s=Soccer`, payload => {
            const league = selectTheSportsDBLeague(payload, options);
            onSuccess(league);
        }, onError);
    }

    if (country.length === 0 || normalizedText(country) === "international tournaments") {
        searchAcrossSoccer();
        return;
    }

    const url = `${THESPORTSDB_API_BASE_URL}/search_all_leagues.php?c=${encodeURIComponent(country)}&s=Soccer`;
    requestJson(url, payload => {
        const league = selectTheSportsDBLeague(payload, options);
        if (stringValue(league && league.id).length > 0) {
            onSuccess(league);
            return;
        }

        searchAcrossSoccer();
    }, searchAcrossSoccer);
}

function selectTheSportsDBLeague(payload, options) {
    const wantedLeague = ProviderCatalog.leagueLabel(options && options.league);
    const leagues = arrayValue(payload && payload.countries).concat(arrayValue(payload && payload.leagues));
    let best = {};
    let bestScore = 0;

    leagues.forEach(league => {
        const label = stringValue(league && league.strLeague);
        const alternate = stringValue(league && league.strLeagueAlternate);
        const score = Math.max(
            similarityScore(normalizedText(label), normalizedText(wantedLeague)),
            similarityScore(normalizedText(alternate), normalizedText(wantedLeague))
        );
        if (score > bestScore) {
            bestScore = score;
            best = {
                id: stringValue(league && league.idLeague),
                label
            };
        }
    });

    return bestScore > 0 ? best : {};
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
        matchday: theSportsDBRoundLabel(event),
        stadium: stringValue(event && event.strVenue),
        homeBadge: stringValue(event && event.strHomeTeamBadge),
        awayBadge: stringValue(event && event.strAwayTeamBadge),
        poster: stringValue(event && (event.strPoster || event.strThumb)),
        popular: false
    };
}

function theSportsDBRoundLabel(event) {
    const label = roundLabelFromText(event && (event.strRound || event.strStage || event.strGroup || event.strRoundName));
    if (label.length > 0)
        return label;

    return event && event.intRound ? "Round " + event.intRound : "";
}

function fallbackLeague(map, options) {
    const slug = ProviderCatalog.sportScoreSlug(options.league);
    return map[slug] || {};
}

function fallbackCacheKey(options) {
    return [
        ProviderCatalog.sportScoreSlug(options && options.league),
        String(options && options.country || "").trim().toLowerCase()
    ].join("|");
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
    const forceRefresh = Boolean(options && options.forceLiveRefresh);
    const cached = cachedSportScoreLiveRows(options);
    if (cached !== null && !forceRefresh) {
        onSuccess(cached);
        return;
    }

    if (forceRefresh && cached !== null && cached.length > 0) {
        fetchSportScoreLiveState(options, onSuccess, () => {
            fetchSportScoreLiveHtml(options, onSuccess, onError, true);
        });
        return;
    }

    fetchSportScoreLiveHtml(options, onSuccess, onError, forceRefresh);
}

function fetchSportScoreLiveHtml(options, onSuccess, onError, forceRefresh) {
    const url = forceRefresh ? cacheBustedUrl("https://sportscore.com/football/live/") : "https://sportscore.com/football/live/";
    requestText(url, html => {
        try {
            sportScoreLiveCache = {
                timestamp: Date.now(),
                rows: normalizeSportScoreLivePage(html, Object.assign({}, options, { league: "" }))
            };
            onSuccess(filterSportScoreLiveRows(sportScoreLiveCache.rows, options));
        } catch (error) {
            onError(String(error));
        }
    }, onError);
}

function fetchSportScoreLiveState(options, onSuccess, onError) {
    requestJson(cacheBustedUrl("https://sportscore.com/football/live-state/"), payload => {
        const rows = applySportScoreLiveState(sportScoreLiveCache.rows, payload);
        sportScoreLiveCache = {
            timestamp: Date.now(),
            rows
        };
        onSuccess(filterSportScoreLiveRows(rows, options));
    }, onError);
}

function applySportScoreLiveState(rows, payload) {
    const states = payload && payload.matches ? payload.matches : {};
    return (Array.isArray(rows) ? rows : []).map(row => {
        const state = states[sportScoreLiveStateKey(row)];
        if (!state)
            return null;

        if (state.is_finished)
            return null;

        const copy = Object.assign({}, row);
        copy.homeScore = stringValue(state.home_score);
        copy.awayScore = stringValue(state.away_score);
        copy.minute = stringValue(state.status_str);
        copy.status = state.is_live ? "Live" : statusLabel(state.status_str);
        return copy;
    }).filter(hasTeams).filter(isLiveMatch);
}

function sportScoreLiveStateKey(row) {
    const id = stringValue(row && row.id);
    const prefix = "sportscore-live-";
    return id.indexOf(prefix) === 0 ? id.slice(prefix.length) : id;
}

function cachedSportScoreLiveRows(options) {
    if (sportScoreLiveCache.timestamp <= 0)
        return null;

    if (Date.now() - sportScoreLiveCache.timestamp > LIVE_CACHE_TTL_MS)
        return null;

    return filterSportScoreLiveRows(sportScoreLiveCache.rows, options);
}

function filterSportScoreLiveRows(rows, options) {
    return sortMatches(dedupeMatches(filterMatchesForSelection(rows.slice(), options).filter(isLiveMatch)));
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
        const context = section.slice(0, match.index);
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
    const liveUrl = sportScoreLiveUrl(path);
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
        popular: false,
        matchPath: path,
        liveUrl,
        detailsProvider: "sportscore",
        statsProvider: "sportscore"
    };
}

function sportScoreLiveDetailsUrl(options) {
    const explicit = stringValue(options && options.liveUrl).trim();
    if (explicit.length > 0)
        return explicit;

    return sportScoreLiveUrl(stringValue(options && options.matchPath).trim());
}

function sportScoreLiveUrl(path) {
    const value = stringValue(path).trim();
    if (value.length === 0)
        return "";

    const normalized = value.replace(/\/?$/, "/");
    if (/^https?:\/\//.test(normalized))
        return normalized.replace(/\/?$/, "/") + "live/";

    return "https://sportscore.com" + normalized + "live/";
}

function emptyLiveMatchDetails() {
    return {
        ok: false,
        statusLabel: "",
        homeScore: "",
        awayScore: "",
        hasRealtimeStats: false,
        summaryRows: [],
        statsRows: [],
        events: [],
        updatedAt: ""
    };
}

function normalizeSportScoreLiveDetails(payload) {
    payload = payload || {};
    const score = payload.score || {};
    const status = payload.status || {};
    const stats = payload.stats || {};
    const details = emptyLiveMatchDetails();

    details.ok = Boolean(payload.ok);
    details.statusLabel = stringValue(status.label);
    details.homeScore = stringValue(score.home_display !== undefined ? score.home_display : score.home);
    details.awayScore = stringValue(score.away_display !== undefined ? score.away_display : score.away);
    details.hasRealtimeStats = Boolean(stats.has_realtime_stats);
    details.updatedAt = stringValue(payload.updated_at);
    details.summaryRows = [
        liveSummaryRow("corners", i18ncShim("Corners"), stats.home_corners, stats.away_corners),
        liveSummaryRow("yellow", i18ncShim("Yellow cards"), stats.home_yellow_cards, stats.away_yellow_cards),
        liveSummaryRow("red", i18ncShim("Red cards"), stats.home_red_cards, stats.away_red_cards)
    ];
    details.statsRows = [
        liveStatRow(i18ncShim("Possession"), stats.home_ball_possession, stats.away_ball_possession, true),
        liveStatRow(i18ncShim("Attacks"), stats.home_attacks, stats.away_attacks, false),
        liveStatRow(i18ncShim("Shots on target"), stats.home_shots_on_target, stats.away_shots_on_target, false),
        liveStatRow(i18ncShim("Dangerous attacks"), stats.home_dangerous_attacks, stats.away_dangerous_attacks, false),
        liveStatRow(i18ncShim("Shots off target"), stats.home_shots_off_target, stats.away_shots_off_target, false)
    ];
    details.events = arrayValue(payload.latest_events)
        .map(normalizeSportScoreLiveEvent)
        .filter(event => stringValue(event.label).length > 0 || stringValue(event.kind).length > 0);
    details.hasRealtimeStats = details.hasRealtimeStats || details.statsRows.some(row => numberValue(row.homeRaw) > 0 || numberValue(row.awayRaw) > 0);

    return details;
}

function i18ncShim(value) {
    return value;
}

function liveSummaryRow(kind, label, homeValue, awayValue) {
    return {
        kind,
        label,
        homeValue: stringValue(numberValue(homeValue)),
        awayValue: stringValue(numberValue(awayValue))
    };
}

function liveStatRow(label, homeValue, awayValue, percent) {
    const home = numberValue(homeValue);
    const away = numberValue(awayValue);
    const total = home + away;
    let homeRatio = 0;
    let awayRatio = 0;

    if (percent) {
        homeRatio = Math.max(0, Math.min(1, home / 100));
        awayRatio = Math.max(0, Math.min(1, away / 100));
    } else if (total > 0) {
        homeRatio = home / total;
        awayRatio = away / total;
    }

    return {
        label,
        homeValue: percent ? Math.round(home) + "%" : stringValue(Math.round(home)),
        awayValue: percent ? Math.round(away) + "%" : stringValue(Math.round(away)),
        homeRaw: home,
        awayRaw: away,
        homeRatio,
        awayRatio,
        homeHighlight: home > away,
        awayHighlight: away > home
    };
}

function normalizeSportScoreLiveEvent(event) {
    event = event || {};
    const kind = stringValue(event.kind).trim();
    const player = stringValue(event.player || event.label).trim();
    const inPlayer = stringValue(event.in_player_name).trim();
    const outPlayer = stringValue(event.out_player_name).trim();
    let label = player;

    if (kind === "sub") {
        label = [inPlayer, outPlayer].filter(value => value.length > 0).join(" -> ");
    }

    if (label.length === 0)
        label = liveEventKindLabel(kind);

    return {
        minute: stringValue(event.minute).trim(),
        kind,
        side: stringValue(event.side).trim().toLowerCase(),
        label,
        player,
        inPlayer,
        outPlayer
    };
}

function liveEventKindLabel(kind) {
    switch (kind) {
    case "goal":
        return "Goal";
    case "yellow":
        return "Yellow card";
    case "red":
        return "Red card";
    case "sub":
        return "Substitution";
    case "var":
        return "VAR review";
    case "miss":
        return "Missed chance";
    default:
        return "";
    }
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
    const pattern = /class="(?:competition-round|round-header)[^"]*"[^>]*>([\s\S]*?)<\/(?:span|div)>/g;
    const groupPattern = /<div class="comp-round-group"[^>]*data-round="([^"]+)"/g;
    let result = "";
    let groupMatch = groupPattern.exec(html);
    while (groupMatch) {
        const label = roundLabelFromText(htmlDecode(groupMatch[1]));
        if (label.length > 0)
            result = label;

        groupMatch = groupPattern.exec(html);
    }

    let match = pattern.exec(html);
    while (match) {
        const label = roundLabelFromText(htmlText(match[1]));
        if (label.length > 0)
            result = label;

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
    const absolute = /^https?:\/\/[^/]+(\/football\/[^?#]+\/?)/.exec(value);
    if (absolute)
        return absolute[1];

    const relative = /(\/football\/[^?#]+\/?)/.exec(value);
    return relative ? relative[1] : value;
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

function sportScoreCompetitionSourceUrls(options) {
    const primary = stringValue(options && options.country).trim().toLowerCase();
    const inferred = stringValue(ProviderCatalog.countryCodeForLeague(options && options.league)).trim().toLowerCase();
    const candidates = [];
    const seen = {};

    function addCountry(code) {
        if (code.length === 0 || seen[code])
            return;

        seen[code] = true;
        candidates.push(code);
    }

    addCountry(primary.length > 0 ? primary : "england");
    addCountry(inferred);
    addCountry("world");

    return candidates.map(code => {
        if (code === "world")
            return { country: code, url: "https://sportscore.com/football/competitions/" };

        return {
            country: code,
            url: `https://sportscore.com/football/country/${encodeURIComponent(code)}/`
        };
    });
}

function fetchSportScoreCompetitionPathWithFallback(options, onSuccess, onError) {
    const league = ProviderCatalog.sportScoreSlug(options && options.league);
    if (league.length === 0) {
        onSuccess("");
        return;
    }

    const sources = sportScoreCompetitionSourceUrls(options);
    let index = 0;

    function next() {
        if (index >= sources.length) {
            onSuccess("");
            return;
        }

        const source = sources[index];
        index += 1;
        requestText(cacheBustedUrl(source.url), html => {
            const path = sportScoreCompetitionPath(html, source.country, league);
            if (path.length > 0) {
                onSuccess(path);
                return;
            }

            next();
        }, () => {
            next();
        });
    }

    next();
}

function normalizeSportScoreFixturePage(html, leagueLabel) {
    const htmlRows = normalizeSportScoreFixtureRows(html, leagueLabel);
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
        return sortMatches(dedupeMatches(htmlRows));

    const listItems = arrayValue(selected.itemListElement);
    const schemaRows = listItems.map(item => normalizeSchemaFixture(item && item.item, leagueLabel))
        .filter(hasTeams)
        .sort((left, right) => numberValue(left.timestamp) - numberValue(right.timestamp));

    if (htmlRows.length === 0)
        return schemaRows;

    return mergeFixtureSources(htmlRows, schemaRows);
}

function normalizeSportScoreFixtureRows(html, leagueLabel) {
    const section = sportScoreUpcomingFixturesSection(html);
    const pattern = /<div class="football-match-table-container w-100 nostyle sc-row-stretched">([\s\S]*?)(?=\n\s*<div class="football-match-table-container w-100 nostyle sc-row-stretched">|\n\s*<div class="comp-round-group"|\n\s*<\/div>\s*<\/div>\s*<section|\n\s*<section|$)/g;
    let rows = [];
    let match = pattern.exec(section);
    while (match) {
        const context = section.slice(0, match.index);
        const row = normalizeSportScoreFixtureRow(match[0], context, leagueLabel);
        if (hasTeams(row))
            rows.push(row);

        match = pattern.exec(section);
    }

    return rows;
}

function sportScoreUpcomingFixturesSection(html) {
    const value = stringValue(html);
    const labelMatch = /<span class="match-state-label[^"]*"[^>]*>[^<]*upcoming fixtures[^<]*<\/span>/i.exec(value);
    if (!labelMatch)
        return "";

    const headerStart = value.lastIndexOf("<h2", labelMatch.index);
    const start = headerStart >= 0 ? headerStart : labelMatch.index;
    const endMarkers = [
        value.indexOf('<h2 class="match-state-header', labelMatch.index + labelMatch[0].length),
        value.indexOf('<section class="comp-transfers-section"', labelMatch.index + labelMatch[0].length),
        value.indexOf('<section class="comp-top-scorers-section"', labelMatch.index + labelMatch[0].length),
        value.indexOf('<section class="comp-standings-section"', labelMatch.index + labelMatch[0].length),
        value.indexOf('<script type="application/ld+json">{"@context":"https://schema.org","@type":"FAQPage"', labelMatch.index + labelMatch[0].length)
    ].filter(index => index > start);
    const end = endMarkers.length > 0 ? Math.min.apply(Math, endMarkers) : value.length;
    return value.slice(start, end);
}

function normalizeSportScoreFixtureRow(block, context, leagueLabel) {
    const label = sportScoreLiveAriaLabel(block);
    const labelParts = label.split(" — ");
    const teamLabel = htmlDecode(labelParts[0] || "");
    const teamParts = splitSportScoreTeams(teamLabel);
    const path = sportScoreMatchPath(block);
    const logos = sportScoreLiveLogos(block);
    const timestamp = Date.parse(htmlAttribute(block, "data-utc"));
    const rawStatus = statusLabel(htmlText(sportScoreLiveValue(block, "status")) || "Upcoming");
    const normalizedStatus = normalizedText(rawStatus);
    const league = htmlDecode(labelParts.slice(1).join(" — ")) || leagueLabel;

    return {
        id: "sportscore-fixture-" + stringValue(path || teamLabel),
        sport: "football",
        league,
        homeTeam: teamParts.home,
        awayTeam: teamParts.away,
        homeScore: "",
        awayScore: "",
        status: normalizedStatus === "live" || normalizedStatus === "finished" || normalizedStatus.indexOf("postpon") >= 0 ? rawStatus : "Upcoming",
        minute: "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: sportScoreLastRound(context),
        stadium: "",
        homeBadge: logos[0] || "",
        awayBadge: logos[1] || "",
        poster: "",
        popular: false,
        matchPath: path,
        detailsProvider: "sportscore",
        statsProvider: "sportscore"
    };
}

function mergeFixtureSources(preferredMatches, fallbackMatches) {
    let keyed = {};
    let rows = [];

    function addMatch(match) {
        if (!match)
            return;

        const key = recentResultMergeKey(match);
        if (key.length === 0) {
            rows.push(Object.assign({}, match));
            return;
        }

        const existing = keyed[key] || findMergeableRecentResult(rows, match);
        if (existing) {
            mergeMissingMatchFields(existing, match);
            if (key.length > 0)
                keyed[key] = existing;
            return;
        }

        const copy = Object.assign({}, match);
        keyed[key] = copy;
        rows.push(copy);
    }

    (Array.isArray(preferredMatches) ? preferredMatches : []).forEach(addMatch);
    (Array.isArray(fallbackMatches) ? fallbackMatches : []).forEach(addMatch);
    return sortMatches(dedupeMatches(rows));
}

function normalizeSportScoreRecentResultPage(html, leagueLabel) {
    const section = sportScoreRecentResultsSection(html);
    const pattern = /<div class="football-match-table-container w-100 nostyle sc-row-stretched">([\s\S]*?)(?=\n\s*<div class="football-match-table-container w-100 nostyle sc-row-stretched">|\n\s*<div class="comp-round-group"|\n\s*<\/div>\s*<\/div>\s*<section|\n\s*<section|$)/g;
    let rows = [];
    let match = pattern.exec(section);
    while (match) {
        const context = section.slice(0, match.index);
        const row = normalizeSportScoreResultRow(match[0], context, leagueLabel);
        if (hasTeams(row))
            rows.push(row);

        match = pattern.exec(section);
    }

    return sortRecentMatches(dedupeMatches(rows.filter(isFinishedMatch)));
}

function sportScoreRecentResultsSection(html) {
    const value = stringValue(html);
    const labelMatch = /<span class="match-state-label[^"]*"[^>]*>[^<]*recent results[^<]*<\/span>/i.exec(value);
    if (!labelMatch)
        return "";

    const headerStart = value.lastIndexOf("<h2", labelMatch.index);
    const start = headerStart >= 0 ? headerStart : labelMatch.index;
    const endMarkers = [
        value.indexOf('<section class="comp-transfers-section"', labelMatch.index + labelMatch[0].length),
        value.indexOf('<section class="comp-top-scorers-section"', labelMatch.index + labelMatch[0].length),
        value.indexOf('<section class="comp-standings-section"', labelMatch.index + labelMatch[0].length),
        value.indexOf('<script type="application/ld+json">{"@context":"https://schema.org","@type":"FAQPage"', labelMatch.index + labelMatch[0].length)
    ].filter(index => index > start);
    const end = endMarkers.length > 0 ? Math.min.apply(Math, endMarkers) : value.length;
    return value.slice(start, end);
}

function normalizeSportScoreResultRow(block, context, leagueLabel) {
    const label = sportScoreLiveAriaLabel(block);
    const labelParts = label.split(" — ");
    const teamLabel = htmlDecode(labelParts[0] || "");
    const teamParts = splitSportScoreTeams(teamLabel);
    const path = sportScoreMatchPath(block);
    const logos = sportScoreLiveLogos(block);
    const timestamp = Date.parse(htmlAttribute(block, "data-utc"));
    const league = htmlDecode(labelParts.slice(1).join(" — ")) || leagueLabel;

    return {
        id: "sportscore-result-" + stringValue(path || teamLabel),
        sport: "football",
        league,
        homeTeam: teamParts.home,
        awayTeam: teamParts.away,
        homeScore: htmlText(sportScoreLiveValue(block, "home-score")),
        awayScore: htmlText(sportScoreLiveValue(block, "away-score")),
        status: "Finished",
        minute: "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: sportScoreLastRound(context),
        stadium: "",
        homeBadge: logos[0] || "",
        awayBadge: logos[1] || "",
        poster: "",
        popular: false,
        matchPath: path,
        detailsProvider: "sportscore",
        statsProvider: "sportscore"
    };
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

function selectDefaultSeasonOptions(seasons) {
    const rows = arrayValue(seasons).slice();
    if (rows.length === 0)
        return [];

    rows.sort((left, right) => seasonSortScore(right) - seasonSortScore(left));
    let defaultIndex = rows.findIndex(row => Boolean(row && (row.isCurrent || row.isOngoing)));
    if (defaultIndex < 0)
        defaultIndex = rows.findIndex(row => !Boolean(row && row.isCompleted));
    if (defaultIndex < 0)
        defaultIndex = 0;

    return rows.map((row, index) => {
        const copy = Object.assign({}, row || {});
        copy.isDefault = index === defaultIndex;
        return copy;
    });
}

function seasonSortScore(season) {
    season = season || {};
    const explicitYearScore = numberValue(season.yearScore);
    if (explicitYearScore > 0)
        return explicitYearScore;

    const label = stringValue(season.label || season.id);
    return parseSeasonYearValue(label);
}

function parseSeasonYearValue(value) {
    const text = stringValue(value).trim();
    if (text.length === 0)
        return 0;

    const parts = text.match(/\d{2,4}/g) || [];
    if (parts.length === 0)
        return 0;

    let year = 0;
    parts.forEach(part => {
        const number = numberValue(part);
        if (number <= 0)
            return;

        let candidate = number;
        if (part.length === 2)
            candidate = number >= 70 ? 1900 + number : 2000 + number;
        if (candidate > year)
            year = candidate;
    });

    return year;
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
        matchday: roundLabelFromText(match && (match.round || match.round_name || match.matchday || match.match_day || match.week || match.stage)),
        homeBadge: stringValue(match.home_logo),
        awayBadge: stringValue(match.away_logo),
        popular: false
    };
}

function sportScoreTeamForm(payload, teamName, options) {
    const scopedTeamName = stringValue(payload && payload.team && payload.team.name) || teamName;
    const matches = arrayValue(payload && payload.matches)
        .map(match => normalizeSportScoreMatch(match, "football"))
        .filter(match => Number.isFinite(Number(match.homeScore)) && Number.isFinite(Number(match.awayScore)))
        .filter(isFinishedMatch);

    return teamFormFromMatches(matches, teamName, scopedTeamName, options);
}

function teamFormFromMatches(matches, teamName, scopedTeamName, options) {
    let form = [];
    let details = [];
    const rows = sortRecentMatches(filterMatchesForSelection(arrayValue(matches).slice(), options || {})).slice(0, FORM_TEAM_MATCH_LIMIT);

    rows.forEach(match => {
        if (form.length >= FORM_RESULTS_LIMIT)
            return;

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
        details.push(formMatchDetail(match, options));
    });

    return formEntry(form.reverse(), details.reverse());
}

function formEntry(values, details) {
    return {
        form: arrayValue(values).slice(0, FORM_RESULTS_LIMIT).join(","),
        details: arrayValue(details).slice(0, FORM_RESULTS_LIMIT)
    };
}

function formMatchDetail(match, options) {
    const parts = [];
    const date = formMatchDate(match, options);
    const league = stringValue(match && match.league);
    if (date.length > 0)
        parts.push(date);
    if (league.length > 0)
        parts.push(league);

    const title = parts.join(" - ");
    const result = `${stringValue(match && match.homeTeam)} ${stringValue(match && match.homeScore)} - ${stringValue(match && match.awayScore)} ${stringValue(match && match.awayTeam)}`.replace(/\s+/g, " ").trim();
    if (title.length > 0 && result.length > 0)
        return `${title}\n${result}`;

    return result || title;
}

function formMatchDate(match, options) {
    const timestamp = numberValue(match && match.timestamp);
    if (timestamp > 0) {
        const date = new Date(timestamp);
        const dateText = formatConfiguredDateValue(date, options);
        const timeText = formatConfiguredTimeValue(date, options);
        return [dateText, timeText].filter(part => part.length > 0).join(" ");
    }

    return stringValue(match && match.startTime);
}

function configuredDateFormat(options) {
    return stringValue(options && options.matchDateFormat).trim() || "dd.MM";
}

function configuredTimeFormat(options) {
    return stringValue(options && options.matchTimeFormat).trim() || "HH:mm";
}

function formatConfiguredDateValue(date, options) {
    const format = configuredDateFormat(options);
    if (format === "locale-long") {
        try {
            return date.toLocaleDateString(undefined, { dateStyle: "long" });
        } catch (error) {
            return date.toLocaleDateString();
        }
    }
    if (format === "locale-short") {
        try {
            return date.toLocaleDateString(undefined, { dateStyle: "short" });
        } catch (error) {
            return date.toLocaleDateString();
        }
    }

    return formatDateWithPattern(date, format);
}

function formatConfiguredTimeValue(date, options) {
    const format = configuredTimeFormat(options);
    if (format === "locale")
        return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

    return formatTimeWithPattern(date, format);
}

function formatDateWithPattern(date, pattern) {
    const text = stringValue(pattern).trim();
    if (text.length === 0)
        return "";

    const monthShort = date.toLocaleDateString(undefined, { month: "short" });
    return text.replace(/yyyy|yy|MMM|MM|M|dd|d/g, token => {
        switch (token) {
        case "yyyy":
            return String(date.getFullYear());
        case "yy":
            return String(date.getFullYear()).slice(-2);
        case "MMM":
            return monthShort;
        case "MM":
            return pad(date.getMonth() + 1);
        case "M":
            return String(date.getMonth() + 1);
        case "dd":
            return pad(date.getDate());
        case "d":
            return String(date.getDate());
        default:
            return token;
        }
    });
}

function formatTimeWithPattern(date, pattern) {
    const text = stringValue(pattern).trim();
    if (text.length === 0)
        return "";

    const hours24 = date.getHours();
    const hours12 = ((hours24 + 11) % 12) + 1;
    const ampm = hours24 >= 12 ? "PM" : "AM";
    return text.replace(/HH|H|hh|h|mm|ss|AP|ap/g, token => {
        switch (token) {
        case "HH":
            return pad(hours24);
        case "H":
            return String(hours24);
        case "hh":
            return pad(hours12);
        case "h":
            return String(hours12);
        case "mm":
            return pad(date.getMinutes());
        case "ss":
            return pad(date.getSeconds());
        case "AP":
            return ampm;
        case "ap":
            return ampm.toLowerCase();
        default:
            return token;
        }
    });
}

function normalizeSeasonLabelDisplay(label) {
    const text = stringValue(label).trim();
    if (text.length === 0)
        return "";

    const key = sportScoreSeasonMatchKey(text);
    const full = /^(\d{4})-(\d{4})$/.exec(key);
    if (full)
        return `${full[1]}/${full[2]}`;

    const short = /^(\d{2})\/(\d{2})$/.exec(text);
    if (short)
        return `${Number(short[1]) + 2000}/${Number(short[2]) + 2000}`;

    return text;
}

function formCacheKey(options, teamName) {
    const season = sportScoreSeasonMatchKey(stringValue(options && options.seasonLabel).trim()
        || stringValue(options && options.seasonId).trim()
        || stringValue(options && options.seasonKey).trim());
    return [
        normalizedText(teamName),
        ProviderCatalog.sportScoreSlug(options && options.league),
        normalizedText(ProviderCatalog.countryLabel(options && options.country)),
        season
    ].join("|");
}

function formValues(form) {
    if (form && typeof form === "object" && !Array.isArray(form))
        return formValues(form.form);

    const text = stringValue(form).trim();
    if (text.length === 0)
        return [];

    if (/^[WDL]+$/i.test(text))
        return text.split("").map(value => value.toUpperCase()).slice(-FORM_RESULTS_LIMIT);

    return text.replace(/[^A-Za-z]+/g, ",")
        .split(",")
        .map(value => value.trim().toUpperCase())
        .filter(value => value === "W" || value === "D" || value === "L")
        .slice(-FORM_RESULTS_LIMIT);
}

function normalizedFormString(form) {
    return formValues(form).join(",");
}

function formDetails(form) {
    if (form && typeof form === "object" && !Array.isArray(form))
        return arrayValue(form.details).slice(0, FORM_RESULTS_LIMIT);

    return [];
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

function mergeRecentResultSources(preferredMatches, fallbackMatches) {
    let keyed = {};
    let rows = [];

    function addMatch(match) {
        if (!match)
            return;

        const key = recentResultMergeKey(match);
        if (key.length === 0) {
            rows.push(Object.assign({}, match));
            return;
        }

        const existing = keyed[key] || findMergeableRecentResult(rows, match);
        if (existing) {
            mergeMissingMatchFields(existing, match);
            keyed[key] = existing;
            return;
        }

        const copy = Object.assign({}, match);
        keyed[key] = copy;
        rows.push(copy);
    }

    (Array.isArray(preferredMatches) ? preferredMatches : []).forEach(addMatch);
    (Array.isArray(fallbackMatches) ? fallbackMatches : []).forEach(addMatch);
    return sortRecentMatches(dedupeRecentMatches(rows.filter(isFinishedMatch))).slice(0, RECENT_RESULTS_LIMIT);
}

function dedupeRecentMatches(matches) {
    let keyed = {};
    let rows = [];

    (Array.isArray(matches) ? matches : []).forEach(match => {
        const key = recentResultMergeKey(match);
        const existing = (key.length > 0 ? keyed[key] : null) || findMergeableRecentResult(rows, match);
        if (existing) {
            mergeMissingMatchFields(existing, match);
            if (key.length > 0)
                keyed[key] = existing;
            return;
        }

        const copy = Object.assign({}, match);
        rows.push(copy);
        if (key.length > 0)
            keyed[key] = copy;
    });

    return rows;
}

function recentResultsLimitValue(options) {
    const requested = numberValue(options && options.recentResultsLimit);
    if (requested <= 0)
        return RECENT_RESULTS_LIMIT;

    return Math.max(RECENT_RESULTS_LIMIT, Math.min(300, requested));
}

function findMergeableRecentResult(rows, match) {
    for (let index = 0; index < rows.length; index += 1) {
        if (canMergeRecentResult(rows[index], match))
            return rows[index];
    }

    return null;
}

function canMergeRecentResult(left, right) {
    if (!left || !right)
        return false;

    if (!sameTeamName(left.homeTeam, right.homeTeam) || !sameTeamName(left.awayTeam, right.awayTeam))
        return false;

    const leftTime = numberValue(left.timestamp);
    const rightTime = numberValue(right.timestamp);
    if (leftTime > 0 && rightTime > 0) {
        const timeDifference = Math.abs(leftTime - rightTime);
        if (timeDifference <= 5 * 60 * 1000)
            return true;

        const closeEnough = timeDifference <= 48 * 60 * 60 * 1000;
        if (!closeEnough)
            return false;

        return scoresCompatible(left, right);
    }

    const leftStart = normalizedText(left.startTime);
    const rightStart = normalizedText(right.startTime);
    return leftStart.length > 0 && leftStart === rightStart && scoresCompatible(left, right);
}

function scoresCompatible(left, right) {
    const leftHome = stringValue(left && left.homeScore);
    const leftAway = stringValue(left && left.awayScore);
    const rightHome = stringValue(right && right.homeScore);
    const rightAway = stringValue(right && right.awayScore);
    if (leftHome.length === 0 || leftAway.length === 0 || rightHome.length === 0 || rightAway.length === 0)
        return true;

    return leftHome === rightHome && leftAway === rightAway;
}

function recentResultMergeKey(match) {
    const home = normalizedText(match && match.homeTeam);
    const away = normalizedText(match && match.awayTeam);
    if (home.length === 0 || away.length === 0)
        return "";

    const timestamp = numberValue(match && match.timestamp);
    const dateKey = timestamp > 0 ? new Date(timestamp).toISOString().slice(0, 10) : normalizedText(match && match.startTime);
    return [home, away, dateKey].join("|");
}

function mergeMissingMatchFields(target, source) {
    [
        "id",
        "league",
        "matchday",
        "stadium",
        "homeBadge",
        "awayBadge",
        "poster",
        "matchPath",
        "liveUrl",
        "detailsProvider",
        "statsProvider"
    ].forEach(field => {
        if (stringValue(target[field]).length === 0 && stringValue(source && source[field]).length > 0)
            target[field] = source[field];
    });
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

function sortRecentMatches(matches) {
    return matches.sort((left, right) => {
        const leftTime = numberValue(left && left.timestamp);
        const rightTime = numberValue(right && right.timestamp);
        if (leftTime > 0 && rightTime > 0 && leftTime !== rightTime)
            return rightTime - leftTime;

        if (leftTime > 0 && rightTime === 0)
            return -1;

        if (rightTime > 0 && leftTime === 0)
            return 1;

        return stringValue(left && left.homeTeam).localeCompare(stringValue(right && right.homeTeam));
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

function isFinishedMatch(match) {
    const status = normalizedText(match && match.status);
    if (status.indexOf("finish") >= 0 || status.indexOf("final") >= 0 || status === "ended" || status === "ft")
        return true;

    return stringValue(match && match.homeScore).length > 0 &&
        stringValue(match && match.awayScore).length > 0 &&
        !isLiveMatch(match) &&
        status.indexOf("upcoming") < 0 &&
        status.indexOf("scheduled") < 0 &&
        status.indexOf("not started") < 0;
}

function hasSchedulableFixture(matches) {
    return (Array.isArray(matches) ? matches : []).some(match => isSchedulableFixture(match));
}

function isSchedulableFixture(match) {
    if (!match || isFinishedMatch(match))
        return false;

    if (isLiveMatch(match))
        return true;

    const status = normalizedText(match.status);
    const timestamp = numberValue(match.timestamp);
    const now = Date.now();
    if (status.indexOf("upcoming") >= 0 || status.indexOf("scheduled") >= 0 || status.indexOf("not started") >= 0 || status.indexOf("postponed") >= 0)
        return timestamp === 0 || timestamp >= now - 3 * 60 * 60 * 1000;

    if (timestamp > 0)
        return timestamp >= now - 3 * 60 * 60 * 1000;

    return stringValue(match.homeScore).length === 0 && stringValue(match.awayScore).length === 0;
}

function filterMatchesForSelection(matches, options) {
    const sport = normalizeSports(options.sports)[0] || "football";
    if (sport !== "football" && sport !== "soccer")
        return matches;

    const seasonFiltered = filterMatchesForRequestedSeason(matches, options);
    if (Boolean(options && options.skipLeagueFilter))
        return seasonFiltered;

    if (stringValue(options && options.followMode).trim().toLowerCase() === "team")
        return seasonFiltered;

    const league = ProviderCatalog.sportScoreSlug(options.league);
    if (league.length === 0)
        return seasonFiltered;

    const label = ProviderCatalog.leagueLabel(options.league);
    const candidates = [league, label].map(normalizedText).filter(value => value.length > 0);
    if (candidates.length === 0)
        return seasonFiltered;

    return seasonFiltered.filter(match => {
        const matchLeagueSlug = ProviderCatalog.sportScoreSlug(match && match.league);
        if (matchLeagueSlug.length > 0 && (matchLeagueSlug === league || matchLeagueSlug.indexOf(league) >= 0 || league.indexOf(matchLeagueSlug) >= 0))
            return true;

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

function filterMatchesForRequestedSeason(matches, options) {
    const window = requestedSeasonWindow(options);
    if (!window)
        return arrayValue(matches);

    return arrayValue(matches).filter(match => {
        const timestamp = numberValue(match && match.timestamp);
        if (timestamp <= 0)
            return true;

        return timestamp >= window.start && timestamp < window.end;
    });
}

function requestedSeasonWindow(options) {
    const label = stringValue(options && options.seasonLabel).trim();
    const id = stringValue(options && options.seasonId).trim();
    const key = stringValue(options && options.seasonKey).trim();
    const source = label.length > 0 ? label : (id.length > 0 ? id : key);
    if (source.length === 0)
        return null;

    const normalized = sportScoreSeasonMatchKey(source);
    const long = /^(\d{4})-(\d{4})$/.exec(normalized);
    if (long) {
        const startYear = numberValue(long[1]);
        const endYear = numberValue(long[2]);
        if (startYear > 0 && endYear > startYear) {
            // Most football seasons run mid-year to mid-year.
            return {
                start: Date.UTC(startYear, 6, 1, 0, 0, 0),
                end: Date.UTC(endYear, 6, 1, 0, 0, 0)
            };
        }
    }

    const single = /^(\d{4})$/.exec(source);
    if (single) {
        const year = numberValue(single[1]);
        if (year > 0) {
            return {
                start: Date.UTC(year, 0, 1, 0, 0, 0),
                end: Date.UTC(year + 1, 0, 1, 0, 0, 0)
            };
        }
    }

    return null;
}

function formByTeam(matches, options) {
    let result = {};
    const maxMatches = Math.max(FORM_TEAM_MATCH_LIMIT, recentResultsLimitValue(options || {}));
    const finished = filterMatchesForSelection(matches || [], options || {})
        .filter(match => isFinishedMatch(match) && Number.isFinite(Number(match.homeScore)) && Number.isFinite(Number(match.awayScore)))
        .sort((left, right) => numberValue(right.timestamp) - numberValue(left.timestamp))
        .slice(0, maxMatches);

    function append(teamName, value, detail) {
        const key = normalizedText(teamName);
        if (key.length === 0)
            return;

        if (!result[key])
            result[key] = [];

        result[key].push({
            value,
            detail
        });
    }

    function appendAll(teamName, aliases, value, detail) {
        let seen = {};
        const names = [teamName].concat(Array.isArray(aliases) ? aliases : []);
        names.forEach(name => {
            const key = normalizedText(name);
            if (key.length === 0 || seen[key])
                return;

            seen[key] = true;
            append(name, value, detail);
        });
    }

    finished.forEach(match => {
        const homeGoals = numberValue(match.homeScore);
        const awayGoals = numberValue(match.awayScore);
        const detail = formMatchDetail(match, options);
        if (homeGoals > awayGoals) {
            appendAll(match.homeTeam, match.homeTeamAliases, "W", detail);
            appendAll(match.awayTeam, match.awayTeamAliases, "L", detail);
        } else if (homeGoals < awayGoals) {
            appendAll(match.homeTeam, match.homeTeamAliases, "L", detail);
            appendAll(match.awayTeam, match.awayTeamAliases, "W", detail);
        } else {
            appendAll(match.homeTeam, match.homeTeamAliases, "D", detail);
            appendAll(match.awayTeam, match.awayTeamAliases, "D", detail);
        }
    });

    Object.keys(result).forEach(key => {
        const rows = result[key].slice(0, FORM_RESULTS_LIMIT).reverse();
        result[key] = formEntry(rows.map(row => row.value), rows.map(row => row.detail));
    });
    return result;
}

function formForTeam(formMap, teamName) {
    const entry = formEntryForTeam(formMap, teamName);
    if (entry !== undefined)
        return normalizedFormString(entry);

    return "";
}

function formDetailsForTeam(formMap, teamName) {
    return formDetails(formEntryForTeam(formMap, teamName));
}

function formEntryForTeam(formMap, teamName) {
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
    return undefined;
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
        "atl": "atleticomadrid",
        "atleti": "atleticomadrid",
        "atlmadrid": "atleticomadrid",
        "atmadrid": "atleticomadrid",
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
