/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library
.import "ProviderCatalog.js" as ProviderCatalog
.import "../SportVisuals.js" as SportVisuals

function providerId(configuration) {
    const configured = stringValue(configuration && configuration.provider);
    return configured.length > 0 ? configured : "sportscore";
}

function baseUrl(configuration, sport) {
    const provider = providerId(configuration);
    const normalizedSport = SportVisuals.normalizedSport(sport || "football");
    if (provider === "api-sports")
        return ProviderCatalog.apiSportsBaseUrlForSport(normalizedSport);

    if (provider === "allsportsapi")
        return ProviderCatalog.allSportsBaseUrlForSport(normalizedSport);

    if (provider === "thesportsdb-premium") {
        const key = apiKey(configuration, normalizedSport);
        const base = ProviderCatalog.defaultBaseUrl(provider);
        return key.length > 0 ? base + "/" + encodeURIComponent(key) : base;
    }

    const configured = stringValue(configuration && configuration.apiBaseUrl);
    return configured.length > 0 ? configured : ProviderCatalog.defaultBaseUrl(provider);
}

function apiKey(configuration, sport) {
    const provider = providerId(configuration);
    if (ProviderCatalog.providerUsesBuiltInKey(provider))
        return "123";

    if (provider === "thesportsdb-premium")
        return stringValue(configuration && configuration.theSportsDBApiKey);

    if (provider === "allsportsapi")
        return stringValue(configuration && configuration.allSportsApiKey);

    if (ProviderCatalog.providerUsesSportKeys(provider))
        return apiSportsKeyForSport(configuration, sport);

    return stringValue(configuration && configuration.apiKey);
}

function apiSportsKeyForSport(configuration, sport) {
    const normalizedSport = SportVisuals.normalizedSport(sport || "football");
    const keys = {
        "american-football": configuration && configuration.apiSportsAmericanFootballKey,
        "baseball": configuration && configuration.apiSportsBaseballKey,
        "basketball": configuration && configuration.apiSportsBasketballKey,
        "cricket": configuration && configuration.apiSportsCricketKey,
        "football": configuration && configuration.apiSportsFootballKey,
        "hockey": configuration && configuration.apiSportsHockeyKey,
        "tennis": configuration && configuration.apiSportsTennisKey,
        "volleyball": configuration && configuration.apiSportsVolleyballKey
    };
    return stringValue(keys[normalizedSport]);
}

function stringValue(value) {
    if (value === undefined || value === null)
        return "";

    return String(value).trim();
}
