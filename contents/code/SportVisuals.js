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
    const sport = String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
    if (sport.length === 0)
        return "";
    // Canonicalise common aliases to the widget's sport ids; everything else
    // passes through unchanged so new ESPN sports keep their own id.
    if (sport === "soccer")
        return "football";
    if (sport === "nfl")
        return "american-football";
    if (sport === "nba" || sport === "wnba")
        return "basketball";
    if (sport === "mlb")
        return "baseball";
    if (sport === "nhl" || sport === "ice-hockey")
        return "hockey";
    if (sport === "f1" || sport === "formula-1" || sport === "nascar")
        return "racing";
    if (sport === "ufc")
        return "mma";
    return sport;
}

function emoji(value) {
    const sport = normalizedSport(value);
    const emojis = {
        "american-football": "🏈",
        "australian-football": "🏉",
        "baseball": "⚾",
        "basketball": "🏀",
        "cricket": "🏏",
        "field-hockey": "🏑",
        "football": "⚽",
        "golf": "⛳",
        "hockey": "🏒",
        "lacrosse": "🥍",
        "mma": "🥊",
        "racing": "🏎️",
        "rugby": "🏉",
        "rugby-league": "🏉",
        "snooker": "🎱",
        "tennis": "🎾",
        "volleyball": "🏐",
        "water-polo": "🤽"
    };
    return emojis[sport] || "🏆";
}

function label(value) {
    const sport = normalizedSport(value);
    const labels = {
        "american-football": "American Football",
        "australian-football": "Australian Football",
        "baseball": "Baseball",
        "basketball": "Basketball",
        "cricket": "Cricket",
        "field-hockey": "Field Hockey",
        "football": "Football",
        "golf": "Golf",
        "hockey": "Ice Hockey",
        "lacrosse": "Lacrosse",
        "mma": "MMA",
        "racing": "Racing",
        "rugby": "Rugby",
        "rugby-league": "Rugby League",
        "snooker": "Snooker",
        "tennis": "Tennis",
        "volleyball": "Volleyball",
        "water-polo": "Water Polo"
    };
    return labels[sport] || titleFromSlug(sport);
}

function titleFromSlug(value) {
    return String(value || "")
        .replace(/[-_]+/g, " ")
        .replace(/\s+/g, " ")
        .trim()
        .split(" ")
        .filter(part => part.length > 0)
        .map(part => part.charAt(0).toUpperCase() + part.slice(1))
        .join(" ") || "Sports";
}

