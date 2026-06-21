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
.import "EspnSports.js" as EspnSports

// Curated "Top in the World" landing data for the configuration wizard.
//
// SportScore has no API to list popular/featured competitions, so the first
// wizard page is seeded from this hand-curated catalog. Slugs follow SportScore's
// "<country-adjective>-<name>" competition convention and "<name>" team convention
// and are validated against the project's own history (the football set was in use
// previously). Team/competition emblems are NOT stored here — they are fetched from
// the JSON API (standings/matches) and cached, so this catalog stays small and stable.

function stringValue(value) {
    return value === undefined || value === null ? "" : String(value);
}

function normalizedSport(value) {
    const text = stringValue(value).trim().toLowerCase();
    if (text === "soccer")
        return "football";
    return text.length > 0 ? text : "football";
}

function competitionPath(sport, slug) {
    return "/" + normalizedSport(sport) + "/competition/" + stringValue(slug) + "/";
}

function teamPath(sport, slug) {
    return "/" + normalizedSport(sport) + "/team/" + stringValue(slug) + "/";
}

// label, slug, country (used for both display grouping and the saved entry).
// SportScore slugs use its "<country-adjective>-<name>" convention; the league
// table / teams resolve through SportScore (JSON or HTML) with an ESPN fallback
// (see EspnSports.FALLBACK_LEAGUE_BY_SLUG), so they keep working even when a given
// SportScore slug 404s.
const FOOTBALL_COMPETITIONS = [
    // England
    ["Premier League", "english-premier-league", "england"],
    ["Championship", "english-championship", "england"],
    ["FA Cup", "english-fa-cup", "england"],
    ["EFL Cup", "english-efl-cup", "england"],
    ["FA Community Shield", "english-community-shield", "england"],
    // Spain
    ["La Liga", "spanish-la-liga", "spain"],
    ["LaLiga 2", "spanish-laliga2", "spain"],
    ["Copa del Rey", "spanish-copa-del-rey", "spain"],
    ["Supercopa de España", "spanish-super-cup", "spain"],
    // Italy
    ["Serie A", "italian-serie-a", "italy"],
    ["Serie B", "italian-serie-b", "italy"],
    ["Coppa Italia", "italian-coppa-italia", "italy"],
    // Germany
    ["Bundesliga", "german-bundesliga", "germany"],
    ["Bundesliga 2", "german-bundesliga-2", "germany"],
    // France
    ["Ligue 1", "french-ligue-1", "france"],
    ["Ligue 2", "french-ligue-2", "france"],
    ["Coupe de France", "french-coupe-de-france", "france"],
    // Portugal / Netherlands
    ["Primeira Liga", "portuguese-primera-liga", "portugal"],
    ["Eredivisie", "dutch-eredivisie", "netherlands"],
    // Brazil
    ["Brasileirão Série A", "brazilian-serie-a", "brazil"],
    ["Brasileirão Série B", "brazilian-serie-b", "brazil"],
    ["Copa do Brasil", "brazilian-copa-do-brasil", "brazil"],
    // Argentina
    ["Liga Profesional", "argentine-liga-profesional", "argentina"],
    ["Copa Argentina", "argentine-copa-argentina", "argentina"],
    // Mexico / USA
    ["Liga MX", "mexican-liga-mx", "mexico"],
    ["Major League Soccer", "american-major-league-soccer", "united-states"],
    ["US Open Cup", "american-us-open-cup", "united-states"],
    // International
    ["UEFA Champions League", "uefa-champions-league", "world"],
    ["UEFA Europa League", "uefa-europa-league", "world"],
    ["UEFA Conference League", "uefa-conference-league", "world"],
    ["CONMEBOL Libertadores", "conmebol-libertadores", "world"],
    ["CONCACAF Champions Cup", "concacaf-champions-cup", "world"],
    ["FIFA Club World Cup", "fifa-club-world-cup", "world"],
    ["FIFA World Cup", "fifa-world-cup", "world"]
];

// label, slug, country.
const FOOTBALL_TEAMS = [
    ["Real Madrid", "real-madrid", "spain"],
    ["FC Barcelona", "barcelona", "spain"],
    ["Manchester City", "manchester-city", "england"],
    ["Manchester United", "manchester-united", "england"],
    ["Liverpool", "liverpool", "england"],
    ["Arsenal", "arsenal", "england"],
    ["Chelsea", "chelsea", "england"],
    ["Tottenham Hotspur", "tottenham-hotspur", "england"],
    ["Bayern Munich", "bayern-munich", "germany"],
    ["Borussia Dortmund", "borussia-dortmund", "germany"],
    ["Paris Saint Germain", "paris-saint-germain", "france"],
    ["Juventus", "juventus", "italy"],
    ["Inter Milan", "inter-milan", "italy"],
    ["AC Milan", "ac-milan", "italy"],
    ["Napoli", "napoli", "italy"],
    ["Atletico Madrid", "atletico-madrid", "spain"],
    ["Benfica", "benfica", "portugal"],
    ["FC Porto", "fc-porto", "portugal"],
    ["Ajax", "ajax", "netherlands"]
];

// Best-effort sets for the remaining sports (no historical validation available;
// the wizard degrades gracefully when a slug yields no standings/teams).
const BASKETBALL_COMPETITIONS = [
    ["NBA", "nba", "usa"],
    ["EuroLeague", "euroleague", "world"]
];

const CRICKET_COMPETITIONS = [
    ["ICC Cricket World Cup", "icc-cricket-world-cup", "world"],
    ["Indian Premier League", "indian-premier-league", "india"]
];

function toCompetitionOptions(sport, rows) {
    return rows.map(row => ({
        "label": row[0],
        "value": row[1],
        "slug": row[1],
        "country": row[2],
        "path": competitionPath(sport, row[1])
    }));
}

function toTeamOptions(sport, rows) {
    return rows.map(row => ({
        "label": row[0],
        "value": row[1],
        "slug": row[1],
        "country": row[2],
        "path": teamPath(sport, row[1])
    }));
}

// Top competitions for the landing page. Returns [{ label, value, slug, country, path }].
function popularCompetitions(sport) {
    const value = normalizedSport(sport);
    switch (value) {
    case "football":
        return toCompetitionOptions(value, FOOTBALL_COMPETITIONS);
    case "basketball":
        return toCompetitionOptions(value, BASKETBALL_COMPETITIONS);
    case "cricket":
        return toCompetitionOptions(value, CRICKET_COMPETITIONS);
    default:
        // ESPN-native sports: their leagues are the "Top" competitions.
        if (EspnSports.isNative(value))
            return EspnSports.leaguesFor(value);
        return [];
    }
}

// Top teams for the landing page. Returns [{ label, value, slug, country, path }].
// Tennis is player-based and has no team landing list.
function popularTeams(sport) {
    const value = normalizedSport(sport);
    switch (value) {
    case "football":
        return toTeamOptions(value, FOOTBALL_TEAMS);
    default:
        return [];
    }
}

function hasPopular(sport) {
    return popularCompetitions(sport).length > 0 || popularTeams(sport).length > 0;
}
