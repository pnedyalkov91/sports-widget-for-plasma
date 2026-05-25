/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../../code/SportsApi.js" as SportsApi
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

SportStepPage {
    id: root

    property var configRoot
    property string favoriteFilter: ""
    readonly property var displayedOptions: root.computeDisplayedOptions()
    property var badgeByTeam: ({})
    property var pendingBadgeTeams: ({})
    property var attemptedBadgeTeams: ({})
    property var discoveredTeams: ({})
    property var staticTeamOptions: []
    property bool staticTeamOptionsReady: false
    property bool teamDiscoveryRunning: false
    property int teamDiscoveryToken: 0
    property int teamDiscoveryDoneLeagues: 0
    property int teamDiscoveryTotalLeagues: 0
    readonly property int teamDiscoveryLeagueLimit: 8
    readonly property int teamDiscoveryTargetTeams: 64
    readonly property int teamDiscoveryMaxRowsPerLeague: 40
    readonly property int maxDisplayedTeams: 80
    readonly property int badgePrefetchLimit: 20
    readonly property bool pageActive: root.configRoot && root.configRoot.pageIndex === 2

    title: root.configRoot && root.configRoot.cfg_type === "team" ? i18nc("@title:group", "Team") : i18nc("@title:group", "Highlighted Team")
    subtitle: root.configRoot && root.configRoot.cfg_type === "team" ? root.configRoot.multiSelectEnabled ? i18nc("@info", "Choose one or more teams this widget should follow across competitions.") : i18nc("@info", "Choose the team this saved item should follow across competitions.") : i18nc("@info", "Optional. Choose a team to highlight inside this competition.")
    filterText: root.favoriteFilter
    filterPlaceholder: i18nc("@info:placeholder", "Search teams")
    onFilterEdited: text => root.favoriteFilter = text
    onDisplayedOptionsChanged: root.scheduleBadgePrefetch()
    Component.onCompleted: root.refreshTeamPool()

    Connections {
        target: root.configRoot
        ignoreUnknownSignals: true

        function onCfg_countryChanged() {
            root.badgeByTeam = ({});
            root.pendingBadgeTeams = ({});
            root.attemptedBadgeTeams = ({});
            root.refreshTeamPool();
        }

        function onCfg_selectedSportsChanged() {
            root.badgeByTeam = ({});
            root.pendingBadgeTeams = ({});
            root.attemptedBadgeTeams = ({});
            root.refreshTeamPool();
        }

        function onCfg_typeChanged() {
            root.badgeByTeam = ({});
            root.pendingBadgeTeams = ({});
            root.attemptedBadgeTeams = ({});
            root.refreshTeamPool();
        }

        function onPageIndexChanged() {
            if (!root.pageActive) {
                root.teamDiscoveryToken += 1;
                root.teamDiscoveryRunning = false;
                return;
            }

            root.ensureStaticTeamOptions();
            root.scheduleBadgePrefetch();
            if (root.isTeamMode() && !root.teamDiscoveryRunning && root.discoveredTeamCount() === 0)
                root.startCountryTeamDiscovery();
        }
    }

    Timer {
        id: badgePrefetchTimer

        interval: 120
        repeat: false
        onTriggered: root.prefetchVisibleBadges()
    }

    function teamKey(teamName) {
        return String(teamName || "").trim().toLowerCase();
    }

    function isTeamMode() {
        return root.configRoot && root.configRoot.cfg_type === "team";
    }

    function filteredStaticOptions() {
        if (!root.configRoot || !root.staticTeamOptionsReady)
            return [];

        return root.configRoot.filtered(root.staticTeamOptions, root.favoriteFilter);
    }

    function mergedTeamOptions(filterText) {
        const staticOptions = root.staticTeamOptionsReady ? root.staticTeamOptions : [];
        let merged = [];
        let seen = {};

        function appendOption(option) {
            const value = String(option && option.value || "").trim();
            if (value.length === 0)
                return;

            const key = root.teamKey(value);
            if (key.length === 0 || seen[key])
                return;

            seen[key] = true;
            merged.push({
                label: String(option && option.label || value).trim(),
                value
            });
        }

        (Array.isArray(staticOptions) ? staticOptions : []).forEach(appendOption);
        Object.keys(root.discoveredTeams).forEach(key => appendOption(root.discoveredTeams[key]));

        merged.sort((left, right) => String(left.label || "").localeCompare(String(right.label || "")));
        return root.configRoot ? root.configRoot.filtered(merged, filterText) : merged;
    }

    function isStaticTeamKey(key) {
        if (!root.staticTeamOptionsReady)
            return false;

        for (let index = 0; index < root.staticTeamOptions.length; index += 1) {
            const optionKey = root.teamKey(root.staticTeamOptions[index] && root.staticTeamOptions[index].value);
            if (optionKey.length > 0 && optionKey === key)
                return true;
        }
        return false;
    }

    function computeDisplayedOptions() {
        if (!root.configRoot)
            return [];

        const options = root.isTeamMode() ? root.mergedTeamOptions(root.favoriteFilter) : root.filteredStaticOptions();
        return options.slice(0, root.maxDisplayedTeams);
    }

    function scheduleBadgePrefetch() {
        if (!root.pageActive)
            return;

        badgePrefetchTimer.restart();
    }

    function ensureStaticTeamOptions() {
        if (root.staticTeamOptionsReady || !root.configRoot || !root.pageActive)
            return;

        const options = Array.isArray(root.configRoot.favoriteOptions()) ? root.configRoot.favoriteOptions() : [];
        root.staticTeamOptions = options;
        root.staticTeamOptionsReady = true;
    }

    function refreshTeamPool() {
        root.staticTeamOptions = [];
        root.staticTeamOptionsReady = false;
        root.discoveredTeams = ({});
        root.teamDiscoveryRunning = false;
        root.teamDiscoveryDoneLeagues = 0;
        root.teamDiscoveryTotalLeagues = 0;
        root.teamDiscoveryToken += 1;

        root.ensureStaticTeamOptions();
        root.scheduleBadgePrefetch();
        if (root.isTeamMode() && root.pageActive)
            root.startCountryTeamDiscovery();
    }

    function leaguePriority(league) {
        const label = String(league && league.label || "").toLowerCase();
        if (label.length === 0)
            return -200;

        let score = 0;
        if (label.indexOf("premier") >= 0 || label.indexOf("super league") >= 0 || label.indexOf("liga") >= 0 || label.indexOf("division 1") >= 0 || label.indexOf("serie a") >= 0)
            score += 45;

        if (label.indexOf("cup") >= 0 || label.indexOf("playoff") >= 0 || label.indexOf("play-off") >= 0 || label.indexOf("qualif") >= 0)
            score -= 22;

        if (label.indexOf("women") >= 0 || label.indexOf("womens") >= 0 || label.indexOf("ladies") >= 0)
            score -= 35;

        if (label.indexOf("reserve") >= 0 || label.indexOf("reserves") >= 0 || label.indexOf("youth") >= 0 || /\bu[0-9]{2}\b/.test(label) || /\bu[0-9]{1}\b/.test(label))
            score -= 35;

        if (label.indexOf("amateur") >= 0 || label.indexOf("regional") >= 0 || label.indexOf("state") >= 0 || label.indexOf("metro") >= 0)
            score -= 20;

        if (label.indexOf("friendly") >= 0 || label.indexOf("friendlies") >= 0 || label.indexOf("virtual") >= 0 || label.indexOf("esoccer") >= 0)
            score -= 90;

        return score;
    }

    function prioritizedLeagues() {
        if (!root.configRoot)
            return [];

        const leagues = Array.isArray(root.configRoot.leagueOptions()) ? root.configRoot.leagueOptions().slice() : [];
        leagues.sort((left, right) => root.leaguePriority(right) - root.leaguePriority(left));
        return leagues.slice(0, root.teamDiscoveryLeagueLimit);
    }

    function mergeDiscoveredRows(rows) {
        const tableRows = Array.isArray(rows) ? rows : [];
        if (tableRows.length === 0)
            return;

        let nextTeams = Object.assign({}, root.discoveredTeams);
        let nextBadges = Object.assign({}, root.badgeByTeam);
        let nextAttempted = Object.assign({}, root.attemptedBadgeTeams);
        let teamsChanged = false;
        let badgesChanged = false;

        tableRows.slice(0, root.teamDiscoveryMaxRowsPerLeague).forEach(row => {
            const team = String(row && row.team || "").trim();
            const key = root.teamKey(team);
            if (key.length === 0)
                return;

            if (!nextTeams[key]) {
                nextTeams[key] = {
                    label: team,
                    value: team
                };
                teamsChanged = true;
            }

            const crest = String(row && (row.crest || row.team_logo) || "").trim();
            if (crest.length > 0 && String(nextBadges[key] || "").trim() !== crest) {
                nextBadges[key] = crest;
                nextAttempted[key] = true;
                badgesChanged = true;
            }
        });

        if (teamsChanged)
            root.discoveredTeams = nextTeams;
        if (badgesChanged) {
            root.badgeByTeam = nextBadges;
            root.attemptedBadgeTeams = nextAttempted;
        }
    }

    function discoveredTeamCount() {
        return Object.keys(root.discoveredTeams).length;
    }

    function startCountryTeamDiscovery() {
        if (!root.configRoot || !root.isTeamMode())
            return;

        const leagues = root.prioritizedLeagues();
        if (leagues.length === 0)
            return;

        const token = root.teamDiscoveryToken + 1;
        root.teamDiscoveryToken = token;
        root.teamDiscoveryRunning = true;
        root.teamDiscoveryDoneLeagues = 0;
        root.teamDiscoveryTotalLeagues = leagues.length;

        root.fetchTeamsFromLeague(token, leagues, 0);
    }

    function finishTeamDiscovery(token) {
        if (token !== root.teamDiscoveryToken)
            return;

        root.teamDiscoveryRunning = false;
        root.prefetchVisibleBadges();
    }

    function fetchTeamsFromLeague(token, leagues, index) {
        if (token !== root.teamDiscoveryToken)
            return;

        if (index >= leagues.length || root.discoveredTeamCount() >= root.teamDiscoveryTargetTeams) {
            root.finishTeamDiscovery(token);
            return;
        }

        const league = leagues[index] || {};
        const leagueValue = String(league.value || "").trim();
        if (leagueValue.length === 0) {
            root.teamDiscoveryDoneLeagues = Math.min(root.teamDiscoveryTotalLeagues, index + 1);
            root.fetchTeamsFromLeague(token, leagues, index + 1);
            return;
        }

        SportsApi.fetchLeagueTable({
            "sports": root.configRoot.normalizedSport(),
            "country": root.configRoot.cfg_country || "",
            "league": leagueValue,
            "followMode": "league"
        }, rows => {
            if (token !== root.teamDiscoveryToken)
                return;

            root.mergeDiscoveredRows(rows);
            root.teamDiscoveryDoneLeagues = Math.min(root.teamDiscoveryTotalLeagues, index + 1);
            root.fetchTeamsFromLeague(token, leagues, index + 1);
        }, () => {
            if (token !== root.teamDiscoveryToken)
                return;

            root.teamDiscoveryDoneLeagues = Math.min(root.teamDiscoveryTotalLeagues, index + 1);
            root.fetchTeamsFromLeague(token, leagues, index + 1);
        });
    }

    function setPendingTeam(teamName, pending) {
        const key = root.teamKey(teamName);
        if (key.length === 0)
            return;

        let next = Object.assign({}, root.pendingBadgeTeams);
        next[key] = Boolean(pending);
        root.pendingBadgeTeams = next;
    }

    function setTeamBadge(teamName, badge) {
        const key = root.teamKey(teamName);
        badge = String(badge || "").trim();
        if (key.length === 0)
            return;

        let next = Object.assign({}, root.badgeByTeam);
        next[key] = badge;
        root.badgeByTeam = next;
        let attempted = Object.assign({}, root.attemptedBadgeTeams);
        attempted[key] = true;
        root.attemptedBadgeTeams = attempted;
    }

    function fetchBadgeFromCountryLeagues(teamName, onDone) {
        onDone = onDone || function () {};
        if (!root.configRoot) {
            onDone();
            return;
        }

        const leagues = root.prioritizedLeagues();
        if (!Array.isArray(leagues) || leagues.length === 0) {
            root.setTeamBadge(teamName, "");
            onDone();
            return;
        }

        const maxLookups = Math.min(6, leagues.length);
        let leagueIndex = 0;

        function lookupNextLeague() {
            if (leagueIndex >= maxLookups) {
                root.setTeamBadge(teamName, "");
                onDone();
                return;
            }

            const leagueValue = String(leagues[leagueIndex] && leagues[leagueIndex].value || "").trim();
            leagueIndex += 1;
            if (leagueValue.length === 0) {
                lookupNextLeague();
                return;
            }

            SportsApi.fetchLeagueTable({
                "sports": root.configRoot.normalizedSport(),
                "country": root.configRoot.cfg_country || "",
                "league": leagueValue,
                "favoriteTeam": teamName,
                "followMode": "league"
            }, rows => {
                const tableRows = Array.isArray(rows) ? rows : [];
                for (let rowIndex = 0; rowIndex < tableRows.length; rowIndex += 1) {
                    const row = tableRows[rowIndex] || {};
                    if (SportsApi.sameTeamName(row.team, teamName)) {
                        const crest = String(row.crest || row.team_logo || "").trim();
                        if (crest.length > 0) {
                            root.setTeamBadge(teamName, crest);
                            onDone();
                            return;
                        }
                    }
                }

                lookupNextLeague();
            }, () => {
                lookupNextLeague();
            });
        }

        lookupNextLeague();
    }

    function ensureTeamBadge(teamName, forceRefresh) {
        forceRefresh = Boolean(forceRefresh);
        const key = root.teamKey(teamName);
        if (key.length === 0)
            return;

        if (!forceRefresh && String(root.badgeByTeam[key] || "").trim().length > 0)
            return;

        if (!forceRefresh && Boolean(root.attemptedBadgeTeams[key]))
            return;

        if (Boolean(root.pendingBadgeTeams[key]))
            return;

        if (root.isStaticTeamKey(key)) {
            root.setPendingTeam(teamName, true);
            root.fetchBadgeFromCountryLeagues(teamName, () => root.setPendingTeam(teamName, false));
            return;
        }

        root.setPendingTeam(teamName, true);
        SportsApi.fetchTeamBadge({
            "sports": root.configRoot ? root.configRoot.normalizedSport() : "football",
            "country": root.configRoot ? root.configRoot.cfg_country : "",
            "favoriteTeam": teamName
        }, badge => {
            root.setPendingTeam(teamName, false);
            badge = String(badge || "").trim();
            if (badge.length > 0) {
                root.setTeamBadge(teamName, badge);
                return;
            }

            if (forceRefresh) {
                root.setTeamBadge(teamName, "");
            } else {
                root.fetchBadgeFromCountryLeagues(teamName, () => root.setPendingTeam(teamName, false));
                return;
            }
            root.setPendingTeam(teamName, false);
        }, () => {
            if (forceRefresh) {
                root.setTeamBadge(teamName, "");
                root.setPendingTeam(teamName, false);
            } else {
                root.fetchBadgeFromCountryLeagues(teamName, () => root.setPendingTeam(teamName, false));
            }
        });
    }

    function teamBadge(teamName) {
        const key = root.teamKey(teamName);
        if (key.length === 0)
            return "";

        const badge = String(root.badgeByTeam[key] || "").trim();
        return badge;
    }

    function prefetchVisibleBadges() {
        if (!root.configRoot || root.configRoot.cfg_type !== "team")
            return;

        // During discovery we rely on league-table crests to avoid transient wrong badge assignments.
        if (root.teamDiscoveryRunning)
            return;

        const verifyExistingBadges = root.discoveredTeamCount() > 0;
        root.displayedOptions.slice(0, root.badgePrefetchLimit).forEach(option => {
            const teamName = String(option && option.value || "").trim();
            if (teamName.length > 0)
                root.ensureTeamBadge(teamName, verifyExistingBadges);
        });
    }

    Repeater {
        model: root.displayedOptions

        delegate: SportChoiceCard {
            title: modelData.label
            iconSource: root.teamBadge(modelData.value)
            iconName: modelData.value.length > 0 ? "im-user" : "edit-none"
            selected: root.configRoot && root.configRoot.isFavoriteTeamSelected(modelData.value)
            onClicked: root.configRoot.selectFavoriteTeam(modelData.value)
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        visible: root.isTeamMode() && root.teamDiscoveryRunning
        spacing: Kirigami.Units.smallSpacing

        BusyIndicator {
            running: parent.visible
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
        }

        Label {
            text: i18nc("@info", "Loading teams from %1 of %2 competitions...", root.teamDiscoveryDoneLeagues, Math.max(1, root.teamDiscoveryTotalLeagues))
            color: Kirigami.Theme.disabledTextColor
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.displayedOptions.length === 0 && !root.teamDiscoveryRunning
        text: root.configRoot && root.configRoot.cfg_type === "team"
            ? i18nc("@info", "No teams were found for this country yet. Try another country or competition.")
            : ""
        color: Kirigami.Theme.disabledTextColor
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    headerContent: ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        SportChoiceCard {
            Layout.fillWidth: true
            visible: root.configRoot && root.configRoot.cfg_type === "team"
            title: i18nc("@title:group", "National Teams")
            subtitle: root.configRoot && root.configRoot.selectedNationalTeamValues().length > 0
                ? i18nc("@info", "%1 selected", root.configRoot.selectedNationalTeamValues().length)
                : i18nc("@info", "Optional: add national team variants for this country")
            iconName: "flag"
            selected: root.configRoot && root.configRoot.showNationalTeamStep
            onClicked: {
                if (root.configRoot)
                    root.configRoot.openNationalTeamsStep();
            }
        }

        Frame {
            Layout.fillWidth: true
            visible: root.configRoot && root.configRoot.cfg_type === "competition" && root.configRoot.cfg_favoriteTeam.length > 0

            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.largeSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        Layout.fillWidth: true
                        text: i18nc("@label", "Follow mode")
                        font.bold: true
                    }

                    Label {
                        Layout.fillWidth: true
                        text: followTeamSwitch.checked ? i18nc("@info", "Show this team across competitions; tables can be switched when more competitions are available.") : i18nc("@info", "Show the selected league; the favorite team is highlighted and sorted first.")
                        color: Kirigami.Theme.disabledTextColor
                        wrapMode: Text.WordWrap
                    }
                }

                Switch {
                    id: followTeamSwitch

                    text: checked ? i18nc("@option:check", "Team") : i18nc("@option:check", "League")
                    enabled: root.configRoot && root.configRoot.cfg_favoriteTeam.length > 0
                    checked: root.configRoot && root.configRoot.cfg_followMode === "team"
                    onToggled: {
                        if (root.configRoot)
                            root.configRoot.setFollowMode(checked ? "team" : "league");
                    }
                }
            }
        }
    }
}
