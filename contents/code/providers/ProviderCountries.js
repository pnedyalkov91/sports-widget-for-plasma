/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library

const FOOTBALL_COUNTRIES = [
    {
        "label": "International Tournaments",
        "value": "world",
        "infoText": "FIFA World Cup\nUEFA European Championship\nUEFA Nations League\nCONCACAF Gold Cup\nAFC Asian Cup\nUEFA Champions League\nUEFA Europa League\nUEFA Europa Conference League\nUEFA Super Cup\nFIFA Club World Cup"
    },
    {
        "label": "Afghanistan",
        "value": "afghanistan",
        "infoText": ""
    },
    {
        "label": "Albania",
        "value": "albania",
        "infoText": ""
    },
    {
        "label": "Algeria",
        "value": "algeria",
        "infoText": ""
    },
    {
        "label": "Andorra",
        "value": "andorra",
        "infoText": ""
    },
    {
        "label": "Angola",
        "value": "angola",
        "infoText": ""
    },
    {
        "label": "Antigua and Barbuda",
        "value": "antigua-and-barbuda",
        "infoText": ""
    },
    {
        "label": "Argentina",
        "value": "argentina",
        "infoText": ""
    },
    {
        "label": "Armenia",
        "value": "armenia",
        "infoText": ""
    },
    {
        "label": "Aruba",
        "value": "aruba",
        "infoText": ""
    },
    {
        "label": "Australia",
        "value": "australia",
        "infoText": ""
    },
    {
        "label": "Austria",
        "value": "austria",
        "infoText": ""
    },
    {
        "label": "Azerbaijan",
        "value": "azerbaijan",
        "infoText": ""
    },
    {
        "label": "Bahrain",
        "value": "bahrain",
        "infoText": ""
    },
    {
        "label": "Bangladesh",
        "value": "bangladesh",
        "infoText": ""
    },
    {
        "label": "Barbados",
        "value": "barbados",
        "infoText": ""
    },
    {
        "label": "Belarus",
        "value": "belarus",
        "infoText": ""
    },
    {
        "label": "Belgium",
        "value": "belgium",
        "infoText": ""
    },
    {
        "label": "Belize",
        "value": "belize",
        "infoText": ""
    },
    {
        "label": "Benin",
        "value": "benin",
        "infoText": ""
    },
    {
        "label": "Bermuda",
        "value": "bermuda",
        "infoText": ""
    },
    {
        "label": "Bhutan",
        "value": "bhutan",
        "infoText": ""
    },
    {
        "label": "Bolivia",
        "value": "bolivia",
        "infoText": ""
    },
    {
        "label": "Bosnia and Herzegovina",
        "value": "bosnia-and-herzegovina",
        "infoText": ""
    },
    {
        "label": "Botswana",
        "value": "botswana",
        "infoText": ""
    },
    {
        "label": "Brazil",
        "value": "brazil",
        "infoText": ""
    },
    {
        "label": "Brunei",
        "value": "brunei",
        "infoText": ""
    },
    {
        "label": "Bulgaria",
        "value": "bulgaria",
        "infoText": ""
    },
    {
        "label": "Burkina Faso",
        "value": "burkina-faso",
        "infoText": ""
    },
    {
        "label": "Burundi",
        "value": "burundi",
        "infoText": ""
    },
    {
        "label": "Cambodia",
        "value": "cambodia",
        "infoText": ""
    },
    {
        "label": "Cameroon",
        "value": "cameroon",
        "infoText": ""
    },
    {
        "label": "Canada",
        "value": "canada",
        "infoText": ""
    },
    {
        "label": "Chile",
        "value": "chile",
        "infoText": ""
    },
    {
        "label": "China",
        "value": "china",
        "infoText": ""
    },
    {
        "label": "Colombia",
        "value": "colombia",
        "infoText": ""
    },
    {
        "label": "Comoros",
        "value": "comoros",
        "infoText": ""
    },
    {
        "label": "Congo",
        "value": "congo",
        "infoText": ""
    },
    {
        "label": "Costa Rica",
        "value": "costa-rica",
        "infoText": ""
    },
    {
        "label": "Croatia",
        "value": "croatia",
        "infoText": ""
    },
    {
        "label": "Cuba",
        "value": "cuba",
        "infoText": ""
    },
    {
        "label": "Curacao",
        "value": "curacao",
        "infoText": ""
    },
    {
        "label": "Cyprus",
        "value": "cyprus",
        "infoText": ""
    },
    {
        "label": "Czech Republic",
        "value": "czech-republic",
        "infoText": ""
    },
    {
        "label": "Democratic Republic of the Congo",
        "value": "democratic-republic-of-the-congo",
        "infoText": ""
    },
    {
        "label": "Denmark",
        "value": "denmark",
        "infoText": ""
    },
    {
        "label": "Djibouti",
        "value": "djibouti",
        "infoText": ""
    },
    {
        "label": "Dominica",
        "value": "dominica",
        "infoText": ""
    },
    {
        "label": "Dominican Republic",
        "value": "dominican-republic",
        "infoText": ""
    },
    {
        "label": "Ecuador",
        "value": "ecuador",
        "infoText": ""
    },
    {
        "label": "Egypt",
        "value": "egypt",
        "infoText": ""
    },
    {
        "label": "El Salvador",
        "value": "el-salvador",
        "infoText": ""
    },
    {
        "label": "England",
        "value": "england",
        "infoText": ""
    },
    {
        "label": "Estonia",
        "value": "estonia",
        "infoText": ""
    },
    {
        "label": "Ethiopia",
        "value": "ethiopia",
        "infoText": ""
    },
    {
        "label": "Faroe Islands",
        "value": "faroe-islands",
        "infoText": ""
    },
    {
        "label": "Fiji",
        "value": "fiji",
        "infoText": ""
    },
    {
        "label": "Finland",
        "value": "finland",
        "infoText": ""
    },
    {
        "label": "France",
        "value": "france",
        "infoText": ""
    },
    {
        "label": "Gabon",
        "value": "gabon",
        "infoText": ""
    },
    {
        "label": "Gambia",
        "value": "gambia",
        "infoText": ""
    },
    {
        "label": "Georgia",
        "value": "georgia",
        "infoText": ""
    },
    {
        "label": "Germany",
        "value": "germany",
        "infoText": ""
    },
    {
        "label": "Ghana",
        "value": "ghana",
        "infoText": ""
    },
    {
        "label": "Gibraltar",
        "value": "gibraltar",
        "infoText": ""
    },
    {
        "label": "Greece",
        "value": "greece",
        "infoText": ""
    },
    {
        "label": "Grenada",
        "value": "grenada",
        "infoText": ""
    },
    {
        "label": "Guatemala",
        "value": "guatemala",
        "infoText": ""
    },
    {
        "label": "Guyana",
        "value": "guyana",
        "infoText": ""
    },
    {
        "label": "Haiti",
        "value": "haiti",
        "infoText": ""
    },
    {
        "label": "Honduras",
        "value": "honduras",
        "infoText": ""
    },
    {
        "label": "Hong Kong, China",
        "value": "hong-kong-china",
        "infoText": ""
    },
    {
        "label": "Hungary",
        "value": "hungary",
        "infoText": ""
    },
    {
        "label": "Iceland",
        "value": "iceland",
        "infoText": ""
    },
    {
        "label": "India",
        "value": "india",
        "infoText": ""
    },
    {
        "label": "Indonesia",
        "value": "indonesia",
        "infoText": ""
    },
    {
        "label": "Iran",
        "value": "iran",
        "infoText": ""
    },
    {
        "label": "Iraq",
        "value": "iraq",
        "infoText": ""
    },
    {
        "label": "Ireland",
        "value": "ireland",
        "infoText": ""
    },
    {
        "label": "Israel",
        "value": "israel",
        "infoText": ""
    },
    {
        "label": "Italy",
        "value": "italy",
        "infoText": ""
    },
    {
        "label": "Ivory Coast",
        "value": "ivory-coast",
        "infoText": ""
    },
    {
        "label": "Jamaica",
        "value": "jamaica",
        "infoText": ""
    },
    {
        "label": "Japan",
        "value": "japan",
        "infoText": ""
    },
    {
        "label": "Jordan",
        "value": "jordan",
        "infoText": ""
    },
    {
        "label": "Kazakhstan",
        "value": "kazakhstan",
        "infoText": ""
    },
    {
        "label": "Kenya",
        "value": "kenya",
        "infoText": ""
    },
    {
        "label": "Kosovo",
        "value": "kosovo",
        "infoText": ""
    },
    {
        "label": "Kuwait",
        "value": "kuwait",
        "infoText": ""
    },
    {
        "label": "Kyrgyzstan",
        "value": "kyrgyzstan",
        "infoText": ""
    },
    {
        "label": "Laos",
        "value": "laos",
        "infoText": ""
    },
    {
        "label": "Latvia",
        "value": "latvia",
        "infoText": ""
    },
    {
        "label": "Lebanon",
        "value": "lebanon",
        "infoText": ""
    },
    {
        "label": "Lesotho",
        "value": "lesotho",
        "infoText": ""
    },
    {
        "label": "Liberia",
        "value": "liberia",
        "infoText": ""
    },
    {
        "label": "Libya",
        "value": "libya",
        "infoText": ""
    },
    {
        "label": "Liechtenstein",
        "value": "liechtenstein",
        "infoText": ""
    },
    {
        "label": "Lithuania",
        "value": "lithuania",
        "infoText": ""
    },
    {
        "label": "Luxembourg",
        "value": "luxembourg",
        "infoText": ""
    },
    {
        "label": "Madagascar",
        "value": "madagascar",
        "infoText": ""
    },
    {
        "label": "Malawi",
        "value": "malawi",
        "infoText": ""
    },
    {
        "label": "Malaysia",
        "value": "malaysia",
        "infoText": ""
    },
    {
        "label": "Maldives",
        "value": "maldives",
        "infoText": ""
    },
    {
        "label": "Mali",
        "value": "mali",
        "infoText": ""
    },
    {
        "label": "Malta",
        "value": "malta",
        "infoText": ""
    },
    {
        "label": "Mauritania",
        "value": "mauritania",
        "infoText": ""
    },
    {
        "label": "Mexico",
        "value": "mexico",
        "infoText": ""
    },
    {
        "label": "Moldova",
        "value": "moldova",
        "infoText": ""
    },
    {
        "label": "Mongolia",
        "value": "mongolia",
        "infoText": ""
    },
    {
        "label": "Montenegro",
        "value": "montenegro",
        "infoText": ""
    },
    {
        "label": "Morocco",
        "value": "morocco",
        "infoText": ""
    },
    {
        "label": "Mozambique",
        "value": "mozambique",
        "infoText": ""
    },
    {
        "label": "Myanmar",
        "value": "myanmar",
        "infoText": ""
    },
    {
        "label": "Namibia",
        "value": "namibia",
        "infoText": ""
    },
    {
        "label": "Nepal",
        "value": "nepal",
        "infoText": ""
    },
    {
        "label": "Netherlands",
        "value": "netherlands",
        "infoText": ""
    },
    {
        "label": "New Zealand",
        "value": "new-zealand",
        "infoText": ""
    },
    {
        "label": "Nicaragua",
        "value": "nicaragua",
        "infoText": ""
    },
    {
        "label": "Niger",
        "value": "niger",
        "infoText": ""
    },
    {
        "label": "Nigeria",
        "value": "nigeria",
        "infoText": ""
    },
    {
        "label": "North Macedonia",
        "value": "north-macedonia",
        "infoText": ""
    },
    {
        "label": "Northern Ireland",
        "value": "northern-ireland",
        "infoText": ""
    },
    {
        "label": "Norway",
        "value": "norway",
        "infoText": ""
    },
    {
        "label": "Oman",
        "value": "oman",
        "infoText": ""
    },
    {
        "label": "Pakistan",
        "value": "pakistan",
        "infoText": ""
    },
    {
        "label": "Palestine",
        "value": "palestine",
        "infoText": ""
    },
    {
        "label": "Panama",
        "value": "panama",
        "infoText": ""
    },
    {
        "label": "Paraguay",
        "value": "paraguay",
        "infoText": ""
    },
    {
        "label": "Peru",
        "value": "peru",
        "infoText": ""
    },
    {
        "label": "Philippines",
        "value": "philippines",
        "infoText": ""
    },
    {
        "label": "Poland",
        "value": "poland",
        "infoText": ""
    },
    {
        "label": "Portugal",
        "value": "portugal",
        "infoText": ""
    },
    {
        "label": "Puerto Rico",
        "value": "puerto-rico",
        "infoText": ""
    },
    {
        "label": "Qatar",
        "value": "qatar",
        "infoText": ""
    },
    {
        "label": "Romania",
        "value": "romania",
        "infoText": ""
    },
    {
        "label": "Russia",
        "value": "russia",
        "infoText": ""
    },
    {
        "label": "Rwanda",
        "value": "rwanda",
        "infoText": ""
    },
    {
        "label": "Saint Kitts and Nevis",
        "value": "saint-kitts-and-nevis",
        "infoText": ""
    },
    {
        "label": "Samoa",
        "value": "samoa",
        "infoText": ""
    },
    {
        "label": "San Marino",
        "value": "san-marino",
        "infoText": ""
    },
    {
        "label": "Sao Tome and Principe",
        "value": "sao-tome-and-principe",
        "infoText": ""
    },
    {
        "label": "Saudi Arabia",
        "value": "saudi-arabia",
        "infoText": ""
    },
    {
        "label": "Scotland",
        "value": "scotland",
        "infoText": ""
    },
    {
        "label": "Senegal",
        "value": "senegal",
        "infoText": ""
    },
    {
        "label": "Serbia",
        "value": "serbia",
        "infoText": ""
    },
    {
        "label": "Seychelles",
        "value": "seychelles",
        "infoText": ""
    },
    {
        "label": "Sierra Leone",
        "value": "sierra-leone",
        "infoText": ""
    },
    {
        "label": "Singapore",
        "value": "singapore",
        "infoText": ""
    },
    {
        "label": "Slovakia",
        "value": "slovakia",
        "infoText": ""
    },
    {
        "label": "Slovenia",
        "value": "slovenia",
        "infoText": ""
    },
    {
        "label": "Solomon Islands",
        "value": "solomon-islands",
        "infoText": ""
    },
    {
        "label": "South Africa",
        "value": "south-africa",
        "infoText": ""
    },
    {
        "label": "South Korea",
        "value": "south-korea",
        "infoText": ""
    },
    {
        "label": "Spain",
        "value": "spain",
        "infoText": ""
    },
    {
        "label": "Sri Lanka",
        "value": "sri-lanka",
        "infoText": ""
    },
    {
        "label": "Sudan",
        "value": "sudan",
        "infoText": ""
    },
    {
        "label": "Suriname",
        "value": "suriname",
        "infoText": ""
    },
    {
        "label": "Sweden",
        "value": "sweden",
        "infoText": ""
    },
    {
        "label": "Switzerland",
        "value": "switzerland",
        "infoText": ""
    },
    {
        "label": "Syria",
        "value": "syria",
        "infoText": ""
    },
    {
        "label": "Tajikistan",
        "value": "tajikistan",
        "infoText": ""
    },
    {
        "label": "Tanzania",
        "value": "tanzania",
        "infoText": ""
    },
    {
        "label": "Thailand",
        "value": "thailand",
        "infoText": ""
    },
    {
        "label": "Togo",
        "value": "togo",
        "infoText": ""
    },
    {
        "label": "Trinidad and Tobago",
        "value": "trinidad-and-tobago",
        "infoText": ""
    },
    {
        "label": "Tunisia",
        "value": "tunisia",
        "infoText": ""
    },
    {
        "label": "Turkey",
        "value": "turkey",
        "infoText": ""
    },
    {
        "label": "Turkmenistan",
        "value": "turkmenistan",
        "infoText": ""
    },
    {
        "label": "Uganda",
        "value": "uganda",
        "infoText": ""
    },
    {
        "label": "Ukraine",
        "value": "ukraine",
        "infoText": ""
    },
    {
        "label": "United Arab Emirates",
        "value": "united-arab-emirates",
        "infoText": ""
    },
    {
        "label": "United States",
        "value": "united-states",
        "infoText": ""
    },
    {
        "label": "Uruguay",
        "value": "uruguay",
        "infoText": ""
    },
    {
        "label": "Uzbekistan",
        "value": "uzbekistan",
        "infoText": ""
    },
    {
        "label": "Vanuatu",
        "value": "vanuatu",
        "infoText": ""
    },
    {
        "label": "Venezuela",
        "value": "venezuela",
        "infoText": ""
    },
    {
        "label": "Vietnam",
        "value": "vietnam",
        "infoText": ""
    },
    {
        "label": "Wales",
        "value": "wales",
        "infoText": ""
    },
    {
        "label": "Yemen",
        "value": "yemen",
        "infoText": ""
    },
    {
        "label": "Zambia",
        "value": "zambia",
        "infoText": ""
    },
    {
        "label": "Zimbabwe",
        "value": "zimbabwe",
        "infoText": ""
    }
];

