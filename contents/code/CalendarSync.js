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

function normalizedTimestampMs(match) {
    let timestamp = Number(match && match.timestamp || 0);
    if (!Number.isFinite(timestamp) || timestamp <= 0)
        return 0;
    if (timestamp < 100000000000)
        timestamp *= 1000;
    return timestamp;
}

// Default match duration per sport, in minutes, used for the event end time.
function durationMinutes(sport) {
    switch (stringValue(sport).trim().toLowerCase()) {
    case "basketball":
        return 150;
    case "american-football":
    case "americanfootball":
        return 210;
    case "cricket":
        return 480;
    case "tennis":
        return 150;
    case "hockey":
    case "ice-hockey":
        return 150;
    default:
        return 120;
    }
}

function pad(number, width) {
    let text = String(Math.abs(number));
    while (text.length < width)
        text = "0" + text;
    return text;
}

// UTC timestamp in iCalendar form: 20260614T173000Z
function toICalUtc(ms) {
    const date = new Date(ms);
    return date.getUTCFullYear()
        + pad(date.getUTCMonth() + 1, 2)
        + pad(date.getUTCDate(), 2)
        + "T"
        + pad(date.getUTCHours(), 2)
        + pad(date.getUTCMinutes(), 2)
        + pad(date.getUTCSeconds(), 2)
        + "Z";
}

// RFC 5545 text escaping for property values.
function escapeText(value) {
    return stringValue(value)
        .replace(/\\/g, "\\\\")
        .replace(/;/g, "\\;")
        .replace(/,/g, "\\,")
        .replace(/\r?\n/g, "\\n");
}

// A short, stable, ascii-only token derived from a string (used in UIDs).
function slugToken(value) {
    let hash = 0;
    const text = stringValue(value);
    for (let index = 0; index < text.length; index += 1) {
        hash = ((hash << 5) - hash + text.charCodeAt(index)) | 0;
    }
    return (hash >>> 0).toString(36);
}

function matchUid(match) {
    match = match || {};
    const path = stringValue(match.matchPath || match.liveUrl).trim();
    const base = path.length > 0
        ? path
        : [stringValue(match.league), stringValue(match.homeTeam), stringValue(match.awayTeam), String(normalizedTimestampMs(match))].join("|");
    return "sports-" + slugToken(base.toLowerCase()) + "@sports-widget-for-plasma";
}

function isUpcomingStatus(status) {
    const value = stringValue(status).trim().toLowerCase();
    return value.length === 0 || value === "upcoming" || value === "scheduled";
}

// Calendar summary: "{emoji} Home 2 - 1 Away · League" once a score exists,
// otherwise "{emoji} Home vs Away · League". A calendar event cannot carry team
// badge images, so the sport emoji stands in as a lightweight "emblem".
function eventSummary(match) {
    match = match || {};
    const emoji = stringValue(match.emoji).trim();
    const home = stringValue(match.homeTeam).trim();
    const away = stringValue(match.awayTeam).trim();
    const homeScore = stringValue(match.homeScore).trim();
    const awayScore = stringValue(match.awayScore).trim();

    const middle = (!isUpcomingStatus(match.status) && homeScore.length > 0 && awayScore.length > 0)
        ? homeScore + " - " + awayScore
        : "vs";

    let summary = (emoji.length > 0 ? emoji + " " : "") + home + " " + middle + " " + away;
    const league = stringValue(match.league).trim();
    if (league.length > 0)
        summary += " · " + league;
    return summary;
}

function eventDescription(match) {
    match = match || {};
    const parts = [];
    const league = stringValue(match.league).trim();
    const matchday = stringValue(match.matchday).trim();
    if (league.length > 0)
        parts.push(league);
    if (matchday.length > 0)
        parts.push(matchday);
    return parts.join(" · ");
}


// Default event color (Plasma highlight-ish green) shown in the calendar grid.
var EVENT_COLOR = "#27ae60";

// Builds the inert JSON snapshot consumed by the bundled Plasma calendar-events
// plugin (plugin/sportsmatchesevents). The plugin feeds these straight to the
// Plasma calendar in memory - no .ics, no Akonadi, no PIM indexer - so it cannot
// hang plasmashell. Returns a JSON string: { "matches": [ {startMs, ...} ] }.
//
// Each entry carries:
//   startMs          - kickoff time in epoch milliseconds (UTC)
//   durationMinutes  - per-sport default match length
//   title            - "{emoji} Home vs Away · League" (or with score)
//   description      - league · matchday
//   uid              - stable id (so the plugin can de-duplicate)
//   color            - grid color
function buildSnapshot(matches, options) {
    options = options || {};
    const nowMs = Number(options.nowMs) || Date.now();
    // Drop matches older than the start of yesterday (day-granular floor keeps the
    // snapshot stable all day for an unchanged fixture list).
    const nowDate = new Date(nowMs);
    const floorMs = new Date(nowDate.getFullYear(), nowDate.getMonth(), nowDate.getDate()).getTime() - 24 * 60 * 60 * 1000;

    const seen = {};
    const ordered = (Array.isArray(matches) ? matches.slice() : []).sort((left, right) => {
        const leftStart = normalizedTimestampMs(left);
        const rightStart = normalizedTimestampMs(right);
        if (leftStart !== rightStart)
            return leftStart - rightStart;
        return stringValue(matchUid(left)).localeCompare(stringValue(matchUid(right)));
    });

    const rows = [];
    ordered.forEach(match => {
        const startMs = normalizedTimestampMs(match);
        if (startMs <= 0 || startMs < floorMs)
            return;

        const uid = matchUid(match);
        if (seen[uid])
            return;
        seen[uid] = true;

        rows.push({
            "startMs": startMs,
            "durationMinutes": durationMinutes(match && match.sport),
            "title": eventSummary(match),
            "description": eventDescription(match),
            "uid": uid,
            "color": EVENT_COLOR
        });
    });

    return JSON.stringify({ "matches": rows });
}

