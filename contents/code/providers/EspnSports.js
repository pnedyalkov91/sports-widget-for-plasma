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

// ESPN public API catalog. Used both as a fallback for the SportScore sports
// (football, basketball, tennis) when SportScore fails, and as the data
// source for the ESPN-native sports (NFL, MLB, NHL, cricket, racing, …).
//
// Each sport maps to an ESPN "sport" path segment plus a curated list of leagues
// (ESPN league path segments). Endpoints:
//   https://site.api.espn.com/apis/site/v2/sports/{espnSport}/{league}/{scoreboard|teams|standings}
//
// "kind":
//   "team-league" - has standings + a team roster (league table & follow teams)
//   "event"       - individual/event based (tennis, racing, mma): scoreboard
//                   only; standings/teams degrade to empty states in the UI.
//
// Well-known league slugs (soccer big-5 + UCL/UEL/MLS/World Cup, nba/wnba, nfl,
// mlb, nhl, atp/wta, f1) are validated by common ESPN usage. The more obscure
// ones are best-effort; if a slug is wrong ESPN simply returns no events and the UI
// shows its normal empty state.

const SPORTS = [
    // --- Shared with SportScore (ESPN is the fallback) ---------------------
    {
        label: "Football", value: "football", espnSport: "soccer", kind: "team-league",
        leagues: [
            { label: "FIFA World Cup", league: "fifa.world", country: "world" },
            { label: "FIFA Women's World Cup", league: "fifa.wwc", country: "world" },
            { label: "FIFA Under-20 World Cup", league: "fifa.world.u20", country: "world" },
            { label: "FIFA Under-17 World Cup", league: "fifa.world.u17", country: "world" },
            { label: "FIFA Under-17 Women's World Cup", league: "fifa.wworld.u17", country: "world" },
            { label: "FIFA Club World Cup", league: "fifa.cwc", country: "world" },
            { label: "FIFA Intercontinental Cup", league: "fifa.intercontinental_cup", country: "world" },
            { label: "FIFA Women's Champions Cup", league: "fifa.w.champions_cup", country: "world" },
            { label: "Olympics Men's Football", league: "fifa.olympics", country: "world" },
            { label: "Olympics Women's Football", league: "fifa.w.olympics", country: "world" },
            { label: "International Friendly", league: "fifa.friendly", country: "world" },
            { label: "Women's International Friendly", league: "fifa.friendly.w", country: "world" },
            { label: "U21 International Friendly", league: "fifa.friendly_u21", country: "world" },
            { label: "U20 International Friendly", league: "fifa.u20.friendly", country: "world" },
            { label: "SheBelieves Cup", league: "fifa.shebelieves", country: "world" },
            { label: "World Cup Qualifying", league: "fifa.worldq", country: "world" },
            { label: "World Cup Qualifying - UEFA", league: "fifa.worldq.uefa", country: "world" },
            { label: "World Cup Qualifying - CAF", league: "fifa.worldq.caf", country: "world" },
            { label: "World Cup Qualifying - AFC", league: "fifa.worldq.afc", country: "world" },
            { label: "World Cup Qualifying - Concacaf", league: "fifa.worldq.concacaf", country: "world" },
            { label: "World Cup Qualifying - CONMEBOL", league: "fifa.worldq.conmebol", country: "world" },
            { label: "World Cup Qualifying - OFC", league: "fifa.worldq.ofc", country: "world" },
            { label: "Women's World Cup Qualifying - Playoff", league: "fifa.wwcq.ply", country: "world" },
            { label: "Women's World Cup Qualifying - UEFA", league: "fifa.wworldq.uefa", country: "world" },
            { label: "UEFA Champions League", league: "uefa.champions", country: "world" },
            { label: "UEFA Champions League Qualifying", league: "uefa.champions_qual", country: "world" },
            { label: "UEFA Europa League", league: "uefa.europa", country: "world" },
            { label: "UEFA Europa League Qualifying", league: "uefa.europa_qual", country: "world" },
            { label: "UEFA Conference League", league: "uefa.europa.conf", country: "world" },
            { label: "UEFA Conference League Qualifying", league: "uefa.europa.conf_qual", country: "world" },
            { label: "UEFA Super Cup", league: "uefa.super_cup", country: "world" },
            { label: "UEFA Women's Champions League", league: "uefa.wchampions", country: "world" },
            { label: "UEFA European Championship", league: "uefa.euro", country: "world" },
            { label: "UEFA European Championship Qualifying", league: "uefa.euroq", country: "world" },
            { label: "UEFA Women's European Championship", league: "uefa.weuro", country: "world" },
            { label: "UEFA European Under-21 Championship", league: "uefa.euro_u21", country: "world" },
            { label: "UEFA European Under-21 Championship Qualifying", league: "uefa.euro_u21_qual", country: "world" },
            { label: "UEFA European Under-19 Championship", league: "uefa.euro.u19", country: "world" },
            { label: "UEFA Nations League", league: "uefa.nations", country: "world" },
            { label: "UEFA Women's Nations League", league: "uefa.w.nations", country: "world" },
            { label: "Concacaf Champions Cup", league: "concacaf.champions", country: "world" },
            { label: "Leagues Cup", league: "concacaf.leagues.cup", country: "world" },
            { label: "Concacaf Gold Cup", league: "concacaf.gold", country: "world" },
            { label: "Concacaf Nations League", league: "concacaf.nations.league", country: "world" },
            { label: "Concacaf W Gold Cup", league: "concacaf.w.gold", country: "world" },
            { label: "Concacaf W Champions Cup", league: "concacaf.w.champions_cup", country: "world" },
            { label: "CONMEBOL Libertadores", league: "conmebol.libertadores", country: "world" },
            { label: "CONMEBOL Sudamericana", league: "conmebol.sudamericana", country: "world" },
            { label: "CONMEBOL Recopa", league: "conmebol.recopa", country: "world" },
            { label: "Copa America", league: "conmebol.america", country: "world" },
            { label: "Copa America Qualifying", league: "conmebol.america_qual", country: "world" },
            { label: "Copa America Femenina", league: "conmebol.america.femenina", country: "world" },
            { label: "Africa Cup of Nations", league: "caf.nations", country: "world" },
            { label: "Africa Cup of Nations Qualifying", league: "caf.nations_qual", country: "world" },
            { label: "CAF Champions League", league: "caf.champions", country: "world" },
            { label: "CAF Confederation Cup", league: "caf.confed", country: "world" },
            { label: "AFC Champions League Elite", league: "afc.champions", country: "world" },
            { label: "AFC Champions League Two", league: "afc.cup", country: "world" },
            { label: "AFC Asian Cup", league: "afc.asian.cup", country: "world" },
            { label: "Premier League", league: "eng.1", country: "england" },
            { label: "EFL Championship", league: "eng.2", country: "england" },
            { label: "EFL League One", league: "eng.3", country: "england" },
            { label: "EFL League Two", league: "eng.4", country: "england" },
            { label: "National League", league: "eng.5", country: "england" },
            { label: "FA Cup", league: "eng.fa", country: "england" },
            { label: "EFL Cup (Carabao Cup)", league: "eng.league_cup", country: "england" },
            { label: "EFL Trophy", league: "eng.trophy", country: "england" },
            { label: "FA Community Shield", league: "eng.charity", country: "england" },
            { label: "Premier League Asia Trophy", league: "eng.asia_trophy", country: "england" },
            { label: "Women's Super League", league: "eng.w.1", country: "england" },
            { label: "Women's FA Cup", league: "eng.w.fa", country: "england" },
            { label: "Women's FA Community Shield", league: "eng.w.charity", country: "england" },
            { label: "La Liga", league: "esp.1", country: "spain" },
            { label: "La Liga 2", league: "esp.2", country: "spain" },
            { label: "Copa del Rey", league: "esp.copa_del_rey", country: "spain" },
            { label: "Supercopa de Espana", league: "esp.super_cup", country: "spain" },
            { label: "Trofeo Joan Gamper", league: "esp.joan_gamper", country: "spain" },
            { label: "Liga F", league: "esp.w.1", country: "spain" },
            { label: "Copa de la Reina", league: "esp.copa_de_la_reina", country: "spain" },
            { label: "Bundesliga", league: "ger.1", country: "germany" },
            { label: "2. Bundesliga", league: "ger.2", country: "germany" },
            { label: "DFB-Pokal", league: "ger.dfb_pokal", country: "germany" },
            { label: "DFL-Supercup", league: "ger.super_cup", country: "germany" },
            { label: "Bundesliga Relegation Playoff", league: "ger.playoff.relegation", country: "germany" },
            { label: "2. Bundesliga Relegation Playoff", league: "ger.2.promotion.relegation", country: "germany" },
            { label: "Serie A", league: "ita.1", country: "italy" },
            { label: "Serie B", league: "ita.2", country: "italy" },
            { label: "Coppa Italia", league: "ita.coppa_italia", country: "italy" },
            { label: "Supercoppa Italiana", league: "ita.super_cup", country: "italy" },
            { label: "Ligue 1", league: "fra.1", country: "france" },
            { label: "Ligue 2", league: "fra.2", country: "france" },
            { label: "Coupe de France", league: "fra.coupe_de_france", country: "france" },
            { label: "Trophee des Champions", league: "fra.super_cup", country: "france" },
            { label: "Premiere Ligue (Women)", league: "fra.w.1", country: "france" },
            { label: "Eredivisie", league: "ned.1", country: "netherlands" },
            { label: "Eerste Divisie", league: "ned.2", country: "netherlands" },
            { label: "Tweede Divisie", league: "ned.3", country: "netherlands" },
            { label: "KNVB Beker", league: "ned.cup", country: "netherlands" },
            { label: "Johan Cruyff Shield", league: "ned.supercup", country: "netherlands" },
            { label: "Vrouwen Eredivisie", league: "ned.w.1", country: "netherlands" },
            { label: "KNVB Beker Vrouwen", league: "ned.w.knvb_cup", country: "netherlands" },
            { label: "Primeira Liga", league: "por.1", country: "portugal" },
            { label: "Taca de Portugal", league: "por.taca.portugal", country: "portugal" },
            { label: "Scottish Premiership", league: "sco.1", country: "scotland" },
            { label: "Scottish Championship", league: "sco.2", country: "scotland" },
            { label: "Scottish League One", league: "sco.3", country: "scotland" },
            { label: "Scottish League Two", league: "sco.4", country: "scotland" },
            { label: "Scottish Cup", league: "sco.tennents", country: "scotland" },
            { label: "Scottish League Cup", league: "sco.cis", country: "scotland" },
            { label: "Scottish Challenge Cup", league: "sco.challenge", country: "scotland" },
            { label: "Belgian Pro League", league: "bel.1", country: "belgium" },
            { label: "Austrian Bundesliga", league: "aut.1", country: "austria" },
            { label: "Greek Super League", league: "gre.1", country: "greece" },
            { label: "Turkish Super Lig", league: "tur.1", country: "turkey" },
            { label: "Danish Superliga", league: "den.1", country: "denmark" },
            { label: "Norwegian Eliteserien", league: "nor.1", country: "norway" },
            { label: "Swedish Allsvenskan", league: "swe.1", country: "sweden" },
            { label: "Cypriot First Division", league: "cyp.1", country: "cyprus" },
            { label: "League of Ireland Premier Division", league: "irl.1", country: "ireland" },
            { label: "Russian Premier League", league: "rus.1", country: "russia" },
            { label: "Major League Soccer", league: "usa.1", country: "usa" },
            { label: "U.S. Open Cup", league: "usa.open", country: "usa" },
            { label: "NWSL", league: "usa.nwsl", country: "usa" },
            { label: "NWSL Challenge Cup", league: "usa.nwsl.cup", country: "usa" },
            { label: "NWSL x Liga MX Femenil Summer Cup", league: "usa.nwsl.summer.cup", country: "usa" },
            { label: "USL Championship", league: "usa.usl.1", country: "usa" },
            { label: "USL League One", league: "usa.usl.l1", country: "usa" },
            { label: "USL Super League", league: "usa.w.usl.1", country: "usa" },
            { label: "NCAA Men's Soccer", league: "usa.ncaa.m.1", country: "usa" },
            { label: "NCAA Women's Soccer", league: "usa.ncaa.w.1", country: "usa" },
            { label: "Northern Super League", league: "can.w.nsl", country: "canada" },
            { label: "Liga MX", league: "mex.1", country: "mexico" },
            { label: "Liga de Expansion MX", league: "mex.2", country: "mexico" },
            { label: "Campeon de Campeones", league: "mex.campeon", country: "mexico" },
            { label: "Supercopa MX", league: "mex.supercopa", country: "mexico" },
            { label: "Liga Profesional Argentina", league: "arg.1", country: "argentina" },
            { label: "Copa Argentina", league: "arg.copa", country: "argentina" },
            { label: "Brasileirao Serie A", league: "bra.1", country: "brazil" },
            { label: "Brasileirao Serie B", league: "bra.2", country: "brazil" },
            { label: "Copa do Brasil", league: "bra.copa_do_brazil", country: "brazil" },
            { label: "Primera Division Chile", league: "chi.1", country: "chile" },
            { label: "Primera A Colombia", league: "col.1", country: "colombia" },
            { label: "Primera Division Paraguay", league: "par.1", country: "paraguay" },
            { label: "Liga 1 Peru", league: "per.1", country: "peru" },
            { label: "Primera Division Uruguay", league: "uru.1", country: "uruguay" },
            { label: "Liga Profesional Bolivia", league: "bol.1", country: "bolivia" },
            { label: "LigaPro Ecuador", league: "ecu.1", country: "ecuador" },
            { label: "Primera Division Venezuela", league: "ven.1", country: "venezuela" },
            { label: "South African Premiership", league: "rsa.1", country: "south-africa" },
            { label: "Nigerian Professional League", league: "nga.1", country: "nigeria" },
            { label: "Ghanaian Premier League", league: "gha.1", country: "ghana" },
            { label: "Saudi Pro League", league: "ksa.1", country: "saudi-arabia" },
            { label: "Saudi King's Cup", league: "ksa.kings.cup", country: "saudi-arabia" },
            { label: "J.League", league: "jpn.1", country: "japan" },
            { label: "Chinese Super League", league: "chn.1", country: "china" },
            { label: "Indian Super League", league: "ind.1", country: "india" },
            { label: "Thai League 1", league: "tha.1", country: "thailand" },
            { label: "Malaysian Super League", league: "mys.1", country: "malaysia" },
            { label: "Indonesian Super League", league: "idn.1", country: "indonesia" },
            { label: "Singapore Premier League", league: "sgp.1", country: "singapore" },
            { label: "A-League Men", league: "aus.1", country: "australia" },
            { label: "A-League Women", league: "aus.w.1", country: "australia" }
        ]
    },
    {
        label: "Basketball", value: "basketball", espnSport: "basketball", kind: "team-league",
        leagues: [
            { label: "NBA", league: "nba", country: "usa" },
            { label: "WNBA", league: "wnba", country: "usa" },
            { label: "NBA G League", league: "nba-development", country: "usa" },
            { label: "NCAA Men's", league: "mens-college-basketball", country: "usa" },
            { label: "NCAA Women's", league: "womens-college-basketball", country: "usa" },
            { label: "NBL", league: "nbl", country: "australia" },
            { label: "FIBA World Cup", league: "fiba", country: "world" },
            { label: "Olympics Men's Basketball", league: "mens-olympics-basketball", country: "world" },
            { label: "Olympics Women's Basketball", league: "womens-olympics-basketball", country: "world" },
            { label: "NBA California Classic Summer League", league: "nba-summer-california", country: "usa" },
            { label: "Golden State Summer League", league: "nba-summer-golden-state", country: "usa" },
            { label: "Las Vegas Summer League", league: "nba-summer-las-vegas", country: "usa" },
            { label: "Orlando Summer League", league: "nba-summer-orlando", country: "usa" },
            { label: "Sacramento Summer League", league: "nba-summer-sacramento", country: "usa" },
            { label: "Salt Lake City Summer League", league: "nba-summer-utah", country: "usa" }
        ]
    },
    {
        // Cricket is ESPN-only. ESPN's cricket "league" is a numeric
        // series id, not a slug: the core API's league list is empty and the site API
        // 404s slug paths such as /cricket/icc.t20/, so the ids below are the only
        // addressable form. They work in:
        //   site/v2/sports/cricket/{id}/scoreboard   (also carries a teams[] list)
        //   apis/v2/sports/cricket/{id}/standings    (note: no "/site")
        // Bilateral tours and one-off series get new ids all the time, so this list
        // only holds the evergreen competitions; everything currently running is added
        // live by SportsApi.fetchEspnCricketSeries (ESPN's scoreboard header feed).
        label: "Cricket", value: "cricket", espnSport: "cricket", kind: "team-league",
        leagues: [
            // International tournaments
            { label: "ICC Cricket World Cup", league: "8039", country: "world" },
            { label: "ICC Men's T20 World Cup", league: "8604", country: "world" },
            // Franchise T20 leagues
            { label: "Indian Premier League", league: "8048", country: "india" },
            { label: "Women's Premier League", league: "21282", country: "india" },
            { label: "Big Bash League", league: "8044", country: "australia" },
            { label: "Women's Big Bash League", league: "21284", country: "australia" },
            { label: "Pakistan Super League", league: "8679", country: "pakistan" },
            { label: "SA20", league: "21275", country: "south-africa" },
            { label: "International League T20", league: "20921", country: "uae" },
            { label: "Caribbean Premier League", league: "8623", country: "west-indies" },
            { label: "Women's Caribbean Premier League", league: "20898", country: "west-indies" },
            { label: "Bangladesh Premier League", league: "8653", country: "bangladesh" },
            { label: "The Hundred Men's Competition", league: "19601", country: "england" },
            { label: "Major League Cricket", league: "20978", country: "usa" },
            { label: "European T20 Premier League", league: "24698", country: "world" },
            // Domestic competitions
            { label: "County Championship Division One", league: "8052", country: "england" },
            { label: "Marsh Sheffield Shield", league: "8043", country: "australia" },
            { label: "Syed Mushtaq Ali Trophy", league: "8661", country: "india" },
            { label: "CSA 4-Day Series Division 1", league: "21185", country: "south-africa" },
            { label: "SLC T20 League", league: "18851", country: "sri-lanka" },
            { label: "ECB Women's One-Day Cup", league: "23080", country: "england" },
            { label: "Africa Continental Cup", league: "21470", country: "world" }
        ]
    },
    {
        label: "Tennis", value: "tennis", espnSport: "tennis", kind: "event",
        leagues: [
            { label: "ATP", league: "atp", country: "world" },
            { label: "WTA", league: "wta", country: "world" }
        ]
    },

    // --- ESPN-native sports ------------------------------------------------
    {
        label: "American Football", value: "american-football", espnSport: "football", kind: "team-league",
        leagues: [
            { label: "NFL", league: "nfl", country: "usa" },
            { label: "NCAA Football", league: "college-football", country: "usa" },
            { label: "CFL", league: "cfl", country: "canada" },
            { label: "UFL", league: "ufl", country: "usa" },
            { label: "XFL", league: "xfl", country: "usa" }
        ]
    },
    {
        label: "Baseball", value: "baseball", espnSport: "baseball", kind: "team-league",
        leagues: [
            { label: "MLB", league: "mlb", country: "usa" },
            { label: "College Baseball", league: "college-baseball", country: "usa" },
            { label: "World Baseball Classic", league: "world-baseball-classic", country: "world" },
            { label: "Caribbean Series", league: "caribbean-series", country: "world" },
            { label: "NCAA Softball", league: "college-softball", country: "usa" },
            { label: "Dominican Winter League", league: "dominican-winter-league", country: "dominican-republic" },
            { label: "Little League Baseball", league: "llb", country: "usa" },
            { label: "Little League Softball", league: "lls", country: "usa" },
            { label: "Mexican League", league: "mexican-winter-league", country: "mexico" },
            { label: "Olympics Men's Baseball", league: "olympics-baseball", country: "world" },
            { label: "Puerto Rican Winter League", league: "puerto-rican-winter-league", country: "puerto-rico" },
            { label: "Venezuelan Winter League", league: "venezuelan-winter-league", country: "venezuela" }
        ]
    },
    {
        label: "Ice Hockey", value: "hockey", espnSport: "hockey", kind: "team-league",
        leagues: [
            { label: "NHL", league: "nhl", country: "usa" },
            { label: "NCAA Men's Hockey", league: "mens-college-hockey", country: "usa" },
            { label: "NCAA Women's Hockey", league: "womens-college-hockey", country: "usa" },
            { label: "World Cup of Hockey", league: "hockey-world-cup", country: "world" },
            { label: "Olympics Men's Ice Hockey", league: "olympics-mens-ice-hockey", country: "world" },
            { label: "Olympics Women's Ice Hockey", league: "olympics-womens-ice-hockey", country: "world" }
        ]
    },
    {
        label: "Racing", value: "racing", espnSport: "racing", kind: "event",
        leagues: [
            { label: "Formula 1", league: "f1", country: "world" },
            { label: "NASCAR Cup Series", league: "nascar-premier", country: "usa" },
            { label: "NASCAR O'Reilly Auto Parts Series", league: "nascar-secondary", country: "usa" },
            { label: "NASCAR Truck Series", league: "nascar-truck", country: "usa" },
            { label: "IndyCar", league: "irl", country: "usa" }
        ]
    },
    {
        label: "MMA", value: "mma", espnSport: "mma", kind: "event",
        leagues: [
            { label: "UFC", league: "ufc", country: "world" },
            { label: "PFL", league: "pfl", country: "world" },
            { label: "Bellator MMA", league: "bellator", country: "world" }
        ]
    },
    {
        // "Rugby" unifies rugby union and rugby league. The league-feed entries use
        // espnSport "rugby"; the single rugby-league feed (numeric id 3) carries a
        // per-league espnSport override since it lives under a different ESPN path
        // ("rugby-league") - there are no separate NRL / Super League slugs.
        label: "Rugby", value: "rugby", espnSport: "rugby", kind: "team-league",
        leagues: [
            { label: "Premiership Rugby", league: "267979", country: "england" },
            { label: "United Rugby Championship", league: "270557", country: "world" },
            { label: "Six Nations", league: "180659", country: "world" },
            { label: "Rugby World Cup", league: "164205", country: "world" },
            { label: "Super Rugby Pacific", league: "242041", country: "world" },
            { label: "Major League Rugby", league: "289262", country: "usa" },
            { label: "Rugby League", league: "3", country: "world", espnSport: "rugby-league" }
        ]
    },
    {
        label: "Australian Football", value: "australian-football", espnSport: "australian-football", kind: "team-league",
        leagues: [
            { label: "AFL", league: "afl", country: "australia" }
        ]
    },
    {
        label: "Lacrosse", value: "lacrosse", espnSport: "lacrosse", kind: "team-league",
        leagues: [
            { label: "PLL", league: "pll", country: "usa" },
            { label: "NCAA Men's", league: "mens-college-lacrosse", country: "usa" },
            { label: "NCAA Women's", league: "womens-college-lacrosse", country: "usa" },
            { label: "NLL", league: "nll", country: "usa" }
        ]
    },
    {
        label: "Volleyball", value: "volleyball", espnSport: "volleyball", kind: "team-league",
        leagues: [
            { label: "NCAA Women's", league: "womens-college-volleyball", country: "usa" },
            { label: "NCAA Men's", league: "mens-college-volleyball", country: "usa" }
        ]
    }
];

