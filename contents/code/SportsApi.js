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

.pragma library
.import "providers/ProviderCatalog.js" as ProviderCatalog
.import "providers/SportScoreSports.js" as SportScoreSports
.import "providers/EspnSports.js" as EspnSports

const SPORTSCORE_BASE_URL = "https://sportscore.com";
const ESPN_SITE_BASE = "https://site.api.espn.com/apis/site/v2/sports";
// Standings live under apis/v2 (NOT apis/site/v2). The site.api .../standings
// endpoint returns an empty object, which is why league tables came up blank.
const ESPN_STANDINGS_BASE = "https://site.api.espn.com/apis/v2/sports";
// Undocumented but stable ESPN "core" API; used only for the per-match play-by-play
// feed (goals/cards/substitutions), which the site.api summary endpoint lacks.
const ESPN_CORE_BASE = "https://sports.core.api.espn.com/v2/sports";
const ESPN_MATCH_LIMIT = 100;
const ESPN_PLAYS_LIMIT = 300;
// How many days ahead of "today" to ask ESPN for when listing fixtures. (The
// unified window's look-BACK is a fixed one-day boundary buffer - see
// ESPN_UNIFIED_DAYS_BACK - since "recent" has its own year-to-date fetch.)
const ESPN_FIXTURE_DAYS_AHEAD = 14;
// ESPN returns matches ascending and caps at the limit, so the wide year-to-date
// recent window needs a high limit or the actual last matches (end of the window)
// get dropped.
const ESPN_RECENT_FALLBACK_LIMIT = 300;
const SPORTSCORE_MATCH_LIMIT = 50;
const SPORTSCORE_COUNTRY_COMPETITION_LIMIT = 64;
const SPORTSCORE_COUNTRY_COMPETITION_CONCURRENCY = 6;
const SPORTSCORE_TEAM_LIMIT = 2000;
const SPORTSCORE_BASKETBALL_TRACKER_PROFILE = "47q3ktv6gh1u8mx";
// "Recent results" surfaces every finished match from the start of the current
// calendar year (year-to-date). A match older than this hard floor is dropped
// even when year-to-date would reach further, so very early-season requests in
// January still keep at least a sensible recent window.
const RECENT_MATCH_MIN_WINDOW_MS = 120 * 24 * 60 * 60 * 1000;

// Milliseconds from 00:00 on Jan 1 of the current year until now. Used as the
// recent-results look-back so "this year's" matches are all included.
function recentYearToDateWindowMs() {
    const now = new Date();
    const yearStart = new Date(now.getFullYear(), 0, 1).getTime();
    return Math.max(now.getTime() - yearStart, RECENT_MATCH_MIN_WINDOW_MS);
}
const REQUEST_TIMEOUT_MS = 14000;
// SportScore's origin is slow and frequently returns 504s under load. Limit how
// many requests hit it at once, retry the transient failures with backoff, and
// briefly cool down after a gateway error instead of hammering a struggling
// origin. The actual backoff timing is driven by a delay scheduler injected
// from the QML layer (a .pragma library cannot create timers itself).
const MAX_CONCURRENT_REQUESTS = 3;
const MAX_REQUEST_RETRIES = 2;
const RETRY_BASE_DELAY_MS = 700;
const REQUEST_COOLDOWN_MS = 2500;
// Circuit breaker: when SportScore (the non-exempt origin) fails this many times
// in a row, stop sending it new requests for a while and fail them immediately.
// A dead origin otherwise has every request sit until the 14s timeout, clogging
// the 3-slot queue and making the whole widget lag for entries ESPN can't cover
// (e.g. a followed club in a league ESPN doesn't carry). ESPN requests are exempt.
const SPORTSCORE_BREAKER_THRESHOLD = 4;
const SPORTSCORE_BREAKER_MS = 30000;
// Round the cache-buster to a time bucket instead of a unique-per-request value,
// so an edge cache (and our in-flight dedup, and retries) can be served without
// always forcing a hit on the slow origin, while data stays fresh per bucket.
const CACHE_BUST_BUCKET_MS = 30000;

let _activeRequestCount = 0;
const _pendingRequestQueue = [];
let _requestCooldownUntil = 0;
let _sportScoreFailureStreak = 0;
let _sportScoreBreakerUntil = 0;
let _delayScheduler = null;

// Runs the ESPN scoreboard for an entry/mode as a race runner, or null when ESPN
// can't help with this entry.
function espnScoreboardRunner(options, mode) {
    const plan = espnPlan(options);
    if (!plan)
        return null;
    return (onRows, onErr) => fetchEspnScoreboard(plan.espnSport, plan.league, mode, options, onRows, onErr);
}

// Live / fixtures / recent / table route to ESPN when it covers the entry, and
// otherwise to SportScore's JSON widget API (/api/widget/{matches,team,standings}).
// The earlier plasmashell freeze came from scraping SportScore's ~680 KB HTML pages
// with backtracking regexes on the UI thread; the JSON widgets are small documents
// that JSON.parse in well under a millisecond, so SportScore-only leagues (e.g. the
// Bulgarian First League, which ESPN doesn't carry) work again without the freeze.
// The HTML page scrapers remain only for the config wizard's browsing/badges.
function fetchLiveScores(options, onSuccess, onError) {
    if (isEspnNativeRequest(options)) {
        tryEspnMatches(options, "live", onSuccess, onError, () => finish(onSuccess, []));
        return;
    }
    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    const sportScoreRunner = (onRows, onErr) => {
        const deliver = rows => enrichSportScoreLiveMinutes(rows, onRows);
        if (isTeamRequest(options))
            fetchSportScoreTeamMatches(options, "live", deliver, onErr);
        else
            fetchSportScoreCompetitionMatches(options, "live", deliver, onErr);
    };
    fetchByCoverage(espnScoreboardRunner(options, "live"), sportScoreRunner, onSuccess, onError);
}

// SportScore's feed-level widgets (matches/team) carry only the phase
// ("1st half") - the actual clock (live_minute, e.g. "67" or "90+") exists only
// in the single-match widget. Enrich live rows with one small match-widget
// request each, memoized per match briefly so the 60 s live poll costs at most
// one request per live match (the endpoint itself is edge-cached 60 s). Rows
// are delivered unchanged when a lookup fails - the phase label remains.
const SPORTSCORE_LIVE_MINUTE_TTL_MS = 45000;
const SPORTSCORE_LIVE_MINUTE_MAX_LOOKUPS = 12;
const _sportScoreLiveMinuteCache = {};

function enrichSportScoreLiveMinutes(rows, onDone) {
    const list = arrayValue(rows);
    const targets = list.filter(row => row && isLiveStatus(row.status)
        && stringValue(row.liveUrl).length > 0
        && normalizedLiveMinute(stringValue(row.minute)).length === 0)
        .slice(0, SPORTSCORE_LIVE_MINUTE_MAX_LOOKUPS);
    if (targets.length === 0) {
        finish(onDone, list);
        return;
    }

    let pending = targets.length;
    const settle = () => {
        pending -= 1;
        if (pending <= 0)
            finish(onDone, list);
    };

    targets.forEach(row => {
        const key = stringValue(row.liveUrl);
        const cached = _sportScoreLiveMinuteCache[key];
        if (cached && (Date.now() - cached.ts) < SPORTSCORE_LIVE_MINUTE_TTL_MS) {
            if (cached.minute.length > 0)
                row.minute = cached.minute;
            settle();
            return;
        }

        requestText(cacheBustedUrl(key), text => {
            let minute = "";
            try {
                const payload = JSON.parse(text);
                minute = sportScoreLiveMinute(payload && payload.match, row.status, row.sport);
            } catch (error) {
                minute = "";
            }
            // Cache misses too, so a match without a clock doesn't get re-queried
            // on every poll.
            _sportScoreLiveMinuteCache[key] = { ts: Date.now(), minute: minute };
            if (minute.length > 0)
                row.minute = minute;
            settle();
        }, settle);
    });
}

function fetchScoresFixtures(options, onSuccess, onError) {
    if (isEspnNativeRequest(options)) {
        tryEspnMatches(options, "fixtures", onSuccess, onError, () => finish(onSuccess, []));
        return;
    }
    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    const sportScoreRunner = (onRows, onErr) => {
        if (isTeamRequest(options))
            fetchSportScoreTeamMatches(options, "fixtures", onRows, onErr);
        else
            fetchSportScoreCompetitionMatches(options, "fixtures", onRows, onErr);
    };
    fetchByCoverage(espnScoreboardRunner(options, "fixtures"), sportScoreRunner, onSuccess, onError);
}

function fetchRecentResults(options, onSuccess, onError) {
    if (isEspnNativeRequest(options)) {
        tryEspnMatches(options, "recent", onSuccess, onError, () => finish(onSuccess, []));
        return;
    }
    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    const sportScoreRunner = (onRows, onErr) => {
        if (isTeamRequest(options))
            fetchSportScoreTeamMatches(options, "recent", onRows, onErr);
        else
            fetchSportScoreCompetitionMatches(options, "recent", onRows, onErr);
    };
    fetchByCoverage(espnScoreboardRunner(options, "recent"), sportScoreRunner, onSuccess, onError);
}

function fetchLeagueTable(options, onSuccess, onError) {
    const plan = espnPlan(options);
    const espnRunner = plan ? (onRows, onErr) => fetchEspnStandings(plan.espnSport, plan.league, options, onRows, onErr) : null;

    if (isEspnNativeRequest(options)) {
        if (espnRunner)
            espnRunner(onSuccess, onError);
        else
            finish(onSuccess, []);
        return;
    }

    fetchByCoverage(espnRunner, (onRows, onErr) => fetchSportScoreLeagueTable(options, onRows, onErr), onSuccess, onError);
}

function fetchLeagueSeasons(options, onSuccess, onError) {
    // ESPN-covered competition: probe ESPN's own seasons endpoint so the season
    // dropdown lists exactly the seasons ESPN can serve standings for (e.g. World
    // Cup 2022). Selecting one drives fetchEspnStandings's ?season= parameter.
    const plan = espnPlan(options);
    if (plan) {
        fetchEspnSeasons(plan.espnSport, plan.league, options, onSuccess, () => finish(onSuccess, []));
        return;
    }

    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    fetchSportScoreCompetitionPage(options, page => {
        finish(onSuccess, sportScoreSeasonOptionsFromCompetitionPage(page.html));
    }, error => finish(onError, error));
}


function fetchTeamCompetitions(options, onSuccess, onError) {
    if (!isTeamRequest(options)) {
        finish(onSuccess, []);
        return;
    }

    // ESPN-covered team: its competition IS the ESPN league it plays in. Return
    // that directly (selecting it loads the ESPN standings) - never touch
    // SportScore for an ESPN entry.
    const plan = espnPlan(options);
    if (plan) {
        const sport = normalizedSport(options && (options.sports || options.sport));
        const label = stringValue(options && options.leagueLabel)
            || EspnSports.leagueLabelFor(plan.league)
            || ProviderCatalog.leagueLabel(plan.league)
            || plan.league;
        finish(onSuccess, [{
            label: label,
            slug: plan.league,
            value: plan.league,
            country: stringValue(options && options.country),
            sport: sport,
            path: "",
            url: "",
            provider: "espn"
        }]);
        return;
    }

    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    // SportScore team: the JSON team widget already tags each of the team's
    // matches with its competition - one small request keyed by slug alone (no
    // page id needed). Deriving the list from those labels avoids the page route
    // entirely. That route was the "add a team" freeze: a saved team path
    // without SportScore's id segment (the standings widget's team_url has none)
    // forced resolveSportScoreTeamPath to scrape the country page plus up to 64
    // competition pages on the UI thread just to recover the id. The page scrape
    // remains only for teams the widget doesn't index at all.
    // Ask for the widget's full 30-match window regardless of the caller's own
    // fixture limits - more matches means better competition coverage.
    fetchSportScoreTeamWidgetMatches(Object.assign({}, options, { limit: 30, fixtureLimit: 30 }), rows => {
        if (rows.length === 0) {
            fetchTeamCompetitionsFromTeamPage(options, onSuccess, onError);
            return;
        }

        finish(onSuccess, sportScoreCompetitionsFromWidgetMatches(rows, options));
    }, () => fetchTeamCompetitionsFromTeamPage(options, onSuccess, onError));
}

function fetchTeamCompetitionsFromTeamPage(options, onSuccess, onError) {
    fetchSportScoreTeamPage(options, page => {
        finish(onSuccess, sportScoreTeamCompetitions(page.html, options));
    }, error => finish(onError, error));
}

// Rows in the sportScoreTeamCompetitions shape, derived from the team widget's
// normalized match list: one row per distinct competition label. `path`/`url`
// stay empty - the table dropdown works from slug + country via the standings
// widget, and the HTML table fallback can resolve a path from the slug in the
// rare case the widget can't serve the competition.
function sportScoreCompetitionsFromWidgetMatches(rows, options) {
    const country = ProviderCatalog.slugForValue(options && options.country);
    const seen = {};
    const out = [];
    arrayValue(rows).forEach(match => {
        const label = stringValue(match && match.league).trim();
        const slug = ProviderCatalog.slugForValue(label);
        if (label.length === 0 || slug.length === 0 || seen[slug])
            return;
        seen[slug] = true;
        out.push({
            label: label,
            slug: slug,
            value: slug,
            country: country,
            path: "",
            url: ""
        });
    });

    out.sort((left, right) => competitionPriority(left.label) === competitionPriority(right.label)
        ? stringValue(left.label).localeCompare(stringValue(right.label))
        : competitionPriority(right.label) - competitionPriority(left.label));
    return out;
}

// Competitions per (sport, country) rarely change within a session, but are
// re-fetched every time the wizard revisits a country. Cache successful
// results so re-selecting a country (e.g. "world") is instant.
const _countryCompetitionsCache = {};

function fetchCountryCompetitions(options, onSuccess, onError) {
    // ESPN-native sports: competitions are the sport's ESPN leagues (optionally
    // filtered to the chosen country).
    if (isEspnNativeRequest(options)) {
        const sport = normalizedSport(options && (options.sports || options.sport));
        const wantCountry = ProviderCatalog.slugForValue(options && options.country);
        const leagues = EspnSports.leaguesFor(sport).filter(league =>
            wantCountry.length === 0 || wantCountry === "world" || wantCountry === "all"
            || ProviderCatalog.slugForValue(league.country) === wantCountry);
        finish(onSuccess, leagues);
        return;
    }

    // Shared sports (football/basketball/cricket/tennis): prefer ESPN's own
    // league catalog for the chosen country, and only fall back to SportScore's
    // slower, flakier competition listing when ESPN covers no league there.
    // Cricket has no ESPN leagues, so it always uses SportScore.
    const sharedSport = normalizedSport(options && (options.sports || options.sport));
    if (EspnSports.supports(sharedSport) && !EspnSports.isNative(sharedSport)) {
        const wantCountry = ProviderCatalog.slugForValue(options && options.country);
        const espnLeagues = EspnSports.leaguesFor(sharedSport)
            .filter(league => wantCountry.length === 0
                || ProviderCatalog.slugForValue(league.country) === wantCountry)
            // ESPN entries resolve to ESPN directly (see espnLeagueForEntry); drop
            // the SportScore-style path so no bogus SportScore lookup is stored.
            .map(league => Object.assign({}, league, { provider: "espn", path: "" }));
        if (espnLeagues.length > 0) {
            finish(onSuccess, espnLeagues);
            return;
        }
    }

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
    const cacheKey = sport + "|" + country;
    if (_countryCompetitionsCache.hasOwnProperty(cacheKey)) {
        finish(onSuccess, _countryCompetitionsCache[cacheKey]);
        return;
    }

    const sourcePath = SportScoreSports.competitionSourcePath(sport, country);
    const url = sourcePath.length > 0 ? SPORTSCORE_BASE_URL + sourcePath : "";
    if (url.length === 0) {
        finish(onSuccess, []);
        return;
    }

    const rootPath = SPORTSCORE_BASE_URL + SportScoreSports.rootPath(sport);
    const needsRootSupplement = sport === "tennis" && country === "world" && rootPath !== url;
    if (!needsRootSupplement) {
        requestText(cacheBustedUrl(url), html => {
            const rows = sportScoreCompetitionLinks(html, country, sport);
            _countryCompetitionsCache[cacheKey] = rows;
            finish(onSuccess, rows);
        }, error => {
            // A missing country page (404) means no competitions, not an outage.
            if (isHttpNotFound(error))
                finish(onSuccess, []);
            else
                finish(onError, error || "Unable to load SportScore competitions");
        });
        return;
    }

    // Tennis/world: fetch both the competitions overview and the live root page so
    // ATP Challengers / WTA 125K events (only listed on the live page) are included.
    let pending = 2;
    let merged = [];
    let seen = {};
    function combine(rows) {
        (Array.isArray(rows) ? rows : []).forEach(row => {
            const key = String(row && row.path || "").trim();
            if (key.length > 0 && !seen[key]) { seen[key] = true; merged.push(row); }
        });
        pending -= 1;
        if (pending > 0) return;
        merged.sort((a, b) => {
            if ((b.priority || 0) !== (a.priority || 0)) return (b.priority || 0) - (a.priority || 0);
            return String(a.label || "").localeCompare(String(b.label || ""));
        });
        _countryCompetitionsCache[cacheKey] = merged;
        finish(onSuccess, merged);
    }
    requestText(cacheBustedUrl(url), html => combine(sportScoreCompetitionLinks(html, country, sport)), () => combine([]));
    requestText(cacheBustedUrl(rootPath), html => combine(sportScoreCompetitionLinks(html, country, sport)), () => combine([]));
}

function fetchSportCountries(options, onSuccess, onError) {
    // ESPN-native sports have no SportScore countries: present the countries used
    // by the sport's ESPN leagues so the wizard's country step still works.
    if (isEspnNativeRequest(options)) {
        finish(onSuccess, EspnSports.countriesFor(normalizedSport(options && (options.sports || options.sport))));
        return;
    }

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

    const fetchPath = SportScoreSports.countriesPath(sport) || SportScoreSports.rootPath(sport);
    requestText(cacheBustedUrl(SPORTSCORE_BASE_URL + fetchPath), html => {
        finish(onSuccess, sportScoreCountryOptions(html, sport));
    }, error => {
        if (isHttpNotFound(error))
            finish(onSuccess, []);
        else
            finish(onError, error || "Unable to load SportScore countries");
    });
}

function fetchCountryTeams(options, onSuccess, onError) {
    const sport = normalizedSport(options && options.sports);
    const country = ProviderCatalog.slugForValue(options && options.country);
    const plan = espnPlan(options);
    const espnRunner = plan ? (onRows, onErr) => fetchEspnTeams(plan.espnSport, plan.league, options, onRows, onErr) : null;

    if (isEspnNativeRequest(options) || !SportScoreSports.supports(sport) || country.length === 0) {
        if (espnRunner)
            espnRunner(onSuccess, () => finish(onSuccess, []));
        else
            finish(onSuccess, []);
        return;
    }

    fetchByCoverage(espnRunner, (onRows, onErr) => fetchSportScoreCountryTeams(sport, country, onRows, onErr), onSuccess, onError);
}

function fetchTeamBadge(options, onSuccess, onError) {
    if (!canUseSportScore(options) || !isTeamRequest(options)) {
        finish(onSuccess, "");
        return;
    }

    // The team widget envelope carries the crest directly (team.logo) - one
    // small JSON request instead of scraping the team's HTML page. limit=1
    // keeps the payload minimal; the page scrape stays as the fallback for
    // teams the widget doesn't index.
    function fetchFromTeamPage() {
        fetchSportScoreTeamPage(options, page => {
            finish(onSuccess, sportScoreTeamBadge(page.html));
        }, () => finish(onSuccess, ""));
    }

    const widgetUrl = sportScoreTeamWidgetUrl(Object.assign({}, options, { limit: 1, fixtureLimit: 1 }));
    if (widgetUrl.length === 0) {
        fetchFromTeamPage();
        return;
    }

    requestText(cacheBustedUrl(widgetUrl), text => {
        let badge = "";
        try {
            const payload = JSON.parse(text);
            badge = absoluteSportScoreUrl(payload && payload.team && payload.team.logo);
        } catch (error) {
            badge = "";
        }
        if (badge.length > 0)
            finish(onSuccess, badge);
        else
            fetchFromTeamPage();
    }, fetchFromTeamPage);
}

function fetchLiveMatchDetails(options, onSuccess, onError) {
    // Details follow the match's own source: an ESPN match uses ESPN's incident
    // feed, a SportScore match uses SportScore's widget - never the other provider,
    // even for a shared sport where both could in principle answer.
    if (stringValue(options && options.detailsProvider) === "espn") {
        fetchEspnLiveMatchDetails(options, onSuccess);
        return;
    }

    if (!canUseSportScore(options)) {
        finish(onSuccess, emptyLiveMatchDetails());
        return;
    }

    const urls = sportScoreWidgetMatchUrls(options);
    if (urls.length === 0) {
        finish(onSuccess, emptyLiveMatchDetails());
        return;
    }

    const sport = normalizedSport(options && (options.sports || options.sport));
    if (sport === "tennis") {
        fetchSportScoreWidgetMatchDetailsByUrls(urls, 0, options, apiDetails => {
            fetchTennisMatchPage(options, html => {
                finish(onSuccess, Object.assign({}, apiDetails, {
                    tennisSets: sportScoreTennisSets(html),
                    tennisPlayerComparison: sportScorePlayerComparison(html)
                }));
            });
        }, onError);
        return;
    }

    fetchSportScoreWidgetMatchDetailsByUrls(urls, 0, options, onSuccess, onError);
}

function fetchTennisMatchPage(options, onSuccess) {
    const path = sportScorePathFromUrl(options && options.matchPath);
    if (path.length === 0 || !/\/tennis\/match\//.test(path)) {
        finish(onSuccess, "");
        return;
    }
    requestText(absoluteSportScoreUrl(path), text => finish(onSuccess, text), () => finish(onSuccess, ""));
}

