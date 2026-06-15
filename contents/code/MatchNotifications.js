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

function stringValue(value) {
    return value === undefined || value === null ? "" : String(value);
}

// A stable identity for a match across refreshes. The match URL/path is the
// most reliable; team + competition is a good fallback.
function matchId(match) {
    match = match || {};
    const path = stringValue(match.matchPath || match.liveUrl).trim().toLowerCase();
    if (path.length > 0)
        return path;

    return [stringValue(match.league), stringValue(match.homeTeam), stringValue(match.awayTeam)]
        .join("|")
        .toLowerCase();
}

// A stable identity for a saved competition/team entry, used to opt entries in
// or out of notifications and the calendar. Team entries are keyed by favorite
// team (the saved model clears their league), competitions by league.
function entryKey(entry) {
    entry = entry || {};
    const sport = stringValue(entry.sport).trim().toLowerCase();
    const country = stringValue(entry.country).trim().toLowerCase();
    const favorite = stringValue(entry.favoriteTeam).trim().toLowerCase();
    if (favorite.length > 0)
        return "team|" + sport + "|" + favorite + "|" + country;

    const league = stringValue(entry.league).trim().toLowerCase();
    return "comp|" + sport + "|" + league + "|" + country;
}

function isLiveStatus(status) {
    return stringValue(status).trim().toLowerCase() === "live";
}

function isUpcomingStatus(status) {
    const value = stringValue(status).trim().toLowerCase();
    return value.length === 0 || value === "upcoming" || value === "scheduled";
}

function hasScores(match) {
    return stringValue(match && match.homeScore).length > 0 && stringValue(match && match.awayScore).length > 0;
}

function scoreText(match) {
    return stringValue(match && match.homeScore) + "–" + stringValue(match && match.awayScore);
}

function matchInScope(match, options) {
    options = options || {};
    if (!options.favoriteOnly)
        return true;

    const names = Array.isArray(options.favoriteNames) ? options.favoriteNames : [];
    if (names.length === 0)
        return true;

    const home = stringValue(match && match.homeTeam).toLowerCase();
    const away = stringValue(match && match.awayTeam).toLowerCase();
    return names.some(name => {
        const needle = stringValue(name).trim().toLowerCase();
        return needle.length > 0 && (home.indexOf(needle) >= 0 || away.indexOf(needle) >= 0);
    });
}

function snapshotEntry(match) {
    return {
        "status": stringValue(match.status),
        "homeScore": stringValue(match.homeScore),
        "awayScore": stringValue(match.awayScore),
        "live": isLiveStatus(match.status),
        "homeTeam": stringValue(match.homeTeam),
        "awayTeam": stringValue(match.awayTeam),
        "league": stringValue(match.league),
        "sport": stringValue(match.sport)
    };
}

// Compares the live matches of the previous refresh against the current ones
// and returns the notification events that should fire, plus the new snapshot
// to remember for next time.
//
//   previous     - map of matchId -> snapshotEntry from the last call ({} first time)
//   liveMatches  - current array of live match rows
//   options      - { hasBaseline, triggers:{kickoff,goals,fullTime}, favoriteOnly, favoriteNames }
//
// Events: { kind: "kickoff"|"goal"|"fulltime", match, scoreText }.
function computeLiveNotifications(previous, liveMatches, options) {
    previous = previous || {};
    options = options || {};
    const triggers = options.triggers || {};
    const hasBaseline = options.hasBaseline === true;

    const events = [];
    const snapshot = {};

    (Array.isArray(liveMatches) ? liveMatches : []).forEach(match => {
        const id = matchId(match);
        const entry = snapshotEntry(match);
        snapshot[id] = entry;

        const prev = previous[id];
        if (!hasBaseline || !prev || !matchInScope(match, options))
            return;

        if (triggers.kickoff && !prev.live && entry.live)
            events.push({ "kind": "kickoff", "match": match, "scoreText": "" });

        if (triggers.goals && prev.live && entry.live && hasScores(match)
            && (entry.homeScore !== prev.homeScore || entry.awayScore !== prev.awayScore))
            events.push({ "kind": "goal", "match": match, "scoreText": scoreText(match) });
    });

    // A live match that has vanished from the feed has finished. Fire full-time
    // using its last known score (only when we have a real baseline to compare).
    if (triggers.fullTime && hasBaseline) {
        Object.keys(previous).forEach(id => {
            const prev = previous[id];
            if (!prev || !prev.live || snapshot[id])
                return;

            if (!matchInScope(prev, options))
                return;

            events.push({
                "kind": "fulltime",
                "match": prev,
                "scoreText": hasScores(prev) ? scoreText(prev) : ""
            });
        });
    }

    return { "events": events, "snapshot": snapshot };
}

// Returns scheduled matches whose kickoff falls within the next `minutes` and
// have not been announced yet, marking them announced in `announced` (a map).
//   scheduledMatches - array of upcoming match rows (must carry numeric timestamp)
//   nowMs            - current time in milliseconds
//   minutes          - lead time
//   announced        - map of matchId -> true (mutated)
//   options          - { favoriteOnly, favoriteNames }
function computeStartsSoon(scheduledMatches, nowMs, minutes, announced, options) {
    announced = announced || {};
    options = options || {};
    const windowMs = Math.max(1, Number(minutes) || 0) * 60 * 1000;
    const events = [];

    (Array.isArray(scheduledMatches) ? scheduledMatches : []).forEach(match => {
        let timestamp = Number(match && match.timestamp || 0);
        if (!Number.isFinite(timestamp) || timestamp <= 0)
            return;
        if (timestamp < 100000000000)
            timestamp *= 1000;

        const delta = timestamp - nowMs;
        if (delta <= 0 || delta > windowMs)
            return;

        if (!isUpcomingStatus(match.status))
            return;
        if (!matchInScope(match, options))
            return;

        const id = matchId(match);
        if (announced[id])
            return;

        announced[id] = true;
        events.push({ "kind": "startssoon", "match": match, "minutes": Math.max(1, Math.round(delta / 60000)) });
    });

    return events;
}