// Sports SportScore also provides; for these ESPN is only a fallback, not a
// new sport in the picker. (Cricket is deliberately NOT here: it is ESPN-only.)
const SHARED_SPORTS = ["football", "basketball", "tennis"];

// ESPN-native sports whose whole league set is the curated "Top" list - there is
// no meaningful per-country catalog to browse, so the wizard skips the country
// step and ends on the Top page for them.
const NO_COUNTRY_BROWSE_SPORTS = [
    "american-football", "baseball", "hockey", "racing", "mma", "rugby",
    "australian-football", "lacrosse", "volleyball", "cricket"
];

// Maps a SportScore competition identity to an ESPN league, so SportScore's saved
// entries can fall back to ESPN. Keyed by the SportScore league slug.
const FALLBACK_LEAGUE_BY_SLUG = {
    // England
    "english-premier-league": { espnSport: "soccer", league: "eng.1" },
    "english-championship": { espnSport: "soccer", league: "eng.2" },
    "english-fa-cup": { espnSport: "soccer", league: "eng.fa" },
    "english-efl-cup": { espnSport: "soccer", league: "eng.league_cup" },
    "english-community-shield": { espnSport: "soccer", league: "eng.charity" },
    // Spain
    "spanish-la-liga": { espnSport: "soccer", league: "esp.1" },
    "spanish-laliga2": { espnSport: "soccer", league: "esp.2" },
    "spanish-copa-del-rey": { espnSport: "soccer", league: "esp.copa_del_rey" },
    "spanish-super-cup": { espnSport: "soccer", league: "esp.super_cup" },
    // Italy
    "italian-serie-a": { espnSport: "soccer", league: "ita.1" },
    "italian-serie-b": { espnSport: "soccer", league: "ita.2" },
    "italian-coppa-italia": { espnSport: "soccer", league: "ita.coppa_italia" },
    // Germany
    "german-bundesliga": { espnSport: "soccer", league: "ger.1" },
    "german-bundesliga-2": { espnSport: "soccer", league: "ger.2" },
    // France
    "french-ligue-1": { espnSport: "soccer", league: "fra.1" },
    "french-ligue-2": { espnSport: "soccer", league: "fra.2" },
    "french-coupe-de-france": { espnSport: "soccer", league: "fra.coupe_de_france" },
    // Portugal / Netherlands
    "portuguese-primera-liga": { espnSport: "soccer", league: "por.1" },
    "dutch-eredivisie": { espnSport: "soccer", league: "ned.1" },
    // Brazil
    "brazilian-serie-a": { espnSport: "soccer", league: "bra.1" },
    "brazilian-serie-b": { espnSport: "soccer", league: "bra.2" },
    "brazilian-copa-do-brasil": { espnSport: "soccer", league: "bra.copa_do_brazil" },
    // Argentina
    "argentine-liga-profesional": { espnSport: "soccer", league: "arg.1" },
    "argentine-copa-argentina": { espnSport: "soccer", league: "arg.copa" },
    // Mexico / USA
    "mexican-liga-mx": { espnSport: "soccer", league: "mex.1" },
    "american-major-league-soccer": { espnSport: "soccer", league: "usa.1" },
    "american-us-open-cup": { espnSport: "soccer", league: "usa.open" },
    // International
    "uefa-champions-league": { espnSport: "soccer", league: "uefa.champions" },
    "uefa-europa-league": { espnSport: "soccer", league: "uefa.europa" },
    "uefa-conference-league": { espnSport: "soccer", league: "uefa.europa.conf" },
    "conmebol-libertadores": { espnSport: "soccer", league: "conmebol.libertadores" },
    "concacaf-champions-cup": { espnSport: "soccer", league: "concacaf.champions" },
    "fifa-club-world-cup": { espnSport: "soccer", league: "fifa.cwc" },
    "fifa-world-cup": { espnSport: "soccer", league: "fifa.world" },
    // basketball
    "nba": { espnSport: "basketball", league: "nba" }
    // EuroLeague / EuroCup / EuroBasket etc. are intentionally NOT mapped: ESPN has no
    // feed for them, so they must resolve to null and be served by SportScore.
    // (A previous "euroleague" -> nba entry made EuroLeague show NBA games and teams.)
};

