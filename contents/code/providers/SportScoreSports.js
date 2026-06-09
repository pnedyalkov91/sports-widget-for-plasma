/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
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

function usesPlayers(sport) {
    return normalizedSport(sport) === "tennis";
}

function hasCountryCompetitions(sport) {
    return normalizedSport(sport) !== "tennis";
}

function participantLabel(sport, plural) {
    if (usesPlayers(sport))
        return plural ? "Players" : "Player";
    return plural ? "Teams" : "Team";
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

function matchPrefix(sport) {
    const value = normalizedSport(sport);
    return supports(value) ? "/" + value + "/match/" : "";
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

function supportsStandings(sport) {
    return normalizedSport(sport) !== "tennis";
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
