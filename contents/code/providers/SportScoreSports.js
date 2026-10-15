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

const SPORTS = [
    { label: "Football", value: "football" },
    { label: "Basketball", value: "basketball" },
    { label: "Tennis", value: "tennis" }
];

function options() {
    return SPORTS.slice();
}

function supports(sport) {
    const wanted = normalizedSport(sport);
    return SPORTS.some(option => option.value === wanted);
}

// Individual sports where a "team" is really a single player/competitor.
const PLAYER_SPORTS = ["tennis", "golf", "mma", "racing"];

function usesPlayers(sport) {
    return PLAYER_SPORTS.indexOf(normalizedSport(sport)) >= 0;
}

function hasCountryCompetitions(sport) {
    return normalizedSport(sport) !== "tennis";
}

function rootPath(sport) {
    const value = normalizedSport(sport);
    return supports(value) ? "/" + value + "/" : "";
}

function countriesPath(sport) {
    if (normalizedSport(sport) === "football")
        return "/football/countries/";
    return "";
}

function competitionSourcePath(sport, country) {
    const value = normalizedSport(sport);
    const countrySlug = slug(country);
    if (!supports(value))
        return "";
    if (value === "tennis" || countrySlug === "world")
        return "/" + value + "/competitions/";
    return "/" + value + "/country/" + countrySlug + "/";
}

function competitionPrefix(sport) {
    const value = normalizedSport(sport);
    return supports(value) ? "/" + value + "/competition/" : "";
}

function participantPrefix(sport) {
    const value = normalizedSport(sport);
    if (!supports(value))
        return "";
    return "/" + value + "/" + (usesPlayers(value) ? "player" : "team") + "/";
}

function isCompetitionPath(path, sport) {
    return stringValue(path).indexOf(competitionPrefix(sport)) === 0;
}

function isParticipantPath(path, sport) {
    return stringValue(path).indexOf(participantPrefix(sport)) === 0;
}

function defaultCountryOptions(sport) {
    if (normalizedSport(sport) !== "tennis")
        return [];

    return [{
        label: "International",
        value: "world",
        icon: "globe",
        infoText: "SportScore exposes tennis competitions and players internationally."
    }];
}

