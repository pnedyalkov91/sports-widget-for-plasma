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

// ESPN public API catalog. Used both as a fallback for the four SportScore sports
// (football, basketball, cricket, tennis) when SportScore fails, and as the data
// source for the ESPN-native sports (NFL, MLB, NHL, golf, racing, …).
//
// Each sport maps to an ESPN "sport" path segment plus a curated list of leagues
// (ESPN league path segments). Endpoints:
//   https://site.api.espn.com/apis/site/v2/sports/{espnSport}/{league}/{scoreboard|teams|standings}
//
// "kind":
//   "team-league" — has standings + a team roster (league table & follow teams)
//   "event"       — individual/event based (golf, tennis, racing, mma): scoreboard
//                   only; standings/teams degrade to empty states in the UI.
//
// Well-known league slugs (soccer big-5 + UCL/UEL/MLS/World Cup, nba/wnba, nfl,
// mlb, nhl, atp/wta, pga, f1) are validated by common ESPN usage. The more obscure
// ones are best-effort; if a slug is wrong ESPN simply returns no events and the UI
// shows its normal empty state.

const SPORTS = [
    // --- Shared with SportScore (ESPN is the fallback) ---------------------
    {
        label: "Football", value: "football", espnSport: "soccer", kind: "team-league",
        leagues: [
            { label: "Premier League", league: "eng.1", country: "england" },
            { label: "La Liga", league: "esp.1", country: "spain" },
            { label: "Serie A", league: "ita.1", country: "italy" },
            { label: "Bundesliga", league: "ger.1", country: "germany" },
            { label: "Ligue 1", league: "fra.1", country: "france" },
            { label: "Eredivisie", league: "ned.1", country: "netherlands" },
            { label: "Primeira Liga", league: "por.1", country: "portugal" },
            { label: "Major League Soccer", league: "usa.1", country: "usa" },
            { label: "EFL Championship", league: "eng.2", country: "england" },
            { label: "UEFA Champions League", league: "uefa.champions", country: "world" },
            { label: "UEFA Europa League", league: "uefa.europa", country: "world" },
            { label: "FIFA World Cup", league: "fifa.world", country: "world" }
        ]
    },
    {
        label: "Basketball", value: "basketball", espnSport: "basketball", kind: "team-league",
        leagues: [
            { label: "NBA", league: "nba", country: "usa" },
            { label: "WNBA", league: "wnba", country: "usa" },
            { label: "NCAA Men's", league: "mens-college-basketball", country: "usa" },
            { label: "NCAA Women's", league: "womens-college-basketball", country: "usa" }
        ]
    },
    {
        // ESPN cricket league codes are numeric/unstable; left minimal. Scoreboard
        // by these may be empty — the UI degrades gracefully.
        label: "Cricket", value: "cricket", espnSport: "cricket", kind: "team-league",
        leagues: []
    },
    {
        label: "Tennis", value: "tennis", espnSport: "tennis", kind: "event",
        leagues: [
            { label: "ATP", league: "atp", country: "world" },
            { label: "WTA", league: "wta", country: "world" }
        ]
    },

    // --- ESPN-native sports ------------------------------------------------
    {
        label: "American Football", value: "american-football", espnSport: "football", kind: "team-league",
        leagues: [
            { label: "NFL", league: "nfl", country: "usa" },
            { label: "NCAA Football", league: "college-football", country: "usa" }
        ]
    },
    {
        label: "Baseball", value: "baseball", espnSport: "baseball", kind: "team-league",
        leagues: [
            { label: "MLB", league: "mlb", country: "usa" },
            { label: "College Baseball", league: "college-baseball", country: "usa" }
        ]
    },
    {
        label: "Ice Hockey", value: "hockey", espnSport: "hockey", kind: "team-league",
        leagues: [
            { label: "NHL", league: "nhl", country: "usa" },
            { label: "NCAA Men's Hockey", league: "mens-college-hockey", country: "usa" }
        ]
    },
    {
        label: "Golf", value: "golf", espnSport: "golf", kind: "event",
        leagues: [
            { label: "PGA Tour", league: "pga", country: "world" },
            { label: "LPGA", league: "lpga", country: "world" },
            { label: "DP World Tour", league: "eur", country: "world" },
            { label: "LIV Golf", league: "liv", country: "world" }
        ]
    },
    {
        label: "Racing", value: "racing", espnSport: "racing", kind: "event",
        leagues: [
            { label: "Formula 1", league: "f1", country: "world" },
            { label: "NASCAR Cup Series", league: "nascar-premier", country: "usa" },
            { label: "IndyCar", league: "irl", country: "usa" }
        ]
    },
    {
        label: "MMA", value: "mma", espnSport: "mma", kind: "event",
        leagues: [
            { label: "UFC", league: "ufc", country: "world" },
            { label: "PFL", league: "pfl", country: "world" }
        ]
    },
    {
        label: "Rugby", value: "rugby", espnSport: "rugby", kind: "team-league",
        leagues: [
            { label: "Premiership Rugby", league: "267979", country: "england" },
            { label: "United Rugby Championship", league: "270557", country: "world" },
            { label: "Six Nations", league: "180659", country: "world" }
        ]
    },
    {
        // ESPN exposes a single, generic rugby-league feed (numeric id 3); there
        // are no separate NRL / Super League league paths (those slugs 400). The
        // one feed carries the league's fixtures, results and standings.
        label: "Rugby League", value: "rugby-league", espnSport: "rugby-league", kind: "team-league",
        leagues: [
            { label: "Rugby League", league: "3", country: "world" }
        ]
    },
    {
        label: "Australian Football", value: "australian-football", espnSport: "australian-football", kind: "team-league",
        leagues: [
            { label: "AFL", league: "afl", country: "australia" }
        ]
    },
    {
        // ESPN's only field-hockey league is NCAA Women's (slug
        // womens-college-field-hockey); the "fih"/international slug 400s.
        label: "Field Hockey", value: "field-hockey", espnSport: "field-hockey", kind: "team-league",
        leagues: [
            { label: "NCAA Women's Field Hockey", league: "womens-college-field-hockey", country: "usa" }
        ]
    },
    {
        label: "Lacrosse", value: "lacrosse", espnSport: "lacrosse", kind: "team-league",
        leagues: [
            { label: "PLL", league: "pll", country: "usa" },
            { label: "NCAA Men's", league: "mens-college-lacrosse", country: "usa" }
        ]
    },
    {
        label: "Volleyball", value: "volleyball", espnSport: "volleyball", kind: "team-league",
        leagues: [
            { label: "NCAA Women's", league: "womens-college-volleyball", country: "usa" },
            { label: "NCAA Men's", league: "mens-college-volleyball", country: "usa" }
        ]
    },
    {
        label: "Water Polo", value: "water-polo", espnSport: "water-polo", kind: "team-league",
        leagues: [
            { label: "NCAA Men's", league: "mens-college-water-polo", country: "usa" },
            { label: "NCAA Women's", league: "womens-college-water-polo", country: "usa" }
        ]
    }
];