// SportScore country slug -> default ESPN soccer league, so a country's matches can
// fall back even without an explicit competition mapping.
const FALLBACK_LEAGUE_BY_COUNTRY = {
    "england": { espnSport: "soccer", league: "eng.1" },
    "spain": { espnSport: "soccer", league: "esp.1" },
    "italy": { espnSport: "soccer", league: "ita.1" },
    "germany": { espnSport: "soccer", league: "ger.1" },
    "france": { espnSport: "soccer", league: "fra.1" },
    "netherlands": { espnSport: "soccer", league: "ned.1" },
    "portugal": { espnSport: "soccer", league: "por.1" },
    "united-states": { espnSport: "soccer", league: "usa.1" },
    "usa": { espnSport: "soccer", league: "usa.1" }
};

function stringValue(value) {
    return value === undefined || value === null ? "" : String(value).trim();
}

function normalizedSport(value) {
    const text = stringValue(value).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
    if (text === "soccer")
        return "football";
    return text;
}

function sportEntry(sport) {
    const wanted = normalizedSport(sport);
    for (let index = 0; index < SPORTS.length; index += 1) {
        if (SPORTS[index].value === wanted)
            return SPORTS[index];
    }
    return null;
}

// All ESPN sports as picker options { label, value }.
function options() {
    return SPORTS.map(sport => ({ label: sport.label, value: sport.value }));
}