const COUNTRY_FLAG_CODES = {
    "afghanistan": "af",
    "albania": "al",
    "algeria": "dz",
    "andorra": "ad",
    "angola": "ao",
    "antigua-and-barbuda": "ag",
    "argentina": "ar",
    "armenia": "am",
    "aruba": "aw",
    "australia": "au",
    "austria": "at",
    "azerbaijan": "az",
    "bahrain": "bh",
    "bangladesh": "bd",
    "barbados": "bb",
    "belarus": "by",
    "belgium": "be",
    "belize": "bz",
    "benin": "bj",
    "bermuda": "bm",
    "bhutan": "bt",
    "bolivia": "bo",
    "bosnia-and-herzegovina": "ba",
    "botswana": "bw",
    "brazil": "br",
    "brunei": "bn",
    "bulgaria": "bg",
    "burkina-faso": "bf",
    "burundi": "bi",
    "cambodia": "kh",
    "cameroon": "cm",
    "canada": "ca",
    "chile": "cl",
    "china": "cn",
    "colombia": "co",
    "comoros": "km",
    "congo": "cg",
    "costa-rica": "cr",
    "croatia": "hr",
    "cuba": "cu",
    "curacao": "an",
    "cyprus": "cy",
    "czech-republic": "cz",
    "democratic-republic-of-the-congo": "cd",
    "denmark": "dk",
    "djibouti": "dj",
    "dominica": "dm",
    "dominican-republic": "do",
    "ecuador": "ec",
    "egypt": "eg",
    "el-salvador": "sv",
    "england": "gb",
    "estonia": "ee",
    "ethiopia": "et",
    "faroe-islands": "fo",
    "fiji": "fj",
    "finland": "fi",
    "france": "fr",
    "gabon": "ga",
    "gambia": "gm",
    "georgia": "ge",
    "germany": "de",
    "ghana": "gh",
    "gibraltar": "gi",
    "greece": "gr",
    "grenada": "gd",
    "guatemala": "gt",
    "guyana": "gy",
    "haiti": "ht",
    "honduras": "hn",
    "hong-kong-china": "hk",
    "hungary": "hu",
    "iceland": "is",
    "india": "in",
    "indonesia": "id",
    "iran": "ir",
    "iraq": "iq",
    "ireland": "ie",
    "israel": "il",
    "italy": "it",
    "ivory-coast": "ci",
    "jamaica": "jm",
    "japan": "jp",
    "jordan": "jo",
    "kazakhstan": "kz",
    "kenya": "ke",
    "kosovo": "xk",
    "kuwait": "kw",
    "kyrgyzstan": "kg",
    "laos": "la",
    "latvia": "lv",
    "lebanon": "lb",
    "lesotho": "ls",
    "liberia": "lr",
    "libya": "ly",
    "liechtenstein": "li",
    "lithuania": "lt",
    "luxembourg": "lu",
    "madagascar": "mg",
    "malawi": "mw",
    "malaysia": "my",
    "maldives": "mv",
    "mali": "ml",
    "malta": "mt",
    "mauritania": "mr",
    "mexico": "mx",
    "moldova": "md",
    "mongolia": "mn",
    "montenegro": "me",
    "morocco": "ma",
    "mozambique": "mz",
    "myanmar": "mm",
    "namibia": "na",
    "nepal": "np",
    "netherlands": "nl",
    "new-zealand": "nz",
    "nicaragua": "ni",
    "niger": "ne",
    "nigeria": "ng",
    "north-macedonia": "mk",
    "northern-ireland": "gb",
    "norway": "no",
    "oman": "om",
    "pakistan": "pk",
    "palestine": "ps",
    "panama": "pa",
    "paraguay": "py",
    "peru": "pe",
    "philippines": "ph",
    "poland": "pl",
    "portugal": "pt",
    "puerto-rico": "pr",
    "qatar": "qa",
    "romania": "ro",
    "russia": "ru",
    "rwanda": "rw",
    "saint-kitts-and-nevis": "kn",
    "samoa": "ws",
    "san-marino": "sm",
    "sao-tome-and-principe": "st",
    "saudi-arabia": "sa",
    "scotland": "gb",
    "senegal": "sn",
    "serbia": "rs",
    "seychelles": "sc",
    "sierra-leone": "sl",
    "singapore": "sg",
    "slovakia": "sk",
    "slovenia": "si",
    "solomon-islands": "sb",
    "south-africa": "za",
    "south-korea": "kr",
    "spain": "es",
    "sri-lanka": "lk",
    "sudan": "sd",
    "suriname": "sr",
    "sweden": "se",
    "switzerland": "ch",
    "syria": "sy",
    "tajikistan": "tj",
    "tanzania": "tz",
    "thailand": "th",
    "togo": "tg",
    "trinidad-and-tobago": "tt",
    "tunisia": "tn",
    "turkey": "tr",
    "turkmenistan": "tm",
    "uganda": "ug",
    "ukraine": "ua",
    "united-arab-emirates": "ae",
    "united-states": "us",
    "uruguay": "uy",
    "uzbekistan": "uz",
    "vanuatu": "vu",
    "venezuela": "ve",
    "vietnam": "vn",
    "wales": "gb",
    "yemen": "ye",
    "zambia": "zm",
    "zimbabwe": "zw"
};

