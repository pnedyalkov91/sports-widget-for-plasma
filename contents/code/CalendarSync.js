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

// Folds a single content line to <=75 octets as required by RFC 5545. We keep
// it simple and fold on character count, which is safe for our mostly-ascii
// content; continuation lines start with a single space.
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

function buildEvent(match, nowMs, reminderMinutes) {
    const startMs = normalizedTimestampMs(match);
    if (startMs <= 0)
        return [];

    const endMs = startMs + durationMinutes(match && match.sport) * 60 * 1000;
    const lines = [];
    lines.push("BEGIN:VEVENT");
    lines.push("UID:" + matchUid(match));
    // DTSTAMP must be stable across rebuilds (deriving it from "now" would make
    // every sync produce a different file, forcing needless Akonadi reloads).
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

// Builds a complete VCALENDAR document for the given upcoming matches. Past
// matches (and ones without a usable kickoff time) are skipped. Returns a
// string terminated with CRLF line endings, ready to write to an .ics file.
function buildCalendar(matches, options) {
    options = options || {};
    const nowMs = Number(options.nowMs) || Date.now();
    const reminderMinutes = Number(options.reminderMinutes) || 0;
    const calendarName = stringValue(options.calendarName || "Sports");
    // Drop matches older than the start of yesterday. Using a day-granular floor
    // (rather than "now - Nh") keeps the generated file byte-identical all day for
    // an unchanged fixture list, so the cache prevents needless rewrites/reloads.
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

    // Emit in a deterministic order (kickoff, then teams) so an unchanged set of
    // fixtures always produces a byte-identical file regardless of input order.
    const ordered = (Array.isArray(matches) ? matches.slice() : []).sort((left, right) => {
        const leftStart = normalizedTimestampMs(left);
        const rightStart = normalizedTimestampMs(right);
        if (leftStart !== rightStart)
            return leftStart - rightStart;
        return stringValue(matchUid(left)).localeCompare(stringValue(matchUid(right)));
    });

    ordered.forEach(match => {
        const startMs = normalizedTimestampMs(match);
        if (startMs < floorMs)
            return;

        const uid = matchUid(match);
        if (seen[uid])
            return;
        seen[uid] = true;

        buildEvent(match, nowMs, reminderMinutes).forEach(line => lines.push(line));
    });

    lines.push("END:VCALENDAR");
    return lines.map(foldLine).join("\r\n") + "\r\n";
}

function eventCount(icsText) {
    const matches = stringValue(icsText).match(/BEGIN:VEVENT/g);
    return matches ? matches.length : 0;
}

// Marker grepped for in the resource rc files to find our own ical resources.
var RESOURCE_PATH_MARKER = "sports-widget-for-plasma/sports-matches.ics";

// POSIX-sh script (run via `sh`) that guarantees exactly one read-only Akonadi
// iCal resource points at our file. It de-duplicates any extra instances (the
// cause of calendar duplication), (re)creates one if missing, then sets its
// path, display name and read-only flag. Read-only stops Akonadi writing back
// to the file, which otherwise fights the widget's own writes.
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
        // Collect every resource pointing at our file; keep the first, drop the rest.
        "matches=\"\"",
        "for rc in \"$HOME\"/.config/akonadi_ical_resource_*rc; do",
        "  [ -e \"$rc\" ] || continue",
        "  grep -q \"" + RESOURCE_PATH_MARKER + "\" \"$rc\" && matches=\"$matches $(basename \"$rc\" | sed -E 's/rc$//')\"",
        "done",
        "set -- $matches",
        "keep=\"${1:-}\"",
        "[ -n \"$keep\" ] && shift",
        "for extra in \"$@\"; do qdbus $AM.removeAgentInstance \"$extra\" >/dev/null 2>&1 || true; done",
        // Create via konsolekalendar (reliably sets the file path) only when none exists.
        "if [ -z \"$keep\" ]; then",
        "  konsolekalendar --create \"$ICS\" >/dev/null 2>&1 || true",
        "  sleep 1"
    ].concat(findKept.map(line => "  " + line)).concat([
        "fi",
        "[ -n \"$keep\" ] || exit 0",
        // Wait for the resource's D-Bus service before configuring it.
        "i=0; while [ $i -lt 50 ]; do qdbus \"org.freedesktop.Akonadi.Resource.$keep\" /Settings >/dev/null 2>&1 && break; sleep 0.2; i=$((i+1)); done",
        "S=\"org.freedesktop.Akonadi.Resource.$keep /Settings org.kde.Akonadi.ICal.Settings\"",
        // Mark read-only (so Akonadi never writes back to our file) and rename.
        // save() persists to the rc; reconfigure applies it to the running agent.
        // Applied twice with a settle in between so a still-initialising agent
        // cannot clobber the values by reloading its config afterwards.
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
        "qdbus org.freedesktop.Akonadi.Resource.$keep / org.freedesktop.Akonadi.Resource.synchronize >/dev/null 2>&1 || true"
    ]).join("\n");
}

// POSIX-sh script that removes every ical resource pointing at our file and
// deletes the generated files (used when the user turns calendar sync off).
function resourceRemoveScript(icsPath) {
    return [
        "AM=\"org.freedesktop.Akonadi.Control /AgentManager org.freedesktop.Akonadi.AgentManager\"",
        "for rc in \"$HOME\"/.config/akonadi_ical_resource_*rc; do",
        "  [ -e \"$rc\" ] || continue",
        "  grep -q \"" + RESOURCE_PATH_MARKER + "\" \"$rc\" && qdbus $AM.removeAgentInstance \"$(basename \"$rc\" | sed -E 's/rc$//')\" >/dev/null 2>&1 || true",
        "done",
        "rm -f \"" + stringValue(icsPath) + "\" \"" + stringValue(icsPath) + "~\""
    ].join("\n");
}
