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

function normalizedSport(value) {
    const sport = String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
    if (sport.length === 0)
        return "";
    // Canonicalise common aliases to the widget's sport ids; everything else
    // passes through unchanged so new ESPN sports keep their own id.
    if (sport === "soccer")
        return "football";
    if (sport === "nfl")
        return "american-football";
    if (sport === "nba" || sport === "wnba")
        return "basketball";
    if (sport === "mlb")
        return "baseball";
    if (sport === "nhl" || sport === "ice-hockey")
        return "hockey";
    if (sport === "f1" || sport === "formula-1" || sport === "nascar")
        return "racing";
    if (sport === "ufc")
        return "mma";
    return sport;
}

function emoji(value) {
    const sport = normalizedSport(value);
    const emojis = {
        "american-football": "🏈",
        "australian-football": "🏉",
        "baseball": "⚾",
        "basketball": "🏀",
        "cricket": "🏏",
        "field-hockey": "🏑",
        "football": "⚽",
        "golf": "⛳",
        "hockey": "🏒",
        "lacrosse": "🥍",
        "mma": "🥊",
        "racing": "🏎️",
        "rugby": "🏉",
        "rugby-league": "🏉",
        "snooker": "🎱",
        "tennis": "🎾",
        "volleyball": "🏐",
        "water-polo": "🤽"
    };
    return emojis[sport] || "🏆";
}

function label(value) {
    const sport = normalizedSport(value);
    const labels = {
        "american-football": "American Football",
        "australian-football": "Australian Football",
        "baseball": "Baseball",
        "basketball": "Basketball",
        "cricket": "Cricket",
        "field-hockey": "Field Hockey",
        "football": "Football",
        "golf": "Golf",
        "hockey": "Ice Hockey",
        "lacrosse": "Lacrosse",
        "mma": "MMA",
        "racing": "Racing",
        "rugby": "Rugby",
        "rugby-league": "Rugby League",
        "snooker": "Snooker",
        "tennis": "Tennis",
        "volleyball": "Volleyball",
        "water-polo": "Water Polo"
    };
    return labels[sport] || titleFromSlug(sport);
}

function titleFromSlug(value) {
    return String(value || "")
        .replace(/[-_]+/g, " ")
        .replace(/\s+/g, " ")
        .trim()
        .split(" ")
        .filter(part => part.length > 0)
        .map(part => part.charAt(0).toUpperCase() + part.slice(1))
        .join(" ") || "Sports";
}
