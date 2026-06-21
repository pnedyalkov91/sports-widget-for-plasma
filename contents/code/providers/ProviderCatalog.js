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
.import "ProviderCountries.js" as ProviderCountries
.import "SportScoreSports.js" as SportScoreSports
.import "EspnSports.js" as EspnSports

// Sport picker = SportScore's sports plus the ESPN-native sports, deduped.
function sportOptions(providerId) {
    const options = SportScoreSports.options();
    const seen = {};
    options.forEach(option => { seen[option.value] = true; });
    EspnSports.nativeOptions().forEach(option => {
        if (!seen[option.value]) {
            seen[option.value] = true;
            options.push(option);
        }
    });
    return options;
}

function countryOptions(providerId, sport) {
    const normalized = SportScoreSports.normalizedSport(sport);
    // ESPN-native sports: countries come from their ESPN leagues.
    if (EspnSports.isNative(normalized))
        return EspnSports.countriesFor(normalized);
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
