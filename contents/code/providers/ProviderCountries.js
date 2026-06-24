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
        "label": "Guinea",
        "value": "guinea",
        "infoText": ""
    },
    {
        "label": "Guinea-Bissau",
        "value": "guinea-bissau",
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
        "label": "Macao, China",
        "value": "macao-china",
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
        "label": "Mauritius",
        "value": "mauritius",
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
        "label": "Monaco",
        "value": "monaco",
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
        "label": "North Korea",
        "value": "north-korea",
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
        "label": "Somalia",
        "value": "somalia",
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
        "label": "South Sudan",
        "value": "south-sudan",
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
        "label": "Timor-Leste",
        "value": "timor-leste",
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
    "somalia": "so",
    "south-africa": "za",
    "south-korea": "kr",
    "south-sudan": "ss",
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
    "zimbabwe": "zw",
    "bosnia": "ba",
    "canadian": "ca",
    "chinese-taipei": "tw",
    "costa": "cr",
    "eswatini": "sz",
    "fyr-macedonia": "mk",
    "guinea": "gn",
    "guinea-bissau": "gw",
    "korea-republic": "kr",
    "macao-china": "mo",
    "mauritius": "mu",
    "monaco": "mc",
    "north-korea": "kp",
    "st-vincent-and-the-grenadines": "vc",
    "timor-leste": "tl"
};

const NATIONAL_TEAM_ALIASES = {
    "czech-republic": ["Czechia"],
    "democratic-republic-of-the-congo": ["DR Congo", "Congo DR"],
    "hong-kong-china": ["Hong Kong"],
    "ivory-coast": ["Cote d'Ivoire", "Côte d'Ivoire"],
    "macao-china": ["Macao", "Macau"],
    "north-korea": ["DPR Korea", "Korea DPR"],
    "north-macedonia": ["Macedonia", "FYR Macedonia"],
    "south-korea": ["Korea Republic", "Republic of Korea"],
    "timor-leste": ["East Timor"],
    "turkey": ["Türkiye"],
    "united-states": ["USA", "United States of America"]
};

