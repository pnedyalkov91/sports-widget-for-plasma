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
    const sport = String(value || "").toLowerCase();
    if (sport.length === 0)
        return "";
    if (sport.indexOf("american") >= 0 || sport === "nfl")
        return "american-football";
    if (sport.indexOf("basket") >= 0 || sport === "nba")
        return "basketball";
    if (sport.indexOf("base") >= 0 || sport === "mlb")
        return "baseball";
    if (sport.indexOf("cricket") >= 0)
        return "cricket";
    if (sport.indexOf("hockey") >= 0 || sport === "nhl")
        return "hockey";
    if (sport.indexOf("snooker") >= 0)
        return "snooker";
    if (sport.indexOf("tennis") >= 0)
        return "tennis";
    if (sport.indexOf("volley") >= 0)
        return "volleyball";
    return "football";
}

function emoji(value) {
    const sport = normalizedSport(value);
    const emojis = {
        "american-football": "🏈",
        "baseball": "⚾",
        "basketball": "🏀",
        "cricket": "🏏",
        "football": "⚽",
        "hockey": "🏒",
        "snooker": "🎱",
        "tennis": "🎾",
        "volleyball": "🏐"
    };
    return emojis[sport] || "🏆";
}

function label(value) {
    const sport = normalizedSport(value);
    const labels = {
        "american-football": "American Football",
        "baseball": "Baseball",
        "basketball": "Basketball",
        "cricket": "Cricket",
        "football": "Football",
        "hockey": "Hockey",
        "snooker": "Snooker",
        "tennis": "Tennis",
        "volleyball": "Volleyball"
    };
    return labels[sport] || "Sports";
}