// Sports SportScore already provides; for these ESPN is only a fallback, not a
// new sport in the picker.
const SHARED_SPORTS = ["football", "basketball", "cricket", "tennis"];

// Maps a SportScore competition identity to an ESPN league, so SportScore's saved
// entries can fall back to ESPN. Keyed by the SportScore league slug.
const FALLBACK_LEAGUE_BY_SLUG = {
    // England
    "english-premier-league": { espnSport: "soccer", league: "eng.1" },
    "english-championship": { espnSport: "soccer", league: "eng.2" },
    "english-fa-cup": { espnSport: "soccer", league: "eng.fa" },
    "english-efl-cup": { espnSport: "soccer", league: "eng.league_cup" },
    "english-community-shield": { espnSport: "soccer", league: "eng.charity" },
    // Spain
    "spanish-la-liga": { espnSport: "soccer", league: "esp.1" },
    "spanish-laliga2": { espnSport: "soccer", league: "esp.2" },
    "spanish-copa-del-rey": { espnSport: "soccer", league: "esp.copa_del_rey" },
    "spanish-super-cup": { espnSport: "soccer", league: "esp.super_cup" },
    // Italy
    "italian-serie-a": { espnSport: "soccer", league: "ita.1" },
    "italian-serie-b": { espnSport: "soccer", league: "ita.2" },
    "italian-coppa-italia": { espnSport: "soccer", league: "ita.coppa_italia" },
    // Germany
    "german-bundesliga": { espnSport: "soccer", league: "ger.1" },
    "german-bundesliga-2": { espnSport: "soccer", league: "ger.2" },
    // France
    "french-ligue-1": { espnSport: "soccer", league: "fra.1" },
    "french-ligue-2": { espnSport: "soccer", league: "fra.2" },
    "french-coupe-de-france": { espnSport: "soccer", league: "fra.coupe_de_france" },
    // Portugal / Netherlands
    "portuguese-primera-liga": { espnSport: "soccer", league: "por.1" },
    "dutch-eredivisie": { espnSport: "soccer", league: "ned.1" },
    // Brazil
    "brazilian-serie-a": { espnSport: "soccer", league: "bra.1" },
    "brazilian-serie-b": { espnSport: "soccer", league: "bra.2" },
    "brazilian-copa-do-brasil": { espnSport: "soccer", league: "bra.copa_do_brazil" },
    // Argentina
    "argentine-liga-profesional": { espnSport: "soccer", league: "arg.1" },
    "argentine-copa-argentina": { espnSport: "soccer", league: "arg.copa" },
    // Mexico / USA
    "mexican-liga-mx": { espnSport: "soccer", league: "mex.1" },
    "american-major-league-soccer": { espnSport: "soccer", league: "usa.1" },
    "american-us-open-cup": { espnSport: "soccer", league: "usa.open" },
    // International
    "uefa-champions-league": { espnSport: "soccer", league: "uefa.champions" },
    "uefa-europa-league": { espnSport: "soccer", league: "uefa.europa" },
    "uefa-conference-league": { espnSport: "soccer", league: "uefa.europa.conf" },
    "conmebol-libertadores": { espnSport: "soccer", league: "conmebol.libertadores" },
    "concacaf-champions-cup": { espnSport: "soccer", league: "concacaf.champions" },
    "fifa-club-world-cup": { espnSport: "soccer", league: "fifa.cwc" },
    "fifa-world-cup": { espnSport: "soccer", league: "fifa.world" },
    // basketball
    "nba": { espnSport: "basketball", league: "nba" },
    "euroleague": { espnSport: "basketball", league: "nba" }
};