// `i18nc` is passed in by the caller (e.g. `SportScoreSports.standingsColumns(sport,
// i18nc)` from a .qml file) rather than called directly from this file. This file
// is `.pragma library`, which runs without a QQmlContext, so the global i18n/i18nc
// functions that KLocalizedContext exposes are NOT reachable from in here - calling
// them directly would silently return undefined/throw. Accepting the function as a
// parameter keeps the resolution happening on the QML side where it works, while
// keeping all the per-sport column layout logic in one place.
function standingsColumns(sport, i18nc) {
    const value = normalizedSport(sport);
    if (value === "basketball") {
        return [
            column("played", i18nc("Abbreviation for 'games played' in a basketball standings table, keep very short", "GP"), i18nc("@info:tooltip", "Games played"), 2.4),
            column("won", i18nc("Abbreviation for 'won' in a standings table, keep very short", "W"), i18nc("@info:tooltip", "Won"), 2),
            column("lost", i18nc("Abbreviation for 'lost' in a standings table, keep very short", "L"), i18nc("@info:tooltip", "Lost"), 2),
            column("pointsFor", i18nc("Abbreviation for 'points for' in a basketball standings table, keep very short", "PF"), i18nc("@info:tooltip", "Points for"), 2.2),
            column("pointsAgainst", i18nc("Abbreviation for 'points against' in a basketball standings table, keep very short", "PA"), i18nc("@info:tooltip", "Points against"), 2.4),
            column("pointDifference", i18nc("Abbreviation for 'point differential' in a basketball standings table, keep very short", "+/-"), i18nc("@info:tooltip", "Point differential"), 2.2),
            column("percentage", i18nc("Abbreviation for 'win percentage' in a basketball standings table, keep very short", "Pct"), i18nc("@info:tooltip", "Win percentage"), 3, true)
        ];
    }
    // Tennis "table" = the ATP / WTA world ranking: points and the places gained or
    // lost since the previous ranking update.
    if (value === "tennis") {
        return [
            column("points", i18nc("Abbreviation for 'ranking points' in a tennis rankings table, keep very short", "Pts"), i18nc("@info:tooltip", "Ranking points"), 3.4, true),
            column("trend", i18nc("Abbreviation for 'change since the previous ranking' in a tennis rankings table, keep very short", "+/-"), i18nc("@info:tooltip", "Places gained or lost since the previous ranking"), 2.6)
        ];
    }
    // Cricket is ESPN-only (no SportScore); the columns match ESPN's cricket standings
    // stats: matches played/won/lost, tied-or-drawn, no result, points and net run rate.
    if (value === "cricket") {
        return [
            column("played", i18nc("Abbreviation for 'matches played' in a cricket standings table, keep very short", "M"), i18nc("@info:tooltip", "Matches played"), 2.4),
            column("won", i18nc("Abbreviation for 'won' in a standings table, keep very short", "W"), i18nc("@info:tooltip", "Won"), 2),
            column("lost", i18nc("Abbreviation for 'lost' in a standings table, keep very short", "L"), i18nc("@info:tooltip", "Lost"), 2),
            column("draw", i18nc("Abbreviation for 'tied or drawn' in a cricket standings table, keep very short", "T"), i18nc("@info:tooltip", "Tied or drawn"), 2),
            column("noResult", i18nc("Abbreviation for 'no result' in a cricket standings table, keep very short", "NR"), i18nc("@info:tooltip", "No result"), 2.2),
            column("points", i18nc("Abbreviation for 'points' in a standings table, keep very short", "Pts"), i18nc("@info:tooltip", "Points"), 2.8, true),
            column("netRunRate", i18nc("Abbreviation for 'net run rate' in a cricket standings table, keep very short", "NRR"), i18nc("@info:tooltip", "Net run rate"), 3.6)
        ];
    }
    // Baseball has no draws and no league points: teams are ranked by win pct, with
    // games-behind the leader. Runs scored/against stand in for goals for/against.
    if (value === "baseball") {
        return [
            column("won", i18nc("Abbreviation for 'won' in a standings table, keep very short", "W"), i18nc("@info:tooltip", "Won"), 2),
            column("lost", i18nc("Abbreviation for 'lost' in a standings table, keep very short", "L"), i18nc("@info:tooltip", "Lost"), 2),
            column("winPercent", i18nc("Abbreviation for 'win percentage' in a baseball standings table, keep very short", "PCT"), i18nc("@info:tooltip", "Win percentage"), 2.8, true),
            column("gamesBehind", i18nc("Abbreviation for 'games behind' in a baseball standings table, keep very short", "GB"), i18nc("@info:tooltip", "Games behind"), 2.4),
            column("goalsFor", i18nc("Abbreviation for 'runs scored' in a baseball standings table, keep very short", "RS"), i18nc("@info:tooltip", "Runs scored"), 2.4),
            column("goalsAgainst", i18nc("Abbreviation for 'runs against' in a baseball standings table, keep very short", "RA"), i18nc("@info:tooltip", "Runs against"), 2.4),
            column("goalDifference", i18nc("Abbreviation for 'run differential' in a baseball standings table, keep very short", "DIFF"), i18nc("@info:tooltip", "Run differential"), 2.6)
        ];
    }
    // Ice hockey standings have no draws: a game decided in overtime/shootout counts
    // as an OT loss (OTL), worth a point. Ranked by points, then goals for/against.
    if (value === "hockey") {
        return [
            column("played", i18nc("Abbreviation for 'games played' in a hockey standings table, keep very short", "GP"), i18nc("@info:tooltip", "Games played"), 2.4),
            column("won", i18nc("Abbreviation for 'won' in a standings table, keep very short", "W"), i18nc("@info:tooltip", "Won"), 2),
            column("lost", i18nc("Abbreviation for 'lost' in a standings table, keep very short", "L"), i18nc("@info:tooltip", "Lost"), 2),
            column("otLosses", i18nc("Abbreviation for 'overtime/shootout losses' in a hockey standings table, keep very short", "OTL"), i18nc("@info:tooltip", "Overtime/shootout losses"), 2.6),
            column("goalsFor", i18nc("Abbreviation for 'goals for' in a hockey standings table, keep very short", "GF"), i18nc("@info:tooltip", "Goals for"), 2.2),
            column("goalsAgainst", i18nc("Abbreviation for 'goals against' in a hockey standings table, keep very short", "GA"), i18nc("@info:tooltip", "Goals against"), 2.4),
            column("goalDifference", i18nc("Abbreviation for 'goal differential' in a hockey standings table, keep very short", "DIFF"), i18nc("@info:tooltip", "Goal differential"), 2.6),
            column("points", i18nc("Abbreviation for 'points' in a standings table, keep very short", "Pts"), i18nc("@info:tooltip", "Points"), 2.8, true)
        ];
    }
    // American football has no league points and is ranked by win pct. Ties are a
    // real (if rare) outcome, so the "T" column stays. Points for/against, not goals.
    if (value === "american-football") {
        return [
            column("won", i18nc("Abbreviation for 'won' in a standings table, keep very short", "W"), i18nc("@info:tooltip", "Won"), 2),
            column("lost", i18nc("Abbreviation for 'lost' in a standings table, keep very short", "L"), i18nc("@info:tooltip", "Lost"), 2),
            column("draw", i18nc("Abbreviation for 'tied' in an American football standings table, keep very short", "T"), i18nc("@info:tooltip", "Tied"), 2),
            column("winPercent", i18nc("Abbreviation for 'win percentage' in an American football standings table, keep very short", "PCT"), i18nc("@info:tooltip", "Win percentage"), 2.8, true),
            column("goalsFor", i18nc("Abbreviation for 'points for' in an American football standings table, keep very short", "PF"), i18nc("@info:tooltip", "Points for"), 2.4),
            column("goalsAgainst", i18nc("Abbreviation for 'points against' in an American football standings table, keep very short", "PA"), i18nc("@info:tooltip", "Points against"), 2.4),
            column("goalDifference", i18nc("Abbreviation for 'point differential' in an American football standings table, keep very short", "DIFF"), i18nc("@info:tooltip", "Point differential"), 2.6)
        ];
    }

    return [
        column("played", i18nc("Abbreviation for 'played' in a football/soccer standings table, keep very short", "Pl"), i18nc("@info:tooltip", "Played"), 2.4),
        column("won", i18nc("Abbreviation for 'won' in a standings table, keep very short", "W"), i18nc("@info:tooltip", "Won"), 2),
        column("draw", i18nc("Abbreviation for 'drawn' in a football/soccer standings table, keep very short", "D"), i18nc("@info:tooltip", "Drawn"), 2.2),
        column("lost", i18nc("Abbreviation for 'lost' in a standings table, keep very short", "L"), i18nc("@info:tooltip", "Lost"), 2),
        column("goalsFor", i18nc("Abbreviation for 'goals for' in a football/soccer standings table, keep very short", "F"), i18nc("@info:tooltip", "Goals for"), 2),
        column("goalsAgainst", i18nc("Abbreviation for 'goals against' in a football/soccer standings table, keep very short", "A"), i18nc("@info:tooltip", "Goals against"), 2.4),
        column("goalDifference", i18nc("Abbreviation for 'goal difference' in a football/soccer standings table, keep very short", "GD"), i18nc("@info:tooltip", "Goal difference"), 2),
        column("points", i18nc("Abbreviation for 'points' in a standings table, keep very short", "Pts"), i18nc("@info:tooltip", "Points"), 2.8, true)
    ];
}

