/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library
.import "providers/ProviderCatalog.js" as ProviderCatalog
.import "providers/SportScoreSports.js" as SportScoreSports

function create(serializedEntries, options) {
    options = options || {};

    const entries = parseEntries(serializedEntries, options);
    const activeIndex = normalizedActiveIndex(entries, options.activeIndex);
    const activeEntry = activeSavedEntry(entries, activeIndex);
    const primaryCompetition = firstCompetitionEntry(entries, activeEntry);

    return {
        entries: entries,
        count: entries.length,
        activeIndex: activeIndex,
        activeEntry: activeEntry,
        primaryCompetition: primaryCompetition,
        sports: uniqueSports(entries),
        entriesForSport: function(sport) {
            return entriesForSport(entries, sport);
        },
        activeEntryForSport: function(sport) {
            return activeEntryForSport(entries, activeEntry, sport);
        },
        primaryCompetitionForSport: function(sport) {
            const sportEntries = entriesForSport(entries, sport);
            return firstCompetitionEntry(sportEntries, activeEntryForSport(entries, activeEntry, sport));
        },
        scopeEntries: function(flagName, sport) {
            return scopeEntries(entries, flagName, sport);
        },
        liveScopeEntries: function(sport) {
            return scopeEntries(entries, "includeLive", sport);
        },
        scheduleScopeEntries: function(sport) {
            return scopeEntries(entries, "includeSchedules", sport);
        },
        recentScopeEntries: function(sport) {
            return scopeEntries(entries, "includeRecent", sport);
        },
        tableScopeEntries: function(sport) {
            return scopeEntries(entries, "includeTables", sport);
        },
        panelScopeEntries: function(sport) {
            return scopeEntries(entries, "includePanel", sport);
        },
        tooltipScopeEntries: function(sport) {
            return scopeEntries(entries, "includeTooltip", sport);
        },
        watchedTeamEntries: function(flagName, sport) {
            return watchedTeamEntries(entriesForSport(entries, sport), activeEntryForSport(entries, activeEntry, sport), flagName);
        },
        watchedTeamNames: function(sport) {
            return watchedTeamNames(entriesForSport(entries, sport), activeEntryForSport(entries, activeEntry, sport));
        },
        teamWatchMode: function(sport) {
            const sportEntries = entriesForSport(entries, sport);
            return watchedTeamEntries(sportEntries, activeEntryForSport(entries, activeEntry, sport)).length > 0;
        }
    };
}

function parseEntries(serializedEntries, options) {
    try {
        const parsed = JSON.parse(stringValue(serializedEntries || "[]"));
        return Array.isArray(parsed) ? parsed.map(entry => normalizeEntry(entry, options)) : [];
    } catch (error) {
        return [];
    }
}

function normalizeEntry(entry, options) {
    options = options || {};

    const copy = Object.assign({}, entry || {});
    copy.type = entryType(copy);
    copy.followMode = copy.type === "team" ? "team" : "league";
    copy.includeLive = copy.includeLive !== false;
    copy.includeSchedules = copy.includeSchedules !== false;
    copy.includeRecent = copy.includeRecent !== false;
    copy.includeTables = copy.includeTables !== false;
    copy.includePanel = copy.includePanel !== false;
    copy.includeTooltip = copy.includeTooltip !== false;
    if (!SportScoreSports.supportsStandings(copy.sport))
        copy.includeTables = false;

    if (copy.type === "team") {
        copy.favoriteTeam = stripLegacyTeamPrefix(copy.customFavoriteTeamLabel || copy.favoriteTeam || copy.customLeagueLabel || copy.leagueLabel || copy.league || "");
        copy.league = "";
        copy.leagueLabel = stringValue(options.allCompetitionsLabel || "All competitions");
    } else {
        copy.favoriteTeam = stringValue(copy.favoriteTeam).trim();
    }

    delete copy.starred;
    return copy;
}

function normalizedActiveIndex(entries, configuredIndex) {
    entries = Array.isArray(entries) ? entries : [];
    if (entries.length === 0)
        return -1;

    const configured = Number(configuredIndex || 0);
    const index = Number.isFinite(configured) ? Math.round(configured) : 0;
    return Math.max(0, Math.min(entries.length - 1, index));
}

function activeSavedEntry(entries, activeIndex) {
    entries = Array.isArray(entries) ? entries : [];
    if (entries.length === 0)
        return {};

    return entries[activeIndex] || entries[0] || {};
}

function firstCompetitionEntry(entries, fallbackEntry) {
    entries = Array.isArray(entries) ? entries : [];
    for (let index = 0; index < entries.length; index += 1) {
        const entry = entries[index] || {};
        if (entryType(entry) === "competition" && stringValue(entry.league).trim().length > 0)
            return entry;
    }

    return fallbackEntry || {};
}

function hasEntryTarget(entry) {
    if (entryType(entry) === "team")
        return stringValue(entry && entry.favoriteTeam).trim().length > 0;

    return stringValue(entry && entry.league).trim().length > 0;
}

function scopeEntries(entries, flagName, sport) {
    entries = entriesForSport(entries, sport);
    return entries.filter(entry => {
        if (!hasEntryTarget(entry))
            return false;

        return entry && entry[flagName] !== false;
    });
}

