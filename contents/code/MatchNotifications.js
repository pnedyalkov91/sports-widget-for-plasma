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

// Whether the live "minute" field denotes the half-time break (as opposed to a
// numeric playing minute). The widget's live model normalizes the break to
// "HT" (see SportsApi/main.qml liveMatchForModel), but tolerate the raw
// provider spellings too.
function isHalfTimeMinute(minute) {
    const value = stringValue(minute).trim().toLowerCase();
    return value === "ht" || value === "half-time" || value === "half time" || value === "halftime" || value === "break";
}

// Whether the "minute" field denotes second-half play has resumed (a plain
// numeric minute, not the empty/"HT"/extra-time-style value seen during the
// break). Used only to detect the HT -> playing transition.
function isSecondHalfMinute(minute) {
    const value = stringValue(minute).trim();
    return /^\d{1,3}(\+\d{0,2})?$/.test(value);
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

    // A match the user explicitly opted in via the per-match bell always fires,
    // regardless of the favourite-only filter.
    if (typeof options.forceInclude === "function" && options.forceInclude(match))
        return true;

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
        "sport": stringValue(match.sport),
        "minute": stringValue(match.minute)
    };
}

// Compares the live matches of the previous refresh against the current ones
// and returns the notification events that should fire, plus the new snapshot
// to remember for next time.
//
//   previous     - map of matchId -> snapshotEntry from the last call ({} first time)
//   liveMatches  - current array of live match rows
//   options      - { hasBaseline, triggers:{kickoff,goals,halfTime,fullTime}, favoriteOnly,
//                    favoriteNames, isUnreliable(prevEntry), detailedEventsAvailable(match) }
//
// Events: { kind: "kickoff"|"goal"|"halftime"|"secondhalf"|"fulltime", match, scoreText }.
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

        // When detailed events are on for this match, the incidents poll fires a
        // single enriched "goalscorer" notification instead (see
        // computeIncidentNotifications) - skip this plain one to avoid double
        // notifying the same goal.
        const hasDetailedEvents = typeof options.detailedEventsAvailable === "function" && options.detailedEventsAvailable(match);
        if (triggers.goals && !hasDetailedEvents && prev.live && entry.live && hasScores(match)
            && (entry.homeScore !== prev.homeScore || entry.awayScore !== prev.awayScore))
            events.push({ "kind": "goal", "match": match, "scoreText": scoreText(match) });

        if (triggers.halfTime && prev.live && entry.live) {
            if (!isHalfTimeMinute(prev.minute) && isHalfTimeMinute(entry.minute))
                events.push({ "kind": "halftime", "match": match, "scoreText": hasScores(match) ? scoreText(match) : "" });
            else if (isHalfTimeMinute(prev.minute) && isSecondHalfMinute(entry.minute))
                events.push({ "kind": "secondhalf", "match": match, "scoreText": hasScores(match) ? scoreText(match) : "" });
        }
    });

    // A live match that has vanished from the feed has finished. Fire full-time
    // using its last known score (only when we have a real baseline to compare).
    // Exception: if the match vanished only because its competition/team's fetch
    // failed this refresh (see options.isUnreliable), it has not necessarily
    // ended - a flaky provider response should not be read as full-time.
    if (triggers.fullTime && hasBaseline) {
        const isUnreliable = typeof options.isUnreliable === "function" ? options.isUnreliable : null;
        Object.keys(previous).forEach(id => {
            const prev = previous[id];
            if (!prev || !prev.live || snapshot[id])
                return;

            if (!matchInScope(prev, options))
                return;

            if (isUnreliable && isUnreliable(prev))
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

// A stable-enough identity for one incident within a match (incidents have no
// id of their own from either provider): kind + player + minute is unique for
// all practical purposes (two different players don't score in the same
// minute on the same side without distinct names).
function incidentId(incident) {
    incident = incident || {};
    return [stringValue(incident.kind), stringValue(incident.side), stringValue(incident.player), stringValue(incident.minute)]
        .join("|")
        .toLowerCase();
}

// Maps an incident's provider-agnostic kind (see sportScoreWidgetIncidents /
// fetchEspnMatchIncidents in SportsApi.js) to a notification kind.
function notificationKindForIncident(kind) {
    const value = stringValue(kind).toLowerCase();
    if (value === "goal")
        return "goalscorer";
    if (value === "yellow")
        return "yellowcard";
    if (value === "red")
        return "redcard";
    if (value === "substitution")
        return "substitution";
    if (value === "extratime")
        return "extratime";
    if (value === "extratimesecondhalf")
        return "extratimesecondhalf";
    if (value === "shootout")
        return "shootout";
    return "";
}

// Diffs one match's current incident list against the set of incident ids
// already notified for it, returning the new notification events and the
// updated id set (to persist for next time).
//   previousIds  - array of incidentId() strings already notified for this match
//   match        - the match row (for building notification events)
//   incidents    - current incident rows from fetchEspnMatchIncidents/
//                  sportScoreWidgetIncidents
//   triggers     - { goals, cards, substitutions, halfTime } - which kinds to
//                  notify (halfTime also gates extratime/extratimesecondhalf/
//                  shootout, the same "match phase changed" family)
function computeIncidentNotifications(previousIds, match, incidents, triggers) {
    const seen = {};
    (Array.isArray(previousIds) ? previousIds : []).forEach(id => { seen[id] = true; });

    triggers = triggers || {};
    const events = [];
    const nextIds = [];

    (Array.isArray(incidents) ? incidents : []).forEach(incident => {
        const id = incidentId(incident);
        nextIds.push(id);
        if (seen[id])
            return;

        const notifKind = notificationKindForIncident(incident && incident.kind);
        if (notifKind.length === 0)
            return;
        if (notifKind === "goalscorer" && !triggers.goals)
            return;
        if ((notifKind === "yellowcard" || notifKind === "redcard") && !triggers.cards)
            return;
        if (notifKind === "substitution" && !triggers.substitutions)
            return;
        // Same "match phase changed" family as half-time/second-half (which use
        // the lightweight scoreboard field instead); reuse that trigger rather
        // than invent a separate one for this knockout-only scenario.
        if ((notifKind === "extratime" || notifKind === "extratimesecondhalf" || notifKind === "shootout") && !triggers.halfTime)
            return;

        const isPhaseChange = notifKind === "extratime" || notifKind === "extratimesecondhalf" || notifKind === "shootout";
        events.push({
            "kind": notifKind,
            "match": match,
            "incident": incident,
            "scoreText": isPhaseChange && hasScores(match) ? scoreText(match) : ""
        });
    });

    return { "events": events, "incidentIds": nextIds };
}