const NATIONAL_TEAM_ALIASES = {
    "czech-republic": ["Czechia"],
    "democratic-republic-of-the-congo": ["DR Congo", "Congo DR"],
    "hong-kong-china": ["Hong Kong"],
    "ivory-coast": ["Cote d'Ivoire", "Côte d'Ivoire"],
    "north-macedonia": ["Macedonia"],
    "south-korea": ["Korea Republic", "Republic of Korea"],
    "turkey": ["Türkiye"],
    "united-states": ["USA", "United States of America"]
};

function footballCountryOptions(includeWorld) {
    return FOOTBALL_COUNTRIES.filter(country => includeWorld || country.value !== "world").map(country => ({
        label: country.label,
        value: country.value,
        icon: flagSource(country.value),
        infoText: country.infoText || ""
    }));
}

function flagSource(countryCode) {
    const code = COUNTRY_FLAG_CODES[String(countryCode || "").trim().toLowerCase()];
    if (!code)
        return "flag";

    return "file:///usr/share/locale/l10n/" + code + "/flag.png";
}

function normalizedTeamName(value) {
    return String(value || "")
        .toLowerCase()
        .replace(/[’`]/g, "'")
        .replace(/[^a-z0-9']+/g, " ")
        .replace(/\s+/g, " ")
        .trim();
}

function isNationalTeamVariant(teamName, countryName) {
    const team = normalizedTeamName(teamName);
    const country = normalizedTeamName(countryName);
    if (team.length === 0 || country.length === 0)
        return false;
    if (team === country)
        return true;
    if (team.indexOf(country + " ") !== 0)
        return false;

    const suffix = team.slice(country.length).trim();
    return /^(?:men|women|woman|w|ladies|olympic|olympics|u\s?\d{2}|under\s?\d{2})(?:\s.*)?$/.test(suffix);
}

function nationalTeamCountry(teamName) {
    for (let index = 0; index < FOOTBALL_COUNTRIES.length; index += 1) {
        const country = FOOTBALL_COUNTRIES[index];
        if (!country || country.value === "world")
            continue;

        const names = [country.label].concat(NATIONAL_TEAM_ALIASES[country.value] || []);
        for (let nameIndex = 0; nameIndex < names.length; nameIndex += 1) {
            if (isNationalTeamVariant(teamName, names[nameIndex]))
                return country.value;
        }
    }

    return "";
}