const BASKETBALL_COUNTRIES = [
    { "label": "International Tournaments", "value": "world", "infoText": "NBA\nFIBA World Cup\nOlympic Basketball Tournament\nEuroLeague\nEuroCup\nFIBA Europe Cup\nFIBA Champions League" },
    { "label": "Albania", "value": "albania", "infoText": "" },
    { "label": "Algeria", "value": "algeria", "infoText": "" },
    { "label": "Angola", "value": "angola", "infoText": "" },
    { "label": "Argentina", "value": "argentina", "infoText": "" },
    { "label": "Armenia", "value": "armenia", "infoText": "" },
    { "label": "Australia", "value": "australia", "infoText": "" },
    { "label": "Austria", "value": "austria", "infoText": "" },
    { "label": "Azerbaijan", "value": "azerbaijan", "infoText": "" },
    { "label": "Bahrain", "value": "bahrain", "infoText": "" },
    { "label": "Belarus", "value": "belarus", "infoText": "" },
    { "label": "Belgium", "value": "belgium", "infoText": "" },
    { "label": "Bolivia", "value": "bolivia", "infoText": "" },
    { "label": "Bosnia and Herzegovina", "value": "bosnia", "infoText": "" },
    { "label": "Brazil", "value": "brazil", "infoText": "" },
    { "label": "Bulgaria", "value": "bulgaria", "infoText": "" },
    { "label": "Cameroon", "value": "cameroon", "infoText": "" },
    { "label": "Canada", "value": "canada", "infoText": "" },
    { "label": "Canada", "value": "canadian", "infoText": "" },
    { "label": "Chile", "value": "chile", "infoText": "" },
    { "label": "China", "value": "china", "infoText": "" },
    { "label": "Colombia", "value": "colombia", "infoText": "" },
    { "label": "Costa Rica", "value": "costa", "infoText": "" },
    { "label": "Croatia", "value": "croatia", "infoText": "" },
    { "label": "Cuba", "value": "cuba", "infoText": "" },
    { "label": "Cyprus", "value": "cyprus", "infoText": "" },
    { "label": "Czech Republic", "value": "czech-republic", "infoText": "" },
    { "label": "Denmark", "value": "denmark", "infoText": "" },
    { "label": "Dominican Republic", "value": "dominican-republic", "infoText": "" },
    { "label": "Ecuador", "value": "ecuador", "infoText": "" },
    { "label": "Egypt", "value": "egypt", "infoText": "" },
    { "label": "El Salvador", "value": "el-salvador", "infoText": "" },
    { "label": "England", "value": "england", "infoText": "" },
    { "label": "Estonia", "value": "estonia", "infoText": "" },
    { "label": "Finland", "value": "finland", "infoText": "" },
    { "label": "France", "value": "france", "infoText": "" },
    { "label": "Georgia", "value": "georgia", "infoText": "" },
    { "label": "Germany", "value": "germany", "infoText": "" },
    { "label": "Greece", "value": "greece", "infoText": "" },
    { "label": "Guatemala", "value": "guatemala", "infoText": "" },
    { "label": "Hungary", "value": "hungary", "infoText": "" },
    { "label": "Israel", "value": "israel", "infoText": "" },
    { "label": "Japan", "value": "japan", "infoText": "" },
    { "label": "South Korea", "value": "korea-republic", "infoText": "" },
    { "label": "Latvia", "value": "latvia", "infoText": "" },
    { "label": "Lithuania", "value": "lithuania", "infoText": "" },
    { "label": "Luxembourg", "value": "luxembourg", "infoText": "" },
    { "label": "Mexico", "value": "mexico", "infoText": "" },
    { "label": "Montenegro", "value": "montenegro", "infoText": "" },
    { "label": "Morocco", "value": "morocco", "infoText": "" },
    { "label": "Netherlands", "value": "netherlands", "infoText": "" },
    { "label": "New Zealand", "value": "new-zealand", "infoText": "" },
    { "label": "Nigeria", "value": "nigeria", "infoText": "" },
    { "label": "North Macedonia", "value": "fyr-macedonia", "infoText": "" },
    { "label": "Norway", "value": "norway", "infoText": "" },
    { "label": "Paraguay", "value": "paraguay", "infoText": "" },
    { "label": "Peru", "value": "peru", "infoText": "" },
    { "label": "Philippines", "value": "philippines", "infoText": "" },
    { "label": "Poland", "value": "poland", "infoText": "" },
    { "label": "Portugal", "value": "portugal", "infoText": "" },
    { "label": "Puerto Rico", "value": "puerto-rico", "infoText": "" },
    { "label": "Romania", "value": "romania", "infoText": "" },
    { "label": "Russia", "value": "russia", "infoText": "" },
    { "label": "Senegal", "value": "senegal", "infoText": "" },
    { "label": "Serbia", "value": "serbia", "infoText": "" },
    { "label": "Singapore", "value": "singapore", "infoText": "" },
    { "label": "Slovakia", "value": "slovakia", "infoText": "" },
    { "label": "Slovenia", "value": "slovenia", "infoText": "" },
    { "label": "South Africa", "value": "south-africa", "infoText": "" },
    { "label": "Spain", "value": "spain", "infoText": "" },
    { "label": "Sweden", "value": "sweden", "infoText": "" },
    { "label": "Switzerland", "value": "switzerland", "infoText": "" },
    { "label": "Thailand", "value": "thailand", "infoText": "" },
    { "label": "Turkey", "value": "turkey", "infoText": "" },
    { "label": "Ukraine", "value": "ukraine", "infoText": "" },
    { "label": "United States", "value": "united-states", "infoText": "" },
    { "label": "Uruguay", "value": "uruguay", "infoText": "" },
    { "label": "Venezuela", "value": "venezuela", "infoText": "" }
];