// SportScore country slug -> default ESPN soccer league, so a country's matches can
// fall back even without an explicit competition mapping.
const FALLBACK_LEAGUE_BY_COUNTRY = {
    "england": { espnSport: "soccer", league: "eng.1" },
    "spain": { espnSport: "soccer", league: "esp.1" },
    "italy": { espnSport: "soccer", league: "ita.1" },
    "germany": { espnSport: "soccer", league: "ger.1" },
    "france": { espnSport: "soccer", league: "fra.1" },
    "netherlands": { espnSport: "soccer", league: "ned.1" },
    "portugal": { espnSport: "soccer", league: "por.1" },
    "united-states": { espnSport: "soccer", league: "usa.1" },
    "usa": { espnSport: "soccer", league: "usa.1" }
};

function stringValue(value) {
    return value === undefined || value === null ? "" : String(value).trim();
}

function normalizedSport(value) {
    const text = stringValue(value).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
    if (text === "soccer")
        return "football";
    return text;
}

function sportEntry(sport) {
    const wanted = normalizedSport(sport);
    for (let index = 0; index < SPORTS.length; index += 1) {
        if (SPORTS[index].value === wanted)
            return SPORTS[index];
    }
    return null;
}

// All ESPN sports as picker options { label, value }.
function options() {
    return SPORTS.map(sport => ({ label: sport.label, value: sport.value }));
}

// Only the ESPN-native sports (not already provided by SportScore).
function nativeOptions() {
    return SPORTS.filter(sport => SHARED_SPORTS.indexOf(sport.value) < 0)
        .map(sport => ({ label: sport.label, value: sport.value }));
}

function supports(sport) {
    return sportEntry(sport) !== null;
}

function isNative(sport) {
    return supports(sport) && SHARED_SPORTS.indexOf(normalizedSport(sport)) < 0;
}

function espnSportFor(sport) {
    const entry = sportEntry(sport);
    return entry ? entry.espnSport : "";
}

function kind(sport) {
    const entry = sportEntry(sport);
    return entry ? entry.kind : "";
}

function usesStandings(sport) {
    return kind(sport) === "team-league";
}

function usesTeams(sport) {
    return kind(sport) === "team-league";
}

// Leagues for a sport as competition-style options the wizard can render:
// { label, value (=ESPN league slug), slug, country, espnSport, path }.
function leaguesFor(sport) {
    const entry = sportEntry(sport);
    if (!entry)
        return [];
    return entry.leagues.map(league => ({
        label: league.label,
        value: league.league,
        slug: league.league,
        country: league.country || "world",
        espnSport: entry.espnSport,
        path: "/" + entry.value + "/competition/" + league.league + "/"
    }));
}