// Only the ESPN-native sports (not already provided by SportScore).
function nativeOptions() {
    return SPORTS.filter(sport => SHARED_SPORTS.indexOf(sport.value) < 0)
        .map(sport => ({ label: sport.label, value: sport.value }));
}

function supports(sport) {
    return sportEntry(sport) !== null;
}

function isNative(sport) {
    return supports(sport) && SHARED_SPORTS.indexOf(normalizedSport(sport)) < 0;
}

// True when the sport offers a per-country browse flow. ESPN-native sports with a
// fixed, fully-curated league set return false so the wizard ends on the Top page.
function hasCountryBrowse(sport) {
    return NO_COUNTRY_BROWSE_SPORTS.indexOf(normalizedSport(sport)) < 0;
}

function espnSportFor(sport) {
    const entry = sportEntry(sport);
    return entry ? entry.espnSport : "";
}

function kind(sport) {
    const entry = sportEntry(sport);
    return entry ? entry.kind : "";
}

function usesStandings(sport) {
    return kind(sport) === "team-league";
}

function usesTeams(sport) {
    return kind(sport) === "team-league";
}

// Individual ("event") sports whose followable competitors are single players, not
// teams, so the wizard offers players to follow instead of teams. They differ in
// where ESPN exposes the player list:
//   "rankings"  - tennis: a tour rankings feed (top ranked athletes).
//   "scoreboard"- mma/racing: the athletes are the event's competitors
//                 (tournament field / fight card / race grid) on the scoreboard.
const PLAYER_SOURCE = {
    "tennis": "rankings",
    "mma": "scoreboard",
    "racing": "scoreboard"
};