const CRICKET_COUNTRIES = [
    { "label": "International Tournaments", "value": "world", "infoText": "ICC Cricket World Cup\nICC T20 World Cup\nICC Champions Trophy\nICC World Test Championship\nICC Women's Cricket World Cup" },
    { "label": "Afghanistan", "value": "afghanistan", "infoText": "" },
    { "label": "Australia", "value": "australia", "infoText": "" },
    { "label": "Bangladesh", "value": "bangladesh", "infoText": "" },
    { "label": "Chinese Taipei", "value": "chinese-taipei", "infoText": "" },
    { "label": "Cyprus", "value": "cyprus", "infoText": "" },
    { "label": "Czech Republic", "value": "czech-republic", "infoText": "" },
    { "label": "England", "value": "england", "infoText": "" },
    { "label": "Eswatini", "value": "eswatini", "infoText": "" },
    { "label": "Finland", "value": "finland", "infoText": "" },
    { "label": "Germany", "value": "germany", "infoText": "" },
    { "label": "Hong Kong, China", "value": "hong-kong-china", "infoText": "" },
    { "label": "Iceland", "value": "iceland", "infoText": "" },
    { "label": "India", "value": "india", "infoText": "" },
    { "label": "Ireland", "value": "ireland", "infoText": "" },
    { "label": "Nepal", "value": "nepal", "infoText": "" },
    { "label": "Netherlands", "value": "netherlands", "infoText": "" },
    { "label": "New Zealand", "value": "new-zealand", "infoText": "" },
    { "label": "Pakistan", "value": "pakistan", "infoText": "" },
    { "label": "Qatar", "value": "qatar", "infoText": "" },
    { "label": "South Africa", "value": "south-africa", "infoText": "" },
    { "label": "Spain", "value": "spain", "infoText": "" },
    { "label": "Sri Lanka", "value": "sri-lanka", "infoText": "" },
    { "label": "St Vincent and the Grenadines", "value": "st-vincent-and-the-grenadines", "infoText": "" },
    { "label": "Sweden", "value": "sweden", "infoText": "" },
    { "label": "Switzerland", "value": "switzerland", "infoText": "" },
    { "label": "Uganda", "value": "uganda", "infoText": "" },
    { "label": "United Arab Emirates", "value": "united-arab-emirates", "infoText": "" },
    { "label": "Vanuatu", "value": "vanuatu", "infoText": "" }
];

function footballCountryOptions(includeWorld) {
    return FOOTBALL_COUNTRIES.filter(country => includeWorld || country.value !== "world").map(country => ({
        label: country.label,
        value: country.value,
        icon: flagSource(country.value),
        infoText: country.infoText || ""
    }));
}

function basketballCountryOptions() {
    return BASKETBALL_COUNTRIES.map(country => ({
        label: country.label,
        value: country.value,
        icon: flagSource(country.value),
        infoText: country.infoText || ""
    }));
}

function cricketCountryOptions() {
    return CRICKET_COUNTRIES.map(country => ({
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

// Regional-indicator emoji flag for a country slug (e.g. "spain" -> 🇪🇸), or ""
// when there is no ISO-2 mapping (incl. "world"/international, which use a globe).
function flagEmoji(countrySlug) {
    const code = COUNTRY_FLAG_CODES[String(countrySlug || "").trim().toLowerCase()];
    if (!code || code.length !== 2)
        return "";

    const upper = code.toUpperCase();
    const base = 0x1F1E6;
    const first = upper.charCodeAt(0) - 65;
    const second = upper.charCodeAt(1) - 65;
    if (first < 0 || first > 25 || second < 0 || second > 25)
        return "";

    return String.fromCodePoint(base + first) + String.fromCodePoint(base + second);
}

// Acronym / special-case country labels that simple title-casing would get wrong.
const COUNTRY_DISPLAY_OVERRIDES = {
    "usa": "USA",
    "uae": "UAE",
    "united-states": "United States",
    "world": "International"
};

// Human-readable country name for a slug: "england" -> "England",
// "united-states" -> "United States", "usa" -> "USA". Falls back to title-casing
// the hyphenated slug. Used so saved entries / summaries never show a bare slug.
function countryDisplayName(countrySlug) {
    const slug = String(countrySlug || "").trim().toLowerCase();
    if (slug.length === 0)
        return "";
    if (COUNTRY_DISPLAY_OVERRIDES.hasOwnProperty(slug))
        return COUNTRY_DISPLAY_OVERRIDES[slug];
    return slug.split("-")
        .filter(part => part.length > 0)
        .map(part => part.charAt(0).toUpperCase() + part.slice(1))
        .join(" ");
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