// ESPN identifies national teams/athletes by FIFA/IOC 3-letter codes in its flag
// URLs (e.g. .../countries/500/cro.png). These differ from ISO-3166 alpha-2, which
// is what a flag emoji is built from, so map the codes we can encounter to ISO-2.
// Home nations (England/Scotland/Wales/N.Ireland) have no distinct emoji, so they
// fall back to GB. Anything unmapped yields no emoji (caller keeps its icon).
const FIFA_TO_ISO2 = {
    "afg": "AF", "alb": "AL", "alg": "DZ", "and": "AD", "ang": "AO", "arg": "AR", "arm": "AM", "aus": "AU",
    "aut": "AT", "aze": "AZ", "bah": "BS", "ban": "BD", "bar": "BB", "bel": "BE", "ben": "BJ", "ber": "BM",
    "bhu": "BT", "bih": "BA", "blr": "BY", "bol": "BO", "bot": "BW", "bra": "BR", "bru": "BN", "bul": "BG",
    "bfa": "BF", "bdi": "BI", "cam": "KH", "cmr": "CM", "can": "CA", "cpv": "CV", "cay": "KY", "cta": "CF",
    "cha": "TD", "chi": "CL", "chn": "CN", "col": "CO", "com": "KM", "cgo": "CG", "cod": "CD", "cos": "CR",
    "civ": "CI", "cro": "HR", "cub": "CU", "cyp": "CY", "cze": "CZ", "den": "DK", "dji": "DJ", "dma": "DM",
    "dom": "DO", "ecu": "EC", "egy": "EG", "slv": "SV", "eng": "GB", "gnq": "GQ", "eri": "ER", "est": "EE",
    "eth": "ET", "fij": "FJ", "fin": "FI", "fra": "FR", "gab": "GA", "gam": "GM", "geo": "GE", "ger": "DE",
    "gha": "GH", "gre": "GR", "grn": "GD", "gua": "GT", "gui": "GN", "gnb": "GW", "guy": "GY", "hai": "HT",
    "hon": "HN", "hkg": "HK", "hun": "HU", "isl": "IS", "ind": "IN", "idn": "ID", "irn": "IR", "irq": "IQ",
    "irl": "IE", "isr": "IL", "ita": "IT", "jam": "JM", "jpn": "JP", "jor": "JO", "kaz": "KZ", "ken": "KE",
    "kor": "KR", "prk": "KP", "kuw": "KW", "kgz": "KG", "lao": "LA", "lat": "LV", "lib": "LB", "les": "LS",
    "lbr": "LR", "lby": "LY", "lie": "LI", "ltu": "LT", "lux": "LU", "mac": "MO", "mkd": "MK", "mad": "MG",
    "mwi": "MW", "mas": "MY", "mdv": "MV", "mli": "ML", "mlt": "MT", "mtn": "MR", "mri": "MU", "mex": "MX",
    "mda": "MD", "mng": "MN", "mne": "ME", "mar": "MA", "moz": "MZ", "mya": "MM", "nam": "NA", "nep": "NP",
    "ned": "NL", "nzl": "NZ", "nca": "NI", "nig": "NE", "nga": "NG", "nir": "GB", "nor": "NO", "oma": "OM",
    "pak": "PK", "pan": "PA", "par": "PY", "per": "PE", "phi": "PH", "pol": "PL", "por": "PT", "pur": "PR",
    "qat": "QA", "rou": "RO", "rus": "RU", "rwa": "RW", "ksa": "SA", "sco": "GB", "sen": "SN", "srb": "RS",
    "sey": "SC", "sle": "SL", "sin": "SG", "svk": "SK", "svn": "SI", "sol": "SB", "som": "SO", "rsa": "ZA",
    "esp": "ES", "sri": "LK", "sdn": "SD", "sur": "SR", "swe": "SE", "sui": "CH", "syr": "SY", "tah": "PF",
    "tan": "TZ", "tha": "TH", "tog": "TG", "tri": "TT", "tun": "TN", "tur": "TR", "tkm": "TM", "uga": "UG",
    "ukr": "UA", "uae": "AE", "usa": "US", "uru": "UY", "uzb": "UZ", "ven": "VE", "vie": "VN", "wal": "GB",
    "yem": "YE", "zam": "ZM", "zim": "ZW", "gbr": "GB", "tpe": "TW", "ina": "ID", "rsa2": "ZA"
};

// Build a regional-indicator flag emoji from an ISO-3166 alpha-2 code, or "" if the
// code isn't two A–Z letters.
function flagEmojiFromIso2(code) {
    const iso = String(code || "").toUpperCase();
    if (!/^[A-Z]{2}$/.test(iso))
        return "";
    const base = 0x1F1E6;
    return String.fromCodePoint(base + iso.charCodeAt(0) - 65)
        + String.fromCodePoint(base + iso.charCodeAt(1) - 65);
}

// Country flag emoji for a team-badge URL, covering both flag URL shapes the app
// sees: the system/SportScore "…/<iso2>/flag.png" form and ESPN's
// "…/countries/500/<fifa3>.png" form. Returns "" when the URL isn't a country flag
// or the code is unknown, so callers can keep their own (icon) fallback.
function flagEmojiFromUrl(url) {
    const value = String(url || "");
    const iso2 = value.match(/\/([a-z]{2})\/flag\.(?:png|svg)$/i);
    if (iso2 && iso2[1])
        return flagEmojiFromIso2(iso2[1]);
    const espn = value.match(/\/countries\/\d+\/([a-z]{3})\.(?:png|svg)$/i);
    if (espn && espn[1])
        return flagEmojiFromIso2(FIFA_TO_ISO2[espn[1].toLowerCase()]);
    return "";
}