function usesPlayers(sport) {
    return PLAYER_SOURCE.hasOwnProperty(normalizedSport(sport));
}

// "rankings" or "scoreboard" - where to source this player sport's athletes from.
function playerSource(sport) {
    return PLAYER_SOURCE[normalizedSport(sport)] || "";
}

// Per-sport curation for the match-details Statistics tab. Each entry is the ordered
// list of ESPN boxscore statistic "name"s to show (others are dropped, so the panel
// shows the few meaningful ones in a sensible order rather than all ~28). The bar in
// the UI is drawn from each side's share of the pair's total; for a stat that is
// itself already a percentage/share (possession, shooting %s) we instead use the
// value as the ratio directly - listed in ESPN_PERCENT_STATS below. A sport not
// listed here falls back to showing every stat ESPN returns, in feed order.
const ESPN_STAT_ORDER = {
    "football": [
        "possessionPct", "totalShots", "shotsOnTarget", "wonCorners", "offsides",
        "foulsCommitted", "yellowCards", "redCards", "saves", "totalPasses",
        "accuratePasses", "passPct"
    ],
    "basketball": [
        "fieldGoalsMade-fieldGoalsAttempted", "fieldGoalPct",
        "threePointFieldGoalsMade-threePointFieldGoalsAttempted", "threePointFieldGoalPct",
        "freeThrowsMade-freeThrowsAttempted", "freeThrowPct", "totalRebounds",
        "assists", "steals", "blocks", "totalTurnovers", "fouls"
    ],
    "hockey": [
        "shotsTotal", "powerPlayGoals", "powerPlayPct", "faceoffsWon", "hits",
        "blockedShots", "takeaways", "penalties"
    ],
    "american-football": [
        "totalYards", "firstDowns", "thirdDownEff", "fourthDownEff", "netPassingYards",
        "completionAttempts", "rushingYards", "totalPenaltiesYards", "turnovers",
        "possessionTime"
    ]
};