// --- Optional iCalendar (.ics) export -------------------------------------
// This is an EXPORT-ONLY file the user can import into any calendar app. It is
// never registered as an Akonadi resource (that is what used to hang Plasma);
// it is just a plain file written to disk for the user to subscribe to/import.

// Folds a content line to <=75 octets as required by RFC 5545; continuation
// lines start with a single space.
function foldLine(line) {
    if (line.length <= 75)
        return line;

    const chunks = [];
    let remaining = line;
    chunks.push(remaining.slice(0, 75));
    remaining = remaining.slice(75);
    while (remaining.length > 0) {
        chunks.push(" " + remaining.slice(0, 74));
        remaining = remaining.slice(74);
    }
    return chunks.join("\r\n");
}

function buildEvent(match, reminderMinutes) {
    const startMs = normalizedTimestampMs(match);
    if (startMs <= 0)
        return [];

    const endMs = startMs + durationMinutes(match && match.sport) * 60 * 1000;
    const lines = [];
    lines.push("BEGIN:VEVENT");
    lines.push("UID:" + matchUid(match));
    // DTSTAMP stable across rebuilds (deriving from "now" would change the file
    // on every write).
    lines.push("DTSTAMP:" + toICalUtc(startMs));
    lines.push("DTSTART:" + toICalUtc(startMs));
    lines.push("DTEND:" + toICalUtc(endMs));
    lines.push("SUMMARY:" + escapeText(eventSummary(match)));

    const description = eventDescription(match);
    if (description.length > 0)
        lines.push("DESCRIPTION:" + escapeText(description));

    const location = stringValue(match && match.stadium).trim();
    if (location.length > 0)
        lines.push("LOCATION:" + escapeText(location));

    lines.push("TRANSP:TRANSPARENT");

    const reminder = Math.max(0, Number(reminderMinutes) || 0);
    if (reminder > 0) {
        lines.push("BEGIN:VALARM");
        lines.push("ACTION:DISPLAY");
        lines.push("DESCRIPTION:" + escapeText(eventSummary(match)));
        lines.push("TRIGGER:-PT" + reminder + "M");
        lines.push("END:VALARM");
    }

    lines.push("END:VEVENT");
    return lines;
}

// Builds a complete VCALENDAR document for the given matches. Past matches (and
// ones without a usable kickoff time) are skipped. CRLF line endings.
function buildIcs(matches, options) {
    options = options || {};
    const nowMs = Number(options.nowMs) || Date.now();
    const reminderMinutes = Number(options.reminderMinutes) || 0;
    const calendarName = stringValue(options.calendarName || "Sports Widget for Plasma");
    const nowDate = new Date(nowMs);
    const floorMs = new Date(nowDate.getFullYear(), nowDate.getMonth(), nowDate.getDate()).getTime() - 24 * 60 * 60 * 1000;

    const seen = {};
    const lines = [];
    lines.push("BEGIN:VCALENDAR");
    lines.push("VERSION:2.0");
    lines.push("PRODID:-//Sports Widget for Plasma//Match Calendar//EN");
    lines.push("CALSCALE:GREGORIAN");
    lines.push("METHOD:PUBLISH");
    lines.push("X-WR-CALNAME:" + escapeText(calendarName));

    const ordered = (Array.isArray(matches) ? matches.slice() : []).sort((left, right) => {
        const leftStart = normalizedTimestampMs(left);
        const rightStart = normalizedTimestampMs(right);
        if (leftStart !== rightStart)
            return leftStart - rightStart;
        return stringValue(matchUid(left)).localeCompare(stringValue(matchUid(right)));
    });

    ordered.forEach(match => {
        const startMs = normalizedTimestampMs(match);
        if (startMs <= 0 || startMs < floorMs)
            return;
        const uid = matchUid(match);
        if (seen[uid])
            return;
        seen[uid] = true;
        buildEvent(match, reminderMinutes).forEach(line => lines.push(line));
    });

    lines.push("END:VCALENDAR");
    return lines.map(foldLine).join("\r\n") + "\r\n";
}

