/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library
.import "ProviderCountries.js" as ProviderCountries
.import "SportScoreSports.js" as SportScoreSports

function sportOptions(providerId) {
    return SportScoreSports.options();
}

function countryOptions(providerId, sport) {
    const normalized = SportScoreSports.normalizedSport(sport);
    if (normalized === "basketball")
        return ProviderCountries.basketballCountryOptions();
    if (normalized === "cricket")
        return ProviderCountries.cricketCountryOptions();
    const defaults = SportScoreSports.defaultCountryOptions(sport);
    if (defaults.length > 0)
        return defaults;
    if (SportScoreSports.supports(sport))
        return ProviderCountries.footballCountryOptions(true);
    return [];
}


function leagueOptions(providerId, sport, country) {
    return [];
}

function favoriteTeamOptions(leagueCode) {
    return [];
}

function countryTeamOptions(providerId, sport, countryCode) {
    return [];
}

function participantLabel(sport, plural) {
    return SportScoreSports.participantLabel(sport, Boolean(plural));
}

function sportSupportsParticipants(sport) {
    return SportScoreSports.supports(sport);
}

function resolveFootballLeagueCode(countryCode, labelOrCode) {
    return slug(labelOrCode);
}

function leagueLabel(leagueCode) {
    return titleFromSlug(leagueCode);
}

function normalizedCompetitionLabel(value, leagueCode) {
    const slug = slugForValue(leagueCode);
    let label = stringValue(value)
        .replace(/&trade;|&#8482;/gi, "™")
        .replace(/&reg;|&#174;/gi, "®")
        .replace(/\s+/g, " ")
        .trim();

    if (slug === "fifa-world-cup" && /^FIFA World Cup 2026\b/i.test(label))
        return "FIFA World Cup 2026";

    return label.replace(/[™®]/g, "").trim();
}

function countryCodeForLeague(leagueCode) {
    return "";
}


function slugForValue(code) {
    return slug(code);
}

function slug(value) {
    return stringValue(value)
        .toLowerCase()
        .replace(/&/g, "and")
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "");
}

function normalizedSport(value) {
    const sport = slug(value);
    if (sport.length === 0)
        return "";
    if (sport === "soccer")
        return "football";

    return sport;
}

function titleFromSlug(value) {
    return stringValue(value)
        .replace(/[-_]+/g, " ")
        .replace(/\s+/g, " ")
        .trim()
        .split(" ")
        .filter(part => part.length > 0)
        .map(part => part.charAt(0).toUpperCase() + part.slice(1))
        .join(" ");
}

function stringValue(value) {
    if (value === undefined || value === null)
        return "";

    return String(value).trim();
}