// Stats whose value is already a percentage/share, so the comparison bar uses the
// value itself rather than each side's portion of the pair total. Names cover the
// sports above; a value > 1 is read as already-percent (57 -> 57%), a value in
// 0..1 as a ratio (0.8 -> 80%) - see espnStatRatio in SportsApi.
const ESPN_PERCENT_STATS = [
    "possessionPct", "passPct", "shotPct", "crossPct", "longballPct", "tacklePct",
    "fieldGoalPct", "threePointFieldGoalPct", "freeThrowPct", "powerPlayPct", "leadPercentage"
];

// Ordered statistic names to show for a sport, or [] to show every stat ESPN gives.
function statOrder(sport) {
    return ESPN_STAT_ORDER[normalizedSport(sport)] || [];
}

// Whether an ESPN statistic name is a percentage/share value (bar uses it directly).
function isPercentStat(name) {
    return ESPN_PERCENT_STATS.indexOf(stringValue(name)) >= 0;
}

// Per-player box score curation for the Players tab. ESPN's boxscore.players has one
// or more stat GROUPS per team, each with column `labels` and per-athlete `stats`.
// Sports vary: basketball is a single group; hockey/NFL split players into position
// groups. We curate, per sport, which groups to show and which columns (by label) to
// keep - the raw tables have 14-21 columns, far too wide for the panel. Each entry:
//   { group: <boxscore group name or "" for the single/unnamed group>,
//     title: <section heading shown in the UI>, columns: [<label>, …] }
// Football is absent on purpose: ESPN provides no per-player box score for it.
const ESPN_PLAYER_BOX = {
    "basketball": [
        { group: "", title: "Players", columns: ["MIN", "PTS", "REB", "AST", "STL", "BLK", "+/-"] }
    ],
    "hockey": [
        { group: "skaters", title: "Skaters", columns: ["G", "A", "SOG", "HT", "+/-", "TOI"] },
        { group: "forwards", title: "Forwards", columns: ["G", "A", "SOG", "HT", "+/-", "TOI"] },
        { group: "defenses", title: "Defense", columns: ["G", "A", "SOG", "HT", "+/-", "TOI"] },
        { group: "goalies", title: "Goalies", columns: ["SV", "GA", "SV%", "TOI"] }
    ],
    // Baseball: ESPN's boxscore.players statistics blocks are typed "batting" / "pitching"
    // (matched by espnPlayerBoxSection via the block's name or type). Columns missing from
    // a block are simply left out, so the list may name labels some feeds do not send.
    "baseball": [
        { group: "batting", title: "Batting", columns: ["H-AB", "R", "RBI", "HR", "BB", "K", "AVG"] },
        { group: "pitching", title: "Pitching", columns: ["IP", "H", "R", "ER", "BB", "K", "HR", "ERA"] }
    ],
    "american-football": [
        { group: "passing", title: "Passing", columns: ["C/ATT", "YDS", "TD", "INT"] },
        { group: "rushing", title: "Rushing", columns: ["CAR", "YDS", "TD", "LONG"] },
        { group: "receiving", title: "Receiving", columns: ["REC", "YDS", "TD", "LONG"] },
        { group: "defensive", title: "Defense", columns: ["TOT", "SOLO", "SACKS", "TD"] }
    ]
};