// --- Optional Akonadi (live KDE Plasma calendar via PIM) ------------------
// UNSTABLE / NOT RECOMMENDED. Registering the exported .ics as a read-only
// Akonadi ical resource makes it a "live" KDE calendar, but on some systems the
// PIM stack reconciles and re-indexes every event on each write and can freeze
// plasmashell. The native in-memory plugin is the recommended path; this exists
// only as an opt-in escape hatch and requires the .ics export to be enabled.

// Marker grepped for in the resource rc files to find our own ical resources.
var RESOURCE_PATH_MARKER = "sports-widget-for-plasma/sports-matches.ics";

// POSIX-sh script (run via `sh`) that guarantees exactly one read-only Akonadi
// iCal resource points at our file. De-duplicates extras, (re)creates one if
// missing, then sets its path, display name and read-only flag, and brings it
// online. Read-only stops Akonadi writing back to the file.
function resourceEnsureScript(icsPath, displayName) {
    const name = stringValue(displayName).replace(/["$`\\]/g, "");
    const findKept = [
        "keep=\"\"",
        "for rc in \"$HOME\"/.config/akonadi_ical_resource_*rc; do",
        "  [ -e \"$rc\" ] || continue",
        "  grep -q \"" + RESOURCE_PATH_MARKER + "\" \"$rc\" && keep=\"$(basename \"$rc\" | sed -E 's/rc$//')\"",
        "done"
    ];
    return [
        "AM=\"org.freedesktop.Akonadi.Control /AgentManager org.freedesktop.Akonadi.AgentManager\"",
        "ICS=\"" + stringValue(icsPath) + "\"",
        "NAME=\"" + name + "\"",
        "matches=\"\"",
        "for rc in \"$HOME\"/.config/akonadi_ical_resource_*rc; do",
        "  [ -e \"$rc\" ] || continue",
        "  grep -q \"" + RESOURCE_PATH_MARKER + "\" \"$rc\" && matches=\"$matches $(basename \"$rc\" | sed -E 's/rc$//')\"",
        "done",
        "set -- $matches",
        "keep=\"${1:-}\"",
        "[ -n \"$keep\" ] && shift",
        "for extra in \"$@\"; do qdbus $AM.removeAgentInstance \"$extra\" >/dev/null 2>&1 || true; done",
        "if [ -z \"$keep\" ]; then",
        "  konsolekalendar --create \"$ICS\" >/dev/null 2>&1 || true",
        "  sleep 1"
    ].concat(findKept.map(line => "  " + line)).concat([
        "fi",
        "[ -n \"$keep\" ] || exit 0",
        "i=0; while [ $i -lt 50 ]; do qdbus \"org.freedesktop.Akonadi.Resource.$keep\" /Settings >/dev/null 2>&1 && break; sleep 0.2; i=$((i+1)); done",
        "S=\"org.freedesktop.Akonadi.Resource.$keep /Settings org.kde.Akonadi.ICal.Settings\"",
        "configure() {",
        "  qdbus $S.setReadOnly true >/dev/null 2>&1 || true",
        "  qdbus $S.setDisplayName \"$NAME\" >/dev/null 2>&1 || true",
        "  qdbus $S.save >/dev/null 2>&1 || true",
        "  qdbus $AM.setAgentInstanceName \"$keep\" \"$NAME\" >/dev/null 2>&1 || true",
        "  qdbus org.freedesktop.Akonadi.Resource.$keep / org.freedesktop.Akonadi.Agent.Control.reconfigure >/dev/null 2>&1 || true",
        "}",
        "configure",
        "sleep 2",
        "configure",
        "qdbus $AM.setAgentInstanceOnline \"$keep\" true >/dev/null 2>&1 || true",
        "qdbus org.freedesktop.Akonadi.Resource.$keep / org.freedesktop.Akonadi.Resource.synchronize >/dev/null 2>&1 || true"
    ]).join("\n");
}

// POSIX-sh script that takes our ical resource(s) OFFLINE (used when Akonadi
// mode is turned off / calendar disabled). Offline is a single fast call that
// stops the reconcile churn without the removal-time spin; the resource and
// file are left in place and can be removed from calendar settings.
function resourceOfflineScript() {
    return [
        "AM=\"org.freedesktop.Akonadi.Control /AgentManager org.freedesktop.Akonadi.AgentManager\"",
        "for rc in \"$HOME\"/.config/akonadi_ical_resource_*rc; do",
        "  [ -e \"$rc\" ] || continue",
        "  grep -q \"" + RESOURCE_PATH_MARKER + "\" \"$rc\" || continue",
        "  id=\"$(basename \"$rc\" | sed -E 's/rc$//')\"",
        "  qdbus $AM.setAgentInstanceOnline \"$id\" false >/dev/null 2>&1 || true",
        "done"
    ].join("\n");
}