// All distinct countries used by a sport's leagues, as country options.
function countriesFor(sport) {
    const entry = sportEntry(sport);
    if (!entry)
        return [];
    const seen = {};
    const out = [];
    entry.leagues.forEach(league => {
        const country = stringValue(league.country) || "world";
        if (!seen[country]) {
            seen[country] = true;
            out.push({ label: country.charAt(0).toUpperCase() + country.slice(1).replace(/-/g, " "), value: country, icon: "" });
        }
    });
    return out;
}

// True when `league` is already an ESPN league slug for this sport (e.g. a
// shared-sport entry the wizard sourced from ESPN's own league catalog rather
// than from SportScore). Lets such entries resolve straight to ESPN.
function espnLeagueInCatalog(sport, league) {
    const entry = sportEntry(sport);
    const wanted = stringValue(league).toLowerCase();
    if (!entry || wanted.length === 0)
        return false;
    for (let index = 0; index < entry.leagues.length; index += 1) {
        if (stringValue(entry.leagues[index].league).toLowerCase() === wanted)
            return true;
    }
    return false;
}

// Human label for an ESPN league slug from the curated catalog, or "" if unknown.
function leagueLabelFor(leagueSlug) {
    const wanted = stringValue(leagueSlug).toLowerCase();
    if (wanted.length === 0)
        return "";
    for (let i = 0; i < SPORTS.length; i += 1) {
        for (let j = 0; j < SPORTS[i].leagues.length; j += 1) {
            if (stringValue(SPORTS[i].leagues[j].league).toLowerCase() === wanted)
                return SPORTS[i].leagues[j].label;
        }
    }
    return "";
}

// Resolve { espnSport, league } when `league` is an ESPN league slug that appears
// as a FALLBACK_LEAGUE_BY_SLUG target (covers leagues outside the curated catalog),
// or null. Matched against the given espnSport so e.g. a basketball slug can't
// resolve a soccer entry.
function espnLeagueFromTargets(espnSport, league) {
    const wantedSport = stringValue(espnSport).toLowerCase();
    const wantedLeague = stringValue(league).toLowerCase();
    if (wantedLeague.length === 0)
        return null;
    for (const slug in FALLBACK_LEAGUE_BY_SLUG) {
        const target = FALLBACK_LEAGUE_BY_SLUG[slug];
        if (stringValue(target.league).toLowerCase() === wantedLeague
            && (wantedSport.length === 0 || stringValue(target.espnSport).toLowerCase() === wantedSport))
            return { espnSport: target.espnSport, league: target.league };
    }
    return null;
}

// Resolve an ESPN { espnSport, league } for a saved/working entry, or null.
function espnLeagueForEntry(options) {
    options = options || {};
    const sport = normalizedSport(options.sport || options.sports);
    const league = stringValue(options.league).toLowerCase();
    const country = stringValue(options.country).toLowerCase();

    // ESPN-native sport: the entry's league IS an ESPN league slug already.
    if (isNative(sport)) {
        const entry = sportEntry(sport);
        if (league.length > 0)
            return { espnSport: entry.espnSport, league };
        if (entry.leagues.length > 0)
            return { espnSport: entry.espnSport, league: entry.leagues[0].league };
        return null;
    }

    // Shared sport sourced from ESPN's own catalog: the league IS an ESPN slug.
    if (league.length > 0 && espnLeagueInCatalog(sport, league))
        return { espnSport: espnSportFor(sport), league: league };

    // Shared sport sourced from SportScore: translate the competition identity.
    if (league.length > 0 && FALLBACK_LEAGUE_BY_SLUG.hasOwnProperty(league))
        return FALLBACK_LEAGUE_BY_SLUG[league];

    // ESPN covers many leagues that aren't in the curated catalog (Brazil, second
    // tiers, cups…) — they only appear as fallback targets. If the entry already
    // carries such an ESPN league slug (e.g. "bra.1"), resolve it directly so it
    // isn't sent to SportScore.
    if (league.length > 0) {
        const direct = espnLeagueFromTargets(espnSportFor(sport), league);
        if (direct)
            return direct;
    }
    if (country.length > 0 && FALLBACK_LEAGUE_BY_COUNTRY.hasOwnProperty(country))
        return FALLBACK_LEAGUE_BY_COUNTRY[country];

    // Sport-level fallback for sports with a single global feed.
    if (sport === "basketball")
        return { espnSport: "basketball", league: "nba" };

    return null;
}