// Curated box-score sections for a sport, or [] when it has no per-player box score.
function playerBoxSections(sport) {
    return ESPN_PLAYER_BOX[normalizedSport(sport)] || [];
}

// Whether a sport offers a per-player box score (drives the Players tab visibility).
function hasPlayerBox(sport) {
    return playerBoxSections(sport).length > 0;
}

// Leagues for a sport as competition-style options the wizard can render:
// { label, value (=ESPN league slug), slug, country, espnSport, path }.
function leaguesFor(sport) {
    const entry = sportEntry(sport);
    if (!entry)
        return [];
    return entry.leagues.map(league => ({
        label: league.label,
        value: league.league,
        slug: league.league,
        country: league.country || "world",
        // A league may override the sport's ESPN path (e.g. the rugby-league feed
        // under the unified "Rugby" sport lives at espnSport "rugby-league").
        espnSport: league.espnSport || entry.espnSport,
        path: "/" + entry.value + "/competition/" + league.league + "/"
    }));
}

// Display name for a country slug ("usa" -> "USA", "united-states" -> "United States").
function countryLabelFor(country) {
    const slug = stringValue(country).toLowerCase();
    if (slug === "usa")
        return "USA";
    if (slug === "uae")
        return "UAE";
    return slug.split("-").filter(part => part.length > 0)
        .map(part => part.charAt(0).toUpperCase() + part.slice(1)).join(" ");
}

// This catalog says "usa"; SportScore-based country lists say "united-states".
function canonicalCountry(value) {
    const slug = stringValue(value).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
    if (slug === "usa" || slug === "us" || slug === "united-states-of-america")
        return "united-states";
    return slug;
}

function countryMatches(left, right) {
    const a = canonicalCountry(left);
    return a.length > 0 && a === canonicalCountry(right);
}

// All distinct countries used by a sport's leagues, as country options.
function countriesFor(sport) {
    const entry = sportEntry(sport);
    if (!entry)
        return [];
    const seen = {};
    const out = [];
    entry.leagues.forEach(league => {
        const country = stringValue(league.country) || "world";
        if (!seen[country]) {
            seen[country] = true;
            out.push({ label: countryLabelFor(country), value: country, icon: "" });
        }
    });
    return out;
}