function standingsHtmlSchema(sport) {
    const value = normalizedSport(sport);
    if (value === "basketball") {
        return {
            minimumCells: 9,
            formCell: 9,
            fields: {
                played: 2,
                won: 3,
                lost: 4,
                pointsFor: 5,
                pointsAgainst: 6,
                pointDifference: 7,
                percentage: 8
            }
        };
    }
    return {
        minimumCells: 10,
        formCell: 10,
        fields: {
            played: 2,
            won: 3,
            draw: 4,
            lost: 5,
            goalsFor: 6,
            goalsAgainst: 7,
            goalDifference: 8,
            points: 9
        }
    };
}

// Individual / event sports have no league table.
const NO_STANDINGS_SPORTS = ["tennis", "golf", "racing", "mma"];

function supportsStandings(sport) {
    return NO_STANDINGS_SPORTS.indexOf(normalizedSport(sport)) < 0;
}

function standingsHasForm(sport) {
    const value = normalizedSport(sport);
    return value === "football" || value === "basketball";
}

function column(key, label, tooltip, width, emphasized) {
    return {
        key,
        label,
        tooltip,
        width,
        emphasized: Boolean(emphasized)
    };
}

function normalizedSport(value) {
    const result = slug(value);
    return result === "soccer" ? "football" : result;
}

function slug(value) {
    return stringValue(value)
        .toLowerCase()
        .replace(/&/g, "and")
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "");
}

function stringValue(value) {
    return value === undefined || value === null ? "" : String(value).trim();
}