function sportScoreTennisSets(html) {
    const str = stringValue(html);
    // Primary: find a div/section with id or class containing "sets" and "card"
    let block = "";
    const containerM = /<(?:div|section)\b[^>]*(?:id=["'][^"']*sets[^"']*["']|class=["'][^"']*\bsets-card\b[^"']*["'])[^>]*>([\s\S]*?)<\/table>/i.exec(str);
    if (containerM) {
        block = containerM[0];
    } else {
        // Fallback: any <table> whose content has both player-col and set-score cells
        const tblPat = /<table\b[^>]*>([\s\S]*?)<\/table>/gi;
        let tm;
        while ((tm = tblPat.exec(str)) !== null) {
            if (/player-col/.test(tm[1]) && /set-score/.test(tm[1])) {
                block = tm[0];
                break;
            }
        }
    }
    if (!block) return null;

    const titleMatch = /<h2[^>]*>([\s\S]*?)<\/h2>/i.exec(block);
    const title = titleMatch ? htmlText(titleMatch[1]).replace(/\s+/g, " ").trim() : "Set-by-set scoreboard";
    const bestOfMatch = /Best of (\d+)/i.exec(title);
    const bestOf = bestOfMatch ? Number(bestOfMatch[1]) : 0;

    const theadMatch = /<thead[^>]*>([\s\S]*?)<\/thead>/i.exec(block);
    const setLabels = [];
    if (theadMatch) {
        const thPat = /<th\b[^>]*>([\s\S]*?)<\/th>/gi;
        let thM;
        let skip = true;
        while ((thM = thPat.exec(theadMatch[1])) !== null) {
            if (skip) { skip = false; continue; }
            const label = htmlText(thM[1]).trim();
            if (label.toLowerCase() !== "sets") setLabels.push(label);
        }
    }

    const tbodyMatch = /<tbody[^>]*>([\s\S]*?)<\/tbody>/i.exec(block);
    const rows = [];
    if (tbodyMatch) {
        const trPat = /<tr\b[^>]*>([\s\S]*?)<\/tr>/gi;
        let trM;
        while ((trM = trPat.exec(tbodyMatch[1])) !== null) {
            const tr = trM[1];
            const playerColM = /<td\b[^>]*class=["'][^"']*\bplayer-col\b[^"']*["'][^>]*>([\s\S]*?)<\/td>/i.exec(tr);
            if (!playerColM) continue;
            const imgM = /<img\b[^>]*src=["']([^"']+)["'][^>]*>/i.exec(playerColM[1]);
            const badge = imgM ? absoluteSportScoreUrl(imgM[1]) : "";
            const playerName = htmlText(playerColM[1]).replace(/\s+/g, " ").trim();
            const setScores = [];
            const setPat = /<td\b[^>]*class=["']([^"']*\bset-score\b[^"']*)["'][^>]*>([\s\S]*?)<\/td>/gi;
            let setM;
            while ((setM = setPat.exec(tr)) !== null)
                setScores.push({ score: htmlText(setM[2]).trim(), winner: /\bwinner\b/.test(setM[1]) });
            const totalM = /<td\b[^>]*class=["'][^"']*\bsets-total\b[^"']*["'][^>]*>([\s\S]*?)<\/td>/i.exec(tr);
            const rawTotal = totalM ? htmlText(totalM[1]).trim() : "";
            const rawNum = parseInt(rawTotal, 10);
            // rawTotal is authoritative when > 0. When it lags at "0" (some live matches),
            // fall back to counting completed sets via winner-class cells.
            // Guard with score >= 6 to exclude in-progress sets where sportscore
            // pre-marks the current leader with the winner class.
            const setsWon = setScores.filter(s => {
                if (!s.winner) return false;
                const n = parseInt(s.score, 10);
                return !isNaN(n) && n >= 6;
            }).length;
            const totalSets = (!isNaN(rawNum) && rawNum > 0)
                ? rawTotal
                : (setsWon > 0 ? String(setsWon) : rawTotal);
            if (playerName.length > 0)
                rows.push({ playerName, badge, setScores, totalSets });
        }
    }
    return rows.length > 0 ? { title, bestOf, setLabels, rows } : null;
}

function sportScorePlayerComparison(html) {
    const str = stringValue(html);
    const compareIdx = str.indexOf("player-compare");
    if (compareIdx < 0) return null;
    const headM = /<div\b[^>]*class=["'][^"']*\bcard-head\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i.exec(str.slice(compareIdx));
    const title = headM ? htmlText(headM[1]).trim() : "Player Comparison";
    const gridIdx = str.indexOf("compare-grid", compareIdx);
    if (gridIdx < 0) return null;
    const gridStart = str.indexOf(">", gridIdx) + 1;
    const gridSection = str.slice(gridStart, gridStart + 6000);
    const cellPat = /<div\b[^>]*class=["'][^"']*\bp-(?:cell|label)\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/g;
    const cells = [];
    let cellM;
    while ((cellM = cellPat.exec(gridSection)) !== null)
        cells.push(htmlText(cellM[1]).replace(/\s+/g, " ").trim());
    const rows = [];
    for (let i = 0; i + 2 < cells.length; i += 3) {
        const homeValue = cells[i];
        const label = cells[i + 1];
        const awayValue = cells[i + 2];
        const empty = v => v.length === 0 || v === "N/A" || v === "-" || v.toLowerCase() === "unknown";
        if (label.length > 0 && (!empty(homeValue) || !empty(awayValue)))
            rows.push({ label, homeValue, awayValue });
    }
    return rows.length > 0 ? { title, rows } : null;
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

// Best-effort details for an ESPN-sourced match: just the incident feed
// (goals/cards/subs), since ESPN's site.api has no lineups/stats/match-info
// equivalent to what SportScore provides. Currently scoped to football, the
// only sport this incident feed has been verified against.
function fetchEspnLiveMatchDetails(options, onSuccess) {
    const sport = normalizedSport(options && (options.sports || options.sport));
    const espnSport = stringValue(options && options.espnSport);
    const espnLeague = stringValue(options && options.espnLeague);
    const eventId = stringValue(options && options.espnEventId);

    // Tennis: ESPN has no match-details endpoint, but the scoreboard row already
    // carries the set-by-set breakdown (espnTennisSets), so surface that directly.
    if (sport === "tennis") {
        const sets = options && options.espnTennisSets;
        finish(onSuccess, Object.assign(emptyLiveMatchDetails(), {
            sourceProvider: "ESPN",
            statsProvider: "ESPN",
            competition: stringValue(options && options.league),
            tennisSets: sets && Array.isArray(sets.rows) && sets.rows.length > 0 ? sets : null
        }));
        return;
    }

    if (espnSport.length === 0 || espnLeague.length === 0 || eventId.length === 0) {
        finish(onSuccess, emptyLiveMatchDetails());
        return;
    }

    // Two best-effort feeds make up the details panel:
    //   • summary  - boxscore team stats (Statistics tab) + venue/attendance/referee
    //                and half-time score (Information tab). All ESPN sports.
    //   • plays    - goal/card/sub incidents (Details/events tab). Football only;
    //                the plays feed is empty/uninformative for other sports.
    // Either may be unavailable; we surface whatever came back rather than failing.
    let pending = 2;
    let summary = null;
    let events = [];

    function done() {
        pending -= 1;
        if (pending > 0)
            return;
        // Prefer the summary's keyEvents (structured team/participants, and includes
        // subs + cards, not just goals) when present; fall back to the plays feed.
        const summaryEvents = summary ? arrayValue(summary.eventRows) : [];
        const detailEvents = summaryEvents.length > 0 ? summaryEvents : events;
        const base = Object.assign(emptyLiveMatchDetails(), {
            sourceProvider: "ESPN",
            statsProvider: "ESPN",
            competition: stringValue(options && options.league),
            summaryRows: sportScoreWidgetSummaryRows(detailEvents),
            homeEvents: detailEvents.filter(row => row.side === "home"),
            awayEvents: detailEvents.filter(row => row.side === "away"),
            events: detailEvents
        });
        if (summary) {
            base.statsRows = arrayValue(summary.statsRows);
            base.matchInfoRows = arrayValue(summary.matchInfoRows);
            base.halfTimeScore = stringValue(summary.halfTimeScore);
            base.leaderRows = arrayValue(summary.leaderRows);
            if (summary.lineups)
                base.lineups = summary.lineups;
            if (summary.playerBox)
                base.playerBox = summary.playerBox;
        }
        finish(onSuccess, base);
    }

    fetchEspnMatchSummary(espnSport, espnLeague, eventId, sport, options,
        result => { summary = result; done(); }, () => done());

    if (sport === "football") {
        fetchEspnMatchIncidents(espnSport, espnLeague, eventId, stringValue(options && options.homeTeam),
            stringValue(options && options.awayTeam), rows => { events = arrayValue(rows); done(); }, () => done());
    } else {
        done();
    }
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
        leaderRows: [],
        playerBox: null,
        homeEvents: [],
        awayEvents: [],
        events: [],
        trackerUrl: ""
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
        events,
        trackerUrl: sportScoreTrackerUrl(match)
    };
}

function sportScoreTrackerUrl(match) {
    const tracker = match && match.tracker;
    if (!tracker || !tracker.id || !tracker.sport)
        return "";

    // SportScore's API reports an expired "profile" for the basketball pro
    // tracker, so /api/widget/tracker/ shows "Your subscription has expired!".
    // Their own match pages embed the basketball tracker directly with the
    // same profile used for the cricket tracker, which is still active.
    if (tracker.sport === "basketball")
        return "https://widgets-v2.thesports01.com/en/pro/basketball?profile=" + SPORTSCORE_BASKETBALL_TRACKER_PROFILE + "&uuid=" + encodeURIComponent(tracker.id);

    return "https://sportscore.com/api/widget/tracker/?sport=" + encodeURIComponent(tracker.sport) + "&id=" + encodeURIComponent(tracker.id);
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

// ─────────────────────────────────────────────────────────────────────────────
// ESPN provider - the SOLE source for every sport/competition/team it covers (the
// SportScore sports + the ESPN-native sports). SportScore is used only for entries
// ESPN does not cover at all (no plan), never as a runtime fallback for an ESPN
// hiccup - routing is decided once, up front, by coverage (see fetchByCoverage).
// Uses the same hardened request queue; ESPN requests bypass SportScore's post-504
// cooldown (ignoreCooldown) so a failing SportScore never throttles ESPN.
// ─────────────────────────────────────────────────────────────────────────────

// Resolve an ESPN { espnSport, league } for an entry, or null when ESPN can't help.
function espnPlan(options) {
    return EspnSports.espnLeagueForEntry({
        sport: normalizedSport(options && (options.sports || options.sport)),
        // A followed team carries no league of its own, but does carry the
        // competition it was followed from (teamLeague) so ESPN can scope it -
        // essential for international/multi-league comps where country can't.
        league: stringValue(options && (options.league || options.teamLeague)),
        country: stringValue(options && options.country)
    });
}

function isEspnNativeRequest(options) {
    return EspnSports.isNative(normalizedSport(options && (options.sports || options.sport)));
}

// Fetch the ESPN scoreboard for an entry/mode (used for ESPN-native sports, where
// ESPN is the only source). Calls onNoEspn() when ESPN has no plan for the entry;
// an empty-but-successful ESPN response is reported as an empty result, not routed
// elsewhere.
function tryEspnMatches(options, mode, onSuccess, onError, onNoEspn) {
    const plan = espnPlan(options);
    if (!plan) {
        onNoEspn();
        return;
    }
    fetchEspnScoreboard(plan.espnSport, plan.league, mode, options, rows => {
        if (arrayValue(rows).length > 0)
            finish(onSuccess, rows);
        else
            onNoEspn();
    }, () => onNoEspn());
}

// Coverage-based routing - no instability fallback. Each entry is served by
// exactly ONE provider, decided up front by ESPN coverage:
//   • ESPN covers it (espnRunner !== null) → ESPN exclusively, even if ESPN
//     returns an empty result. We never retry against SportScore just because
//     ESPN was momentarily empty or errored - ESPN is the reliable source, and
//     racing/falling back to SportScore is exactly the instability we're avoiding.
//   • ESPN does not cover it (espnRunner === null) → the supplied sportScoreRunner,
//     or an empty result when that is null too. Live/fixtures/recent/table pass a
//     null SportScore runner (those modes are ESPN-only - see fetchLiveScores), so
//     an ESPN-uncovered entry simply yields no rows there instead of scraping a
//     huge SportScore HTML page on the UI thread.
//   espnRunner(onRows, onErr) - the ESPN path, or null when ESPN has no plan.
//   sportScoreRunner(onRows, onErr) - the SportScore path, or null to disable it.
function fetchByCoverage(espnRunner, sportScoreRunner, onSuccess, onError) {
    const runner = espnRunner || sportScoreRunner;
    if (!runner) {
        finish(onSuccess, []);
        return;
    }
    runner(rows => finish(onSuccess, rows), err => finish(onError, err));
}

function espnDate(timestamp) {
    const date = new Date(timestamp);
    const y = date.getFullYear();
    const m = ("0" + (date.getMonth() + 1)).slice(-2);
    const d = ("0" + date.getDate()).slice(-2);
    return "" + y + m + d;
}

// Honours the caller's requested look-ahead (scoreboardDaysForward) when present,
// capped so a single scoreboard call can't pull a multi-MB payload that blocks the
// UI thread during JSON.parse; falls back to the module default otherwise.
function espnClampDays(value, fallback, max) {
    const n = numberValue(value);
    const cap = numberValue(max) > 0 ? numberValue(max) : 30;
    return n > 0 ? Math.min(n, cap) : fallback;
}

// How far ahead the fixtures window may reach. Larger than the back cap because
// fixtures are sparse (a few per league) - a wide look-ahead is cheap and is what
// surfaces next-season fixtures during the off-season (e.g. an August restart when
// "today" is late June), instead of an empty Schedules tab. Upper bound for the
// user-configurable "Schedules days ahead" setting (max one year).
const ESPN_FIXTURE_MAX_DAYS_AHEAD = 365;

// The unified window only ever feeds live + fixtures - "recent" has its own
// year-to-date fetch (see fetchEspnScoreboard) and never reads this window, so a
// wide look-BACK here is dead weight. Worse, it is actively harmful for busy
// leagues: ESPN returns scoreboard events ascending from the range start and caps
// the payload at `limit`, so a fortnight of past MLB/NHL/NBA games (~15/day) fills
// the whole cap before the response ever reaches today - today's and every future
// fixture get truncated off the end, leaving the Schedule tab empty. Keeping only a
// one-day boundary buffer behind "now" (enough to cover the UTC/local date-line gap
// and a game that runs past midnight) spends the ascending cap on today + upcoming,
// which is exactly what live/fixtures need.
const ESPN_UNIFIED_DAYS_BACK = 1;

// One window spanning "just before now"..fixtures, fetched once per league and
// split into live/fixtures by status (see fetchEspnScoreboard).
function espnUnifiedDates(options) {
    const now = Date.now();
    const day = 24 * 60 * 60 * 1000;
    const ahead = espnClampDays(options && options.scoreboardDaysForward, ESPN_FIXTURE_DAYS_AHEAD, ESPN_FIXTURE_MAX_DAYS_AHEAD);
    return espnDate(now - ESPN_UNIFIED_DAYS_BACK * day) + "-" + espnDate(now + ahead * day);
}

function espnScoreboardUrl(espnSport, league, dates, limit) {
    const max = numberValue(limit) > 0 ? numberValue(limit) : ESPN_MATCH_LIMIT;
    let url = ESPN_SITE_BASE + "/" + encodeURIComponent(espnSport) + "/" + encodeURIComponent(league)
        + "/scoreboard?limit=" + max;
    if (stringValue(dates).length > 0)
        url += "&dates=" + encodeURIComponent(dates);
    return url;
}

function espnLogoFromTeam(team) {
    if (!team)
        return "";
    if (team.logo)
        return stringValue(team.logo);
    const logos = arrayValue(team.logos);
    return logos.length > 0 ? stringValue(logos[0] && logos[0].href) : "";
}

function espnStatusFromState(state, completed) {
    const value = stringValue(state).toLowerCase();
    if (value === "in")
        return "Live";
    if (value === "post" || completed === true)
        return "Finished";
    return "Upcoming";
}

// ESPN keeps the live match clock in status.displayClock ("63'", "90'+7'");
// status.type.shortDetail is often only the phase ("1st Half", "HT"). For
// football the clock is the live label users expect. Other sports keep
// shortDetail, which already combines clock and period ("5:32 - 3rd Quarter").
function espnLiveMinute(sportValue, statusObject, statusText) {
    // A break phase beats the frozen clock: at half time the clock still reads
    // "45'", which would look like play is running.
    if (/^ht$|half[\s-]?time|break/i.test(stringValue(statusText).trim()))
        return statusText;
    if (normalizedSport(sportValue) === "football") {
        const clock = stringValue(statusObject && statusObject.displayClock).trim();
        if (clock.length > 0 && clock !== "0'" && clock !== "0:00")
            return clock;
    }
    return statusText;
}

function normalizeEspnEvent(event, sportValue, options) {
    const competition = arrayValue(event && event.competitions)[0] || {};
    const competitors = arrayValue(competition.competitors);
    let home = null;
    let away = null;
    competitors.forEach(side => {
        if (stringValue(side && side.homeAway) === "home")
            home = side;
        else if (stringValue(side && side.homeAway) === "away")
            away = side;
    });
    if (!home && competitors.length > 0)
        home = competitors[0];
    if (!away && competitors.length > 1)
        away = competitors[1];
    if (!home || !away)
        return null;

    const statusObject = competition.status || (event && event.status) || {};
    const statusType = statusObject.type || {};
    const status = espnStatusFromState(statusType.state, statusType.completed);
    const statusText = stringValue(statusType.shortDetail || statusType.detail || statusType.description);
    const timestamp = Date.parse(stringValue(event && event.date));
    const homeTeam = home.team || {};
    const awayTeam = away.team || {};

    return {
        id: "espn-" + stringValue(event && event.id),
        sport: sportValue,
        league: stringValue(options && options.leagueLabel),
        homeTeam: stringValue(homeTeam.displayName || homeTeam.name || homeTeam.shortDisplayName),
        awayTeam: stringValue(awayTeam.displayName || awayTeam.name || awayTeam.shortDisplayName),
        homeScore: status === "Upcoming" ? "" : stringValue(home.score),
        awayScore: status === "Upcoming" ? "" : stringValue(away.score),
        status,
        statusText,
        minute: status === "Live" ? espnLiveMinute(sportValue, statusObject, statusText) : "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp, options) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: "",
        group: "",
        stadium: stringValue(competition.venue && competition.venue.fullName),
        homeBadge: espnLogoFromTeam(homeTeam),
        awayBadge: espnLogoFromTeam(awayTeam),
        poster: "",
        popular: false,
        matchPath: "",
        liveUrl: "",
        detailsProvider: "espn",
        statsProvider: "espn",
        sourceProvider: "ESPN",
        // Needed to fetch this match's incident feed later (see fetchEspnMatchIncidents).
        espnEventId: stringValue(event && event.id),
        espnSport: stringValue(options && options.espnSport),
        espnLeague: stringValue(options && options.espnLeague)
    };
}

// Sets won by a tennis competitor = the linescores (per-set games) they won. ESPN
// gives no aggregate "sets" field, so derive it; falls back to the flat score when
// linescores are absent.
function espnTennisSetsWon(competitor) {
    const lines = arrayValue(competitor && competitor.linescores);
    if (lines.length > 0)
        return lines.filter(line => line && line.winner === true).length;
    return numberValue(competitor && competitor.score);
}

// Per-set "games (tiebreak)" string for one competitor's set, e.g. "6" or "7(3)".
function espnTennisSetCell(line) {
    const games = stringValue(line && line.value);
    const tb = line && line.tiebreak !== undefined && line.tiebreak !== null ? stringValue(line.tiebreak) : "";
    return tb.length > 0 ? games + "(" + tb + ")" : games;
}

// Set-by-set details for an ESPN tennis match, in the SAME shape the UI's details
// panel expects from SportScore (sportScoreTennisSets): { title, rows:[{ label,
// homeValue, awayValue }] }, one row per set. Lets ESPN tennis matches show their
// set breakdown even though ESPN has no separate match-details endpoint.
function espnTennisSetsDetails(home, away) {
    const homeLines = arrayValue(home && home.linescores);
    const awayLines = arrayValue(away && away.linescores);
    const count = Math.max(homeLines.length, awayLines.length);
    if (count === 0)
        return null;
    const rows = [];
    for (let i = 0; i < count; i += 1) {
        const homeValue = espnTennisSetCell(homeLines[i]);
        const awayValue = espnTennisSetCell(awayLines[i]);
        if (homeValue.length > 0 || awayValue.length > 0)
            rows.push({ label: "Set " + (i + 1), homeValue, awayValue });
    }
    return rows.length > 0 ? { title: "Set-by-set scoreboard", rows } : null;
}

// One ESPN tennis match (a competition inside an event's groupings) → a match row
// in the same shape as the football path, plus tennisSets for the per-set display.
function normalizeEspnTennisMatch(competition, tournamentName, sportValue, options) {
    const competitors = arrayValue(competition && competition.competitors);
    if (competitors.length < 2)
        return null;
    let home = competitors.find(side => stringValue(side && side.homeAway) === "home") || competitors[0];
    let away = competitors.find(side => stringValue(side && side.homeAway) === "away") || competitors[1];
    if (home === away)
        away = competitors[1] === home ? competitors[0] : competitors[1];

    const homeAthlete = (home && home.athlete) || {};
    const awayAthlete = (away && away.athlete) || {};
    const homeName = stringValue(homeAthlete.displayName || homeAthlete.fullName);
    const awayName = stringValue(awayAthlete.displayName || awayAthlete.fullName);
    if (homeName.length === 0 || awayName.length === 0)
        return null;

    const statusType = (competition.status && competition.status.type) || {};
    const status = espnStatusFromState(statusType.state, statusType.completed);
    const statusText = stringValue(statusType.shortDetail || statusType.detail || statusType.description);
    const timestamp = Date.parse(stringValue(competition.date));
    const round = stringValue(competition.round && (competition.round.displayName || competition.round.name));

    return {
        id: "espn-" + stringValue(competition.id),
        sport: sportValue,
        league: tournamentName || stringValue(options && options.leagueLabel),
        homeTeam: homeName,
        awayTeam: awayName,
        homeScore: status === "Upcoming" ? "" : stringValue(espnTennisSetsWon(home)),
        awayScore: status === "Upcoming" ? "" : stringValue(espnTennisSetsWon(away)),
        status,
        statusText,
        minute: status === "Live" ? statusText : "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp, options) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: round,
        group: round,
        stadium: stringValue(competition.venue && competition.venue.fullName),
        homeBadge: stringValue(homeAthlete.flag && homeAthlete.flag.href),
        awayBadge: stringValue(awayAthlete.flag && awayAthlete.flag.href),
        poster: "",
        popular: false,
        matchPath: "",
        liveUrl: "",
        // Set-by-set breakdown (details-panel shape) carried on the row, so the
        // details panel can show it without a separate fetch - ESPN has no tennis
        // match-details endpoint. Surfaced by fetchEspnLiveMatchDetails.
        espnTennisSets: espnTennisSetsDetails(home, away),
        detailsProvider: "espn",
        statsProvider: "espn",
        sourceProvider: "ESPN",
        espnEventId: stringValue(competition.id),
        espnSport: stringValue(options && options.espnSport),
        espnLeague: stringValue(options && options.espnLeague)
    };
}

// Tennis scoreboards nest matches under event.groupings[].competitions[] (each
// event is a tournament), unlike the flat team-sport scoreboard. Flatten them.
function normalizeEspnTennisScoreboard(payload, sportValue, options) {
    let rows = [];
    arrayValue(payload && payload.events).forEach(event => {
        const tournament = stringValue(event && event.name);
        arrayValue(event && event.groupings).forEach(grouping => {
            arrayValue(grouping && grouping.competitions).forEach(competition => {
                const row = normalizeEspnTennisMatch(competition, tournament, sportValue, options);
                if (row)
                    rows.push(row);
            });
        });
    });
    return rows;
}

// One ESPN MMA fight (a competition on the event) → a head-to-head match row.
// Fights carry two athlete competitors and a winner flag but no running score, so
// the score columns stay blank and the winner is shown via the status/round line.
function normalizeEspnMmaFight(competition, cardName, sportValue, options) {
    const competitors = arrayValue(competition && competition.competitors);
    if (competitors.length < 2)
        return null;
    const home = competitors[0];
    const away = competitors[1];
    const homeAthlete = (home && home.athlete) || {};
    const awayAthlete = (away && away.athlete) || {};
    const homeName = stringValue(homeAthlete.displayName || homeAthlete.fullName);
    const awayName = stringValue(awayAthlete.displayName || awayAthlete.fullName);
    if (homeName.length === 0 || awayName.length === 0)
        return null;

    const statusType = (competition.status && competition.status.type) || {};
    const status = espnStatusFromState(statusType.state, statusType.completed);
    const timestamp = Date.parse(stringValue(competition.date || (options && options.eventDate)));
    // Weight class / card segment, if present, used as the "round" line.
    const segment = stringValue(competition.type && (competition.type.text || competition.type.abbreviation));
    // Result line for a finished fight: who won.
    const winner = home && home.winner === true ? homeName : (away && away.winner === true ? awayName : "");
    const resultText = status === "Finished" && winner.length > 0
        ? winner + " def." : stringValue(statusType.shortDetail || statusType.description);

    return {
        id: "espn-" + stringValue(competition.id),
        sport: sportValue,
        league: cardName || stringValue(options && options.leagueLabel),
        homeTeam: homeName,
        awayTeam: awayName,
        // No running score in the feed; show the winner via the score column as a
        // checkmark-style "W"/"L" only once finished, blank otherwise.
        homeScore: status === "Finished" && home && home.winner === true ? "W" : (status === "Finished" && winner.length > 0 ? "L" : ""),
        awayScore: status === "Finished" && away && away.winner === true ? "W" : (status === "Finished" && winner.length > 0 ? "L" : ""),
        status,
        statusText: resultText,
        minute: status === "Live" ? stringValue(statusType.shortDetail) : "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp, options) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: segment,
        group: segment,
        stadium: stringValue(competition.venue && competition.venue.fullName),
        homeBadge: stringValue(homeAthlete.flag && homeAthlete.flag.href),
        awayBadge: stringValue(awayAthlete.flag && awayAthlete.flag.href),
        poster: "",
        popular: false,
        matchPath: "",
        liveUrl: "",
        detailsProvider: "espn",
        statsProvider: "espn",
        sourceProvider: "ESPN",
        espnEventId: stringValue(competition.id),
        espnSport: stringValue(options && options.espnSport),
        espnLeague: stringValue(options && options.espnLeague)
    };
}

// MMA scoreboards list each fight as a competition on the event (the fight card).
function normalizeEspnMmaScoreboard(payload, sportValue, options) {
    let rows = [];
    arrayValue(payload && payload.events).forEach(event => {
        const card = stringValue(event && event.name);
        const eventDate = stringValue(event && event.date);
        const merged = Object.assign({}, options, { eventDate: eventDate });
        arrayValue(event && event.competitions).forEach(competition => {
            const row = normalizeEspnMmaFight(competition, card, sportValue, merged);
            if (row)
                rows.push(row);
        });
    });
    return rows;
}

// Position label for a leaderboard competitor: prefer an explicit position, else
// the 1-based finishing/standing order.
function espnLeaderboardPosition(competitor, fallbackOrder) {
    const pos = competitor && competitor.status && competitor.status.position;
    const explicit = stringValue(pos && (pos.displayName || pos.abbreviation || pos.id));
    if (explicit.length > 0)
        return explicit;
    const order = numberValue(competitor && competitor.order) || fallbackOrder;
    return order > 0 ? "P" + order : "";
}

// Golf / racing are leaderboards, not head-to-head, but the UI delegate is two-
// sided. Represent each event as a single row "leader vs runner-up", with the
// event name as the competition. When a specific player is followed
// (filterEspnRowsForEntry uses favoriteTeam), surface that player as the home side
// against the leader instead, so a follower sees their own standing.
function normalizeEspnLeaderboardEvent(event, sportValue, options) {
    const competition = arrayValue(event && event.competitions)
        // Pick the competition with the most competitors (the race/round with the
        // full field, not an empty practice session).
        .reduce((best, c) => (arrayValue(c && c.competitors).length > arrayValue(best && best.competitors).length ? c : best), null);
    const competitors = arrayValue(competition && competition.competitors)
        .slice()
        .sort((a, b) => (numberValue(a && a.order) || 9999) - (numberValue(b && b.order) || 9999));
    if (competitors.length < 1)
        return null;

    const eventName = stringValue(event && event.name);
    const statusType = (competition.status && competition.status.type) || (event && event.status && event.status.type) || {};
    const status = espnStatusFromState(statusType.state, statusType.completed);
    const timestamp = Date.parse(stringValue((competition && competition.date) || (event && event.date)));

    const leader = competitors[0];
    const followed = stringValue(options && options.favoriteTeam);
    // Home side: the followed player if they are in this field, else the leader.
    let home = leader;
    if (followed.length > 0) {
        const mine = competitors.find(c => sameTeamName((c.athlete || {}).displayName || (c.athlete || {}).fullName, followed));
        if (mine)
            home = mine;
    }
    // Away side: the leader (or runner-up when the followed player IS the leader).
    let away = (home === leader) ? (competitors[1] || null) : leader;

    const homeAthlete = (home && home.athlete) || {};
    const awayAthlete = (away && away.athlete) || {};
    const homeName = stringValue(homeAthlete.displayName || homeAthlete.fullName);
    if (homeName.length === 0)
        return null;
    const awayName = stringValue(awayAthlete.displayName || awayAthlete.fullName);

    return {
        id: "espn-" + stringValue(event && event.id),
        sport: sportValue,
        league: eventName || stringValue(options && options.leagueLabel),
        homeTeam: homeName,
        awayTeam: awayName.length > 0 ? awayName : eventName,
        homeScore: status === "Upcoming" ? "" : (stringValue(home.score) || espnLeaderboardPosition(home, 1)),
        awayScore: status === "Upcoming" || awayName.length === 0 ? "" : (stringValue(away.score) || espnLeaderboardPosition(away, 2)),
        status,
        statusText: stringValue(statusType.shortDetail || statusType.detail || statusType.description),
        minute: status === "Live" ? stringValue(statusType.shortDetail) : "",
        startTime: Number.isFinite(timestamp) ? formatStartTime(timestamp, options) : "",
        timestamp: Number.isFinite(timestamp) ? timestamp : 0,
        matchday: eventName,
        group: eventName,
        stadium: stringValue((competition && competition.venue && competition.venue.fullName)
            || (event && event.circuit && event.circuit.fullName)),
        homeBadge: stringValue(homeAthlete.flag && homeAthlete.flag.href),
        awayBadge: stringValue(awayAthlete.flag && awayAthlete.flag.href),
        poster: "",
        popular: false,
        matchPath: "",
        liveUrl: "",
        detailsProvider: "espn",
        statsProvider: "espn",
        sourceProvider: "ESPN",
        espnEventId: stringValue(event && event.id),
        espnSport: stringValue(options && options.espnSport),
        espnLeague: stringValue(options && options.espnLeague)
    };
}

function normalizeEspnLeaderboardScoreboard(payload, sportValue, options) {
    let rows = [];
    arrayValue(payload && payload.events).forEach(event => {
        const row = normalizeEspnLeaderboardEvent(event, sportValue, options);
        if (row)
            rows.push(row);
    });
    return rows;
}

function normalizeEspnScoreboard(payload, sportValue, leagueLabel, options) {
    const merged = Object.assign({ leagueLabel: leagueLabel }, options || {});
    const sport = normalizedSport(sportValue);
    if (sport === "tennis")
        return normalizeEspnTennisScoreboard(payload, sportValue, merged);
    if (sport === "mma")
        return normalizeEspnMmaScoreboard(payload, sportValue, merged);
    if (sport === "golf" || sport === "racing")
        return normalizeEspnLeaderboardScoreboard(payload, sportValue, merged);

    const league = stringValue((payload && payload.leagues && payload.leagues[0] && payload.leagues[0].name)) || leagueLabel;
    return arrayValue(payload && payload.events)
        .map(event => {
            const row = normalizeEspnEvent(event, sportValue, merged);
            if (row && stringValue(row.league).length === 0)
                row.league = league;
            return row;
        })
        .filter(row => row && stringValue(row.homeTeam).length > 0 && stringValue(row.awayTeam).length > 0);
}

function filterEspnMatchesForMode(rows, mode) {
    const list = arrayValue(rows);
    if (mode === "live")
        return list.filter(isLiveMatch);
    if (mode === "recent")
        return list.filter(isFinishedMatch);
    if (mode === "fixtures")
        return list.filter(row => stringValue(row.status) === "Upcoming");
    return list;
}

// Most fixtures/recent matches a single competition contributes to the UI. A live
// tournament (e.g. the World Cup) can return ~100 matches in the unified window;
// pushing all of them through the schedule + panel + tooltip models on the UI
// thread is what makes adding such a competition freeze for seconds. The soonest
// (fixtures) / most-recent (recent) of this many is far more than the UI shows.
const ESPN_MODE_MATCH_LIMIT = 40;
// "Recent results" deliberately shows a whole year of finished matches, so its
// cap is far higher than the unified-window default - a full football season is
// ~38 league matches plus cup ties per club, and a year-to-date competition view
// can hold many more. Still bounded so a huge tournament can't flood the models.
const ESPN_RECENT_MODE_MATCH_LIMIT = 300;

// When the entry follows a single team/player, keep only that competitor's
// matches out of the league scoreboard. Essential for player sports (tennis): the
// ATP/WTA scoreboard carries every match, but a followed player wants just theirs.
// For whole-competition entries (no favoriteTeam) this is a no-op.
function filterEspnRowsForEntry(rows, options) {
    const team = stringValue(options && options.favoriteTeam);
    if (team.length === 0)
        return arrayValue(rows);
    return arrayValue(rows).filter(row => matchBelongsToTeam(row, team));
}

// Sort + return only the rows for one mode out of a fully-normalized scoreboard.
function espnRowsForMode(rows, mode, limit) {
    const filtered = filterEspnMatchesForMode(rows, mode);
    if (mode === "live")
        return sortMatches(filtered);
    const sorted = mode === "recent" ? sortRecentMatches(filtered) : sortMatches(filtered);
    const cap = numberValue(limit) > 0 ? numberValue(limit) : ESPN_MODE_MATCH_LIMIT;
    return sorted.slice(0, cap);
}

// First day of the current calendar year, ESPN date format (YYYYMMDD).
function espnYearStartDate() {
    const now = new Date();
    return espnDate(new Date(now.getFullYear(), 0, 1).getTime());
}

// High-cadence sports play (almost) daily, so a year-to-date "recent" window pulls a
// multi-MB scoreboard: each ESPN event row is ~15-25 KB (it carries the full box
// score/odds blob), and MLB/NHL/NBA rack up ~1000+ events a season. At limit=300
// that is 5-8 MB - which BOTH blows past the 14 s request timeout (so Recent came up
// empty) AND stalls the UI thread on JSON.parse. These sports instead use a short
// trailing window: the Recent tab only shows ~80 matches anyway, and ESPN returns
// events ascending so a *narrow* window ending today is the only way to actually get
// the most recent ones (a wide window + small limit returns the OLDEST in range).
const ESPN_DAILY_CADENCE_SPORTS = ["baseball", "basketball", "hockey"];
// Trailing span (days) for those sports' recent window. It MUST be short enough that
// the whole window holds fewer games than ESPN_DAILY_RECENT_LIMIT: ESPN only returns
// events ascending and truncates at the limit, so a window bigger than the limit
// would hand back the OLDEST games in range and drop the most recent - the opposite
// of "recent". At ~15 games/day, 8 days ≈ 120 games, comfortably under the 200 cap,
// so the fetch returns the entire window (yesterday's games included) at ~2.4 MB -
// parseable and inside the request timeout, unlike the old 5-8 MB year-to-date pull.
// (A league that is between seasons legitimately has no games in this window and the
// Recent tab shows its empty state - there genuinely are no recent results.)
const ESPN_DAILY_RECENT_DAYS = 8;
// Cap chosen to exceed the window's game count (so nothing truncates) while bounding
// the payload if a stretch is unusually dense (doubleheaders, catch-up games).
const ESPN_DAILY_RECENT_LIMIT = 200;

// { dates, limit } for a league's "recent" scoreboard fetch. Daily-cadence sports get
// a bounded trailing window; everyone else keeps the full year-to-date span (a
// weekly-cadence league's whole season is small enough to fetch and parse at once).
function espnRecentWindow(sportValue) {
    const sport = normalizedSport(sportValue);
    if (ESPN_DAILY_CADENCE_SPORTS.indexOf(sport) >= 0) {
        const now = Date.now();
        const day = 24 * 60 * 60 * 1000;
        return {
            dates: espnDate(now - ESPN_DAILY_RECENT_DAYS * day) + "-" + espnDate(now),
            limit: ESPN_DAILY_RECENT_LIMIT
        };
    }
    return { dates: espnYearStartDate() + "-" + espnDate(Date.now()), limit: ESPN_RECENT_FALLBACK_LIMIT };
}

// Wider trailing window used ONLY when a daily-cadence sport's short recent window
// came back empty - i.e. the league is between seasons and its last games are weeks
// back. Offseason there are few games in range, so this stays small (NHL ~45 days in
// July is ~11 games / ~0.3 MB) and can't truncate the way the in-season window would.
// Returns null for non-daily sports (they already fetch year-to-date, no fallback).
const ESPN_DAILY_RECENT_FALLBACK_DAYS = 45;
function espnRecentFallbackWindow(sportValue) {
    if (ESPN_DAILY_CADENCE_SPORTS.indexOf(normalizedSport(sportValue)) < 0)
        return null;
    const now = Date.now();
    const day = 24 * 60 * 60 * 1000;
    return {
        dates: espnDate(now - ESPN_DAILY_RECENT_FALLBACK_DAYS * day) + "-" + espnDate(now),
        limit: ESPN_DAILY_RECENT_LIMIT
    };
}

// Wider look-AHEAD used ONLY when a daily-cadence sport's default fixtures window is
// empty (between seasons) - reaches the next season's opener, which can be ~3 months
// out (NHL: July → mid-September preseason). Offseason there are few scheduled games
// in range, so the payload stays small. Returns null for non-daily sports.
const ESPN_DAILY_FIXTURES_FALLBACK_DAYS = 100;
function espnFixturesFallbackWindow(sportValue) {
    if (ESPN_DAILY_CADENCE_SPORTS.indexOf(normalizedSport(sportValue)) < 0)
        return null;
    const now = Date.now();
    const day = 24 * 60 * 60 * 1000;
    return {
        dates: espnDate(now - 1 * day) + "-" + espnDate(now + ESPN_DAILY_FIXTURES_FALLBACK_DAYS * day),
        limit: ESPN_DAILY_RECENT_LIMIT
    };
}

// Date window for the "live" fetch: yesterday..tomorrow (ESPN YYYYMMDD range).
// ESPN files each match under its UTC kickoff date, but espnDate() formats in the
// user's LOCAL time, so a single "today" window misses a live match whenever local
// and UTC fall on different calendar days (e.g. a 21:00 UTC kickoff is already
// "tomorrow" for a UTC+3 user) — and a match starting late in the day can run past
// midnight UTC regardless of timezone. A ±1-day window covers both cases; it stays
// narrow (3 days) so the live refresh doesn't pull a freeze-inducing payload, and
// the status filter still keeps only the genuinely-live rows.
function espnLiveDates() {
    const now = Date.now();
    const day = 24 * 60 * 60 * 1000;
    return espnDate(now - day) + "-" + espnDate(now + day);
}

// Deliver one mode's rows from an already-fetched unified window. Used for
// live/fixtures only; "recent" is routed to its own year-to-date fetch upstream
// (see fetchEspnScoreboard) and never reaches here.
function deliverEspnMode(espnSport, league, mode, options, rows, onSuccess) {
    finish(onSuccess, espnRowsForMode(filterEspnRowsForEntry(rows, options), mode));
}

// Short-lived cache + in-flight de-dup, both keyed by espnSport|league. A saved
// entry's live, fixtures and recent tabs each ask for the SAME league's
// scoreboard, differing only by status filter - and several entries fire them all
// at once right after saving. Fetching and JSON.parsing that payload 3× per entry
// on the UI thread is what froze the widget. Instead we fetch one unified window
// per league, parse it once, and serve every waiter's mode from the result.
const ESPN_SCOREBOARD_TTL_MS = 20000;
const _espnScoreboardCache = {};
const _espnScoreboardWaiters = {};
// Recent results only change when a match finishes, but the year-to-date payload
// behind them (≈865 KB for a busy competition) is expensive to JSON.parse on the
// UI thread. While matches are live the full refresh tightens to every 5 min
// (smartActiveFullRefreshMs); a 20 s TTL meant every one of those refreshes
// re-downloaded and re-parsed the payload per league — the periodic plasmashell
// freeze. The TTL must exceed that cadence (not merely match it, or the cache is
// always just-expired when the next refresh lands): at 10 min every other full
// refresh is served warm, and a finished match still reaches Recent within
// minutes.
const ESPN_RECENT_TTL_MS = 10 * 60 * 1000;
const _espnRecentCache = {};
const _espnRecentWaiters = {};

// One-shot scoreboard fetch over an explicit date window; parses once and returns
// just the requested mode's rows. Does NOT touch the unified cache/dedup. A higher
// `limit` is needed for wide windows, since ESPN returns matches ascending and
// caps at the limit - too low a cap drops the most recent matches.
function fetchEspnScoreboardWindow(espnSport, league, dates, mode, options, onSuccess, onError, limit, modeLimit) {
    const sportValue = normalizedSport(options && (options.sports || options.sport)) || EspnSports.normalizedSport(espnSport);
    const leagueLabel = stringValue(options && options.leagueLabel);
    const merged = Object.assign({}, options, { espnSport: espnSport, espnLeague: league });
    requestText(cacheBustedUrl(espnScoreboardUrl(espnSport, league, dates, limit)), text => {
        let rows = [];
        rows = profileSync("espnScoreboardWindow parse", league + "/" + mode + ", text=" + stringValue(text).length + "B", () => {
            try {
                return normalizeEspnScoreboard(JSON.parse(text), sportValue, leagueLabel, merged);
            } catch (error) {
                return [];
            }
        });
        finish(onSuccess, espnRowsForMode(filterEspnRowsForEntry(rows, options), mode, modeLimit));
    }, error => finish(onError, error || "Unable to load ESPN scoreboard"), { ignoreCooldown: true });
}

function fetchEspnScoreboard(espnSport, league, mode, options, onSuccess, onError) {
    if (stringValue(espnSport).length === 0 || stringValue(league).length === 0) {
        finish(onSuccess, []);
        return;
    }
    const key = espnSport + "|" + league;

    // Recent always needs its own year-to-date window, which is far wider than the
    // unified live/fixtures window - fetch it directly instead of pulling (and
    // caching) the narrow unified window only to discard it. De-dup + cache the
    // recent fetch per league, since several scope entries on the same league each
    // ask for it at once and the year-to-date payload (≈865 KB for a busy comp) is
    // expensive to JSON.parse on the UI thread - parsing it once per refresh
    // instead of once per entry removes a second main-thread stall (see the
    // _sportScoreGlobalLive cache for the same pattern on the SportScore side).
    if (mode === "recent") {
        const recentCached = _espnRecentCache[key];
        if (recentCached && (Date.now() - recentCached.ts) < ESPN_RECENT_TTL_MS) {
            finish(onSuccess, recentCached.rows);
            return;
        }
        if (_espnRecentWaiters[key]) {
            _espnRecentWaiters[key].push({ onSuccess: onSuccess, onError: onError });
            return;
        }
        _espnRecentWaiters[key] = [{ onSuccess: onSuccess, onError: onError }];

        const settleRecent = rows => {
            _espnRecentCache[key] = { ts: Date.now(), rows: rows };
            const waiters = _espnRecentWaiters[key] || [];
            delete _espnRecentWaiters[key];
            waiters.forEach(waiter => finish(waiter.onSuccess, rows));
        };
        const failRecent = error => {
            const waiters = _espnRecentWaiters[key] || [];
            delete _espnRecentWaiters[key];
            waiters.forEach(waiter => finish(waiter.onError, error));
        };

        // Sport-aware window+limit: daily-cadence sports (MLB/NHL/NBA) use a bounded
        // trailing window so the payload stays parseable and inside the request
        // timeout; weekly sports keep the full year-to-date span. See espnRecentWindow.
        const sportValue = normalizedSport(options && (options.sports || options.sport)) || EspnSports.normalizedSport(espnSport);
        const recentWindow = espnRecentWindow(sportValue);
        fetchEspnScoreboardWindow(espnSport, league, recentWindow.dates, "recent", options, rows => {
            // A daily-cadence league that is between seasons has no games in the short
            // trailing window. Widen once to catch the tail of the season that just
            // ended (e.g. NHL playoffs finishing in June, viewed in July) - offseason
            // there are few games, so the wider pull is small and safe. See
            // espnRecentFallbackWindow.
            const fallback = espnRecentFallbackWindow(sportValue);
            if (arrayValue(rows).length === 0 && fallback) {
                fetchEspnScoreboardWindow(espnSport, league, fallback.dates, "recent", options,
                    settleRecent, failRecent, fallback.limit, ESPN_RECENT_MODE_MATCH_LIMIT);
                return;
            }
            settleRecent(rows);
        }, failRecent, recentWindow.limit, ESPN_RECENT_MODE_MATCH_LIMIT);
        return;
    }

    // A warm unified window serves any mode (incl. live) without another fetch.
    const cached = _espnScoreboardCache[key];
    if (cached && (Date.now() - cached.ts) < ESPN_SCOREBOARD_TTL_MS) {
        deliverEspnMode(espnSport, league, mode, options, cached.rows, onSuccess);
        return;
    }

    // Live refresh fires on its own ~60s timer. Pulling the whole unified window
    // (e.g. an in-progress World Cup ≈ 100 matches) every cycle just to filter the
    // few live ones blocks the UI thread - the cause of the periodic freeze. When
    // the cache is cold, fetch only a narrow yesterday..tomorrow window for live -
    // wide enough to catch matches around the UTC/local date boundary (see
    // espnLiveDates), still small enough to parse without freezing.
    if (mode === "live") {
        fetchEspnScoreboardWindow(espnSport, league, espnLiveDates(), mode, options, onSuccess, onError);
        return;
    }

    // fixtures/recent: one unified fetch per league, parsed once, shared by all
    // concurrent waiters and cached briefly for follow-up calls.
    if (_espnScoreboardWaiters[key]) {
        _espnScoreboardWaiters[key].push({ mode: mode, onSuccess: onSuccess, onError: onError });
        return;
    }
    _espnScoreboardWaiters[key] = [{ mode: mode, onSuccess: onSuccess, onError: onError }];

    const sportValue = normalizedSport(options && (options.sports || options.sport)) || EspnSports.normalizedSport(espnSport);
    const leagueLabel = stringValue(options && options.leagueLabel);
    const merged = Object.assign({}, options, { espnSport: espnSport, espnLeague: league });
    const url = espnScoreboardUrl(espnSport, league, espnUnifiedDates(options));

    requestText(cacheBustedUrl(url), text => {
        let rows = [];
        try {
            rows = normalizeEspnScoreboard(JSON.parse(text), sportValue, leagueLabel, merged);
        } catch (error) {
            rows = [];
        }
        _espnScoreboardCache[key] = { ts: Date.now(), rows: rows };
        const waiters = _espnScoreboardWaiters[key] || [];
        delete _espnScoreboardWaiters[key];
        waiters.forEach(waiter => {
            // A daily-cadence league between seasons has no fixtures in the default
            // ~2-week look-ahead (e.g. NHL in July, first games in September). Widen
            // once to surface the season opener - offseason the wider pull is small.
            // Only for fixtures; live must stay on its narrow window.
            if (waiter.mode === "fixtures"
                && espnRowsForMode(filterEspnRowsForEntry(rows, options), "fixtures").length === 0) {
                const fx = espnFixturesFallbackWindow(sportValue);
                if (fx) {
                    fetchEspnScoreboardWindow(espnSport, league, fx.dates, "fixtures", options,
                        waiter.onSuccess, () => finish(waiter.onSuccess, []), fx.limit);
                    return;
                }
            }
            deliverEspnMode(espnSport, league, waiter.mode, options, rows, waiter.onSuccess);
        });
    }, error => {
        const waiters = _espnScoreboardWaiters[key] || [];
        delete _espnScoreboardWaiters[key];
        const message = error || "Unable to load ESPN scoreboard";
        waiters.forEach(waiter => finish(waiter.onError, message));
    }, { ignoreCooldown: true });
}

// Standings → the same row shape as normalizeSportScoreWidgetStandings.
//
// `names` is a PRIORITY list: we look for the first name across all stats, then the
// second, and so on - not "the first stat whose name is in the list". This matters
// because ESPN ships several overlapping fields whose order in the array is not the
// order we want: e.g. both "differential" (a per-game ratio like +0.3) and
// "pointDifferential" (the real run/point differential +33) are present, and the
// ratio appears first. Honouring caller priority lets us pick pointDifferential.
function espnStatEntry(stats, names) {
    const list = arrayValue(stats);
    for (let n = 0; n < names.length; n += 1) {
        for (let i = 0; i < list.length; i += 1) {
            const name = stringValue(list[i] && (list[i].name || list[i].abbreviation || list[i].type)).toLowerCase();
            if (name === names[n])
                return list[i];
        }
    }
    return null;
}

function espnStatValue(stats, names) {
    const entry = espnStatEntry(stats, names);
    if (!entry)
        return 0;
    if (entry.value !== undefined && entry.value !== null)
        return numberValue(entry.value);
    return numberValue(entry.displayValue);
}

// ESPN's own formatted string for a stat (".596", "+170", "8.5", "-"), or "" when
// absent. Used for values that read better verbatim than re-formatted from a number:
// win percentage (leading-dot, 3-decimal) and games-behind (blank/"-" for a leader).
function espnStatDisplay(stats, names) {
    const entry = espnStatEntry(stats, names);
    return entry ? stringValue(entry.displayValue) : "";
}

function normalizeEspnStandingsEntries(entries, group, groupIndex, league, rows) {
    arrayValue(entries).forEach(entry => {
        const team = entry && entry.team ? entry.team : {};
        const stats = (entry && entry.stats) || [];
        rows.push({
            position: espnStatValue(stats, ["rank", "playoffseed", "position"]),
            team: stringValue(team.displayName || team.name || team.shortDisplayName),
            group: group,
            groupIndex: groupIndex,
            played: espnStatValue(stats, ["gamesplayed", "games played", "gp"]),
            won: espnStatValue(stats, ["wins", "w"]),
            draw: espnStatValue(stats, ["ties", "draws", "t", "d"]),
            // NHL regulation/OT losses are separate from ties; ESPN exposes "otLosses".
            otLosses: espnStatValue(stats, ["otlosses", "otl"]),
            lost: espnStatValue(stats, ["losses", "l"]),
            goalsFor: espnStatValue(stats, ["pointsfor", "goalsfor", "pf"]),
            goalsAgainst: espnStatValue(stats, ["pointsagainst", "goalsagainst", "pa"]),
            // Prefer pointDifferential/goalDifferential (the real +33/+47/+170); the
            // bare "differential" is a per-game ratio (+0.3) and must not win.
            goalDifference: espnStatValue(stats, ["pointdifferential", "goaldifferential"]),
            points: espnStatValue(stats, ["points", "pts"]),
            // Win percentage / games-behind keep ESPN's own formatting (".596", "8.5",
            // "-"); a number would lose the leading dot and the leader's blank marker.
            winPercent: espnStatDisplay(stats, ["winpercent", "leaguewinpercent", "percentage", "pct"]),
            gamesBehind: espnStatDisplay(stats, ["gamesbehind", "gb"]),
            form: "",
            crest: espnLogoFromTeam(team),
            teamPath: "",
            teamSlug: ProviderCatalog.slugForValue(team.slug || team.abbreviation || team.id),
            league: league
        });
    });
}

// Collect the LEAF standings groups of an ESPN standings tree in document order.
// ESPN nests groups arbitrarily deep: a flat league (soccer) is one node with
// entries; conferences (NBA/NHL) are one level; divisions requested with level=3
// (MLB "AL East", NHL "Pacific", NFL "AFC North") are two - conference → division,
// where only the division carries entries. We want the innermost groups that
// actually hold teams, so a division-organized league shows each division as its
// own section rather than a single flat table.
function espnStandingsLeafGroups(node, out) {
    if (!node)
        return;
    const children = arrayValue(node.children);
    const entries = arrayValue(node.standings && node.standings.entries);
    // A node with child groups delegates to them (its own entries, if any, are the
    // roll-up we don't want); only a node with entries and no children is a leaf.
    if (children.length > 0) {
        children.forEach(child => espnStandingsLeafGroups(child, out));
        return;
    }
    if (entries.length > 0)
        out.push({ name: stringValue(node.name || node.abbreviation), entries: entries });
}

function normalizeEspnStandings(payload, leagueLabel) {
    const rows = [];
    const league = leagueLabel || "";
    const groups = [];
    espnStandingsLeafGroups(payload, groups);
    if (groups.length === 0) {
        // Flat payload with entries hung directly off the root (no children node).
        const entries = (payload && payload.standings && payload.standings.entries)
            || (payload && payload.entries) || [];
        groups.push({ name: "", entries: entries });
    }
    // Only label groups when there is more than one - a single-table league (e.g. a
    // soccer division) must stay header-less, not gain a stray section title.
    const labelled = groups.length > 1;
    groups.forEach((group, index) => {
        normalizeEspnStandingsEntries(group.entries, labelled ? group.name : "", index, league, rows);
    });

    return rows.filter(row => stringValue(row.team).length > 0)
        .sort((left, right) => numberValue(left.groupIndex) - numberValue(right.groupIndex)
            || numberValue(left.position) - numberValue(right.position)
            || stringValue(left.team).localeCompare(stringValue(right.team)));
}

// ESPN standings carry no recent form, so derive it (last results, oldest→newest)
// per team from the league's finished matches - the same data we already fetch for
// the recent/fixtures tabs.
function espnAppendForm(map, team, result) {
    const key = normalizedTeamName(team);
    if (key.length === 0)
        return;
    map[key] = (map[key] || "") + result;
}

function espnFormByTeam(matches) {
    const finished = arrayValue(matches).filter(isFinishedMatch).slice()
        .sort((left, right) => numberValue(left && left.timestamp) - numberValue(right && right.timestamp));
    const map = {};
    finished.forEach(match => {
        const homeText = stringValue(match && match.homeScore);
        const awayText = stringValue(match && match.awayScore);
        if (homeText.length === 0 || awayText.length === 0)
            return;
        const home = numberValue(homeText);
        const away = numberValue(awayText);
        espnAppendForm(map, match && match.homeTeam, home > away ? "W" : home < away ? "L" : "D");
        espnAppendForm(map, match && match.awayTeam, away > home ? "W" : away < home ? "L" : "D");
    });
    return map;
}

// Build the form map for a league. For the current season, reuse the warm
// scoreboard cache when present (no extra request) and otherwise fetch a ~10-week
// recent window. For a historical season, fetch that season's own calendar-year
// window so the form reflects how each team finished that season, not today's.
function fetchEspnLeagueFormMap(espnSport, league, options, onDone, season) {
    season = stringValue(season);
    const key = espnSport + "|" + league;
    const cached = _espnScoreboardCache[key];
    if (season.length === 0 && cached && (Date.now() - cached.ts) < ESPN_SCOREBOARD_TTL_MS) {
        finish(onDone, espnFormByTeam(cached.rows));
        return;
    }
    const now = Date.now();
    const day = 24 * 60 * 60 * 1000;
    // Historical season: span its whole calendar year. Current: the last 10 weeks.
    const dates = season.length === 4
        ? season + "0101-" + season + "1231"
        : espnDate(now - 70 * day) + "-" + espnDate(now);
    const limit = season.length === 4 ? ESPN_RECENT_FALLBACK_LIMIT : ESPN_MATCH_LIMIT;
    const sportValue = normalizedSport(options && (options.sports || options.sport)) || EspnSports.normalizedSport(espnSport);
    const merged = Object.assign({}, options, { espnSport: espnSport, espnLeague: league });
    requestText(cacheBustedUrl(espnScoreboardUrl(espnSport, league, dates, limit)), text => {
        let matches = [];
        try {
            matches = normalizeEspnScoreboard(JSON.parse(text), sportValue, "", merged);
        } catch (error) {
            matches = [];
        }
        finish(onDone, espnFormByTeam(matches));
    }, () => finish(onDone, {}), { ignoreCooldown: true });
}

// Extract a 4-digit ESPN season year from the selected season option. ESPN
// identifies a season by its starting year (the "2022" World Cup, the "2024"
// Premier League season etc.), so a "2024-2025" key resolves to 2024.
//
// The default season is pinned too (not left blank): our default is the CURRENT
// season (see normalizeEspnSeasons), and the season-less standings endpoint has
// already rolled forward to the not-yet-started NEXT season - so omitting ?season=
// would show next season's mirrored placeholder instead of the live table. Only a
// genuinely season-less entry (no key/id/label at all) omits the parameter.
function espnSeasonYear(options) {
    const candidates = [options && options.seasonId, options && options.seasonKey, options && options.seasonLabel];
    for (let i = 0; i < candidates.length; i += 1) {
        const match = /(\d{4})/.exec(stringValue(candidates[i]));
        if (match)
            return match[1];
    }
    return "";
}

function fetchEspnStandings(espnSport, league, options, onSuccess, onError) {
    if (stringValue(espnSport).length === 0 || stringValue(league).length === 0) {
        finish(onSuccess, []);
        return;
    }
    const season = espnSeasonYear(options);
    // level=3 asks ESPN for the deepest grouping it has - divisions for the US
    // leagues (MLB AL/NL East/Central/West, NHL/NFL divisions) instead of a single
    // flat conference table. Leagues with no divisions (soccer) simply return their
    // one group unchanged; normalizeEspnStandings flattens to the leaf groups.
    let url = ESPN_STANDINGS_BASE + "/" + encodeURIComponent(espnSport) + "/" + encodeURIComponent(league) + "/standings?level=3";
    if (season.length > 0)
        url += "&season=" + encodeURIComponent(season);
    requestText(cacheBustedUrl(url), text => {
        let rows = [];
        try {
            rows = normalizeEspnStandings(JSON.parse(text), stringValue(options && options.leagueLabel));
        } catch (error) {
            rows = [];
        }
        if (rows.length === 0) {
            finish(onSuccess, rows);
            return;
        }
        // Form badges reflect the standings' own season: the CURRENT (default)
        // season pulls from recent scoreboards (warm cache, last ~10 weeks), a
        // historical season from that season's own matches. The standings URL now
        // pins ?season= even for the default, so decide the form window by whether
        // this is the default pick rather than by whether `season` is set.
        const formSeason = (options && options.seasonIsDefault === true) ? "" : season;
        fetchEspnLeagueFormMap(espnSport, league, options, formMap => {
            rows.forEach(row => {
                const form = formMap[normalizedTeamName(row.team)];
                if (stringValue(form).length > 0)
                    row.form = stringValue(form).slice(-5);
            });
            finish(onSuccess, rows);
        }, formSeason);
    }, error => finish(onError, error || "Unable to load ESPN standings"), { ignoreCooldown: true });
}

// ESPN seasons for a league, as season-dropdown options. Reads the core API's
// seasons collection (each item is a $ref ending in the season's starting year),
// newest first.
//
// ESPN's seasons collection lists the UPCOMING season as soon as it is scheduled -
// e.g. in mid-2026 the MLB list already carries 2027, whose standings ESPN serves
// as a copy of the last finished season until the new one starts. Marking the
// newest listed year as the dropdown default (and letting the season-less standings
// request inherit ESPN's own rolled-forward default) is what surfaced a blank/next
// season with last season's rows mirrored into it. The league ROOT document
// (.../leagues/{league}) exposes ESPN's authoritative CURRENT season year, so fetch
// that first and default the dropdown to it.
function fetchEspnSeasons(espnSport, league, options, onSuccess, onError) {
    if (stringValue(espnSport).length === 0 || stringValue(league).length === 0) {
        finish(onSuccess, []);
        return;
    }
    const seasonsUrl = ESPN_CORE_BASE + "/" + encodeURIComponent(espnSport) + "/leagues/" + encodeURIComponent(league) + "/seasons?limit=100";
    fetchEspnCurrentSeasonYear(espnSport, league, currentYear => {
        requestText(cacheBustedUrl(seasonsUrl), text => {
            let rows = [];
            try {
                rows = normalizeEspnSeasons(JSON.parse(text), currentYear);
            } catch (error) {
                rows = [];
            }
            finish(onSuccess, rows);
        }, error => finish(onError, error || "Unable to load ESPN seasons"), { ignoreCooldown: true });
    });
}

// ESPN's authoritative current-season year for a league (the league root's
// season.year), or "" when it can't be read. Callers must tolerate "" and fall
// back to their own heuristic.
function fetchEspnCurrentSeasonYear(espnSport, league, onDone) {
    const url = ESPN_CORE_BASE + "/" + encodeURIComponent(espnSport) + "/leagues/" + encodeURIComponent(league);
    requestText(cacheBustedUrl(url), text => {
        let year = "";
        try {
            const payload = JSON.parse(text);
            year = stringValue(payload && payload.season && payload.season.year);
        } catch (error) {
            year = "";
        }
        finish(onDone, /^\d{4}$/.test(year) ? year : "");
    }, () => finish(onDone, ""), { ignoreCooldown: true });
}

// `currentYear` is ESPN's authoritative current-season year (or "" if unknown). The
// default season is that year when it appears in the list; otherwise the newest year
// that is not in the future; otherwise the newest listed year. This keeps the
// dropdown off a not-yet-started season whose data is only a mirror of the last one.
function normalizeEspnSeasons(payload, currentYear) {
    const items = arrayValue(payload && payload.items);
    const years = [];
    const seen = {};
    items.forEach(item => {
        // Prefer an explicit year field; otherwise pull it from the $ref tail
        // (.../seasons/2024 or .../seasons/2024?lang=en).
        let year = stringValue(item && item.year);
        if (year.length === 0) {
            const refMatch = /\/seasons\/(\d{4})/.exec(stringValue(item && item.$ref));
            year = refMatch ? refMatch[1] : "";
        }
        if (year.length !== 4 || seen[year])
            return;
        seen[year] = true;
        years.push({ year: year, name: stringValue(item && (item.displayName || item.name)) });
    });

    years.sort((left, right) => numberValue(right.year) - numberValue(left.year));

    const wantedCurrent = /^\d{4}$/.test(stringValue(currentYear)) ? stringValue(currentYear) : "";
    const thisCalendarYear = new Date().getFullYear();
    let defaultYear = "";
    if (wantedCurrent.length > 0 && years.some(entry => entry.year === wantedCurrent))
        defaultYear = wantedCurrent;
    else {
        const notFuture = years.find(entry => numberValue(entry.year) <= thisCalendarYear);
        defaultYear = notFuture ? notFuture.year : (years.length > 0 ? years[0].year : "");
    }

    return years.map(entry => ({
        key: entry.year,
        id: entry.year,
        path: entry.year,
        label: entry.name.length > 0 ? entry.name : entry.year,
        provider: "espn",
        yearScore: numberValue(entry.year) * 10000 + numberValue(entry.year),
        isDefault: entry.year === defaultYear
    }));
}

// Teams → the same option shape as fetchCompetitionTeams.
function fetchEspnTeams(espnSport, league, options, onSuccess, onError) {
    if (stringValue(espnSport).length === 0 || stringValue(league).length === 0) {
        finish(onSuccess, []);
        return;
    }
    const country = stringValue(options && options.country);
    const url = ESPN_SITE_BASE + "/" + encodeURIComponent(espnSport) + "/" + encodeURIComponent(league) + "/teams?limit=" + ESPN_MATCH_LIMIT;
    requestText(cacheBustedUrl(url), text => {
        let rows = [];
        try {
            const payload = JSON.parse(text);
            const groups = arrayValue(payload && payload.sports && payload.sports[0] && payload.sports[0].leagues);
            const list = groups.length > 0 ? arrayValue(groups[0].teams) : [];
            const seen = {};
            list.forEach(item => {
                const team = (item && item.team) || item || {};
                const label = stringValue(team.displayName || team.name || team.shortDisplayName);
                const slug = ProviderCatalog.slugForValue(team.slug || team.abbreviation || team.id);
                if (label.length === 0 || seen[slug || label.toLowerCase()])
                    return;
                seen[slug || label.toLowerCase()] = true;
                rows.push({
                    label: label,
                    value: label,
                    slug: slug,
                    teamSlug: slug,
                    teamPath: "",
                    badge: espnLogoFromTeam(team),
                    country: country
                });
            });
        } catch (error) {
            rows = [];
        }
        rows.sort((a, b) => stringValue(a.label).localeCompare(stringValue(b.label)));
        finish(onSuccess, rows);
    }, error => finish(onError, error || "Unable to load ESPN teams"), { ignoreCooldown: true });
}

// One ESPN athlete → a followable row in the SAME shape as fetchEspnTeams, so the
// wizard's team UI / follow flow works unchanged: a followed player is stored as a
// "team" entry whose favoriteTeam is the player's name, which the scoreboard path
// filters on (see filterEspnRowsForEntry). Returns null for an unnamed athlete.
function espnAthleteRow(athlete, options) {
    athlete = athlete || {};
    const label = stringValue(athlete.displayName || athlete.fullName
        || (stringValue(athlete.firstName) + " " + stringValue(athlete.lastName)).trim());
    if (label.length === 0)
        return null;
    const headshot = athlete.headshot && typeof athlete.headshot === "object"
        ? stringValue(athlete.headshot.href) : stringValue(athlete.headshot);
    return {
        label: label,
        value: label,
        slug: ProviderCatalog.slugForValue(athlete.id || label),
        teamSlug: ProviderCatalog.slugForValue(athlete.id || label),
        teamPath: "",
        // Prefer the headshot; fall back to the country flag so the row is never
        // iconless. The UI's "im-user" placeholder covers neither.
        badge: headshot.length > 0 ? headshot
            : (athlete.flag && typeof athlete.flag === "object" ? stringValue(athlete.flag.href) : ""),
        country: stringValue(athlete.citizenshipCountry && athlete.citizenshipCountry.name)
            || stringValue(athlete.flagAltText) || stringValue(options && options.country)
    };
}

// Players for golf / mma / racing: their athletes are the event's competitors (the
// tournament field, the fight card, the race grid), exposed inline on the
// scoreboard - no rankings feed. Collect competitors across every event and every
// competition within it (MMA fight cards and racing weekends split into several
// competitions), deduped by name. Returns the fetchEspnTeams row shape.
function fetchEspnEventPlayers(espnSport, league, options, onSuccess, onError) {
    if (stringValue(espnSport).length === 0 || stringValue(league).length === 0) {
        finish(onSuccess, []);
        return;
    }
    // Use a wide fixed window (not the user's narrow scoreboard window), so the
    // field/grid is found even between events: racing grids and golf fields only
    // populate during an event, so look back ~120 days and ahead ~60 to catch the
    // most recent or next one regardless of when the wizard is opened.
    const day = 24 * 60 * 60 * 1000;
    const now = Date.now();
    const dates = espnDate(now - 120 * day) + "-" + espnDate(now + 60 * day);
    const url = espnScoreboardUrl(espnSport, league, dates);
    requestText(cacheBustedUrl(url), text => {
        let rows = [];
        try {
            const payload = JSON.parse(text);
            const seen = {};
            arrayValue(payload && payload.events).forEach(event => {
                arrayValue(event && event.competitions).forEach(competition => {
                    arrayValue(competition && competition.competitors).forEach(competitor => {
                        const row = espnAthleteRow(competitor && competitor.athlete, options);
                        if (!row || seen[row.slug || row.label.toLowerCase()])
                            return;
                        seen[row.slug || row.label.toLowerCase()] = true;
                        rows.push(row);
                    });
                });
            });
        } catch (error) {
            rows = [];
        }
        rows.sort((a, b) => stringValue(a.label).localeCompare(stringValue(b.label)));
        finish(onSuccess, rows);
    }, error => finish(onError, error || "Unable to load ESPN players"), { ignoreCooldown: true });
}

// Tennis (and other player sports) have no roster, but ESPN's rankings feed lists
// the currently ranked athletes for a tour. Return them in the SAME row shape as
// fetchEspnTeams so the wizard's team UI / follow flow works unchanged - a followed
// player is stored as a "team" entry whose favoriteTeam is the player's name, which
// the scoreboard path filters on (see espnRowsForMode). Rows keep ranking order.
function fetchEspnTennisPlayers(espnSport, league, options, onSuccess, onError) {
    if (stringValue(espnSport).length === 0 || stringValue(league).length === 0) {
        finish(onSuccess, []);
        return;
    }
    const url = ESPN_SITE_BASE + "/" + encodeURIComponent(espnSport) + "/" + encodeURIComponent(league) + "/rankings";
    requestText(cacheBustedUrl(url), text => {
        let rows = [];
        try {
            const payload = JSON.parse(text);
            const ranks = arrayValue(payload && payload.rankings && payload.rankings[0] && payload.rankings[0].ranks);
            const seen = {};
            ranks.forEach(rank => {
                const row = espnAthleteRow(rank && rank.athlete, options);
                if (!row || seen[row.slug || row.label.toLowerCase()])
                    return;
                seen[row.slug || row.label.toLowerCase()] = true;
                rows.push(row);
            });
        } catch (error) {
            rows = [];
        }
        // Keep ranking order (rows already pushed #1..#N); no alpha sort here.
        finish(onSuccess, rows);
    }, error => finish(onError, error || "Unable to load ESPN tennis players"), { ignoreCooldown: true });
}

// Maps an ESPN play "type.type" to the same incident kind vocabulary
// sportScoreIncidentKind() produces, so callers (details panel, notifications)
// don't need to know which provider an incident came from.
function espnPlayKind(playType) {
    const value = stringValue(playType).toLowerCase();
    if (value === "substitution")
        return "substitution";
    if (value === "yellow-card")
        return "yellow";
    if (value === "red-card" || value === "yellow-red-card" || value === "second-yellow-card")
        return "red";
    // Real ESPN GOAL type names: "goal", "goal---header", "goal---volley",
    // "goal---free-kick", "own-goal", "penalty---scored". Match these precisely -
    // a substring test on "goal" wrongly catches "goal-kick" (a restart, NOT a
    // score), which produced phantom goals in the Details tab. A missed/saved
    // penalty ("penalty---saved") is not a scoring play and is excluded.
    if (value === "goal" || value === "own-goal" || value.indexOf("goal---") === 0 || value === "penalty---scored")
        return "goal";
    // Match-period transition markers (no player attached), verified against a
    // real match that went to extra time and penalties: "start-extra-time" (90'
    // played, level), "start-2nd-half-extra-time" (105'), "start-shootout"
    // (120', still level). Distinct from kickoff/halftime, which the lightweight
    // scoreboard "minute" field already covers without needing this feed.
    if (value === "start-extra-time")
        return "extratime";
    if (value === "start-2nd-half-extra-time")
        return "extratimesecondhalf";
    if (value === "start-shootout")
        return "shootout";
    return "";
}

// Which side (home/away) an ESPN play belongs to, inferred from the team name
// mentioned in its text (e.g. "Gabriel Jesus (Arsenal)...") rather than
// dereferencing the play's team $ref - saves a request per incident.
function espnPlaySide(play, homeTeam, awayTeam) {
    const text = stringValue(play && (play.text || play.shortText));
    const parenMatch = /\(([^)]+)\)/.exec(text);
    const mentioned = parenMatch ? parenMatch[1] : "";
    if (sameTeamName(mentioned, homeTeam))
        return "home";
    if (sameTeamName(mentioned, awayTeam))
        return "away";
    // "Substitution, <Team>. <In> replaces <Out>." / "Own Goal by <Player>, <Team>."
    const teamAfterCommaMatch = /^(?:Substitution|Own Goal by [^,]+),\s*([^.]+)\./.exec(text);
    if (teamAfterCommaMatch) {
        if (sameTeamName(teamAfterCommaMatch[1], homeTeam))
            return "home";
        if (sameTeamName(teamAfterCommaMatch[1], awayTeam))
            return "away";
    }
    return "";
}

// shortText is consistently "<Player Name> <Label>", e.g. "Gabriel Jesus Goal",
// "Jean-Philippe Mateta Goal - Head" (label can be truncated - shortText has a
// fixed length), "Malo Gusto Own Goal", "Wesley Fofana Red Card",
// "Gabriel Magalhães Substituti". Strip the known label prefix to get the name.
// Substitutions need the long "text" field instead, to get both players:
// "Substitution, Arsenal. Gabriel Magalhães replaces Riccardo Calafiori."
// Some subs add a trailing reason ESPN doesn't separate out, e.g. "...replaces
// Adam Wharton because of an injury." - stop at that clause too, not just "."
function espnPlayPlayer(play, kind) {
    if (kind === "substitution") {
        const text = stringValue(play && play.text);
        const subMatch = /^Substitution,\s*[^.]+\.\s*(.+?)\s+replaces\s+(.+?)(?:\s+because of[^.]*)?\.?$/.exec(text);
        if (subMatch)
            return subMatch[1].trim() + " -> " + subMatch[2].trim();
        return espnStripShortTextLabel(play, /^(Substitut)/i);
    }

    if (kind === "goal") {
        // Cover "Goal", "Goal - Header"/"Goal - Volley"/"Goal - Free-k" (and
        // their truncated forms), "Own Goal", and "Penalty - Scored".
        return espnStripShortTextLabel(play, /^(Goal|Own Goal|Penalty)/i);
    }

    // Match-period transition markers have no player (and shortText is null);
    // there is nothing to extract.
    if (kind === "extratime" || kind === "extratimesecondhalf" || kind === "shootout")
        return "";

    return espnStripShortTextLabel(play, /^(Yellow Card|Red Card)/i);
}

// Removes the trailing "<label...>" suffix from shortText by finding where the
// known label prefix starts and keeping everything before it. shortText can be
// truncated mid-label (fixed max length), so this matches a prefix rather than
// the whole label.
function espnStripShortTextLabel(play, labelPrefixPattern) {
    const shortText = stringValue(play && play.shortText).trim();
    const words = shortText.split(/\s+/);
    // Try the longest possible label suffix first (e.g. "Own Goal" before
    // "Goal") so a multi-word label isn't cut short.
    for (let i = 1; i < words.length; i += 1) {
        const candidate = words.slice(i).join(" ");
        if (labelPrefixPattern.test(candidate))
            return words.slice(0, i).join(" ").trim();
    }
    return shortText;
}

// Player text for a keyEvent of a given kind. Subs read "<in> -> <out>" from the two
// participants; everything else is the first participant's name. Falls back to the
// shortText label-strip (the plays-feed heuristic) when participants are absent.
function espnKeyEventPlayer(event, kind) {
    const participants = arrayValue(event && event.participants)
        .map(participant => stringValue(participant && participant.athlete && participant.athlete.displayName))
        .filter(name => name.length > 0);
    if (kind === "substitution") {
        if (participants.length >= 2)
            return participants[0] + " -> " + participants[1];
        if (participants.length === 1)
            return participants[0];
    }
    if (participants.length >= 1)
        return participants[0];
    // No structured participants: reuse the shortText heuristic.
    if (kind === "goal")
        return espnStripShortTextLabel(event, /^(Goal|Own Goal|Penalty)/i);
    if (kind === "substitution")
        return espnStripShortTextLabel(event, /^(Substitut)/i);
    return espnStripShortTextLabel(event, /^(Yellow Card|Red Card)/i);
}

// ESPN summary "keyEvents" -> incident rows in the same shape as
// fetchEspnMatchIncidents ({ side, kind, minute, label, player, sideLabel }). Unlike
// the plays feed, keyEvents carries a structured team {id, displayName} and
// participant athletes, so the side and players are read directly instead of parsed
// out of the text. Filtered to the incident kinds the Details tab renders (goals,
// cards, subs, period markers); other entries (delays, kickoff) are dropped.
function espnKeyEventsRows(keyEvents, homeTeamId, awayTeamId, homeTeam, awayTeam) {
    return arrayValue(keyEvents).map(event => {
        const kind = espnPlayKind(event && event.type && event.type.type);
        if (kind.length === 0)
            return null;
        const teamId = stringValue(event && event.team && event.team.id);
        const teamName = stringValue(event && event.team && event.team.displayName);
        let side = "";
        if (teamId.length > 0 && teamId === stringValue(homeTeamId))
            side = "home";
        else if (teamId.length > 0 && teamId === stringValue(awayTeamId))
            side = "away";
        else if (sameTeamName(teamName, homeTeam))
            side = "home";
        else if (sameTeamName(teamName, awayTeam))
            side = "away";
        const player = espnKeyEventPlayer(event, kind);
        const minute = stringValue(event && event.clock && event.clock.displayValue).replace(/'$/, "");
        return {
            side,
            kind,
            minute,
            label: kind === "substitution" ? player : kind,
            player,
            sideLabel: side === "home" ? "HOME" : side === "away" ? "AWAY" : ""
        };
    }).filter(row => row && (row.player.length > 0 || row.kind.length > 0));
}

// Parse one ESPN boxscore stat value (a displayValue string) to a number for the
// comparison bar. Plain ("15"), ratio ("0.8"), percent ("57"), and compound
// ("47-82", "24/35", "22:35") forms all appear; for compound values we use the
// FIRST number (made, completions, minutes) as the magnitude to compare.
function espnStatNumber(displayValue) {
    const text = stringValue(displayValue);
    const match = text.match(/-?\d+(?:\.\d+)?/);
    return match ? Number(match[0]) : 0;
}

// home/away ratios for one stat's comparison bar. A percentage/share stat uses its
// own value (0..1 read as a ratio, >1 as already-percent); everything else uses each
// side's portion of the pair total.
function espnStatRatios(name, homeNum, awayNum) {
    if (EspnSports.isPercentStat(name)) {
        const toRatio = value => value > 1 ? value / 100 : value;
        return { home: Math.max(0, Math.min(1, toRatio(homeNum))), away: Math.max(0, Math.min(1, toRatio(awayNum))) };
    }
    const total = homeNum + awayNum;
    return { home: total > 0 ? homeNum / total : 0, away: total > 0 ? awayNum / total : 0 };
}

// ESPN boxscore team stats -> statsRows in the SAME shape the UI renders for
// SportScore (see sportScoreWidgetStatsRows): { kind, label, homeValue, awayValue,
// homeRaw, awayRaw, homeRatio, awayRatio }. `home`/`away` are the two boxscore.teams
// entries (already oriented to the match's home/away side). Curated + ordered per
// sport (EspnSports.statOrder); unlisted sports show every stat in feed order.
function espnSummaryStatsRows(home, away, sportValue) {
    function statMap(team) {
        const map = {};
        arrayValue(team && team.statistics).forEach(stat => {
            const name = stringValue(stat && stat.name);
            if (name.length > 0)
                map[name] = stat;
        });
        return map;
    }
    const homeStats = statMap(home);
    const awayStats = statMap(away);

    const order = EspnSports.statOrder(sportValue);
    let names = order.slice();
    if (names.length === 0) {
        // No curation for this sport: show every stat the home side reports, in order.
        names = arrayValue(home && home.statistics).map(stat => stringValue(stat && stat.name)).filter(name => name.length > 0);
    }

    return names.map(name => {
        const homeStat = homeStats[name];
        const awayStat = awayStats[name];
        if (!homeStat && !awayStat)
            return null;
        const label = stringValue((homeStat && homeStat.label) || (awayStat && awayStat.label) || name);
        const homeDisplay = stringValue(homeStat && homeStat.displayValue);
        const awayDisplay = stringValue(awayStat && awayStat.displayValue);
        const homeNum = espnStatNumber(homeDisplay);
        const awayNum = espnStatNumber(awayDisplay);
        const ratios = espnStatRatios(name, homeNum, awayNum);
        return {
            kind: sportScoreStatKind(label),
            label,
            homeValue: espnStatDisplay(name, homeDisplay, homeNum),
            awayValue: espnStatDisplay(name, awayDisplay, awayNum),
            homeRaw: homeNum,
            awayRaw: awayNum,
            homeRatio: ratios.home,
            awayRatio: ratios.away
        };
    }).filter(row => row !== null);
}

// Panel display text for one stat value. Percentage stats are shown as whole
// percents: ESPN reports some as a 0..1 ratio (passPct 0.8 -> "80%") and some as an
// already-scaled percent (fieldGoalPct 57 -> "57%"); both end up as "N%". Non-
// percentage values pass through as ESPN formatted them (e.g. "47-82", "22:35").
function espnStatDisplay(name, displayValue, num) {
    const text = stringValue(displayValue);
    if (EspnSports.isPercentStat(name)) {
        if (/%/.test(text))
            return text;
        const percent = num > 1 ? num : num * 100;
        return Math.round(percent) + "%";
    }
    return text.length > 0 ? text : "0";
}

// Half-time score from the header competitors' per-period linescores (first period
// each). Returns "" when the match hasn't reached half-time / has no linescores.
function espnSummaryHalfTimeScore(home, away) {
    const homeFirst = arrayValue(home && home.linescores)[0];
    const awayFirst = arrayValue(away && away.linescores)[0];
    if (!homeFirst || !awayFirst)
        return "";
    const h = stringValue(homeFirst.displayValue || homeFirst.value);
    const a = stringValue(awayFirst.displayValue || awayFirst.value);
    return h.length > 0 && a.length > 0 ? h + " - " + a : "";
}

// Venue / attendance / referee from the summary's gameInfo, plus recent form and
// head-to-head from `extras` -> matchInfoRows in the shape the Information tab
// renders ({ label, value }). startTime is appended so the kick-off line is
// consistent with the rest of the app. `extras` = { homeForm, awayForm, headToHead }.
function espnSummaryInfoRows(gameInfo, halfTime, extras, options) {
    let rows = [];
    function append(label, value) {
        value = stringValue(value);
        if (value.length > 0)
            rows.push({ label, value });
    }
    const startTime = stringValue(options && options.startTime);
    append("Kick-off", startTime);
    append("Half-time", halfTime);
    const venue = (gameInfo && gameInfo.venue) || {};
    const address = venue.address || {};
    const venueName = stringValue(venue.fullName);
    const city = stringValue(address.city);
    append("Venue", venueName.length > 0 && city.length > 0 ? venueName + ", " + city : venueName || city);
    const attendance = numberValue(gameInfo && gameInfo.attendance);
    if (attendance > 0)
        append("Attendance", attendance.toLocaleString());
    const referee = arrayValue(gameInfo && gameInfo.officials)
        .map(official => stringValue(official && official.displayName)).filter(name => name.length > 0)[0];
    append("Referee", referee);
    // Recent form (W/D/L over the last five) for each side, and the head-to-head
    // record between them - low-priority context, so listed after the match facts.
    const safe = extras || {};
    const homeName = stringValue(options && options.homeTeam);
    const awayName = stringValue(options && options.awayTeam);
    append((homeName.length > 0 ? homeName : "Home") + " form", safe.homeForm);
    append((awayName.length > 0 ? awayName : "Away") + " form", safe.awayForm);
    append("Head-to-head", safe.headToHead);
    return rows;
}

// Which boxscore.teams entry is the match's home/away side. ESPN tags each with a
// homeAway via the header competitors; fall back to array order (teams[0]=home).
function espnSummarySides(payload) {
    const teams = arrayValue(payload && payload.boxscore && payload.boxscore.teams);
    const competitors = arrayValue(payload && payload.header && payload.header.competitions
        && payload.header.competitions[0] && payload.header.competitions[0].competitors);
    function sideFor(team) {
        const id = stringValue(team && team.team && team.team.id);
        const match = competitors.find(c => stringValue(c && c.team && c.team.id) === id || stringValue(c && c.id) === id);
        return stringValue(match && match.homeAway);
    }
    let home = teams.find(team => sideFor(team) === "home") || teams[0] || null;
    let away = teams.find(team => sideFor(team) === "away") || (teams[1] === home ? teams[0] : teams[1]) || null;
    // Carry the header competitor (for linescores) alongside each boxscore team.
    function competitorFor(team) {
        const id = stringValue(team && team.team && team.team.id);
        return competitors.find(c => stringValue(c && c.team && c.team.id) === id) || null;
    }
    return { home, away, homeCompetitor: competitorFor(home), awayCompetitor: competitorFor(away) };
}

// One ESPN roster player -> the player shape the lineup UI renders (matches
// sportScoreWidgetPlayers): { name, number, position, captain, rating }.
function espnLineupPlayer(player) {
    const athlete = (player && player.athlete) || {};
    const position = (player && player.position) || {};
    return {
        name: stringValue(athlete.displayName || athlete.fullName),
        number: stringValue(player && player.jersey),
        position: stringValue(position.displayName || position.abbreviation),
        captain: player && player.captain === true,
        rating: ""
    };
}

// ESPN summary rosters -> the lineups object the Information tab already renders
// (same shape as sportScoreWidgetLineups): starting XI + substitutes per side, plus
// each side's formation. A "starter" is the XI; everyone else is a substitute.
// Returns null when rosters are absent (e.g. lineups not yet published, or a sport
// ESPN gives no roster for) so the caller leaves lineups untouched.
function espnSummaryLineups(rosters) {
    const list = arrayValue(rosters);
    if (list.length === 0)
        return null;
    const homeRoster = list.find(r => stringValue(r && r.homeAway) === "home") || list[0];
    const awayRoster = list.find(r => stringValue(r && r.homeAway) === "away")
        || (list[1] === homeRoster ? list[0] : list[1]) || {};

    function players(roster, wantStarters) {
        return arrayValue(roster && roster.roster)
            .filter(player => (player && player.starter === true) === wantStarters)
            .map(espnLineupPlayer)
            .filter(player => player.name.length > 0);
    }

    const lineups = {
        confirmed: true,
        homeFormation: stringValue(homeRoster && homeRoster.formation),
        awayFormation: stringValue(awayRoster && awayRoster.formation),
        homeCoach: "",
        awayCoach: "",
        homeStarting: players(homeRoster, true),
        awayStarting: players(awayRoster, true),
        homeSubstitutes: players(homeRoster, false),
        awaySubstitutes: players(awayRoster, false)
    };
    // No actual players parsed (e.g. roster stubs without athletes): treat as absent.
    if (lineups.homeStarting.length === 0 && lineups.awayStarting.length === 0
        && lineups.homeSubstitutes.length === 0 && lineups.awaySubstitutes.length === 0)
        return null;
    return lineups;
}

// ESPN summary "leaders" -> per-category top-performer rows pairing each side's best
// player: [{ category, homeName, homeValue, awayName, awayValue }]. ESPN lists the
// same categories for each team (Points/Assists/Rebounds, Total Shots/Saves…); we
// align them by category name so each row compares the two teams' leaders. Returns
// [] when leaders are absent. `homeId`/`awayId` are the team ids from espnSummarySides.
function espnSummaryLeaders(leaders, homeId, awayId) {
    const list = arrayValue(leaders);
    if (list.length === 0)
        return [];
    function teamLeaders(teamId, fallbackIndex) {
        const byId = list.find(entry => stringValue(entry && entry.team && entry.team.id) === stringValue(teamId));
        return (byId || list[fallbackIndex] || {}).leaders || [];
    }
    const homeCats = arrayValue(teamLeaders(homeId, 0));
    const awayCats = arrayValue(teamLeaders(awayId, 1));

    function topOf(categories, name) {
        const category = arrayValue(categories).find(cat => stringValue(cat && cat.name) === name);
        const top = arrayValue(category && category.leaders)[0];
        if (!top)
            return { name: "", value: "" };
        const athlete = (top.athlete) || {};
        return { name: stringValue(athlete.displayName || athlete.shortName), value: stringValue(top.displayValue) };
    }

    let rows = [];
    homeCats.forEach(category => {
        const name = stringValue(category && category.name);
        const label = stringValue(category && category.displayName) || name;
        if (name.length === 0)
            return;
        const home = topOf(homeCats, name);
        const away = topOf(awayCats, name);
        if (home.name.length === 0 && away.name.length === 0)
            return;
        rows.push({ category: label, homeName: home.name, homeValue: home.value, awayName: away.name, awayValue: away.value });
    });
    return rows;
}

// Recent-form string ("W W D L L", oldest->newest) for one team from its
// lastFiveGames events. ESPN already orders these oldest-first.
function espnFormString(teamForm) {
    return arrayValue(teamForm && teamForm.events)
        .map(event => stringValue(event && event.gameResult).toUpperCase())
        .filter(result => result === "W" || result === "D" || result === "L")
        .join(" ");
}

// Last-5 form per side as { homeForm, awayForm } W/D/L strings, or {} when absent.
// Aligns each lastFiveGames entry to the match's home/away team by id.
function espnSummaryForm(lastFiveGames, homeId, awayId) {
    const list = arrayValue(lastFiveGames);
    if (list.length === 0)
        return {};
    const byId = id => list.find(entry => stringValue(entry && entry.team && entry.team.id) === stringValue(id));
    const home = byId(homeId) || list[0];
    const away = byId(awayId) || (list[1] === home ? list[0] : list[1]);
    return { homeForm: espnFormString(home), awayForm: espnFormString(away) };
}

// Head-to-head record as a "1W 0D 1L" string from the HOME team's perspective, plus
// the count, or "" when there are no prior meetings. headToHeadGames is given from
// one team's perspective (its gameResult), which we orient to the home team.
function espnSummaryHeadToHead(headToHeadGames, homeId) {
    const list = arrayValue(headToHeadGames);
    if (list.length === 0)
        return "";
    const perspective = list.find(entry => stringValue(entry && entry.team && entry.team.id)) || list[0];
    const events = arrayValue(perspective && perspective.events);
    if (events.length === 0)
        return "";
    // gameResult is from `perspective.team`; flip if that isn't the home side.
    const perspectiveIsHome = stringValue(perspective && perspective.team && perspective.team.id) === stringValue(homeId);
    let win = 0, draw = 0, loss = 0;
    events.forEach(event => {
        const result = stringValue(event && event.gameResult).toUpperCase();
        if (result === "D") { draw += 1; return; }
        const homeWin = perspectiveIsHome ? result === "W" : result === "L";
        if (homeWin) win += 1; else loss += 1;
    });
    return win + "W " + draw + "D " + loss + "L";
}

// One curated box-score section for one team: maps the configured column labels to
// each athlete's matching stats. `teamPlayers` is a boxscore.players[] entry (one
// team); `section` is a config from EspnSports.playerBoxSections. Returns null when
// the configured group/columns aren't present so empty sections don't render.
function espnPlayerBoxSection(teamPlayers, section) {
    const groups = arrayValue(teamPlayers && teamPlayers.statistics);
    // "" matches the single/unnamed group; otherwise match by group name.
    const wantGroup = stringValue(section && section.group);
    const group = wantGroup.length === 0
        ? (groups[0] || null)
        : groups.find(g => stringValue(g && g.name).toLowerCase() === wantGroup.toLowerCase());
    if (!group)
        return null;
    const labels = arrayValue(group.labels).map(stringValue);
    // Column label -> its index in each athlete's stats array.
    const colIndex = arrayValue(section && section.columns)
        .map(label => ({ label, index: labels.indexOf(label) }))
        .filter(col => col.index >= 0);
    if (colIndex.length === 0)
        return null;

    const rows = arrayValue(group.athletes)
        .filter(entry => entry && entry.didNotPlay !== true)
        .map(entry => {
            const athlete = (entry.athlete) || {};
            const stats = arrayValue(entry.stats);
            return {
                name: stringValue(athlete.shortName || athlete.displayName),
                number: stringValue(athlete.jersey),
                starter: entry.starter === true,
                values: colIndex.map(col => stringValue(stats[col.index]))
            };
        })
        .filter(row => row.name.length > 0);
    if (rows.length === 0)
        return null;
    return { title: stringValue(section && section.title), columns: colIndex.map(col => col.label), rows };
}

// Per-player box score for both sides -> { home: [section], away: [section] } where
// each section is { title, columns:[label], rows:[{ name, number, starter, values }]}.
// Curated per sport (EspnSports.playerBoxSections); returns null when the sport has
// no box score or none of the configured sections produced rows.
function espnSummaryPlayerBox(playersByTeam, sportValue, homeId, awayId) {
    const sections = EspnSports.playerBoxSections(sportValue);
    if (sections.length === 0)
        return null;
    const teams = arrayValue(playersByTeam);
    if (teams.length === 0)
        return null;
    const byId = id => teams.find(team => stringValue(team && team.team && team.team.id) === stringValue(id));
    const homeTeam = byId(homeId) || teams[0];
    const awayTeam = byId(awayId) || (teams[1] === homeTeam ? teams[0] : teams[1]);

    function build(teamPlayers) {
        return sections.map(section => espnPlayerBoxSection(teamPlayers, section)).filter(s => s !== null);
    }
    const home = build(homeTeam);
    const away = build(awayTeam);
    if (home.length === 0 && away.length === 0)
        return null;
    return { home, away };
}

// Fetches ESPN's rich match summary (boxscore team stats, gameInfo, linescores) and
// builds the statsRows / matchInfoRows / halfTimeScore the details panel renders -
// the same fields the SportScore path fills. Best-effort: any failure yields an
// empty result so the caller can fall back to the incidents-only details.
function fetchEspnMatchSummary(espnSport, espnLeague, eventId, sportValue, options, onSuccess, onError) {
    if (stringValue(espnSport).length === 0 || stringValue(espnLeague).length === 0 || stringValue(eventId).length === 0) {
        finish(onSuccess, null);
        return;
    }
    const url = ESPN_SITE_BASE + "/" + encodeURIComponent(espnSport) + "/" + encodeURIComponent(espnLeague)
        + "/summary?event=" + encodeURIComponent(eventId);
    requestText(cacheBustedUrl(url), text => {
        let result = null;
        try {
            const payload = JSON.parse(text);
            const sides = espnSummarySides(payload);
            const home = Object.assign({}, sides.home, { linescores: sides.homeCompetitor && sides.homeCompetitor.linescores });
            const away = Object.assign({}, sides.away, { linescores: sides.awayCompetitor && sides.awayCompetitor.linescores });
            // Only football has a meaningful "half-time" - elsewhere the first
            // linescore is a quarter/period, so labelling it half-time would mislead.
            const halfTime = normalizedSport(sportValue) === "football" ? espnSummaryHalfTimeScore(home, away) : "";
            const homeId = sides.home && sides.home.team && sides.home.team.id;
            const awayId = sides.away && sides.away.team && sides.away.team.id;
            const form = espnSummaryForm(payload && payload.lastFiveGames, homeId, awayId);
            const extras = {
                homeForm: form.homeForm,
                awayForm: form.awayForm,
                headToHead: espnSummaryHeadToHead(payload && payload.headToHeadGames, homeId)
            };
            const homeName = stringValue(options && options.homeTeam);
            const awayName = stringValue(options && options.awayTeam);
            result = {
                statsRows: espnSummaryStatsRows(home, away, sportValue),
                matchInfoRows: espnSummaryInfoRows(payload && payload.gameInfo, halfTime, extras, options),
                halfTimeScore: halfTime,
                lineups: espnSummaryLineups(payload && payload.rosters),
                leaderRows: espnSummaryLeaders(payload && payload.leaders, homeId, awayId),
                playerBox: espnSummaryPlayerBox(payload && payload.boxscore && payload.boxscore.players, sportValue, homeId, awayId),
                eventRows: espnKeyEventsRows(payload && payload.keyEvents, homeId, awayId, homeName, awayName)
            };
        } catch (error) {
            result = null;
        }
        finish(onSuccess, result);
    }, error => finish(onError, error || "Unable to load ESPN match summary"), { ignoreCooldown: true });
}

// Fetches the play-by-play feed for one ESPN event and filters/normalizes it to
// goal/card/substitution incidents in the same row shape as
// sportScoreWidgetIncidents(): { side, kind, minute, label, player, sideLabel }.
// Best-effort: this is an undocumented ESPN endpoint, so failures or an empty
// result just mean "no incidents available" rather than an error worth
// surfacing - callers should treat onSuccess([]) and onError the same way.
function fetchEspnMatchIncidents(espnSport, espnLeague, eventId, homeTeam, awayTeam, onSuccess, onError) {
    if (stringValue(espnSport).length === 0 || stringValue(espnLeague).length === 0 || stringValue(eventId).length === 0) {
        finish(onSuccess, []);
        return;
    }

    const url = ESPN_CORE_BASE + "/" + encodeURIComponent(espnSport) + "/leagues/" + encodeURIComponent(espnLeague)
        + "/events/" + encodeURIComponent(eventId) + "/competitions/" + encodeURIComponent(eventId)
        + "/plays?limit=" + ESPN_PLAYS_LIMIT;

    requestText(cacheBustedUrl(url), text => {
        let rows = [];
        try {
            const payload = JSON.parse(text);
            const items = arrayValue(payload && payload.items);
            rows = items
                .map(play => {
                    const kind = espnPlayKind(play && play.type && play.type.type);
                    if (kind.length === 0)
                        return null;
                    const side = espnPlaySide(play, homeTeam, awayTeam);
                    const player = espnPlayPlayer(play, kind);
                    const minute = stringValue(play && play.clock && play.clock.displayValue).replace(/'$/, "");
                    return {
                        side,
                        kind,
                        minute,
                        label: kind === "substitution" ? player : kind,
                        player,
                        sideLabel: side === "home" ? "HOME" : side === "away" ? "AWAY" : ""
                    };
                })
                .filter(row => row && (row.player.length > 0 || row.kind.length > 0));
        } catch (error) {
            rows = [];
        }
        finish(onSuccess, rows);
    }, error => finish(onError, error || "Unable to load ESPN match incidents"), { ignoreCooldown: true });
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
        requestPage(url, html => {
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

    // Bounded sweep: recovering one team's id-bearing path must not fan out
    // into the full 64-competition country scan (each page is a UI-thread
    // parse). The top competitions cover the overwhelmingly common case; a team
    // deeper in the pyramid simply resolves empty and its caller degrades the
    // same way it does for a team SportScore doesn't list at all.
    fetchSportScoreCountryTeams(sport, country, rows => {
        const match = (Array.isArray(rows) ? rows : []).find(row => {
            const rowSlug = ProviderCatalog.slugForValue(row && row.teamSlug);
            return (teamSlug.length > 0 && rowSlug === teamSlug) || sameTeamName(row && (row.value || row.label), team);
        });
        finish(onSuccess, sportScorePathFromUrl(match && match.teamPath));
    }, onError, 16);
}

function isCanonicalSportScoreTeamPath(path, sport) {
    const normalized = sportScorePathFromUrl(path);
    if (!SportScoreSports.isParticipantPath(normalized, sport))
        return false;

    // A usable team URL carries the SportScore id segment after the slug:
    //   /football/team/<slug>/<id>/   (loads)   vs   /football/team/<slug>/  (404).
    // Without the id the page 404s, so treat an id-less path as NOT canonical so
    // the caller resolves the real path via the country team list instead.
    const tail = normalized.replace(/^\/+/, "").replace(/\/+$/, "").split("/");
    // [sport, "team", slug, id]
    return tail.length >= 4 && tail[tail.length - 1].length > 0;
}

// Team matches (live/fixtures/recent) try the JSON team widget (/api/widget/team/)
// first - one small edge-cached request per team - and fall back to scraping the
// team's HTML page (plus its competition pages) when the widget returns nothing
// (e.g. a team it doesn't index). The widget keeps the common case fast/light; the
// HTML fallback restores coverage for teams missing from the widget feed.
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

    if (mode === "recent") {
        const recentCap = numberValue(options && options.recentResultsPerTeam) || 200;
        fetchSportScoreTeamWidgetMatches(widgetOptionsForRecent(options), rows => {
            if (rows.length === 0) {
                fetchSportScoreTeamMatchesFromPages(options, mode, onSuccess, onError);
                return;
            }

            finish(onSuccess, sortRecentMatches(dedupeMatches(filterSportScoreMatchesForMode(rows, "recent"))).slice(0, recentCap));
        }, () => fetchSportScoreTeamMatchesFromPages(options, mode, onSuccess, onError));
        return;
    }

    // The widget reliably reports a team's in-progress match (verified even for
    // teams far down the league pyramid), so rows without a live one mean the
    // team simply isn't playing right now. Falling back to the page scrape in
    // that case - as this used to - re-scraped the team page plus up to 10
    // competition pages on every 60 s live poll for as long as the team was NOT
    // playing, which froze plasmashell for seconds at a time. Only a team the
    // widget doesn't index at all (zero rows) warrants the page fallback.
    fetchSportScoreTeamWidgetMatches(options, rows => {
        if (rows.length === 0) {
            fetchSportScoreTeamMatchesFromPages(options, mode, onSuccess, onError);
            return;
        }

        finish(onSuccess, sortMatches(dedupeMatches(filterSportScoreMatchesForMode(rows, "live"))));
    }, () => fetchSportScoreTeamMatchesFromPages(options, mode, onSuccess, onError));
}

// The team widget caps at 30 matches; ask for the max so recent results reach as
// far back into the season as the endpoint allows in its single cached call.
function widgetOptionsForRecent(options) {
    return Object.assign({}, options, { limit: 30 });
}

function fetchSportScoreTeamMatchesFromPages(options, mode, onSuccess, onError) {
    const cacheKey = sportScoreTeamRowsKey(options, mode);
    const cachedRows = cachedSportScorePageRows(cacheKey, mode);
    if (cachedRows) {
        finish(onSuccess, cachedRows);
        return;
    }

    fetchSportScoreTeamPage(options, page => {
        const teamName = stringValue(options && options.favoriteTeam) || stringValue(sportScoreTeamProfile(page.html, options).label);
        const teamRows = filterSportScoreMatchesForMode(
            normalizeSportScoreMatchPage(page.html, "", options).filter(match => matchBelongsToTeam(match, teamName)),
            mode
        );

        // A team's in-progress match is always on its own page - the (up to 10)
        // competition-page harvest below exists to reach a full season of
        // fixtures/results, which live mode never needs. Skipping it keeps the
        // worst-case live-poll scrape at one page instead of eleven.
        if (mode === "live") {
            finish(onSuccess, rememberSportScorePageRows(cacheKey, sortMatches(dedupeMatches(teamRows))));
            return;
        }

        const competitions = sportScoreTeamCompetitions(page.html, options)
            .filter(row => stringValue(row && row.path).length > 0)
            .slice(0, 10);

        // The team's own SportScore page lists only a few of its newest matches.
        // For "recent" that's far short of a full season, so (like fixtures/live)
        // also harvest the team's matches out of each of its competition pages -
        // those carry the whole season's fixtures, finished ones included.
        if (mode === "recent") {
            const recentCap = numberValue(options && options.recentResultsPerTeam) || 200;
            if (competitions.length === 0) {
                finish(onSuccess, rememberSportScorePageRows(cacheKey, sortRecentMatches(dedupeMatches(teamRows)).slice(0, recentCap)));
                return;
            }

            fetchSportScoreCompetitionPagesByRows(competitions, pages => {
                let rows = teamRows.slice();
                pages.forEach(competitionPage => {
                    const label = stringValue(competitionPage && competitionPage.label);
                    rows = rows.concat(normalizeSportScoreMatchPage(competitionPage.html, label, options)
                        .filter(match => matchBelongsToTeam(match, teamName)));
                });
                rows = filterSportScoreMatchesForMode(rows, "recent");
                finish(onSuccess, rememberSportScorePageRows(cacheKey, sortRecentMatches(dedupeMatches(rows)).slice(0, recentCap)));
            });
            return;
        }

        if (competitions.length === 0) {
            finish(onSuccess, rememberSportScorePageRows(cacheKey, sortMatches(dedupeMatches(teamRows))));
            return;
        }

        fetchSportScoreCompetitionPagesByRows(competitions, pages => {
            let rows = teamRows.slice();
            pages.forEach(competitionPage => {
                const label = stringValue(competitionPage && competitionPage.label);
                rows = rows.concat(normalizeSportScoreMatchPage(competitionPage.html, label, options)
                    .filter(match => matchBelongsToTeam(match, teamName)));
            });
            finish(onSuccess, rememberSportScorePageRows(cacheKey, sortUpcomingMatches(dedupeMatches(filterSportScoreMatchesForMode(rows, mode)))));
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

// Competition-scoped matches first try the global JSON feed filtered to this
// entry's competition (the JSON widget has no per-competition endpoint). That feed
// is capped at ~50 matches worldwide, so it only covers a competition that happens
// to be in the global slice right now; when it yields nothing for this entry we
// fall back to scraping the competition's own HTML page, which carries the league's
// full live/recent/upcoming list. JSON keeps the common case light; the HTML page
// restores coverage for the many leagues the global feed doesn't include.
function fetchSportScoreCompetitionMatches(options, mode, onSuccess, onError) {
    fetchSportScoreGlobalMatches(options, rows => {
        const scoped = filterSportScoreMatchesForMode(rows.filter(match => matchBelongsToCompetition(match, options)), mode);
        if (scoped.length > 0) {
            finish(onSuccess, mode === "recent" ? sortRecentMatches(dedupeMatches(scoped)) : sortMatches(dedupeMatches(scoped)));
            return;
        }

        fetchSportScoreCompetitionMatchesFromPage(options, mode, onSuccess, onError);
    }, () => fetchSportScoreCompetitionMatchesFromPage(options, mode, onSuccess, onError));
}

function fetchSportScoreCompetitionMatchesFromPage(options, mode, onSuccess, onError) {
    const deliver = pageRows => {
        const rows = filterSportScoreMatchesForMode(pageRows, mode);
        finish(onSuccess, mode === "recent" ? sortRecentMatches(dedupeMatches(rows)) : sortMatches(dedupeMatches(rows)));
    };

    // The cache holds the page's UNFILTERED rows so one scrape serves every mode
    // (the 60 s live poll, plus fixtures/recent from the 5 min full refresh)
    // within its TTL, instead of the live poll re-scraping this same page every
    // cycle whenever the competition sits outside the global feed's ~50-match
    // slice - the main remaining plasmashell freeze.
    const cacheKey = sportScoreCompetitionRowsKey(options);
    const cachedRows = cachedSportScorePageRows(cacheKey, mode);
    if (cachedRows) {
        deliver(cachedRows);
        return;
    }

    fetchSportScoreCompetitionPage(options, page => {
        deliver(rememberSportScorePageRows(cacheKey, normalizeSportScoreMatchPage(page.html, sportScoreLeagueLabel(options), options)));
    }, onError, true);
}

// True when a global-feed match belongs to the entry's competition. The entry's
// league label is matched (case-insensitively, normalized) against the match's
// competition name. When the entry carries no usable league label, fall back to
// including the match (the global feed is already sport-scoped).
function matchBelongsToCompetition(match, options) {
    const wanted = normalizedTeamName(stringValue(options && (options.leagueLabel || options.league)));
    if (wanted.length === 0)
        return true;
    const comp = normalizedTeamName(stringValue(match && match.league));
    if (comp.length === 0)
        return false;
    return comp === wanted || comp.indexOf(wanted) >= 0 || wanted.indexOf(comp) >= 0;
}

// All SportScore match data for live/fixtures/recent now comes from the JSON
// widget API (/api/widget/matches/?sport=&limit=50) instead of scraping the
// ~680 KB live HTML page. The JSON payload is a small (≤50 match) document that
// JSON.parses in well under a millisecond, versus the 25-58 ms backtracking-regex
// parse of the HTML page that froze plasmashell. We fetch it once per sport and
// share + briefly cache the normalized rows across every concurrent scope entry
// (mirrors the ESPN scoreboard cache/dedup), so N followed leagues cost ONE fetch
// and ONE parse per refresh rather than N. Competition- and team-scoped requests
// filter this same global feed (see fetchSportScoreCompetitionMatches), and team
// requests additionally use the per-team widget for full-season recent results.
const SPORTSCORE_GLOBAL_TTL_MS = 20000;
const _sportScoreGlobalCache = {};
const _sportScoreGlobalWaiters = {};

// Parsed-rows cache for the HTML page-scrape fallbacks below. A scrape means a
// ~680 KB page download plus a backtracking-regex parse on the UI thread, and
// the 60 s live poll used to hit it on EVERY cycle for any SportScore-only
// entry with nothing currently live - the "few seconds" plasmashell freeze.
// Caching the normalized rows per page identity bounds that to one parse per
// TTL window. Live deliveries demand a fresher cache than fixtures/recent so
// live minute/score still track reasonably.
const SPORTSCORE_PAGE_ROWS_TTL_MS = 5 * 60 * 1000;
const SPORTSCORE_PAGE_ROWS_LIVE_TTL_MS = 2 * 60 * 1000;
const _sportScorePageRowsCache = {};

function cachedSportScorePageRows(key, mode) {
    const cached = key.length > 0 ? _sportScorePageRowsCache[key] : null;
    if (!cached)
        return null;

    const ttl = mode === "live" ? SPORTSCORE_PAGE_ROWS_LIVE_TTL_MS : SPORTSCORE_PAGE_ROWS_TTL_MS;
    return (Date.now() - cached.ts) < ttl ? cached.rows : null;
}

function rememberSportScorePageRows(key, rows) {
    if (key.length > 0)
        _sportScorePageRowsCache[key] = { ts: Date.now(), rows: rows };
    return rows;
}

function sportScoreCompetitionRowsKey(options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    const path = sportScorePathFromUrl(options && (options.competitionPath || options.leaguePath));
    const identity = path.length > 0 ? path : ProviderCatalog.slugForValue(options && options.league);
    if (identity.length === 0)
        return "";

    // A season-specific request resolves to a different page (see
    // sportScoreRequestedSeasonPath), so it must not share the default page's rows.
    const season = stringValue(options && (options.seasonId || options.seasonKey || options.seasonLabel));
    return "competition|" + sport + "|" + identity + "|" + season;
}

function sportScoreTeamRowsKey(options, mode) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    let identity = sportScorePathFromUrl(options && (options.teamPath || options.teamUrl));
    if (identity.length === 0)
        identity = ProviderCatalog.slugForValue(options && options.teamSlug);
    if (identity.length === 0)
        identity = ProviderCatalog.slugForValue(options && options.favoriteTeam);
    if (identity.length === 0)
        return "";

    // The team fallback caches its final mode-shaped result (live scrapes fewer
    // pages than fixtures/recent), so the mode is part of the identity.
    return "team|" + sport + "|" + identity + "|" + mode;
}

// Fetch + normalize the global SportScore match feed for a sport (all statuses),
// cached/deduped per sport. Callers filter by mode/entry themselves.
function fetchSportScoreGlobalMatches(options, onSuccess, onError) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";

    const cached = _sportScoreGlobalCache[sport];
    if (cached && (Date.now() - cached.ts) < SPORTSCORE_GLOBAL_TTL_MS) {
        finish(onSuccess, cached.rows);
        return;
    }

    if (_sportScoreGlobalWaiters[sport]) {
        _sportScoreGlobalWaiters[sport].push({ onSuccess: onSuccess, onError: onError });
        return;
    }
    _sportScoreGlobalWaiters[sport] = [{ onSuccess: onSuccess, onError: onError }];

    const url = SPORTSCORE_BASE_URL + "/api/widget/matches/?sport=" + encodeURIComponent(sport) + "&limit=" + SPORTSCORE_MATCH_LIMIT;
    requestText(cacheBustedUrl(url), text => {
        let rows = [];
        try {
            rows = dedupeMatchesForSport(normalizeSportScoreTeamWidgetMatches(JSON.parse(text), options), sport);
        } catch (error) {
            rows = [];
        }
        _sportScoreGlobalCache[sport] = { ts: Date.now(), rows: rows };
        const waiters = _sportScoreGlobalWaiters[sport] || [];
        delete _sportScoreGlobalWaiters[sport];
        waiters.forEach(waiter => finish(waiter.onSuccess, rows));
    }, error => {
        const waiters = _sportScoreGlobalWaiters[sport] || [];
        delete _sportScoreGlobalWaiters[sport];
        waiters.forEach(waiter => finish(waiter.onError, error || "Unable to load SportScore matches"));
    });
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

// League tables prefer the JSON standings widget (/api/widget/standings/) and
// enrich/cross-check it against the competition's HTML page: the HTML table carries
// recent form and team crests the JSON lacks, and is used outright when it has more
// complete points than the widget. When the widget can't serve the competition we
// fall back to scraping the HTML table directly.
//
// The HTML table rows are cached: the page scrape used to run on EVERY table
// refresh (every 5 min while matches are live) even when the standings API
// succeeded, just to re-derive the same form badges. Enrichment tolerates an
// hour-old scrape (form changes once per matchday); when the HTML is the ONLY
// table source (standings API 404s) it stays fresher so points track finishing
// matches within a refresh cycle or two.
const SPORTSCORE_TABLE_HTML_TTL_MS = 60 * 60 * 1000;
const SPORTSCORE_TABLE_HTML_SOLE_SOURCE_TTL_MS = 10 * 60 * 1000;
const _sportScoreTableHtmlCache = {};

function fetchSportScoreTableHtmlRows(options, maxAgeMs, onRows, onError) {
    const key = sportScoreCompetitionRowsKey(options);
    const cached = key.length > 0 ? _sportScoreTableHtmlCache[key] : null;
    if (cached && (Date.now() - cached.ts) < maxAgeMs) {
        finish(onRows, cached.rows);
        return;
    }

    fetchSportScoreCompetitionPage(options, page => {
        const rows = normalizeSportScoreCompetitionTablePage(page.html, sportScoreLeagueLabel(options), options);
        if (key.length > 0)
            _sportScoreTableHtmlCache[key] = { ts: Date.now(), rows: rows };
        finish(onRows, rows);
    }, onError, true);
}

function fetchSportScoreLeagueTable(options, onSuccess, onError) {
    if (!canUseSportScore(options)) {
        finish(onSuccess, []);
        return;
    }

    function fetchFromCompetitionPage() {
        fetchSportScoreTableHtmlRows(options, SPORTSCORE_TABLE_HTML_SOLE_SOURCE_TTL_MS,
            rows => finish(onSuccess, rows),
            error => finish(onError, error));
    }

    function fetchCompetitionPageForComparison(apiRows) {
        fetchSportScoreTableHtmlRows(options, SPORTSCORE_TABLE_HTML_TTL_MS,
            htmlRows => finish(onSuccess, shouldPreferSportScoreHtmlStandings(apiRows, htmlRows) ? htmlRows : mergeSportScoreHtmlFormsIntoStandings(apiRows, htmlRows)),
            () => finish(onSuccess, apiRows));
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

// The standings widget keys on the competition's CANONICAL site slug - the
// segment before the trailing id in its page path, e.g.
// /football/competition/bulgaria/bulgarian-first-league/kn54qllhn0qvy9d/ →
// "bulgarian-first-league". Slugifying the display label instead often produces
// a near-miss ("First League" → "first-league"), and the endpoint answers 404
// "Competition not found" - which silently sent perfectly servable leagues down
// the heavy HTML-scrape fallback. Prefer the slug embedded in the entry's path.
function sportScoreCompetitionSlugFromPath(path) {
    const normalized = sportScorePathFromUrl(path);
    if (normalized.length === 0)
        return "";

    const segments = normalized.replace(/^\/+/, "").replace(/\/+$/, "").split("/");
    const compIndex = segments.indexOf("competition");
    if (compIndex < 0 || compIndex + 1 >= segments.length)
        return "";

    // After "competition" the path may carry a country segment, then the slug,
    // then optionally the numeric-ish page id and/or a season ("2026",
    // "2025-2026"). Drop id/season tails and take the last remaining segment.
    const candidates = segments.slice(compIndex + 1).filter(segment =>
        !/^\d{4}(-\d{4})?$/.test(segment)
        && !(/^(?=.*\d)[a-z0-9]{12,}$/.test(segment)));
    if (candidates.length === 0)
        return "";

    return ProviderCatalog.slugForValue(candidates[candidates.length - 1]);
}

function sportScoreStandingsSlug(options) {
    const fromPath = sportScoreCompetitionSlugFromPath(options && (options.competitionPath || options.leaguePath));
    if (fromPath.length > 0)
        return fromPath;

    return ProviderCatalog.slugForValue(options && options.league);
}

function canUseSportScoreWidgetStandings(options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    if (sport !== "football")
        return false;

    const slug = sportScoreStandingsSlug(options);
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
    const slug = sportScoreStandingsSlug(options);
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
    }, msg => {
        // No standings for this competition (404) is "no teams", not an outage.
        if (isHttpNotFound(msg))
            finish(onSuccess, []);
        else
            finish(onError, msg);
    });
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

// Teams that play in a competition, derived from its standings table (JSON API,
// edge-cached). Each option carries the emblem and a followable team slug/path,
// so the wizard can offer "follow the whole competition or a team in it" without
// the slow, emblem-less team-page scraping. options.league is the competition slug.
// Maps a team-bearing row (standings or scraped) to a competition-team option.
function competitionTeamOption(row, country) {
    const name = stringValue(row && (row.team || row.label || row.value)).trim();
    const teamSlug = stringValue(row && row.teamSlug).trim() || ProviderCatalog.slugForValue(name);
    if (name.length === 0 || teamSlug.length === 0)
        return null;
    return {
        label: name,
        value: teamSlug,
        slug: teamSlug,
        teamSlug: teamSlug,
        teamPath: stringValue(row && row.teamPath),
        badge: stringValue(row && (row.crest || row.badge)),
        country: stringValue(country)
    };
}

function dedupeCompetitionTeamOptions(rows, country) {
    const seen = {};
    const teams = [];
    arrayValue(rows).forEach(row => {
        const option = competitionTeamOption(row, country);
        if (!option || seen[option.teamSlug])
            return;
        seen[option.teamSlug] = true;
        teams.push(option);
    });
    return teams;
}

// Teams from the SportScore competition HTML page (the "#teams" side-card or the
// standings table). This is the slow scrape the wizard used originally; it is kept
// as a last resort so competitions without a standings JSON table (which 404) still
// list their teams.
function fetchSportScoreCompetitionPageTeams(options, onSuccess, onError) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    fetchSportScoreCompetitionPage(options, page => {
        let rows = teamsFromSportScoreCompetitionPage(page.html, { label: stringValue(options && options.leagueLabel) }, 0, sport);
        // A competition page without a teams card or standings table (e.g. a
        // regional league SportScore carries only fixtures for, like the Darwin
        // Premier League) still names every team in its match rows - harvest
        // those from the page we already fetched. Without this, the caller's
        // last resort swept the whole country's competition pages (Australia:
        // 170 competitions) with UI-thread parses - a multi-second freeze.
        if (rows.length === 0)
            rows = teamsFromSportScoreMatchRows(normalizeSportScoreMatchPage(page.html, stringValue(options && options.leagueLabel), options), options);
        finish(onSuccess, dedupeCompetitionTeamOptions(rows, options && options.country));
    }, error => finish(onError, error), true);
}

// Team option rows (extractSportScoreTeamLinks shape) derived from a page's
// normalized match rows: one row per distinct team name. teamPath stays empty -
// team follow/fetch paths key on the slug, which the JSON team widget accepts.
function teamsFromSportScoreMatchRows(matches, options) {
    const leagueLabel = stringValue(options && options.leagueLabel);
    const seen = {};
    const rows = [];
    arrayValue(matches).forEach(match => {
        [
            { name: stringValue(match && match.homeTeam), badge: stringValue(match && match.homeBadge) },
            { name: stringValue(match && match.awayTeam), badge: stringValue(match && match.awayBadge) }
        ].forEach(side => {
            const label = side.name.trim();
            const slug = ProviderCatalog.slugForValue(label);
            if (label.length === 0 || slug.length === 0 || seen[slug])
                return;
            seen[slug] = true;
            rows.push({
                label: label,
                value: label,
                teamSlug: slug,
                teamPath: "",
                badge: side.badge,
                leagues: leagueLabel.length > 0 ? [leagueLabel] : []
            });
        });
    });
    rows.sort((left, right) => left.label.localeCompare(right.label));
    return rows;
}

function fetchCompetitionTeams(options, onSuccess, onError) {
    const plan = espnPlan(options);
    const sport0 = normalizedSport(options && (options.sports || options.sport)) || "football";

    // Player ("event") sports have no roster, so offer ESPN's athletes to follow
    // instead. ESPN-only - never SportScore. The player list comes from one of two
    // places depending on the sport (see EspnSports.playerSource):
    //   tennis            → the tour rankings feed (top ranked players);
    //   golf/mma/racing   → the event's competitors (field / fight card / grid).
    if (plan && EspnSports.usesPlayers(options && (options.sports || options.sport))) {
        if (EspnSports.playerSource(options && (options.sports || options.sport)) === "scoreboard")
            fetchEspnEventPlayers(plan.espnSport, plan.league, options, onSuccess, onError);
        else
            fetchEspnTennisPlayers(plan.espnSport, plan.league, options, onSuccess, onError);
        return;
    }

    const espnRunner = plan ? (onRows, onErr) => fetchEspnTeams(plan.espnSport, plan.league, options, onRows, onErr) : null;

    // ESPN-native sports have no SportScore standings to derive teams from.
    if (isEspnNativeRequest(options)) {
        if (espnRunner)
            espnRunner(onSuccess, onError);
        else
            finish(onSuccess, []);
        return;
    }

    // SportScore side: standings JSON first, then the HTML competition page (which
    // lists teams even when there is no standings table), and finally — when both
    // come up empty (e.g. an off-season competition, or a scraped slug that doesn't
    // resolve to a real SportScore competition like "bulgaria-championship-nalb") —
    // the country page, which lists the country's teams directly. This last step is
    // what keeps a country pick (Basketball → Bulgaria) showing real local teams
    // instead of nothing.
    const country = ProviderCatalog.slugForValue(options && options.country);
    const tryCountryTeams = (onRows, onErr) => {
        if (country.length === 0 || country === "world") {
            onErr();
            return;
        }
        // Bounded: this last resort exists so a country pick still shows local
        // teams, not to enumerate the whole country - an unbounded sweep meant
        // up to 64 page parses on the UI thread when a niche competition had no
        // teams on its own page.
        fetchSportScoreCountryTeams(sport0, country, rows => {
            const teams = dedupeCompetitionTeamOptions(rows, options && options.country);
            if (teams.length > 0)
                onRows(teams);
            else
                onErr();
        }, () => onErr(), 16);
    };

    const sportScoreRunner = (onRows, onErr) => {
        fetchSportScoreWidgetStandings(options, rows => {
            const teams = dedupeCompetitionTeamOptions(rows, options && options.country);
            if (teams.length > 0) {
                onRows(teams);
                return;
            }
            fetchSportScoreCompetitionPageTeams(options, pageTeams => {
                if (arrayValue(pageTeams).length > 0)
                    onRows(pageTeams);
                else
                    tryCountryTeams(onRows, () => onRows([]));
            }, () => tryCountryTeams(onRows, () => onRows([])));
        }, ssErr => {
            fetchSportScoreCompetitionPageTeams(options, htmlTeams => {
                if (arrayValue(htmlTeams).length > 0)
                    onRows(htmlTeams);
                else
                    tryCountryTeams(onRows, () => onErr(ssErr));
            }, () => tryCountryTeams(onRows, () => onErr(ssErr)));
        });
    };

    fetchByCoverage(espnRunner, sportScoreRunner, onSuccess, onError);
}

// Best-effort emblem lookup for the "Top in the World" page: one edge-cached
// matches call yields competition/team logos by (lowercased) name. Returns
// { competitions: { name: logoUrl }, teams: { name: logoUrl } }.
// Best-effort competition slug from a match record. The widget matches feed may
// expose it directly (competition_slug) or only via a URL/path we can parse; we
// try each so this keeps working regardless of which field the API returns.
function sportScoreCompetitionSlug(match) {
    const direct = ProviderCatalog.slugForValue(match && (match.competition_slug || match.competition_key));
    if (stringValue(direct).length > 0)
        return stringValue(direct);

    const path = sportScorePathFromUrl(match && (match.competition_url || match.competition_path));
    const parsed = /\/competition\/([^\/]+)\/?/.exec(stringValue(path));
    return parsed ? ProviderCatalog.slugForValue(parsed[1]) : "";
}

function fetchPopularEmblems(options, onSuccess) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    const url = SPORTSCORE_BASE_URL + "/api/widget/matches/?sport=" + encodeURIComponent(sport) + "&limit=50";
    requestText(cacheBustedUrl(url), text => {
        const competitions = {};
        const teams = {};
        // Competitions seen in the live feed, with their real (valid) slugs, so the
        // wizard can offer a "Top" list even for sports without a curated catalog.
        const competitionList = [];
        const seenSlugs = {};
        try {
            const payload = JSON.parse(text);
            arrayValue(payload && payload.matches).forEach(match => {
                const competitionLabel = stringValue(match && match.competition).trim();
                const competition = competitionLabel.toLowerCase();
                const competitionLogo = absoluteSportScoreUrl(match && match.competition_logo);
                if (competition.length > 0 && competitionLogo.length > 0 && !competitions[competition])
                    competitions[competition] = competitionLogo;

                const competitionSlug = sportScoreCompetitionSlug(match);
                if (competitionLabel.length > 0 && competitionSlug.length > 0 && !seenSlugs[competitionSlug]) {
                    seenSlugs[competitionSlug] = true;
                    competitionList.push({
                        "label": competitionLabel,
                        "value": competitionSlug,
                        "slug": competitionSlug,
                        "country": stringValue(match && match.country).trim(),
                        "logo": competitionLogo
                    });
                }

                const home = stringValue(match && match.home).trim().toLowerCase();
                const homeLogo = absoluteSportScoreUrl(match && match.home_logo);
                if (home.length > 0 && homeLogo.length > 0 && !teams[home])
                    teams[home] = homeLogo;

                const away = stringValue(match && match.away).trim().toLowerCase();
                const awayLogo = absoluteSportScoreUrl(match && match.away_logo);
                if (away.length > 0 && awayLogo.length > 0 && !teams[away])
                    teams[away] = awayLogo;
            });
        } catch (error) {
            // fall through with whatever was parsed
        }
        finish(onSuccess, { "competitions": competitions, "teams": teams, "competitionList": competitionList });
    }, () => finish(onSuccess, { "competitions": {}, "teams": {}, "competitionList": [] }));
}

function fetchSportScoreCompetitionPage(options, onSuccess, onError, allowDefaultSeasonRedirect) {
    resolveSportScoreCompetitionPath(options, path => {
        if (path.length === 0) {
            finish(onSuccess, { html: "", path: "", url: "" });
            return;
        }

        const requestedSeasonPath = sportScoreRequestedSeasonPath(path, options);
        const initialPath = requestedSeasonPath || path;
        requestPage(absoluteSportScoreUrl(initialPath), html => {
            const defaultSeasonPath = (requestedSeasonPath.length === 0 && allowDefaultSeasonRedirect)
                ? sportScoreCurrentSeasonPathIfStale(html, initialPath, options)
                : "";
            if (defaultSeasonPath.length === 0) {
                finish(onSuccess, { html, path: initialPath, url: absoluteSportScoreUrl(initialPath) });
                return;
            }

            requestPage(absoluteSportScoreUrl(defaultSeasonPath), seasonHtml => {
                finish(onSuccess, { html: seasonHtml, path: defaultSeasonPath, url: absoluteSportScoreUrl(defaultSeasonPath) });
            }, () => finish(onSuccess, { html, path: initialPath, url: absoluteSportScoreUrl(initialPath) }));
        }, onError);
    }, onError);
}

// SportScore's "current season" competition page can lag behind the season
// selector for tournaments that only run periodically (e.g. the FIFA World
// Cup): the match list still shows the most recently *finished* tournament
// while the season dropdown already lists the upcoming/current one as the
// latest entry. When that mismatch is detected, refetch the season-specific
// page that the dropdown marks as default so recent results/fixtures reflect
// the right edition.
function sportScoreCurrentSeasonPathIfStale(html, currentPath, options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    if (sport !== "football")
        return "";

    const defaultSeason = sportScoreSeasonOptionsFromCompetitionPage(html).find(season => season && season.isDefault);
    if (!defaultSeason)
        return "";

    const defaultPath = sportScorePathFromUrl(defaultSeason.path);
    const normalizedCurrentPath = sportScorePathFromUrl(currentPath);
    if (defaultPath.length === 0 || defaultPath === normalizedCurrentPath)
        return "";
    if (sportScorePathWithoutSeason(defaultPath) !== sportScorePathWithoutSeason(normalizedCurrentPath))
        return "";

    const rows = normalizeSportScoreMatchPage(html, "", options);
    const matchesDefaultSeason = rows.some(row => {
        const timestamp = numberValue(row && row.timestamp);
        return timestamp > 0 && sportScoreSeasonKeyMatchesYear(defaultSeason.key, new Date(timestamp).getUTCFullYear());
    });

    return matchesDefaultSeason ? "" : defaultPath;
}

function sportScoreSeasonKeyMatchesYear(key, year) {
    const range = /^(\d{4})-(\d{4})$/.exec(stringValue(key));
    if (range)
        return year === numberValue(range[1]) || year === numberValue(range[2]);
    const single = /^(\d{4})$/.exec(stringValue(key));
    return single ? year === numberValue(single[1]) : false;
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
        // Cricket global live page uses football-class containers (shared class across sports on sportscore)
        appendPattern(/<div class="football-match-table-container w-100 nostyle sc-row-stretched">([\s\S]*?)(?=<div class="d-flex d-md-none|<div class="football-match-table-container w-100 nostyle sc-row-stretched">|<\/section>|$)/g);
        appendPattern(/<a\b[^>]*class="[^"]*\bfootball-match-table-container\b[^"]*\bnostyle\b[^"]*"[^>]*>[\s\S]*?<\/a>/g);
    } else if (sport === "tennis") {
        rows = rows.concat(sportScoreTennisMatchRows(page, leagueLabel, options));
    } else {
        appendPattern(/<div class="football-match-table-container w-100 nostyle sc-row-stretched">([\s\S]*?)(?=<div class="d-flex d-md-none|<div class="football-match-table-container w-100 nostyle sc-row-stretched">|<\/section>|$)/g);
        appendPattern(/<a\b[^>]*class="[^"]*\bfootball-match-table-container\b[^"]*\bnostyle\b[^"]*"[^>]*>[\s\S]*?<\/a>/g);
        rows = rows.concat(sportScoreSeasonOverviewMatchRows(page, leagueLabel, options));
    }
    rows = rows.concat(sportScoreJsonLdUpcomingMatches(page, leagueLabel, options));
    return dedupeMatches(rows);
}

// Season-specific competition pages (e.g. /football/competition/.../2026/)
// render a "season overview" layout with simple "Recent results" /
// "Upcoming fixtures" lists instead of the full match table used by the
// "current season" competition page.
function sportScoreSeasonOverviewMatchRows(page, leagueLabel, options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    let rows = [];
    appendSportScoreSeasonOverviewRows(page, "Recent results", true, sport, leagueLabel, options, rows);
    appendSportScoreSeasonOverviewRows(page, "Upcoming fixtures", false, sport, leagueLabel, options, rows);
    return rows;
}

function appendSportScoreSeasonOverviewRows(page, heading, isFinished, sport, leagueLabel, options, rows) {
    const section = sportScoreSeasonOverviewSection(page, heading);
    if (section.length === 0)
        return;

    const rowPattern = /<div class="match-row sc-row-stretched">([\s\S]*?)<\/div>/g;
    let match;
    while ((match = rowPattern.exec(section)) !== null) {
        const block = match[1];
        const homeText = htmlText((/<span class="home">([\s\S]*?)<\/span>/.exec(block) || [])[1]);
        const awayText = htmlText((/<span class="away">([\s\S]*?)<\/span>/.exec(block) || [])[1]);
        if (homeText.length === 0 || awayText.length === 0)
            continue;

        const hrefMatch = /href="([^"]*\/match\/[^"]*)"/.exec(block);
        const path = hrefMatch ? sportScorePathFromUrl(hrefMatch[1]) : "";
        const whenText = htmlText((/<span class="when">([\s\S]*?)<\/span>/.exec(block) || [])[1]);
        const scoreText = htmlText((/<span class="score[^"]*">([\s\S]*?)<\/span>/.exec(block) || [])[1]);
        const scoreMatch = /(\d+)\s*-\s*(\d+)/.exec(scoreText);
        const status = isFinished ? "Finished" : "Upcoming";
        const timestamp = sportScoreSeasonOverviewTimestamp(whenText, isFinished);

        rows.push({
            id: "sportscore-" + stringValue(path || (homeText + "-" + awayText + "-" + whenText)),
            sport,
            league: leagueLabel || "",
            homeTeam: homeText,
            awayTeam: awayText,
            homeScore: status === "Upcoming" ? "" : stringValue(scoreMatch && scoreMatch[1]),
            awayScore: status === "Upcoming" ? "" : stringValue(scoreMatch && scoreMatch[2]),
            status,
            statusText: status,
            minute: "",
            startTime: timestamp > 0 ? formatStartTime(timestamp, options) : "",
            timestamp: timestamp > 0 ? timestamp : 0,
            matchday: "",
            group: "",
            stadium: "",
            homeBadge: "",
            awayBadge: "",
            poster: "",
            popular: false,
            matchPath: path,
            liveUrl: sportScoreWidgetMatchUrlFromPath(path, sport),
            detailsProvider: "sportscore",
            statsProvider: "sportscore",
            sourceProvider: "SportScore"
        });
    }
}

function sportScoreSeasonOverviewSection(page, heading) {
    const headingPattern = new RegExp("<h2[^>]*>\\s*" + escapeRegExp(heading) + "\\s*<\\/h2>", "i");
    const headingMatch = headingPattern.exec(page);
    if (!headingMatch)
        return "";

    const start = headingMatch.index + headingMatch[0].length;
    const nextHeadingMatch = /<h2[^>]*>/i.exec(page.slice(start));
    const end = nextHeadingMatch ? start + nextHeadingMatch.index : page.length;
    return page.slice(start, end);
}

function sportScoreSeasonOverviewTimestamp(whenText, isFinished) {
    const text = stringValue(whenText).trim();

    if (isFinished) {
        const match = /^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$/.exec(text);
        if (!match)
            return 0;
        const monthIndex = sportScoreMonthIndex(match[2]);
        return monthIndex < 0 ? 0 : Date.UTC(numberValue(match[3]), monthIndex, numberValue(match[1]), 12, 0, 0);
    }

    const match = /^(\d{1,2})\s+([A-Za-z]+),?\s+(\d{1,2}):(\d{2})$/.exec(text);
    if (!match)
        return 0;

    const monthIndex = sportScoreMonthIndex(match[2]);
    if (monthIndex < 0)
        return 0;

    const day = numberValue(match[1]);
    const hour = numberValue(match[3]);
    const minute = numberValue(match[4]);
    const year = new Date().getUTCFullYear();
    let timestamp = Date.UTC(year, monthIndex, day, hour, minute, 0);
    if (timestamp < Date.now() - 24 * 60 * 60 * 1000)
        timestamp = Date.UTC(year + 1, monthIndex, day, hour, minute, 0);
    return timestamp;
}

function sportScoreMonthIndex(name) {
    const months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
    return months.indexOf(stringValue(name).toLowerCase().slice(0, 3));
}

function sportScoreTennisMatchRows(page, leagueLabel, options) {
    let rows = [];
    const pageStr = stringValue(page);

    // Track every match-state-header element (e.g. "Live", "Upcoming",
    // "Finished" round headers) so each match block can be matched against
    // the section it actually falls under, regardless of how far that
    // header is from the match block (a fixed-size backward window misses
    // headers when several matches share the same live section).
    const headerPattern = /<[^>]*\bclass=["'][^"']*\bmatch-state-header\b[^"']*["'][^>]*>/g;
    const headers = [];
    let headerMatch;
    while ((headerMatch = headerPattern.exec(pageStr)) !== null)
        headers.push({ index: headerMatch.index, isLive: /\bis-live\b/i.test(headerMatch[0]) });

    function isLiveSectionAt(position) {
        let result = false;
        for (let i = 0; i < headers.length && headers[i].index <= position; i++)
            result = headers[i].isLive;
        return result;
    }

    // Use lookahead to avoid being cut short by nested </a> tags (e.g. player profile links inside match blocks)
    const pattern = /<a\b[^>]*class=["'][^"']*\bfootball-match-table-container\b[^"']*\bnostyle\b[^"']*["'][^>]*>[\s\S]*?(?=<a\b[^>]*class=["'][^"']*\bfootball-match-table-container\b|<div\b[^>]*class=["'][^"']*\bmatch-state-header\b|<\/section>|$)/g;
    let match;
    while ((match = pattern.exec(pageStr)) !== null) {
        const block = match[0];
        const hrefMatch = /href=["'](\/tennis\/match\/[^"']+\/?)["']/.exec(block);
        if (!hrefMatch)
            continue;
        const context = pageStr.slice(Math.max(0, match.index - 900), match.index);
        const players = sportScoreTennisPlayers(block);
        if (players.length < 2)
            continue;

        const scoreText = htmlText((/<div\b[^>]*class=["'][^"']*\btennis-score-col\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i.exec(block) || [])[1]);
        const scoreMatch = /(\d+)\s*-\s*(\d+)/.exec(scoreText);
        const statusText = htmlText((/<div\b[^>]*class=["'][^"']*\bfootball-match-table-time-str\b[^"']*["'][^>]*>([\s\S]*?)<\/div>/i.exec(block) || [])[1]);
        const liveSection = isLiveSectionAt(match.index);
        const rawStatus = liveSection ? "Live" : statusText;
        const status = sportScoreMatchStatus(rawStatus, scoreMatch && scoreMatch[1], scoreMatch && scoreMatch[2]);
        const timestamp = Date.parse(firstDataUtc(block));
        const path = sportScorePathFromUrl(hrefMatch[1]);
        rows.push({
            id: "sportscore-" + path,
            sport: "tennis",
            league: leagueLabel || sportScoreCompetitionLabelFromContext(context),
            homeTeam: players[0].name,
            awayTeam: players[1].name,
            homeScore: status === "Upcoming" ? "" : stringValue(scoreMatch && scoreMatch[1]),
            awayScore: status === "Upcoming" ? "" : stringValue(scoreMatch && scoreMatch[2]),
            status,
            minute: status === "Live" ? statusText : "",
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
        const altText = htmlAttribute(imageMatch[0], "alt");
        if (!/headshot/i.test(altText))
            continue;
        const name = altText.replace(/\s+headshot$/i, "").trim();
        const badge = absoluteSportScoreUrl(htmlAttribute(imageMatch[0], "src"));
        if (name.length === 0 || players.some(player => normalizedTeamName(player.name) === normalizedTeamName(name)))
            continue;
        players.push({ name, badge });
        if (players.length === 2)
            break;
    }
    return players;
}

function isCricketLiveStatus(rawStatus) {
    const lower = stringValue(rawStatus).toLowerCase().replace(/\s+/g, " ").trim();
    return /\binn(?:ing(?:s)?)?\b/.test(lower) || /\bovers?\b/.test(lower) ||
           lower === "toss" || lower === "lunch" || lower === "tea" || lower === "drinks" ||
           lower === "innings break";
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
        const rawStatusFromBlock = sportScoreCricketStatus(block);
        const liveSection = /match-state-header[^>]*\bis-live\b/i.test(context.slice(context.lastIndexOf("match-state-header")));
        const rawStatus = liveSection ? "Live" : rawStatusFromBlock;
        const isLive = isLiveStatus(rawStatus) || isCricketLiveStatus(rawStatusFromBlock);
        const status = isLive ? "Live" : sportScoreMatchStatus(rawStatus, scores[0], scores[1]);
        const minuteDisplay = rawStatusFromBlock.length > 0 && !isLiveStatus(rawStatusFromBlock) ? rawStatusFromBlock : "";
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
            minute: isLive ? minuteDisplay : "",
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
        const tag = imageMatch[0];
        const name = htmlAttribute(tag, "alt").replace(/\s+(?:logo|flag)$/i, "").trim();
        if (name.length === 0 || name.toLowerCase() === "live")
            continue;
        const dataSrc = htmlAttribute(tag, "data-src");
        const srcAttr = htmlAttribute(tag, "src");
        const raw = dataSrc.length > 0 && dataSrc.indexOf("data:") !== 0 ? dataSrc : srcAttr;
        const badge = raw.indexOf("data:") === 0 ? "" : absoluteSportScoreUrl(raw);
        if (teams.some(team => normalizedTeamName(team.name) === normalizedTeamName(name)))
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


function normalizeSportScoreMatchRow(block, context, leagueLabel, options) {
    const sport = normalizedSport(options && (options.sports || options.sport)) || "football";
    const label = sportScoreLiveAriaLabel(block);
    const labelParts = label.split(" - ");
    const teams = splitSportScoreTeams(htmlDecode(labelParts[0] || ""));
    const league = htmlDecode(labelParts.slice(1).join(" - ")) || leagueLabel || sportScoreCompetitionLabelFromContext(context);
    const timestamp = Date.parse(firstDataUtc(block));
    const rawStatus = htmlText(sportScoreLiveValue(block, "status"));
    const homeScore = htmlText(sportScoreLiveValue(block, "home-score"));
    const awayScore = htmlText(sportScoreLiveValue(block, "away-score"));
    const path = sportScoreMatchPath(block, sport);
    const logos = sportScoreLiveLogos(block);
    const liveSection = /match-state-header[^>]*\bis-live\b/i.test(context.slice(context.lastIndexOf("match-state-header")));
    const status = sportScoreMatchStatus(rawStatus, homeScore, awayScore, liveSection ? "live" : "");
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
        if (mode === "recent") {
            const recentFloor = now - recentYearToDateWindowMs();
            return isFinishedMatch(match) && (numberValue(match && match.timestamp) === 0 || numberValue(match.timestamp) >= recentFloor);
        }
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
        const dataSrc = htmlAttribute(tag, "data-src");
        const srcAttr = htmlAttribute(tag, "src");
        const raw = dataSrc.length > 0 && dataSrc.indexOf("data:") !== 0 ? dataSrc : srcAttr;
        const source = absoluteSportScoreUrl(raw);
        if (source.length > 0 && source.indexOf("data:") !== 0 && rows.indexOf(source) < 0)
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
    const match = /-\s*(.*?)\s+football match/i.exec(text);
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

    const page = stringValue(html);
    const seen = {};
    const values = [];

    function addValue(value) {
        const v = ProviderCatalog.slugForValue(value);
        if (v.length === 0 || v === "world" || seen[v])
            return;
        seen[v] = true;
        values.push(v);
    }

    // Primary: parse /sport/country/{slug}/ links (dedicated countries page)
    const countryLinkPattern = new RegExp("\\/" + escapeRegExp(sportValue) + "\\/country\\/([^\\/\"'?#\\s]+)\\/", "g");
    let match;
    while ((match = countryLinkPattern.exec(page)) !== null)
        addValue(match[1]);

    // Fallback: extract country slugs from competition links
    if (values.length === 0) {
        const competitionPattern = new RegExp("\\/" + escapeRegExp(sportValue) + "\\/competition\\/([^\\/\"']+)\\/", "g");
        while ((match = competitionPattern.exec(page)) !== null)
            addValue(match[1]);
    }

    const rows = values
        .map(value => ({
            label: ProviderCatalog.leagueLabel(value),
            value,
            icon: "",
            infoText: ""
        }))
        .sort((left, right) => stringValue(left.label).localeCompare(stringValue(right.label)));

    if (SportScoreSports.hasCountryCompetitions(sportValue)) {
        rows.unshift({
            label: "International Tournaments",
            value: "world",
            icon: "globe",
            infoText: ""
        });
    }

    return rows;
}

function sportScoreSportFromPath(path) {
    const match = /^\/(football|basketball|cricket|tennis)\//.exec(sportScorePathFromUrl(path));
    return match ? match[1] : "";
}

function fetchSportScoreCountryTeams(sport, country, onSuccess, onError, maxCompetitions) {
    const sportValue = normalizedSport(sport) || "football";
    // The wizard's country browsing needs the full competition sweep; bounded
    // callers (team-path resolution) pass a small cap so a single lookup can't
    // fan out into dozens of page parses on the UI thread.
    const competitionCap = numberValue(maxCompetitions) > 0
        ? Math.min(numberValue(maxCompetitions), SPORTSCORE_COUNTRY_COMPETITION_LIMIT)
        : SPORTSCORE_COUNTRY_COMPETITION_LIMIT;
    const sourcePath = SportScoreSports.usesPlayers(sportValue)
        ? SportScoreSports.rootPath(sportValue)
        : SportScoreSports.competitionSourcePath(sportValue, country);
    requestText(SPORTSCORE_BASE_URL + sourcePath, html => {
        let rows = teamsFromSportScoreCountryPage(html, country, sportValue);
        if (SportScoreSports.usesPlayers(sportValue)) {
            finish(onSuccess, dedupeTeamRows(rows).slice(0, SPORTSCORE_TEAM_LIMIT));
            return;
        }

        const competitions = sportScoreCompetitionLinks(html, country, sportValue).slice(0, competitionCap);
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
    const wantedCountry = ProviderCatalog.slugForValue(country);
    while ((match = expression.exec(page)) !== null) {
        const rowCountry = ProviderCatalog.slugForValue(match[2]);
        // The "International Tournaments" (world) view must show only genuinely
        // international competitions - SportScore tags those with the "world" country
        // segment - not every country's leagues from the global overview page.
        if (rowCountry !== wantedCountry)
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

    // The teams list lives under a section header that is "Popular teams/players"
    // on some pages (football) but "<Country> teams" on others (basketball etc.).
    // Match either so a country pick lists that country's teams regardless of sport.
    let teamsStart = page.search(/<h2[^>]*>\s*Popular (?:teams|players)/i);
    if (teamsStart < 0)
        teamsStart = page.search(/<h2[^>]*>\s*[^<]*\bteams\b/i);
    if (teamsStart >= 0) {
        const block = boundedHtmlBlock(page.slice(teamsStart), "<h2>", "</div>");
        extractSportScoreTeamLinks(block, sportValue).forEach(row => rows.push(row));
    }

    // Fallback: if no recognizable section matched (or it yielded nothing) but the
    // page does list teams, take them from the whole page. Covers layout drift and
    // player sports whose list isn't under a "teams" header.
    if (rows.length === 0)
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
        // The side-card bounding cuts at the FIRST </div>, which on pages with
        // nested markup captures an empty block even though the card lists every
        // team (with id-bearing paths). Re-scan a fixed window after the anchor
        // so those pages don't fall through to heavier fallbacks.
        if (rows.length === 0)
            rows = extractSportScoreTeamLinks(page.slice(teamsAnchor, teamsAnchor + 20000), sportValue);
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

// Injected by the QML layer (main.qml) so retries/cooldowns can use real timed
// delays. Without it we fall back to running the callback immediately.
function setDelayScheduler(scheduler) {
    _delayScheduler = (typeof scheduler === "function") ? scheduler : null;
}

function scheduleAfter(delayMs, callback) {
    if (_delayScheduler && delayMs > 0) {
        _delayScheduler(callback, delayMs);
        return;
    }
    callback();
}

// A 404 means the resource genuinely doesn't exist (e.g. a competition with no
// standings on SportScore) - that is "no data" / an empty result, not a provider
// outage, so callers should treat it as empty rather than a retryable failure.
function isHttpNotFound(message) {
    return stringValue(message).indexOf("HTTP 404") >= 0;
}

function isRetryableFailure(status) {
    return status === 0 || status === 408 || status === 425 || status === 429
        || status === 500 || status === 502 || status === 503 || status === 504;
}

function sportScoreBreakerOpen() {
    return _sportScoreBreakerUntil > Date.now();
}

function noteSportScoreOutcome(succeeded, gatewayFailure) {
    if (succeeded) {
        _sportScoreFailureStreak = 0;
        _sportScoreBreakerUntil = 0;
        return;
    }
    if (!gatewayFailure)
        return;
    _sportScoreFailureStreak += 1;
    if (_sportScoreFailureStreak >= SPORTSCORE_BREAKER_THRESHOLD)
        _sportScoreBreakerUntil = Date.now() + SPORTSCORE_BREAKER_MS;
}

function requestText(url, onSuccess, onError, opts) {
    const ignoreCooldown = Boolean(opts && opts.ignoreCooldown);
    // SportScore is repeatedly failing - fail fast instead of enqueuing a request
    // that will just time out (14s) and clog the queue behind it. ESPN (exempt)
    // is unaffected, so ESPN-covered entries keep loading normally.
    if (!ignoreCooldown && sportScoreBreakerOpen()) {
        finish(onError, "SportScore unavailable");
        return;
    }
    _pendingRequestQueue.push({
        url: stringValue(url),
        onSuccess: onSuccess,
        onError: onError,
        attempt: 0,
        ignoreCooldown: ignoreCooldown
    });
    pumpRequestQueue();
}

function pumpRequestQueue() {
    if (_pendingRequestQueue.length === 0 || _activeRequestCount >= MAX_CONCURRENT_REQUESTS)
        return;

    let job = null;

    // Honour the post-504 cooldown only when a real scheduler is available;
    // otherwise proceed (avoids a busy retry loop without timed delays). The
    // cooldown is set by the failing origin (SportScore) - cooldown-exempt jobs
    // (ESPN, the primary source) are still allowed straight through.
    if (_delayScheduler) {
        const remaining = _requestCooldownUntil - Date.now();
        if (remaining > 0) {
            let exemptIndex = -1;
            for (let index = 0; index < _pendingRequestQueue.length; index += 1) {
                if (_pendingRequestQueue[index].ignoreCooldown) {
                    exemptIndex = index;
                    break;
                }
            }
            if (exemptIndex < 0) {
                _delayScheduler(pumpRequestQueue, remaining);
                return;
            }
            job = _pendingRequestQueue.splice(exemptIndex, 1)[0];
        }
    }

    if (!job)
        job = _pendingRequestQueue.shift();
    _activeRequestCount += 1;
    sendQueuedRequest(job);
}

function sendQueuedRequest(job) {
    const xhr = new XMLHttpRequest();
    xhr.open("GET", job.url);
    xhr.timeout = REQUEST_TIMEOUT_MS;

    const settle = (succeeded, payload, status) => {
        _activeRequestCount -= 1;

        if (succeeded) {
            if (!job.ignoreCooldown)
                noteSportScoreOutcome(true, false);
            finish(job.onSuccess, payload);
            pumpRequestQueue();
            return;
        }

        // A gateway/timeout failure means the origin is overloaded: pause new
        // requests briefly so we don't pile on while it recovers, and count it
        // toward the circuit breaker. Cooldown-exempt (ESPN) requests must not
        // throttle the queue or trip the breaker on their own failures.
        const gatewayFailure = (status === 0 || status === 502 || status === 503 || status === 504);
        if (!job.ignoreCooldown) {
            noteSportScoreOutcome(false, gatewayFailure);
            if (gatewayFailure)
                _requestCooldownUntil = Date.now() + REQUEST_COOLDOWN_MS;
        }

        if (isRetryableFailure(status) && job.attempt < MAX_REQUEST_RETRIES) {
            job.attempt += 1;
            const backoff = RETRY_BASE_DELAY_MS * Math.pow(2, job.attempt - 1);
            scheduleAfter(backoff, () => {
                _pendingRequestQueue.unshift(job);
                pumpRequestQueue();
            });
            pumpRequestQueue();
            return;
        }

        finish(job.onError, payload);
        pumpRequestQueue();
    };

    xhr.onreadystatechange = () => {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return;
        if (xhr.status >= 200 && xhr.status < 300)
            settle(true, xhr.responseText || "", xhr.status);
        else
            settle(false, "HTTP " + xhr.status + " for " + job.url, xhr.status);
    };
    xhr.ontimeout = () => settle(false, "Timeout for " + job.url, 0);
    xhr.onerror = () => settle(false, "Network error for " + job.url, 0);
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
    const page = stringValue(html);
    const imgTagPattern = /<img\b[^>]+>/gi;
    const imgTags = [];
    let m;
    while ((m = imgTagPattern.exec(page)) !== null)
        imgTags.push(m[0]);
    if (imgTags.length === 0)
        return "";
    const last = imgTags[imgTags.length - 1];
    const dataSrc = htmlAttribute(last, "data-src");
    if (dataSrc.length > 0 && dataSrc.indexOf("data:") !== 0)
        return absoluteSportScoreUrl(dataSrc);
    const src = htmlAttribute(last, "src");
    if (src.length > 0 && src.indexOf("data:") !== 0)
        return absoluteSportScoreUrl(src);
    return "";
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
    const bucket = Math.floor(Date.now() / CACHE_BUST_BUCKET_MS);
    return value + separator + "src=sports-widget-for-plasma&t=" + bucket;
}

// In-flight de-duplication for shared HTML pages (a team or competition page is
// fetched by several callers - matches, competitions, badge, seasons, table).
// Concurrent requests for the same page collapse into a single network request;
// nothing is held across requests, so freshness is unaffected.
const _pageRequestsInFlight = {};

function requestPage(url, onSuccess, onError) {
    const key = stringValue(url);
    if (_pageRequestsInFlight[key]) {
        _pageRequestsInFlight[key].push({ onSuccess: onSuccess, onError: onError });
        return;
    }

    _pageRequestsInFlight[key] = [{ onSuccess: onSuccess, onError: onError }];
    requestText(cacheBustedUrl(key), text => {
        const waiters = _pageRequestsInFlight[key] || [];
        delete _pageRequestsInFlight[key];
        waiters.forEach(waiter => finish(waiter.onSuccess, text));
    }, error => {
        const waiters = _pageRequestsInFlight[key] || [];
        delete _pageRequestsInFlight[key];
        waiters.forEach(waiter => finish(waiter.onError, error));
    });
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
    const format = stringValue(options && options.matchDateFormat) || "dd.MM.yy";
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

// TEMP DIAGNOSTIC: time a synchronous block running on the QML/UI thread and log
// it when it exceeds the threshold, so we can see which parse/normalize step is
// stalling plasmashell during a live refresh. `extra` is appended for context
// (e.g. input size, row count). Remove once the freeze cause is confirmed.
const _PROFILE_MAIN_THREAD = false;
const _PROFILE_LOG_THRESHOLD_MS = 8;

function profileSync(label, extra, fn) {
    if (!_PROFILE_MAIN_THREAD)
        return fn();
    const start = Date.now();
    const result = fn();
    const elapsed = Date.now() - start;
    if (elapsed >= _PROFILE_LOG_THRESHOLD_MS)
        console.warn("[sports-widget][profile] " + label + " took " + elapsed + "ms" + (extra ? " (" + extra + ")" : ""));
    return result;
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