// True when `league` is already an ESPN league slug for this sport (e.g. a
// shared-sport entry the wizard sourced from ESPN's own league catalog rather
// than from SportScore). Lets such entries resolve straight to ESPN.
function espnLeagueInCatalog(sport, league) {
    const entry = sportEntry(sport);
    const wanted = stringValue(league).toLowerCase();
    if (!entry || wanted.length === 0)
        return false;
    for (let index = 0; index < entry.leagues.length; index += 1) {
        if (stringValue(entry.leagues[index].league).toLowerCase() === wanted)
            return true;
    }
    return false;
}

// Human label for an ESPN league slug from the curated catalog, or "" if unknown.
function leagueLabelFor(leagueSlug) {
    const wanted = stringValue(leagueSlug).toLowerCase();
    if (wanted.length === 0)
        return "";
    for (let i = 0; i < SPORTS.length; i += 1) {
        for (let j = 0; j < SPORTS[i].leagues.length; j += 1) {
            if (stringValue(SPORTS[i].leagues[j].league).toLowerCase() === wanted)
                return SPORTS[i].leagues[j].label;
        }
    }
    return "";
}

// Resolve { espnSport, league } when `league` is an ESPN league slug that appears
// as a FALLBACK_LEAGUE_BY_SLUG target (covers leagues outside the curated catalog),
// or null. Matched against the given espnSport so e.g. a basketball slug can't
// resolve a soccer entry.
function espnLeagueFromTargets(espnSport, league) {
    const wantedSport = stringValue(espnSport).toLowerCase();
    const wantedLeague = stringValue(league).toLowerCase();
    if (wantedLeague.length === 0)
        return null;
    for (const slug in FALLBACK_LEAGUE_BY_SLUG) {
        const target = FALLBACK_LEAGUE_BY_SLUG[slug];
        if (stringValue(target.league).toLowerCase() === wantedLeague
            && (wantedSport.length === 0 || stringValue(target.espnSport).toLowerCase() === wantedSport))
            return { espnSport: target.espnSport, league: target.league };
    }
    return null;
}

// Resolve an ESPN { espnSport, league } for a saved/working entry, or null.
function espnLeagueForEntry(options) {
    options = options || {};
    const sport = normalizedSport(options.sport || options.sports);
    const league = stringValue(options.league).toLowerCase();
    const country = stringValue(options.country).toLowerCase();

    // Backward compat: "Rugby League" used to be its own sport; it is now a league
    // under the unified "Rugby". Resolve such legacy saved entries to its feed.
    if (sport === "rugby-league")
        return { espnSport: "rugby-league", league: league.length > 0 ? league : "3" };

    // ESPN-native sport: the entry's league IS an ESPN league slug already.
    if (isNative(sport)) {
        const entry = sportEntry(sport);
        if (league.length > 0) {
            // Honor a per-league ESPN path override (e.g. rugby-league under "Rugby").
            for (let i = 0; i < entry.leagues.length; i += 1) {
                if (stringValue(entry.leagues[i].league).toLowerCase() === league && entry.leagues[i].espnSport)
                    return { espnSport: entry.leagues[i].espnSport, league };
            }
            return { espnSport: entry.espnSport, league };
        }
        if (entry.leagues.length > 0)
            return { espnSport: entry.leagues[0].espnSport || entry.espnSport, league: entry.leagues[0].league };
        return null;
    }

    // Shared sport sourced from ESPN's own catalog: the league IS an ESPN slug.
    if (league.length > 0 && espnLeagueInCatalog(sport, league))
        return { espnSport: espnSportFor(sport), league: league };

    // Shared sport sourced from SportScore: translate the competition identity.
    // The fallback maps are keyed by SportScore slug but their targets are mostly
    // soccer (plus a couple of basketball) - only honour a target whose espnSport
    // matches the sport being resolved, so e.g. a basketball slug can't resolve to
    // a soccer league.
    if (league.length > 0 && FALLBACK_LEAGUE_BY_SLUG.hasOwnProperty(league)) {
        const target = FALLBACK_LEAGUE_BY_SLUG[league];
        if (stringValue(target.espnSport).toLowerCase() === espnSportFor(sport))
            return target;
    }

    // ESPN covers many leagues that aren't in the curated catalog (Brazil, second
    // tiers, cups…) - they only appear as fallback targets. If the entry already
    // carries such an ESPN league slug (e.g. "bra.1"), resolve it directly so it
    // isn't sent to SportScore.
    if (league.length > 0) {
        const direct = espnLeagueFromTargets(espnSportFor(sport), league);
        if (direct)
            return direct;
    }

    // FALLBACK_LEAGUE_BY_COUNTRY maps a country to its top SOCCER league, so only
    // apply it for football - otherwise basketball/cricket in those countries would
    // wrongly resolve to a soccer league.
    if (sport === "football" && country.length > 0 && FALLBACK_LEAGUE_BY_COUNTRY.hasOwnProperty(country))
        return FALLBACK_LEAGUE_BY_COUNTRY[country];

    // Basketball default to the NBA, but ONLY for entries that aren't tied to a
    // specific competition or a non-US country. A country-scoped pick (e.g. a
    // Bulgarian league) that ESPN doesn't cover must return null so it routes to
    // SportScore - otherwise it would wrongly resolve to NBA teams/matches.
    if (sport === "basketball" && league.length === 0
        && (country.length === 0 || country === "usa" || country === "united-states")) {
        return { espnSport: "basketball", league: "nba" };
    }

    return null;
}