function uniqueSports(entries) {
    const seen = {};
    const sports = [];
    (Array.isArray(entries) ? entries : []).forEach(entry => {
        const sport = ProviderCatalog.normalizedSport(entry && entry.sport);
        if (sport.length === 0 || seen[sport])
            return;
        seen[sport] = true;
        sports.push(sport);
    });
    return sports;
}

function entriesForSport(entries, sport) {
    const wanted = ProviderCatalog.normalizedSport(sport);
    const source = Array.isArray(entries) ? entries : [];
    if (wanted.length === 0)
        return source.slice();
    return source.filter(entry => ProviderCatalog.normalizedSport(entry && entry.sport) === wanted);
}

function activeEntryForSport(entries, activeEntry, sport) {
    const wanted = ProviderCatalog.normalizedSport(sport);
    if (wanted.length === 0)
        return activeEntry || {};
    if (ProviderCatalog.normalizedSport(activeEntry && activeEntry.sport) === wanted)
        return activeEntry || {};
    const matches = entriesForSport(entries, wanted);
    return matches.length > 0 ? matches[0] : {};
}

function watchedTeamEntries(entries, activeEntry, flagName) {
    entries = Array.isArray(entries) ? entries : [];
    const teams = entries.filter(entry => {
        if (entryType(entry) !== "team" || stringValue(entry.favoriteTeam).trim().length === 0)
            return false;

        return !flagName || stringValue(flagName).trim().length === 0 || entry[flagName] !== false;
    });
    if (teams.length > 0)
        return teams;

    if (entryType(activeEntry) === "team" && stringValue(activeEntry && activeEntry.favoriteTeam).trim().length > 0)
        return !flagName || activeEntry[flagName] !== false ? [activeEntry] : [];

    return [];
}

function watchedTeamNames(entries, activeEntry) {
    const seen = {};
    const names = [];
    watchedTeamEntries(entries, activeEntry).forEach(entry => {
        const name = stringValue(entry && entry.favoriteTeam).trim();
        const key = name.toLowerCase();
        if (key.length === 0 || seen[key])
            return;

        seen[key] = true;
        names.push(name);
    });
    return names;
}

function displayLeagueLabel(entry) {
    entry = entry || {};
    return stringValue(entry.customLeagueLabel || entry.leagueLabel || ProviderCatalog.leagueLabel(entry.league) || entry.league).trim();
}

function displayCountryLabel(entry) {
    entry = entry || {};
    return stringValue(entry.customCountryLabel || entry.countryLabel || entry.country).trim();
}

function displayFavoriteTeam(entry) {
    entry = entry || {};
    return stripLegacyTeamPrefix(entry.customFavoriteTeamLabel || entry.favoriteTeam || "");
}

function normalizedFollowMode(entry) {
    entry = entry || {};
    const favorite = stringValue(entry.favoriteTeam).trim();
    return entryType(entry) === "team" && favorite.length > 0 ? "team" : "league";
}

function entryType(entry) {
    entry = entry || {};
    const explicit = stringValue(entry.type).trim();
    const followMode = stringValue(entry.followMode).trim();
    const favoriteTeam = stringValue(entry.favoriteTeam).trim();
    const league = stringValue(entry.league).trim();
    const legacyLabel = stringValue(entry.customLeagueLabel || entry.leagueLabel).trim();
    const legacyStarredLabel = /^(?:\u2605|[*])\s*/.test(legacyLabel);
    const looksLikeTeam = followMode === "team" || legacyStarredLabel || (favoriteTeam.length > 0 && league.length === 0) || isLikelyLegacyTeamEntry(entry);
    if (explicit === "team")
        return "team";
    if (explicit === "competition")
        return looksLikeTeam ? "team" : "competition";

    return looksLikeTeam ? "team" : "competition";
}

function isLikelyLegacyTeamEntry(entry) {
    entry = entry || {};
    const league = stringValue(entry.league).trim().toLowerCase();
    const favoriteTeam = stringValue(entry.favoriteTeam).trim();
    const followMode = stringValue(entry.followMode).trim();
    if (league.length === 0 || favoriteTeam.length > 0 || followMode === "team")
        return false;

    const leagues = knownLeagueValues(entry.sport, entry.country);
    if (leagues.indexOf(league) >= 0)
        return false;

    const teams = knownCountryTeamValues(entry.sport, entry.country);
    return teams.indexOf(league) >= 0;
}

function knownLeagueValues(sport, country) {
    return optionValues(ProviderCatalog.leagueOptions("", stringValue(sport || "football").trim(), stringValue(country).trim()));
}

function knownCountryTeamValues(sport, country) {
    return optionValues(ProviderCatalog.countryTeamOptions("", stringValue(sport || "football").trim(), stringValue(country).trim()));
}

function optionValues(options) {
    return (Array.isArray(options) ? options : []).map(option => stringValue(option && option.value).trim().toLowerCase()).filter(value => value.length > 0);
}

function stripLegacyTeamPrefix(value) {
    return stringValue(value).replace(/^(?:\u2605|[*])\s*/, "").trim();
}

function stringValue(value) {
    return value === undefined || value === null ? "" : String(value);
}
