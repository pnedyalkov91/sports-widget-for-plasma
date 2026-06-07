/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library
.import "ProviderCountries.js" as ProviderCountries
.import "SportScoreSports.js" as SportScoreSports

const SPORTS = SportScoreSports.options();

const API_SPORTS_BASE_URLS = {
    "american-football": "https://v1.american-football.api-sports.io",
    "baseball": "https://v1.baseball.api-sports.io",
    "basketball": "https://v1.basketball.api-sports.io",
    "cricket": "https://v1.cricket.api-sports.io",
    "football": "https://v3.football.api-sports.io",
    "hockey": "https://v1.hockey.api-sports.io",
    "tennis": "https://v1.tennis.api-sports.io",
    "volleyball": "https://v1.volleyball.api-sports.io"
};

const ALL_SPORTS_PATHS = {
    "american-football": "american-football",
    "baseball": "baseball",
    "basketball": "basketball",
    "cricket": "cricket",
    "football": "football",
    "hockey": "hockey",
    "tennis": "tennis",
    "volleyball": "volleyball"
};

const PROVIDERS = [
    {
        id: "sportscore",
        label: "SportScore",
        defaultBaseUrl: "https://sportscore.com",
        keyMode: "none"
    },
    {
        id: "thesportsdb-free",
        label: "TheSportsDB Free",
        defaultBaseUrl: "https://www.thesportsdb.com/api/v1/json/123",
        keyMode: "builtin"
    },
    {
        id: "thesportsdb-premium",
        label: "TheSportsDB Premium",
        defaultBaseUrl: "https://www.thesportsdb.com/api/v2/json",
        keyMode: "single"
    },
    {
        id: "api-sports",
        label: "API-Sports",
        defaultBaseUrl: API_SPORTS_BASE_URLS.football,
        keyMode: "sport"
    },
    {
        id: "allsportsapi",
        label: "AllSportsAPI",
        defaultBaseUrl: "https://apiv2.allsportsapi.com",
        keyMode: "single"
    }
];

function providerOptions() {
    return PROVIDERS.map(provider => ({
        label: provider.label,
        value: provider.id
    }));
}

function provider(providerId) {
    const wanted = stringValue(providerId);
    for (let index = 0; index < PROVIDERS.length; index += 1) {
        if (PROVIDERS[index].id === wanted)
            return PROVIDERS[index];
    }

    return PROVIDERS[0];
}

function displayName(providerId) {
    return provider(providerId).label;
}

function requiresApiKey(providerId) {
    const mode = provider(providerId).keyMode;
    return mode === "single" || mode === "sport";
}

function providerUsesSportKeys(providerId) {
    return provider(providerId).keyMode === "sport";
}

function providerUsesBuiltInKey(providerId) {
    return provider(providerId).keyMode === "builtin";
}

function defaultBaseUrl(providerId) {
    return provider(providerId).defaultBaseUrl;
}

function sportOptions(providerId) {
    if (stringValue(providerId).length === 0 || stringValue(providerId) === "sportscore")
        return SportScoreSports.options();

    return SPORTS.slice();
}

function countryOptions(providerId, sport) {
    const providerValue = stringValue(providerId) || "sportscore";
    if (providerValue === "sportscore") {
        const defaults = SportScoreSports.defaultCountryOptions(sport);
        if (defaults.length > 0)
            return defaults;
    }

    if (normalizedSport(sport) === "football")
        return ProviderCountries.footballCountryOptions(true);

    if (SportScoreSports.supports(sport))
        return ProviderCountries.footballCountryOptions(true);

    return [];
}

function defaultCountry(providerId, sport) {
    return "";
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

function apiSportsBaseUrlForSport(sport) {
    return API_SPORTS_BASE_URLS[slug(sport)] || API_SPORTS_BASE_URLS.football;
}

function allSportsBaseUrlForSport(sport) {
    return defaultBaseUrl("allsportsapi") + "/" + (ALL_SPORTS_PATHS[slug(sport)] || ALL_SPORTS_PATHS.football);
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
