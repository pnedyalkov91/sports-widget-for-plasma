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

import "../code/providers/ProviderCatalog.js" as ProviderCatalog
import "../code/providers/SportScoreSports.js" as SportScoreSports
import "../code/SportVisuals.js" as SportVisuals
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var tableModel
    property var tableRows: []
    property int tableCount: 0
    property string tableErrorMessage: ""
    property bool tableLoading: false
    property string league: ""
    property string leagueLabel: ""
    property string sport: "football"
    property string favoriteTeam: ""
    property bool followTeamMode: false
    property var tableOptions: []
    property string selectedTableSlug: ""
    property var seasonOptions: []
    property string selectedSeasonKey: ""
    property bool seasonLoading: false
    readonly property int rowCount: tableRows ? tableRows.length : 0
    readonly property var displayRows: groupedRows()
    // Racing standings come as two tables (drivers / constructors). When ESPN
    // returns both they are shown as sub-tabs instead of one long stacked list.
    property string selectedRacingGroup: ""
    readonly property var racingGroups: root.collectRacingGroups()
    readonly property bool showRacingTabs: root.isRacing && root.racingGroups.length > 1
    readonly property string effectiveRacingGroup: root.racingGroups.indexOf(root.selectedRacingGroup) >= 0
        ? root.selectedRacingGroup : (root.racingGroups.length > 0 ? root.racingGroups[0] : "")
    // Tennis rankings are one list per tour (ATP men / WTA women): shown as sub-tabs
    // under the Tables tab instead of the generic "Table:" dropdown.
    readonly property bool showTourTabs: root.sport === "tennis" && Array.isArray(root.tableOptions) && root.tableOptions.length > 1
    // Racing (F1 / NASCAR / IndyCar): the table is the drivers' (and constructors')
    // championship - points and the gap to the leader, no W/D/L and no form.
    readonly property bool isRacing: String(root.sport || "").toLowerCase() === "racing"
    readonly property var racingColumns: [
        { "key": "points", "label": i18nc("@title:column championship points short", "Pts"), "tooltip": i18nc("@info:tooltip", "Championship points"), "width": 3, "emphasized": true },
        { "key": "gap", "label": i18nc("@title:column points gap short", "Gap"), "tooltip": i18nc("@info:tooltip", "Points behind the leader"), "width": 3, "emphasized": false }
    ]
    // Baseball (MLB) mirrors ESPN's standings page: record, win %, games behind, home /
    // away records, runs scored / allowed / differential, streak and last ten. Columns are
    // ranked by `priority` (lower = more important); the ones that do not fit the current
    // popup width are dropped from the least important end, see visibleViewColumns().
    readonly property bool isBaseball: String(root.sport || "").toLowerCase() === "baseball"
    // Standings views (ESPN's MLB page tabs):
    //   "division" - AL East, AL Central ... (ESPN's own groups)
    //   "league"   - every AL / NL team ranked together
    //   "overall"  - all 30 teams in one table
    //   "wildcard" - per league: division leaders, then the wild-card race
    //   "expanded" - division table with every column (scrolls sideways when wide)
    property string selectedBaseballView: "division"
    readonly property bool showBaseballTabs: root.isBaseball && root.rowCount > 0
    readonly property bool baseballExpanded: root.isBaseball && root.selectedBaseballView === "expanded"
    readonly property var baseballViews: ["division", "league", "overall", "wildcard", "expanded"]
    readonly property var baseballColumns: [
        { "key": "won", "label": i18nc("@title:column baseball wins short", "W"), "tooltip": i18nc("@info:tooltip", "Wins"), "width": 1.7, "emphasized": true, "priority": 1 },
        { "key": "lost", "label": i18nc("@title:column baseball losses short", "L"), "tooltip": i18nc("@info:tooltip", "Losses"), "width": 1.7, "emphasized": true, "priority": 1 },
        { "key": "winPercent", "label": i18nc("@title:column baseball win percentage short", "PCT"), "tooltip": i18nc("@info:tooltip", "Winning percentage"), "width": 2.4, "emphasized": false, "priority": 1 },
        { "key": "gamesBehind", "label": i18nc("@title:column baseball games behind short", "GB"), "tooltip": i18nc("@info:tooltip", "Games behind the leader"), "width": 2.1, "emphasized": false, "priority": 1 },
        { "key": "homeRecord", "label": i18nc("@title:column baseball home record short", "HOME"), "tooltip": i18nc("@info:tooltip", "Home record"), "width": 2.8, "emphasized": false, "priority": 6 },
        { "key": "awayRecord", "label": i18nc("@title:column baseball away record short", "AWAY"), "tooltip": i18nc("@info:tooltip", "Away record"), "width": 2.8, "emphasized": false, "priority": 6 },
        { "key": "goalsFor", "label": i18nc("@title:column baseball runs scored short", "RS"), "tooltip": i18nc("@info:tooltip", "Runs scored"), "width": 2.1, "emphasized": false, "priority": 5 },
        { "key": "goalsAgainst", "label": i18nc("@title:column baseball runs allowed short", "RA"), "tooltip": i18nc("@info:tooltip", "Runs allowed"), "width": 2.1, "emphasized": false, "priority": 5 },
        { "key": "goalDifference", "label": i18nc("@title:column baseball run differential short", "DIFF"), "tooltip": i18nc("@info:tooltip", "Run differential"), "width": 2.5, "emphasized": false, "priority": 4 },
        { "key": "streak", "label": i18nc("@title:column baseball streak short", "STRK"), "tooltip": i18nc("@info:tooltip", "Current winning / losing streak"), "width": 2.7, "emphasized": false, "priority": 2 },
        { "key": "lastTen", "label": i18nc("@title:column baseball last ten games short", "L10"), "tooltip": i18nc("@info:tooltip", "Record in the last ten games"), "width": 2.5, "emphasized": false, "priority": 3 },
        { "key": "playoffPercent", "label": i18nc("@title:column baseball playoff probability short", "POFF"), "tooltip": i18nc("@info:tooltip", "Chance of making the playoffs"), "width": 3.0, "emphasized": false, "priority": 7 },
        { "key": "divisionRecord", "label": i18nc("@title:column baseball record in own division short", "DIV"), "tooltip": i18nc("@info:tooltip", "Record against the team's own division"), "width": 2.8, "emphasized": false, "priority": 8, "expandedOnly": true },
        { "key": "leagueRecord", "label": i18nc("@title:column baseball record in own league short", "LG"), "tooltip": i18nc("@info:tooltip", "Record against the team's own league"), "width": 3.0, "emphasized": false, "priority": 8, "expandedOnly": true }
    ]
    // Hockey (NHL) mirrors ESPN's NHL standings page the same way baseball does: a view
    // switch (Standings / League / Wild Card / Expanded) over one set of columns ranked by
    // `priority`. The views only switch on when the rows carry a conference (ESPN's NHL
    // standings do); any other hockey table keeps the generic columns.
    //   "standings" - the four divisions (Atlantic, Metropolitan, Central, Pacific)
    //   "league"    - all teams in one table, ESPN's /standings/_/group/league
    //   "wildcard"  - per conference: top 3 of each division, then the wild-card race
    //   "expanded"  - division tables with every column (scrolls sideways when wide)
    readonly property bool isHockey: String(root.sport || "").toLowerCase() === "hockey"
    readonly property bool hockeyViewsActive: root.isHockey && root.rowCount > 0
        && String(root.tableRows[0].conference || "").length > 0
    property string selectedHockeyView: "standings"
    readonly property bool showHockeyTabs: root.hockeyViewsActive
    readonly property bool hockeyExpanded: root.hockeyViewsActive && root.selectedHockeyView === "expanded"
    readonly property var hockeyViews: ["standings", "league", "wildcard", "expanded"]
    readonly property var hockeyColumns: [
        { "key": "played", "label": i18nc("@title:column hockey games played short", "GP"), "tooltip": i18nc("@info:tooltip", "Games played"), "width": 1.9, "emphasized": false, "priority": 1 },
        { "key": "won", "label": i18nc("@title:column hockey wins short", "W"), "tooltip": i18nc("@info:tooltip", "Wins"), "width": 1.7, "emphasized": false, "priority": 1 },
        { "key": "lost", "label": i18nc("@title:column hockey losses short", "L"), "tooltip": i18nc("@info:tooltip", "Losses"), "width": 1.7, "emphasized": false, "priority": 1 },
        { "key": "otLosses", "label": i18nc("@title:column hockey overtime losses short", "OTL"), "tooltip": i18nc("@info:tooltip", "Overtime / shootout losses"), "width": 2.0, "emphasized": false, "priority": 1 },
        { "key": "points", "label": i18nc("@title:column hockey points short", "PTS"), "tooltip": i18nc("@info:tooltip", "Points"), "width": 2.1, "emphasized": true, "priority": 1 },
        { "key": "pointsPct", "label": i18nc("@title:column hockey points percentage short", "P%"), "tooltip": i18nc("@info:tooltip", "Points percentage (points won out of points available)"), "width": 2.5, "emphasized": false, "priority": 7 },
        { "key": "regWins", "label": i18nc("@title:column hockey regulation wins short", "RW"), "tooltip": i18nc("@info:tooltip", "Regulation wins"), "width": 2.0, "emphasized": false, "priority": 8, "expandedOnly": true },
        { "key": "rowWins", "label": i18nc("@title:column hockey regulation plus overtime wins short", "ROW"), "tooltip": i18nc("@info:tooltip", "Regulation plus overtime wins (first tiebreaker after points)"), "width": 2.3, "emphasized": false, "priority": 2 },
        { "key": "goalsFor", "label": i18nc("@title:column hockey goals for short", "GF"), "tooltip": i18nc("@info:tooltip", "Goals for"), "width": 2.1, "emphasized": false, "priority": 5 },
        { "key": "goalsAgainst", "label": i18nc("@title:column hockey goals against short", "GA"), "tooltip": i18nc("@info:tooltip", "Goals against"), "width": 2.1, "emphasized": false, "priority": 5 },
        { "key": "goalDifference", "label": i18nc("@title:column hockey goal differential short", "DIFF"), "tooltip": i18nc("@info:tooltip", "Goal differential"), "width": 2.5, "emphasized": false, "priority": 3 },
        { "key": "homeRecord", "label": i18nc("@title:column hockey home record short", "HOME"), "tooltip": i18nc("@info:tooltip", "Home record (W-L-OTL)"), "width": 3.0, "emphasized": false, "priority": 6 },
        { "key": "awayRecord", "label": i18nc("@title:column hockey away record short", "AWAY"), "tooltip": i18nc("@info:tooltip", "Away record (W-L-OTL)"), "width": 3.0, "emphasized": false, "priority": 6 },
        { "key": "shootoutRecord", "label": i18nc("@title:column hockey shootout record short", "S/O"), "tooltip": i18nc("@info:tooltip", "Shootout record (wins-losses)"), "width": 2.3, "emphasized": false, "priority": 7 },
        { "key": "lastTen", "label": i18nc("@title:column hockey last ten games short", "L10"), "tooltip": i18nc("@info:tooltip", "Record in the last ten games (W-L-OTL)"), "width": 2.8, "emphasized": false, "priority": 4 },
        { "key": "streak", "label": i18nc("@title:column hockey streak short", "STRK"), "tooltip": i18nc("@info:tooltip", "Current winning / losing streak"), "width": 2.6, "emphasized": false, "priority": 2 },
        { "key": "divisionRecord", "label": i18nc("@title:column hockey record in own division short", "DIV"), "tooltip": i18nc("@info:tooltip", "Record against the team's own division (W-L-OTL)"), "width": 2.9, "emphasized": false, "priority": 8, "expandedOnly": true }
    ]
    // Lacrosse (PLL / NLL / NCAA) mirrors ESPN's PLL standings page: one ranked table with
    // W, L, PCT, PF, PA and DIFF - no draws, no league points and no form badges. ESPN's own
    // glossary for the columns is repeated under the table (see TableLegend).
    // PCT and DIFF are derived from the row's W / L / PF / PA when ESPN does not send them in
    // the expected format, and the order falls back to PCT then DIFF when ESPN sends no rank.
    readonly property bool isLacrosse: String(root.sport || "").toLowerCase() === "lacrosse"
    readonly property var lacrosseColumns: [
        { "key": "won", "label": i18nc("@title:column lacrosse wins short", "W"), "tooltip": i18nc("@info:tooltip", "Wins"), "width": 2.0, "emphasized": true },
        { "key": "lost", "label": i18nc("@title:column lacrosse losses short", "L"), "tooltip": i18nc("@info:tooltip", "Losses"), "width": 2.0, "emphasized": false },
        { "key": "winPercent", "label": i18nc("@title:column lacrosse win percentage short", "PCT"), "tooltip": i18nc("@info:tooltip", "Winning percentage"), "width": 2.6, "emphasized": false },
        { "key": "goalsFor", "label": i18nc("@title:column lacrosse points for short", "PF"), "tooltip": i18nc("@info:tooltip", "Total points for"), "width": 2.4, "emphasized": false },
        { "key": "goalsAgainst", "label": i18nc("@title:column lacrosse points against short", "PA"), "tooltip": i18nc("@info:tooltip", "Total points against"), "width": 2.4, "emphasized": false },
        { "key": "goalDifference", "label": i18nc("@title:column lacrosse point differential short", "DIFF"), "tooltip": i18nc("@info:tooltip", "Point differential"), "width": 2.6, "emphasized": false }
    ]
    // Either of the two view-switched standings (MLB or NHL) is showing.
    readonly property bool viewsActive: root.isBaseball || root.hockeyViewsActive
    readonly property string activeView: root.isBaseball ? root.selectedBaseballView : root.selectedHockeyView
    readonly property bool viewsExpanded: root.baseballExpanded || root.hockeyExpanded
    readonly property var tableColumns: root.isRacing ? root.racingColumns
        : (root.isLacrosse ? root.lacrosseColumns
        : (root.viewsActive ? root.visibleViewColumns(root.width) : SportScoreSports.standingsColumns(root.sport, i18nc)))
    // Total row width (px) of the Expanded view, which scrolls sideways instead of
    // dropping columns; 0 for every other view/sport.
    readonly property real expandedContentWidth: {
        if (!root.viewsExpanded)
            return 0;
        const unit = Kirigami.Units.gridUnit;
        const gap = Kirigami.Units.smallSpacing / unit;
        let units = 1.35 + 1.5 + 0.9 + 8.5 + 1 + 2 * gap;   // rank, crest, marker, team, scroll gutter, margins
        root.tableColumns.forEach(column => { units += column.width + gap; });
        return units * unit + 4 * Kirigami.Units.smallSpacing;
    }
    readonly property bool tableHasForm: (root.isRacing || root.viewsActive || root.isLacrosse) ? false : SportScoreSports.standingsHasForm(root.sport)
    readonly property color tablePrimaryTextColor: Kirigami.Theme.textColor
    readonly property color tableSecondaryTextColor: Kirigami.Theme.disabledTextColor
    readonly property color tableHighlightTextColor: Kirigami.Theme.linkColor
    readonly property color tableRowDividerColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
    readonly property color tablePositiveColor: "#0b8f08"
    readonly property color tableNegativeColor: "#e91e63"

    signal tableSelected(string slug)
    signal seasonSelected(string seasonKey)

    function collectRacingGroups() {
        const rows = root.tableRows || [];
        const names = [];
        rows.forEach(row => {
            const group = String(row.group || "").trim();
            if (group.length > 0 && names.indexOf(group) < 0)
                names.push(group);
        });
        return names;
    }

    function racingGroupKind(group) {
        const text = String(group || "").toLowerCase();
        if (text.indexOf("constructor") >= 0 || text.indexOf("team") >= 0 || text.indexOf("manufacturer") >= 0)
            return "constructor";
        if (text.indexOf("driver") >= 0)
            return "driver";
        return "";
    }

    function racingGroupLabel(group) {
        const kind = root.racingGroupKind(group);
        if (kind === "constructor")
            return i18nc("@title:tab racing constructors' championship", "Constructors");
        if (kind === "driver")
            return i18nc("@title:tab racing drivers' championship", "Drivers");
        return String(group || "");
    }

    // First column header of the racing table follows the selected sub-tab.
    function racingNameHeader() {
        return root.racingGroupKind(root.showRacingTabs ? root.effectiveRacingGroup : "") === "constructor"
            ? i18nc("@label", "Constructor") : i18nc("@label", "Driver");
    }

    // Baseball columns that fit `widthPx`. The fixed part of a row (rank, crest, clinch
    // letter and a readable team name) is reserved first; the stat columns are then added
    // priority level by priority level while they fit, so a narrow popup keeps
    // W / L / PCT / GB (+ streak ...) and a wide one shows the whole ESPN column set.
    // Columns of the selected baseball view. The expanded-only ones (DIV / LG) appear only
    // in the Expanded view; the Wild Card view calls its games-behind column WCGB.
    function viewColumnsForView() {
        const expanded = root.activeView === "expanded";
        const wildCard = root.isBaseball && root.activeView === "wildcard";
        return (root.isBaseball ? root.baseballColumns : root.hockeyColumns)
            .filter(column => expanded || column.expandedOnly !== true)
            .map(column => (wildCard && column.key === "gamesBehind")
                ? Object.assign({}, column, {
                    "label": i18nc("@title:column baseball wild card games behind short", "WCGB"),
                    "tooltip": i18nc("@info:tooltip", "Games behind the last wild card spot (+ = games ahead of it)"),
                    "width": 2.8
                })
                : column);
    }

    function visibleViewColumns(widthPx) {
        const all = root.viewColumnsForView();
        const unit = Kirigami.Units.gridUnit;
        // The Expanded view never drops columns - it scrolls sideways instead.
        if (!(widthPx > 0) || unit <= 0 || root.activeView === "expanded")
            return all;

        const gap = Kirigami.Units.smallSpacing / unit;
        let budget = (widthPx - unit) / unit            // list area (scroll bar gutter removed)
            - 2 * gap                                   // row side margins
            - 1.35 - 1.5 - 0.9 - 6.5                    // rank, crest, clinch letter, team name
            - 4 * gap;                                  // gaps between those fixed items
        const levels = [];
        all.forEach(column => {
            if (levels.indexOf(column.priority) < 0)
                levels.push(column.priority);
        });
        levels.sort((left, right) => left - right);

        const chosen = [];
        for (let index = 0; index < levels.length; index += 1) {
            const members = all.filter(column => column.priority === levels[index]);
            let cost = 0;
            members.forEach(column => { cost += column.width + gap; });
            if (cost > budget && chosen.length > 0)
                break;
            budget -= cost;
            members.forEach(column => chosen.push(column.key));
        }
        // Keep ESPN's column order, only filtering.
        return all.filter(column => chosen.indexOf(column.key) >= 0);
    }

    function baseballGamesBehindText(value) {
        if (value <= 0)
            return "-";
        return value % 1 === 0 ? String(value) : value.toFixed(1);
    }

    // "American League East" -> "American League" (AL/NL together for the league view).
    function baseballLeagueName(group) {
        const name = String(group || "").trim();
        const stripped = name.replace(/\s+(East|Central|West)$/i, "").trim();
        return stripped.length > 0 ? stripped : name;
    }

    function baseballSorted(list) {
        const indexed = list.map((row, index) => ({ "row": row, "index": index }));
        indexed.sort((left, right) => Number(right.row.winPercentValue || 0) - Number(left.row.winPercentValue || 0)
            || Number(right.row.won || 0) - Number(left.row.won || 0)
            || left.index - right.index);
        return indexed.map(item => item.row);
    }

    // Games `row` is behind `leader`: ((leader W - W) + (L - leader L)) / 2.
    function baseballBehind(leader, row) {
        return ((Number(leader.won || 0) - Number(row.won || 0)) + (Number(row.lost || 0) - Number(leader.lost || 0))) / 2;
    }

    // "+1.5" / "-" / "2.0": signed games ahead of (+) or behind a cut-off team.
    function baseballCutoffText(cutoff, row) {
        const behind = root.baseballBehind(cutoff, row);
        if (behind === 0)
            return "-";
        const size = Math.abs(behind);
        const text = size % 1 === 0 ? String(size) : size.toFixed(1);
        return behind < 0 ? "+" + text : text;
    }

    // Wild Card view: for each league the three division leaders, then the rest of the
    // league ranked as the wild-card race. Derived from the standings rows (a division's
    // best record leads it) - ESPN's standings feed has no separate wild-card table.
    function baseballWildCardGroups(rows) {
        const leagues = [];
        const byLeague = {};
        rows.forEach(row => {
            const raw = String(row.group || "").trim();
            const leagueName = root.baseballLeagueName(raw);
            if (byLeague[leagueName] === undefined) {
                byLeague[leagueName] = leagues.length;
                leagues.push({ "name": leagueName, "divisions": {}, "order": [] });
            }
            const league = leagues[byLeague[leagueName]];
            if (league.divisions[raw] === undefined) {
                league.divisions[raw] = [];
                league.order.push(raw);
            }
            league.divisions[raw].push(row);
        });

        const result = [];
        leagues.forEach(league => {
            let leaders = [];
            let rest = [];
            league.order.forEach(division => {
                const ranked = root.baseballSorted(league.divisions[division]);
                if (ranked.length > 0)
                    leaders.push(ranked[0]);
                rest = rest.concat(ranked.slice(1));
            });
            leaders = root.baseballSorted(leaders);
            rest = root.baseballSorted(rest);
            // The last wild-card spot is the 3rd (MLB: three per league).
            const cutoff = rest.length > 0 ? rest[Math.min(2, rest.length - 1)] : null;

            result.push({ "isGroupHeader": true, "group": i18nc("@title:group baseball division leaders of a league", "%1 · Division Leaders", league.name) });
            leaders.forEach((row, index) => {
                const copy = Object.assign({}, row);
                copy.position = index + 1;
                copy.gamesBehind = "-";
                result.push(copy);
            });
            result.push({ "isGroupHeader": true, "group": i18nc("@title:group baseball wild card race of a league", "%1 · Wild Card", league.name) });
            rest.forEach((row, index) => {
                const copy = Object.assign({}, row);
                copy.position = index + 1;
                copy.gamesBehind = cutoff ? root.baseballCutoffText(cutoff, row) : "-";
                result.push(copy);
            });
        });
        return result;
    }

    // Baseball rows for the selected view (see selectedBaseballView). Division / Expanded:
    // ESPN's own groups ranked by win % with 1..n numbering inside each division.
    // League / Overall: AL + NL teams (or all teams) in one list, games behind recomputed
    // against the leader of that list. Wild Card: baseballWildCardGroups().
    function baseballGroups() {
        const rows = root.tableRows || [];
        const view = root.selectedBaseballView;
        if (view === "wildcard")
            return root.baseballWildCardGroups(rows);

        const regroup = view === "league" || view === "overall";
        const groups = [];
        const byName = {};
        rows.forEach(row => {
            const raw = String(row.group || "").trim();
            const name = view === "overall" ? "" : (view === "league" ? root.baseballLeagueName(raw) : raw);
            if (byName[name] === undefined) {
                byName[name] = groups.length;
                groups.push({ "name": name, "rows": [] });
            }
            groups[byName[name]].rows.push(row);
        });

        let result = [];
        groups.forEach(group => {
            if (group.name.length > 0)
                result.push({ "isGroupHeader": true, "group": group.name });

            const ranked = root.baseballSorted(group.rows);
            const leader = ranked.length > 0 ? ranked[0] : null;
            ranked.forEach((row, index) => {
                const copy = Object.assign({}, row);
                copy.position = index + 1;
                if (regroup && leader)
                    copy.gamesBehind = root.baseballGamesBehindText(root.baseballBehind(leader, row));
                result.push(copy);
            });
        });
        return result;
    }

    // NHL ranking: points, then fewer games played, then regulation wins, regulation +
    // overtime wins and goal differential (the league's own tiebreak order).
    function hockeySorted(list) {
        return list.slice().sort((left, right) => Number(right.points || 0) - Number(left.points || 0)
            || Number(left.played || 0) - Number(right.played || 0)
            || Number(right.regWins || 0) - Number(left.regWins || 0)
            || Number(right.rowWins || 0) - Number(left.rowWins || 0)
            || Number(right.goalDifference || 0) - Number(left.goalDifference || 0));
    }

    function hockeyNumbered(list) {
        return list.map((row, index) => Object.assign({}, row, { "position": index + 1 }));
    }

    // Wild Card view: for each conference the top three of every division, then the rest of
    // the conference ranked as the wild-card race (the first two get the wild cards).
    // Derived from the standings rows - ESPN's feed has no separate wild-card table.
    function hockeyWildCardGroups(rows) {
        const conferences = [];
        const byConference = {};
        rows.forEach(row => {
            const conference = String(row.conference || "").trim();
            const division = String(row.group || "").trim();
            if (byConference[conference] === undefined) {
                byConference[conference] = conferences.length;
                conferences.push({ "name": conference, "divisions": {}, "order": [] });
            }
            const entry = conferences[byConference[conference]];
            if (entry.divisions[division] === undefined) {
                entry.divisions[division] = [];
                entry.order.push(division);
            }
            entry.divisions[division].push(row);
        });

        let result = [];
        conferences.forEach(conference => {
            let rest = [];
            conference.order.forEach(division => {
                const ranked = root.hockeySorted(conference.divisions[division]);
                result.push({ "isGroupHeader": true, "group": i18nc("@title:group hockey division of a conference", "%1 · %2", conference.name, division) });
                result = result.concat(root.hockeyNumbered(ranked.slice(0, 3)));
                rest = rest.concat(ranked.slice(3));
            });
            result.push({ "isGroupHeader": true, "group": i18nc("@title:group hockey wild card race of a conference", "%1 · Wild Card", conference.name) });
            result = result.concat(root.hockeyNumbered(root.hockeySorted(rest)));
        });
        return result;
    }

    // Hockey rows for the selected view. Standings / Expanded: each division ranked 1..n;
    // League: every team ranked together; Wild Card: hockeyWildCardGroups().
    function hockeyGroups() {
        const rows = root.tableRows || [];
        const view = root.selectedHockeyView;
        if (view === "wildcard")
            return root.hockeyWildCardGroups(rows);
        if (view === "league")
            return root.hockeyNumbered(root.hockeySorted(rows));

        const groups = [];
        const byName = {};
        rows.forEach(row => {
            const name = String(row.group || "").trim();
            if (byName[name] === undefined) {
                byName[name] = groups.length;
                groups.push({ "name": name, "rows": [] });
            }
            groups[byName[name]].rows.push(row);
        });
        let result = [];
        groups.forEach(group => {
            if (group.name.length > 0)
                result.push({ "isGroupHeader": true, "group": group.name });
            result = result.concat(root.hockeyNumbered(root.hockeySorted(group.rows)));
        });
        return result;
    }

    function hockeyViewLabel(view) {
        if (view === "league")
            return i18nc("@title:tab hockey standings of all teams", "League");
        if (view === "wildcard")
            return i18nc("@title:tab hockey wild card race", "Wild Card");
        if (view === "expanded")
            return i18nc("@title:tab hockey standings with all columns", "Expanded");
        return i18nc("@title:tab hockey standings by division", "Standings");
    }

    // Winning percentage as a number: wins over decided games (a tie counts as half a win).
    // Computed from the record because ESPN's own value is not always a 0..1 ratio.
    function lacrossePctValue(row) {
        const won = Number(row && row.won) || 0;
        const lost = Number(row && row.lost) || 0;
        const tied = Number(row && row.draw) || 0;
        const games = won + lost + tied;
        return games > 0 ? (won + tied / 2) / games : 0;
    }

    // ESPN's PCT cell: ".750", "1.000", ".000". ESPN's own text is used when it already has
    // that shape, otherwise the value is derived from the record ("-" before the first game).
    function lacrossePctText(row) {
        const given = String(row && row.winPercent || "").trim();
        if (/^(1\.000|\.\d{3})$/.test(given))
            return given;
        const games = (Number(row && row.won) || 0) + (Number(row && row.lost) || 0) + (Number(row && row.draw) || 0);
        if (games <= 0)
            return "-";
        const pct = root.lacrossePctValue(row);
        return pct >= 1 ? "1.000" : pct.toFixed(3).replace(/^0/, "");
    }

    // Point differential: PF - PA when either is known, else ESPN's own differential.
    function lacrosseDiffValue(row) {
        const pointsFor = Number(row && row.goalsFor) || 0;
        const pointsAgainst = Number(row && row.goalsAgainst) || 0;
        if (pointsFor > 0 || pointsAgainst > 0)
            return pointsFor - pointsAgainst;
        return Number(row && row.goalDifference) || 0;
    }

    // Ranks one lacrosse table. ESPN's own rank is kept when every team has a distinct one;
    // otherwise PCT, then point differential, then points for decide (which reproduces the
    // order of ESPN's PLL standings page). Teams are always numbered 1..n within the table.
    function lacrosseSorted(list) {
        const rows = list.slice();
        const seen = {};
        let distinct = rows.length > 0;
        rows.forEach(row => {
            const rank = Number(row.position) || 0;
            if (rank <= 0 || seen[rank] === true)
                distinct = false;
            seen[rank] = true;
        });
        rows.sort((left, right) => {
            if (distinct)
                return Number(left.position) - Number(right.position);
            return root.lacrossePctValue(right) - root.lacrossePctValue(left)
                || root.lacrosseDiffValue(right) - root.lacrosseDiffValue(left)
                || (Number(right.goalsFor) || 0) - (Number(left.goalsFor) || 0)
                || String(left.team || "").localeCompare(String(right.team || ""));
        });
        return rows.map((row, index) => Object.assign({}, row, { "position": index + 1 }));
    }

    // Lacrosse rows: one table per ESPN group (NCAA conferences), in ESPN's group order. A
    // league with a single table (PLL, NLL) gets no section header, like ESPN's page.
    function lacrosseGroups() {
        const rows = root.tableRows || [];
        const groups = [];
        const byName = {};
        rows.forEach(row => {
            const name = String(row.group || "").trim();
            if (byName[name] === undefined) {
                byName[name] = groups.length;
                groups.push({ "name": name, "rows": [] });
            }
            groups[byName[name]].rows.push(row);
        });

        let result = [];
        groups.forEach(group => {
            if (group.name.length > 0)
                result.push({ "isGroupHeader": true, "group": group.name });
            result = result.concat(root.lacrosseSorted(group.rows));
        });
        return result;
    }

    function groupedRows() {
        const rows = root.tableRows || [];
        if (root.isLacrosse && rows.length > 0)
            return root.lacrosseGroups();
        if (root.isBaseball && rows.length > 0)
            return root.baseballGroups();
        if (root.hockeyViewsActive)
            return root.hockeyGroups();
        // Racing with several tables: show only the selected one, no inner header.
        if (root.showRacingTabs) {
            const wanted = root.effectiveRacingGroup;
            return rows.filter(row => String(row.group || "").trim() === wanted);
        }
        if (!rows.some(row => String(row.group || "").trim().length > 0))
            return rows;

        let result = [];
        let currentGroup = "";
        rows.forEach(row => {
            const group = String(row.group || "").trim();
            if (group.length > 0 && group !== currentGroup) {
                currentGroup = group;
                result.push({
                    "isGroupHeader": true,
                    "group": group
                });
            }
            result.push(row);
        });
        return result;
    }

    function isFavoriteTeam(teamName) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(teamName || "").toLowerCase().indexOf(favorite) >= 0;
    }

    function leagueTitle() {
        const label = root.leagueLabel.length > 0 ? root.leagueLabel : ProviderCatalog.leagueLabel(root.league);
        if (root.sport === "tennis")
            return label.length > 0 ? i18nc("@label", "%1 Rankings", label) : i18nc("@label", "Rankings");
        if (root.isRacing)
            return label.length > 0 ? i18nc("@label", "%1 Standings", label) : i18nc("@label", "Championship Standings");
        if (root.viewsActive || root.isLacrosse)
            return label.length > 0 ? i18nc("@label", "%1 Standings", label) : i18nc("@label", "Standings");
        return label.length > 0 ? i18nc("@label", "%1 Table", label) : i18nc("@label", "League Table");
    }

    function baseballViewLabel(view) {
        if (view === "league")
            return i18nc("@title:tab baseball standings by league", "League");
        if (view === "overall")
            return i18nc("@title:tab baseball standings of all teams", "Overall");
        if (view === "wildcard")
            return i18nc("@title:tab baseball wild card race", "Wild Card");
        if (view === "expanded")
            return i18nc("@title:tab baseball standings with all columns", "Expanded");
        return i18nc("@title:tab baseball standings by division", "Division");
    }

    function tourTabLabel(option) {
        const slug = ProviderCatalog.slugForValue(option && option.slug);
        if (slug === "atp")
            return i18nc("@title:tab tennis tour: men's ranking", "ATP · Men");
        if (slug === "wta")
            return i18nc("@title:tab tennis tour: women's ranking", "WTA · Women");
        return String(option && option.label || "");
    }

    function selectedTableLabel() {
        const selected = ProviderCatalog.slugForValue(root.selectedTableSlug);
        const options = Array.isArray(root.tableOptions) ? root.tableOptions : [];
        for (let index = 0; index < options.length; index += 1) {
            const option = options[index] || {};
            if (ProviderCatalog.slugForValue(option.slug) === selected)
                return String(option.label || "").trim();
        }

        return root.leagueLabel.length > 0 ? root.leagueLabel : root.leagueTitle().replace(/\s+(Table|Rankings|Standings)$/, "");
    }

    onSelectedTableSlugChanged: {
        if (tableSelector)
            tableSelector.syncSelection();
    }

    onTableOptionsChanged: {
        if (tableSelector)
            tableSelector.syncSelection();
    }

    onSelectedSeasonKeyChanged: {
        if (seasonSelector)
            seasonSelector.syncSelection();
    }

    onSeasonOptionsChanged: {
        if (seasonSelector)
            seasonSelector.syncSelection();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: root.showTourTabs

            Repeater {
                model: root.showTourTabs ? root.tableOptions : []

                TourTab {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: root.tourTabLabel(modelData)
                    active: ProviderCatalog.slugForValue(modelData.slug) === ProviderCatalog.slugForValue(root.selectedTableSlug)
                    onClicked: {
                        const slug = String(modelData.slug || "").trim();
                        if (slug.length > 0 && !active)
                            root.tableSelected(slug);
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: root.showRacingTabs

            Repeater {
                model: root.showRacingTabs ? root.racingGroups : []

                TourTab {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: root.racingGroupLabel(modelData)
                    active: String(modelData) === root.effectiveRacingGroup
                    onClicked: root.selectedRacingGroup = String(modelData)
                }
            }
        }

        // Baseball: Division / League / Overall / Wild Card / Expanded view switch.
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: root.showBaseballTabs

            Repeater {
                model: root.showBaseballTabs ? root.baseballViews : []

                TourTab {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: root.baseballViewLabel(String(modelData))
                    active: String(modelData) === root.selectedBaseballView
                    onClicked: root.selectedBaseballView = String(modelData)
                }
            }
        }

        // Hockey: Standings / League / Wild Card / Expanded view switch.
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: root.showHockeyTabs

            Repeater {
                model: root.showHockeyTabs ? root.hockeyViews : []

                TourTab {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: root.hockeyViewLabel(String(modelData))
                    active: String(modelData) === root.selectedHockeyView
                    onClicked: root.selectedHockeyView = String(modelData)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: !root.showTourTabs && Array.isArray(root.tableOptions) && root.tableOptions.length > 0

            PlasmaComponents.Label {
                text: root.isRacing ? i18nc("@label racing series selector", "Series:") : i18nc("@label", "Table:")
                color: root.tablePrimaryTextColor
            }

            ComboBox {
                id: tableSelector

                Layout.fillWidth: true
                textRole: "label"
                model: root.tableOptions
                onActivated: {
                    const option = model && index >= 0 ? model[index] : null;
                    const slug = String(option && option.slug || "").trim();
                    if (slug.length > 0)
                        root.tableSelected(slug);
                }

                function syncSelection() {
                    const selected = ProviderCatalog.slugForValue(root.selectedTableSlug);
                    let fallback = 0;
                    for (let index = 0; index < count; index += 1) {
                        const option = model[index] || {};
                        if (ProviderCatalog.slugForValue(option.slug) === selected) {
                            currentIndex = index;
                            return;
                        }
                    }
                    currentIndex = fallback;
                }

                Component.onCompleted: syncSelection()
                onModelChanged: syncSelection()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: (Array.isArray(root.seasonOptions) && root.seasonOptions.length > 0) || root.seasonLoading

            PlasmaComponents.Label {
                text: i18nc("@label", "Season:")
                color: root.tablePrimaryTextColor
            }

            ComboBox {
                id: seasonSelector

                Layout.fillWidth: true
                textRole: "label"
                model: root.seasonOptions
                enabled: !root.seasonLoading
                onActivated: {
                    const option = model && index >= 0 ? model[index] : null;
                    const key = String(option && option.key || "").trim();
                    if (key.length > 0)
                        root.seasonSelected(key);
                }

                function syncSelection() {
                    const selected = String(root.selectedSeasonKey || "").trim();
                    let fallback = 0;
                    for (let index = 0; index < count; index += 1) {
                        const option = model[index] || {};
                        if (String(option.key || "").trim() === selected) {
                            currentIndex = index;
                            return;
                        }
                    }
                    currentIndex = fallback;
                    const fallbackOption = model && fallback >= 0 && fallback < count ? model[fallback] : null;
                    const fallbackKey = String(fallbackOption && fallbackOption.key || "").trim();
                    if (fallbackKey.length > 0 && fallbackKey !== selected)
                        root.seasonSelected(fallbackKey);
                }

                Component.onCompleted: syncSelection()
                onModelChanged: syncSelection()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Sideways scroller: only the baseball Expanded view is wider than the popup
            // (contentWidth > width); every other table fits, so it behaves like a plain
            // full-size list there.
            Flickable {
                id: tableFlick

                anchors.fill: parent
                visible: !root.tableLoading
                clip: true
                contentWidth: Math.max(width, root.expandedContentWidth)
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentWidth > width
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                ListView {
                    id: tableList

                    width: tableFlick.contentWidth
                    height: tableFlick.height
                    clip: true
                    spacing: 0
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.displayRows
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    readonly property int contentColumnWidth: Math.max(0, width - Kirigami.Units.gridUnit)

                    header: TableHeader {
                        width: tableList.contentColumnWidth
                        title: root.leagueTitle()
                    }

                    // Lacrosse: ESPN's column glossary under the table, as on its standings page.
                    footer: TableLegend {
                        width: tableList.contentColumnWidth
                        visible: root.isLacrosse && root.rowCount > 0
                        text: i18nc("@info column glossary of the lacrosse standings", "W: Wins · L: Losses · PCT: Winning percentage · PF: Total points for · PA: Total points against · DIFF: Point differential")
                    }

                    delegate: Loader {
                        id: rowLoader

                        width: tableList.contentColumnWidth
                        height: item ? item.height : 0
                        sourceComponent: modelData.isGroupHeader ? groupHeaderComponent : tableRowComponent

                        readonly property var rowData: modelData

                        onLoaded: item.rowData = rowData
                        onRowDataChanged: {
                            if (item)
                                item.rowData = rowData;
                        }
                    }
                }
            }

            EmptyState {
                anchors.fill: parent
                visible: root.rowCount === 0 && !root.tableLoading
                text: root.tableErrorMessage.length > 0 ? root.tableErrorMessage : i18nc("@info:placeholder", "No table data")
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
                visible: root.tableLoading
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Layout.preferredWidth
                    running: root.tableLoading
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: i18nc("@info:status", "Updating table")
                    color: root.tableSecondaryTextColor
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // Pill-shaped sub-tab (ATP / WTA), styled like the main tab strip.
    component TourTab: Rectangle {
        id: tourTab

        property string text: ""
        property bool active: false

        signal clicked()

        implicitHeight: Kirigami.Units.gridUnit * 1.8
        radius: height / 2
        color: active ? Kirigami.Theme.highlightColor : (tourMouse.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1) : "transparent")
        border.width: active ? 0 : 1
        border.color: root.tableRowDividerColor

        PlasmaComponents.Label {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.smallSpacing * 2
            text: tourTab.text
            color: tourTab.active ? Kirigami.Theme.highlightedTextColor : root.tablePrimaryTextColor
            font.bold: tourTab.active
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        MouseArea {
            id: tourMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tourTab.clicked()
        }
    }

    component EmptyState: Item {
        property string text: ""

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Layout.preferredWidth
                source: "view-calendar-day"
                color: root.tableSecondaryTextColor
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: parent.parent.text
                color: root.tableSecondaryTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    component TableHeader: Rectangle {
        property string title: ""

        height: Kirigami.Units.gridUnit * 2.15
        color: "transparent"

        Column {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: 0

            RowLayout {
                width: parent.width
                height: Kirigami.Units.gridUnit * 1.8
                spacing: Kirigami.Units.smallSpacing

                HeaderLabel {
                    text: "#"
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.35
                }

                HeaderLabel {
                    text: root.sport === "tennis" ? i18nc("@label", "Player") : root.isRacing ? root.racingNameHeader() : i18nc("@label", "Team")
                    Layout.fillWidth: true
                }

                Repeater {
                    model: root.tableColumns

                    HeaderLabel {
                        required property var modelData

                        text: modelData.label || ""
                        tooltip: modelData.tooltip || ""
                        Layout.preferredWidth: Kirigami.Units.gridUnit * Number(modelData.width || 2)
                    }
                }

                HeaderLabel {
                    text: i18nc("@label", "Form")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 6.6
                    visible: root.tableHasForm
                }
            }
        }
    }

    // Small wrapped note under a table (column glossary). Takes no space while hidden.
    component TableLegend: Item {
        property string text: ""

        height: visible ? legendLabel.implicitHeight + Kirigami.Units.largeSpacing * 2 : 0

        PlasmaComponents.Label {
            id: legendLabel

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            anchors.topMargin: Kirigami.Units.largeSpacing
            text: parent.text
            color: root.tableSecondaryTextColor
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
        }
    }

    component HeaderLabel: PlasmaComponents.Label {
        property string tooltip: ""

        color: root.tableSecondaryTextColor
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        ToolTip.text: tooltip
        ToolTip.visible: tooltip.length > 0 && hoverHandler.hovered

        HoverHandler {
            id: hoverHandler
        }
    }

    Component {
        id: groupHeaderComponent

        Rectangle {
            property var rowData: ({})

            width: tableList.contentColumnWidth
            height: Kirigami.Units.gridUnit * 1.9
            color: "transparent"

            PlasmaComponents.Label {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                text: parent.rowData.group || ""
                color: root.tableHighlightTextColor
                font.bold: true
                elide: Text.ElideRight
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Qt.rgba(root.tableHighlightTextColor.r, root.tableHighlightTextColor.g, root.tableHighlightTextColor.b, 0.28)
            }
        }
    }

    Component {
        id: tableRowComponent

        TableRow {
            rowData: ({})
            width: tableList.contentColumnWidth
        }
    }

    component TableRow: Rectangle {
        id: tableRow

        property var rowData: ({})
        readonly property int position: Number(rowData.position || 0)
        readonly property string team: String(rowData.team || "")
        readonly property string form: String(rowData.form || "")
        readonly property string crest: String(rowData.crest || "")
        readonly property string clincher: String(rowData.clincher || "")
        readonly property string clincherDescription: String(rowData.clincherDescription || "")
        readonly property bool favorite: root.isFavoriteTeam(team)

        function valueForColumn(column) {
            const key = String(column && column.key || "");
            const value = rowData && rowData[key] !== undefined && rowData[key] !== null ? rowData[key] : 0;
            if (root.isLacrosse) {
                // ESPN-style cells: ".750" for PCT and a signed "+14" / "-6" for DIFF.
                if (key === "winPercent")
                    return root.lacrossePctText(rowData);
                if (key === "goalDifference") {
                    const diff = root.lacrosseDiffValue(rowData);
                    return diff > 0 ? "+" + diff : String(diff);
                }
                return String(value);
            }
            if (root.viewsActive) {
                // ESPN-style cells: a signed run differential and "-" for
                // anything the API did not provide (streak before a first game ...).
                if (key === "goalDifference") {
                    const diff = Number(value) || 0;
                    return diff > 0 ? "+" + diff : String(diff);
                }
                // POFF: ESPN sends "100.0%" / "4.8%"; show whole numbers without ".0".
                if (key === "playoffPercent")
                    return String(value).length === 0 ? "-" : String(value).replace(/\.0%$/, "%");
                if (String(value).length === 0)
                    return "-";
            }
            return String(value);
        }

        // Baseball colouring: winning streak / positive run differential in green, losing
        // streak / negative differential in red; everything else keeps the theme colour.
        function colorForColumn(column) {
            // Lacrosse: only the point differential is coloured (green ahead, red behind).
            if (root.isLacrosse) {
                if (String(column && column.key || "") === "goalDifference") {
                    const lacrosseDiff = root.lacrosseDiffValue(rowData);
                    if (lacrosseDiff > 0)
                        return root.tablePositiveColor;
                    if (lacrosseDiff < 0)
                        return root.tableNegativeColor;
                }
                return root.tablePrimaryTextColor;
            }
            if (!root.viewsActive)
                return root.tablePrimaryTextColor;
            const key = String(column && column.key || "");
            if (key === "streak") {
                const text = String(rowData.streak || "").toUpperCase();
                if (text.charAt(0) === "W")
                    return root.tablePositiveColor;
                if (text.charAt(0) === "L")
                    return root.tableNegativeColor;
            } else if (key === "goalDifference") {
                const diff = Number(rowData.goalDifference) || 0;
                if (diff > 0)
                    return root.tablePositiveColor;
                if (diff < 0)
                    return root.tableNegativeColor;
            }
            return root.tablePrimaryTextColor;
        }

        height: Kirigami.Units.gridUnit * 2.7
        color: favorite ? Qt.rgba(root.tableHighlightTextColor.r, root.tableHighlightTextColor.g, root.tableHighlightTextColor.b, 0.14) : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.tableRowDividerColor
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: position
                color: root.tablePrimaryTextColor
                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.35
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Kirigami.Units.gridUnit
            }

            TeamBadgeImage {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Layout.preferredWidth
                sourceUrl: crest
                fallbackEmoji: SportVisuals.emoji(root.sport)
            }

            // Baseball: ESPN's playoff marker (x / y / z / e) in front of the team name.
            PlasmaComponents.Label {
                id: clinchMarker

                visible: root.viewsActive
                Layout.preferredWidth: Kirigami.Units.gridUnit * 0.9
                text: tableRow.clincher
                horizontalAlignment: Text.AlignHCenter
                font.bold: true
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: tableRow.clincher.toLowerCase() === "e" ? root.tableSecondaryTextColor : root.tablePositiveColor
                ToolTip.text: tableRow.clincherDescription
                ToolTip.visible: tableRow.clincherDescription.length > 0 && clinchHover.hovered

                HoverHandler {
                    id: clinchHover
                }
            }

            PlasmaComponents.Label {
                text: team
                color: root.tablePrimaryTextColor
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.bold: true
            }

            Repeater {
                model: root.tableColumns

                RowValue {
                    required property var modelData

                    text: tableRow.valueForColumn(modelData)
                    color: tableRow.colorForColumn(modelData)
                    font.bold: Boolean(modelData.emphasized)
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                    Layout.preferredWidth: Kirigami.Units.gridUnit * Number(modelData.width || 2)
                }
            }

            FormBadges {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6.6
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.3
                form: tableRow.form
                visible: root.tableHasForm
            }
        }
    }

    component RowValue: PlasmaComponents.Label {
        color: root.tablePrimaryTextColor
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    component FormBadges: Item {
        id: formBadges

        property string form: ""

        function results() {
            const text = String(form || "").trim();
            if (text.length === 0)
                return [];

            if (/^[WDL]+$/i.test(text))
                return text.split("").slice(-5);

            return text.replace(/[^A-Za-z]+/g, ",").split(",").filter(item => item.length > 0).slice(-5);
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            spacing: 3
            visible: parent.results().length > 0

            Repeater {
                model: parent.parent.results()

                Rectangle {
                    width: Kirigami.Units.gridUnit * 1.1
                    height: width
                    radius: 2

                    color: {
                        const result = String(modelData).toUpperCase();
                        if (result === "W")
                            return "#0b8f08";
                        if (result === "L")
                            return "#e91e63";
                        return "#5f6368";
                    }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: String(modelData).charAt(0).toUpperCase()
                        color: "#ffffff"
                        font.bold: true
                        font.pixelSize: Math.max(8, Kirigami.Theme.smallFont.pixelSize - 1)
                    }
                }
            }
        }

        PlasmaComponents.Label {
            anchors.centerIn: parent
            visible: parent.results().length === 0
            text: "-"
            color: root.tableSecondaryTextColor
        }
    }
}
