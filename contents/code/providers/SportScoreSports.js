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
    { label: "Cricket", value: "cricket" },
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
    if (value === "cricket")
        return "/" + value + "/";
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

function standingsColumns(sport) {
    const value = normalizedSport(sport);
    if (value === "basketball") {
        return [
            column("played", "GP", "Games played", 2.4),
            column("won", "W", "Won", 2),
            column("lost", "L", "Lost", 2),
            column("pointsFor", "PF", "Points for", 2.2),
            column("pointsAgainst", "PA", "Points against", 2.4),
            column("pointDifference", "+/-", "Point differential", 2.2),
            column("percentage", "Pct", "Win percentage", 3, true)
        ];
    }
    if (value === "cricket") {
        return [
            column("played", "M", "Matches played", 2.4),
            column("won", "W", "Won", 2),
            column("lost", "L", "Lost", 2),
            column("tied", "T", "Tied or drawn", 2),
            column("noResult", "NR", "No result", 2.2),
            column("points", "Pts", "Points", 2.8, true)
        ];
    }

    return [
        column("played", "Pl", "Played", 2.4),
        column("won", "W", "Won", 2),
        column("draw", "D", "Drawn", 2.2),
        column("lost", "L", "Lost", 2),
        column("goalsFor", "F", "Goals for", 2),
        column("goalsAgainst", "A", "Goals against", 2.4),
        column("goalDifference", "GD", "Goal difference", 2),
        column("points", "Pts", "Points", 2.8, true)
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
    if (value === "cricket") {
        return {
            minimumCells: 8,
            formCell: -1,
            fields: {
                played: 2,
                won: 3,
                lost: 4,
                tied: 5,
                noResult: 6,
                points: 7
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
