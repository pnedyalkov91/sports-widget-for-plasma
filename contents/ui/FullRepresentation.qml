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

import "../code/SportVisuals.js" as SportVisuals
import "../code/SportsApi.js" as SportsApi
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var scoreModel: null
    property var liveModel: null
    property var tableModel: null
    property var tableRows: []
    property var recentResultsModel: null
    property bool loading: false
    property bool liveLoading: false
    property bool schedulesLoading: false
    property bool recentResultsLoading: false
    property string errorMessage: ""
    property string tableErrorMessage: ""
    property string lastUpdatedText: ""
    property string sourceText: ""
    property string primaryText: ""
    property string secondaryText: ""
    property string league: ""
    property string favoriteTeam: ""
    property string sport: "football"
    property bool hasSavedLeagues: true
    property var savedLeagues: []
    property int savedLeagueCount: 0
    property int activeSavedLeagueIndex: -1
    property string activeLeagueLabel: ""
    property string activeCountryLabel: ""
    property string tableLeagueLabel: ""
    property bool followTeamMode: false
    property var teamTableOptions: []
    property string selectedTableSlug: ""
    property var teamTableSeasonOptions: []
    property string selectedTableSeasonKey: ""
    property bool teamTableSeasonLoading: false
    property bool tableLoading: false
    property int sportCount: 0
    property var availableSports: []
    property string selectedSport: "football"
    property int tableCount: 0
    property int recentResultsCount: 0
    property string widgetTabs: "all"
    property int activeTab: 0
    property int selectedLiveIndex: 0
    property int selectedScoreIndex: 0
    property int selectedRecentResultIndex: 0
    property bool matchRotationEnabled: true
    property int matchRotationInterval: 30
    property int heroRotationPosition: 0
    property var heroRotationIndexes: []
    property bool heroRotationRefreshPending: false
    readonly property color liveColor: Kirigami.Theme.negativeTextColor
    readonly property int liveModelCount: root.modelCount(root.liveModel)
    readonly property int scoreModelCount: root.modelCount(root.scoreModel)
    readonly property int heroRotationCount: root.heroRotationIndexes.length
    readonly property var rotatedHeroMatch: root.rotationMatch()
    readonly property int currentHeroCount: root.activeTab === 0 ? root.liveModelCount : root.activeTab === 1 ? root.scoreModelCount : root.activeTab === 2 ? root.recentResultsCount : root.liveModelCount > 0 ? root.liveModelCount : root.scoreModelCount
    readonly property bool hasMatches: root.heroRotationCount > 0 || root.currentHeroCount > 0

    signal refreshRequested()
    signal configureRequested()
    signal leagueSelected(int index)
    signal sportSelected(string sport)
    signal teamTableSelected(string slug)
    signal teamTableSeasonSelected(string seasonKey)

    function isFavoriteTeam(teamName) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(teamName || "").toLowerCase().indexOf(favorite) >= 0;
    }

    function tabVisible(tab) {
        if (tab === 0 || tab === 1)
            return true;

        if (tab === 3 && String(root.sport || "").toLowerCase() === "tennis")
            return false;

        if (root.widgetTabs === "all")
            return true;

        if (root.widgetTabs === "liveStats")
            return tab === 2;

        if (root.widgetTabs === "liveTables")
            return tab === 3;

        return false;
    }

    function activateTab(tab) {
        root.activeTab = root.tabVisible(tab) ? tab : 0;
    }

    function selectedMatchValue(field, fallback) {
        const rotatedMatch = root.rotatedHeroMatch;
        if (rotatedMatch && rotatedMatch[field] !== undefined)
            return rotatedMatch[field];

        if (!root.hasMatches)
            return fallback;

        const model = root.currentHeroModel();
        const count = root.currentHeroCount;
        if (count <= 0)
            return fallback;

        const index = Math.max(0, Math.min(root.currentHeroIndex(), count - 1));
        const match = model.get(index);
        return match && match[field] !== undefined ? match[field] : fallback;
    }

    function selectedMatchBool(field, fallback) {
        const value = root.selectedMatchValue(field, fallback);
        if (typeof value === "boolean")
            return value;

        const text = String(value || "").trim().toLowerCase();
        return text === "true" || text === "1" || text === "yes";
    }

    function modelCount(model) {
        try {
            if (!model || model.count === undefined || model.count === null)
                return 0;

            const count = Number(model.count);
            return Number.isFinite(count) ? count : 0;
        } catch (error) {
            return 0;
        }
    }

    function normalizedMatchTimestamp(match) {
        let timestamp = Number(match && match.timestamp || 0);
        if (!Number.isFinite(timestamp) || timestamp <= 0)
            return 0;
        if (timestamp < 100000000000)
            timestamp *= 1000;
        return timestamp;
    }

    function rotationCandidateIndexes() {
        const indexes = [];
        if (!root.matchRotationEnabled)
            return indexes;

        if (root.liveModelCount > 0) {
            for (let liveIndex = 0; liveIndex < root.liveModelCount; liveIndex += 1)
                indexes.push(liveIndex);
            return indexes;
        }

        const now = new Date();
        const start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2).getTime();
        for (let scheduleIndex = 0; scheduleIndex < root.scoreModelCount; scheduleIndex += 1) {
            const timestamp = root.normalizedMatchTimestamp(root.scoreModel.get(scheduleIndex));
            if (timestamp >= start && timestamp < end)
                indexes.push(scheduleIndex);
        }
        return indexes;
    }

    function rotationMatch() {
        const indexes = root.heroRotationIndexes;
        if (indexes.length === 0)
            return null;

        const model = root.liveModelCount > 0 ? root.liveModel : root.scoreModel;
        return model.get(indexes[Math.max(0, root.heroRotationPosition % indexes.length)]);
    }

    function advanceHeroRotation() {
        const count = root.heroRotationCount;
        root.heroRotationPosition = count > 1 ? (root.heroRotationPosition + 1) % count : 0;
    }

    function scheduleHeroRotationRefresh() {
        if (root.heroRotationRefreshPending)
            return;

        root.heroRotationRefreshPending = true;
        Qt.callLater(() => {
            root.heroRotationRefreshPending = false;
            root.heroRotationIndexes = root.rotationCandidateIndexes();
            if (root.heroRotationPosition >= root.heroRotationIndexes.length)
                root.heroRotationPosition = 0;
        });
    }

    onLiveModelChanged: scheduleHeroRotationRefresh()
    onScoreModelChanged: scheduleHeroRotationRefresh()
    onLiveModelCountChanged: scheduleHeroRotationRefresh()
    onScoreModelCountChanged: scheduleHeroRotationRefresh()
    onMatchRotationEnabledChanged: scheduleHeroRotationRefresh()

    Component.onCompleted: scheduleHeroRotationRefresh()

    function currentHeroModel() {
        if (root.activeTab === 0)
            return root.liveModel;

        if (root.activeTab === 1)
            return root.scoreModel;

        if (root.activeTab === 2)
            return root.recentResultsModel;

        return root.modelCount(root.liveModel) > 0 ? root.liveModel : root.scoreModel;
    }

    function currentHeroIndex() {
        if (root.activeTab === 0)
            return root.modelCount(root.liveModel) > 0 ? root.selectedLiveIndex : root.selectedScoreIndex;

        if (root.activeTab === 1)
            return root.selectedScoreIndex;

        if (root.activeTab === 2)
            return root.selectedRecentResultIndex;

        return root.modelCount(root.liveModel) > 0 ? root.selectedLiveIndex : root.selectedScoreIndex;
    }

    function emptyHeroStatus() {
        if (root.activeTab === 0)
            return i18nc("@info:status", "No live matches");

        if (root.activeTab === 2)
            return i18nc("@info:status", "No recent results");

        return i18nc("@info:status", "No schedules");
    }

    function heroLoading() {
        if (root.heroRotationCount > 0)
            return false;

        if (root.hasMatches)
            return false;

        if (root.activeTab === 0)
            return root.liveLoading;

        if (root.activeTab === 1)
            return root.schedulesLoading;

        if (root.activeTab === 2)
            return root.recentResultsLoading;

        return root.loading || root.schedulesLoading || root.liveLoading;
    }

    function withAlpha(color, alpha) {
        try {
            if (!color || color.r === undefined || color.g === undefined || color.b === undefined)
                return Qt.rgba(0, 0, 0, 0);

            return Qt.rgba(color.r, color.g, color.b, alpha);
        } catch (error) {
            return Qt.rgba(0, 0, 0, 0);
        }
    }

    Timer {
        interval: Math.max(5, root.matchRotationInterval || 30) * 1000
        repeat: true
        running: root.visible && root.matchRotationEnabled && root.heroRotationCount > 1
        onTriggered: heroRotationAnimation.restart()
    }

    SequentialAnimation {
        id: heroRotationAnimation

        NumberAnimation {
            target: matchHero
            property: "opacity"
            to: 0
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutQuad
        }

        ScriptAction {
            script: root.advanceHeroRotation()
        }

        NumberAnimation {
            target: matchHero
            property: "opacity"
            to: 1
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutQuad
        }
    }

    function stripLegacyTeamPrefix(value) {
        return String(value || "").replace(/^[★*]\s*/, "").trim();
    }

    function selectedTableLabel() {
        const selected = String(root.selectedTableSlug || "").trim();
        const options = Array.isArray(root.teamTableOptions) ? root.teamTableOptions : [];
        for (let index = 0; index < options.length; index += 1) {
            const option = options[index] || {};
            if (String(option.slug || "").trim() === selected)
                return String(option.label || "").trim();
        }

        return root.tableLeagueLabel.length > 0 ? root.tableLeagueLabel : root.activeCountryLabel;
    }

    onWidgetTabsChanged: activateTab(activeTab)
    onFollowTeamModeChanged: activateTab(activeTab)
    Layout.minimumWidth: root.hasSavedLeagues ? Kirigami.Units.gridUnit * 30 : Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: root.hasSavedLeagues ? Kirigami.Units.gridUnit * 30 : Kirigami.Units.gridUnit * 14
    Layout.preferredWidth: root.hasSavedLeagues ? Kirigami.Units.gridUnit * 40 : Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: root.hasSavedLeagues ? Kirigami.Units.gridUnit * 43 : Kirigami.Units.gridUnit * 16

    Item {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        visible: !root.hasSavedLeagues

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width, Kirigami.Units.gridUnit * 18)
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Layout.preferredWidth
                text: SportVisuals.emoji("")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Math.round(Kirigami.Units.iconSizes.huge * 0.8)
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: i18nc("@info:status", "No sports added")
                color: Kirigami.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                font.bold: true
                font.pixelSize: Kirigami.Units.gridUnit
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: i18nc("@info", "Add a sport and league to show schedules, tables and fixtures.")
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                icon.name: "list-add"
                text: i18nc("@action:button", "Add a Sport")
                onClicked: root.configureRequested()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing
        visible: root.hasSavedLeagues

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.alignment: Qt.AlignVCenter
                    text: SportVisuals.emoji(root.sport)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Math.round(Kirigami.Units.iconSizes.medium * 0.8)
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: root.activeLeagueLabel.length > 0 ? root.activeLeagueLabel : SportVisuals.label(root.sport)
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                }

                ToolButton {
                    visible: Array.isArray(root.availableSports) && root.availableSports.length > 1
                    icon.name: "arrow-down"
                    display: AbstractButton.IconOnly
                    text: i18nc("@action:button", "Switch sport")
                    onClicked: sportMenu.open()

                    ToolTip.text: text
                    ToolTip.visible: hovered
                    ToolTip.delay: 600

                    Menu {
                        id: sportMenu

                        background: Rectangle {
                            implicitWidth: 1
                            implicitHeight: 1
                            radius: 3
                            color: Kirigami.Theme.backgroundColor
                            border.width: 1
                            border.color: root.withAlpha(Kirigami.Theme.textColor, 0.15)
                        }

                        Repeater {
                            model: Array.isArray(root.availableSports) ? root.availableSports : []

                            delegate: MenuItem {
                                id: sportMenuItem

                                required property var modelData

                                text: SportVisuals.label(modelData)
                                checkable: true
                                checked: String(modelData) === root.selectedSport
                                indicator: null
                                onTriggered: root.sportSelected(String(modelData))

                                contentItem: RowLayout {
                                    spacing: Kirigami.Units.smallSpacing

                                    PlasmaComponents.Label {
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                        Layout.preferredHeight: Layout.preferredWidth
                                        text: SportVisuals.emoji(sportMenuItem.modelData)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: Math.round(Kirigami.Units.iconSizes.smallMedium * 0.8)
                                    }

                                    PlasmaComponents.Label {
                                        Layout.fillWidth: true
                                        text: sportMenuItem.text
                                        color: Kirigami.Theme.textColor
                                        font.bold: sportMenuItem.checked
                                    }
                                }
                            }
                        }
                    }
                }

            }

            ToolButton {
                icon.name: "view-refresh"
                display: AbstractButton.IconOnly
                text: i18nc("@action:button", "Refresh")
                onClicked: root.refreshRequested()

                ToolTip.text: text
                ToolTip.visible: hovered
                ToolTip.delay: 600
            }

            ToolButton {
                icon.name: "configure"
                display: AbstractButton.IconOnly
                text: i18nc("@action:button", "Configure")
                onClicked: root.configureRequested()

                ToolTip.text: text
                ToolTip.visible: hovered
                ToolTip.delay: 600
            }

        }

        MatchHero {
            id: matchHero

            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 8
            homeTeam: root.selectedMatchValue("homeTeam", i18nc("@info:placeholder", "Home team"))
            awayTeam: root.selectedMatchValue("awayTeam", i18nc("@info:placeholder", "Away team"))
            homeScore: root.selectedMatchValue("homeScore", "")
            awayScore: root.selectedMatchValue("awayScore", "")
            status: root.selectedMatchValue("status", root.emptyHeroStatus())
            minute: root.selectedMatchValue("minute", "")
            startTime: root.selectedMatchValue("startTime", "")
            stadium: root.selectedMatchValue("stadium", "")
            homeBadge: root.selectedMatchValue("homeBadge", "")
            awayBadge: root.selectedMatchValue("awayBadge", "")
            matchPath: root.selectedMatchValue("matchPath", "")
            liveUrl: root.selectedMatchValue("liveUrl", "")
            sport: root.selectedMatchValue("sport", root.sport)
            league: root.selectedMatchValue("league", "")
            showScore: root.selectedMatchBool("showScore", root.activeTab === 0)
            loading: root.heroLoading()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            Layout.leftMargin: -Kirigami.Units.largeSpacing
            Layout.rightMargin: -Kirigami.Units.largeSpacing
            radius: height / 2
            color: root.withAlpha(Kirigami.Theme.alternateBackgroundColor, 0.5)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 0

                WeatherStyleTab {
                    label: i18n("Live")
                    active: root.activeTab === 0
                    visible: root.tabVisible(0)
                    onClicked: root.activateTab(0)
                }

                WeatherStyleTab {
                    label: i18n("Schedules")
                    active: root.activeTab === 1
                    visible: root.tabVisible(1)
                    onClicked: root.activateTab(1)
                }

                WeatherStyleTab {
                    label: i18n("Recent Results")
                    active: root.activeTab === 2
                    visible: root.tabVisible(2)
                    onClicked: root.activateTab(2)
                }

                WeatherStyleTab {
                    label: i18n("Tables")
                    active: root.activeTab === 3
                    visible: root.tabVisible(3)
                    onClicked: root.activateTab(3)
                }

            }

        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.activeTab === 1 && root.errorMessage.length > 0 && !root.loading && !root.schedulesLoading
            type: Kirigami.MessageType.Information
            text: root.errorMessage
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.activeTab

            LiveTab {
                liveModel: root.liveModel
                favoriteTeam: root.favoriteTeam
                loading: root.liveLoading
                selectedIndex: root.selectedLiveIndex
                onMatchSelected: (index) => {
                    root.selectedLiveIndex = index;
                }
            }

            ScheduleTab {
                scheduleModel: root.scoreModel
                favoriteTeam: root.favoriteTeam
                loading: root.loading || root.schedulesLoading
                emptyText: root.favoriteTeam.length > 0 ? i18nc("@info:placeholder", "No scheduled matches for %1", root.favoriteTeam) : i18nc("@info:placeholder", "No scheduled matches")
                selectedIndex: root.selectedScoreIndex
                onMatchSelected: (index) => {
                    root.selectedScoreIndex = index;
                }
            }

            RecentResultsTab {
                resultsModel: root.recentResultsModel
                favoriteTeam: root.favoriteTeam
                loading: root.recentResultsLoading
                emptyText: root.favoriteTeam.length > 0 ? i18nc("@info:placeholder", "No recent results for %1", root.favoriteTeam) : i18nc("@info:placeholder", "No recent results")
                selectedIndex: root.selectedRecentResultIndex
                onMatchSelected: (index) => {
                    root.selectedRecentResultIndex = index;
                }
            }

            TableTab {
                tableModel: root.tableModel
                tableRows: root.tableRows
                tableCount: root.tableCount
                tableErrorMessage: root.tableErrorMessage
                tableLoading: root.tableLoading
                league: root.league
                leagueLabel: root.tableLeagueLabel.length > 0 ? root.tableLeagueLabel : root.activeLeagueLabel
                sport: root.sport
                favoriteTeam: root.favoriteTeam
                followTeamMode: root.followTeamMode
                tableOptions: root.teamTableOptions
                selectedTableSlug: root.selectedTableSlug
                seasonOptions: root.teamTableSeasonOptions
                selectedSeasonKey: root.selectedTableSeasonKey
                seasonLoading: root.teamTableSeasonLoading
                onTableSelected: (slug) => root.teamTableSelected(slug)
                onSeasonSelected: (seasonKey) => root.teamTableSeasonSelected(seasonKey)
            }

        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: (root.lastUpdatedText.length > 0 ? root.lastUpdatedText : i18nc("@info:status", "Waiting for update"))
                + " · " + i18nc("@info", "Powered by <a href=\"https://sportscore.com/\">SportScore</a>")
            color: Kirigami.Theme.textColor
            linkColor: Kirigami.Theme.linkColor
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.StyledText
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            onLinkActivated: link => Qt.openUrlExternally(link)

            HoverHandler {
                cursorShape: parent.hoveredLink.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }

    }

    component MatchHero: Rectangle {
        id: hero

        property string homeTeam: ""
        property string awayTeam: ""
        property string homeScore: ""
        property string awayScore: ""
        property string status: ""
        property string minute: ""
        property string startTime: ""
        property string stadium: ""
        property string homeBadge: ""
        property string awayBadge: ""
        property string matchPath: ""
        property string liveUrl: ""
        property string sport: "football"
        property string league: ""
        property bool showScore: true
        property bool loading: false

        function scoreText() {
            if (!showScore)
                return "";

            const home = homeScore.length > 0 ? homeScore : "0";
            const away = awayScore.length > 0 ? awayScore : "0";
            return home + " - " + away;
        }

        function detailText() {
            if (loading)
                return i18nc("@info:status", "Updating");

            if (minute.length > 0)
                return minute;

            if (status === "Live")
                return status;

            return startTime.length > 0 ? startTime : status;
        }

        function isLiveMatch() {
            return status === "Live" && !loading;
        }

        function liveMinuteText() {
            if (String(sport || "").toLowerCase() === "basketball")
                return SportsApi.liveStatusText(sport, minute);

            const value = SportsApi.normalizedLiveMinute(minute);
            if (value.length === 0)
                return minute.trim();

            const minuteMatch = /^(\d+)(?:\+(\d*))?$/.exec(value);
            if (!minuteMatch)
                return value;

            if (minuteMatch[2] === undefined)
                return minuteMatch[1] + "'";
            return minuteMatch[2].length > 0 ? minuteMatch[1] + "' + " + minuteMatch[2] + "'" : minuteMatch[1] + "' +";
        }

        function stoppageMinutePart(index) {
            const match = /^(\d+)\+(\d*)$/.exec(SportsApi.normalizedLiveMinute(minute));
            return match && match[index].length > 0 ? match[index] + "'" : "";
        }

        function hasStoppageTime() {
            return /^\d+\+\d*$/.test(SportsApi.normalizedLiveMinute(minute));
        }

        function isTennisMatch() {
            return String(sport || "").toLowerCase() === "tennis";
        }

        function liveStatusLabelText() {
            if (hero.isTennisMatch() && minute.trim().length > 0)
                return minute.trim();
            return i18nc("@info:live match status", "Live");
        }

        radius: 0
        color: "transparent"
        clip: false

        Item {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.bottomMargin: Kirigami.Units.smallSpacing

            ColumnLayout {
                id: heroScoreColumn

                width: Kirigami.Units.gridUnit * 10.5
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: hero.scoreText()
                    visible: text.length > 0
                    color: Kirigami.Theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                    font.pixelSize: Kirigami.Units.gridUnit * 1.55
                }

                Item {
                    id: heroLiveStatusContainer

                    readonly property int dotSize: Math.max(9, Math.round(Kirigami.Units.smallSpacing * 2))

                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Theme.defaultFont.pixelSize + Kirigami.Units.smallSpacing * 2
                    visible: hero.isLiveMatch()

                    Row {
                        id: heroLiveStatusRow

                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, heroLiveStatusContainer.width)
                        height: implicitHeight
                        spacing: Kirigami.Units.smallSpacing

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: heroLiveStatusContainer.dotSize
                            height: width
                            radius: width / 2
                            color: root.liveColor

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: hero.isLiveMatch()

                                NumberAnimation {
                                    from: 1
                                    to: 0.35
                                    duration: 650
                                    easing.type: Easing.InOutQuad
                                }

                                NumberAnimation {
                                    from: 0.35
                                    to: 1
                                    duration: 650
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        PlasmaComponents.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: hero.liveStatusLabelText()
                            color: root.liveColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.bold: true
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
                        }

                        PlasmaComponents.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !hero.isTennisMatch() && !hero.hasStoppageTime() && hero.liveMinuteText().length > 0
                            text: hero.liveMinuteText()
                            color: root.liveColor
                            font.bold: true
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
                        }

                        HeroMinuteBadge {
                            visible: hero.hasStoppageTime()
                            text: hero.stoppageMinutePart(1)
                        }

                        PlasmaComponents.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: hero.hasStoppageTime()
                            text: "+"
                            color: root.liveColor
                            font.bold: true
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
                        }

                        HeroMinuteBadge {
                            visible: hero.hasStoppageTime() && hero.stoppageMinutePart(2).length > 0
                            text: hero.stoppageMinutePart(2)
                        }
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: hero.detailText()
                    color: Kirigami.Theme.highlightColor
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: !hero.isLiveMatch()
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
                }

                RowLayout {
                    readonly property int stadiumIconSize: Math.round(Kirigami.Units.iconSizes.smallMedium * 1.1)

                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: heroScoreColumn.width
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    visible: hero.stadium.length > 0 && !hero.loading
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: parent.stadiumIconSize
                        Layout.preferredHeight: Layout.preferredWidth
                        text: "🏟️"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Math.round(parent.stadiumIconSize * 0.8)
                    }

                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: heroScoreColumn.width - parent.stadiumIconSize - Kirigami.Units.smallSpacing
                        text: hero.stadium
                        color: Kirigami.Theme.disabledTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                    }
                }

            }

            HeroTeam {
                anchors.left: parent.left
                anchors.right: heroScoreColumn.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Kirigami.Units.largeSpacing
                height: parent.height
                name: hero.homeTeam
                badge: hero.homeBadge
            }

            HeroTeam {
                anchors.left: heroScoreColumn.right
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Kirigami.Units.largeSpacing
                height: parent.height
                name: hero.awayTeam
                badge: hero.awayBadge
            }

        }

    }

    component HeroTeam: ColumnLayout {
        id: heroTeam

        property string name: ""
        property string badge: ""
        readonly property int badgeSize: Kirigami.Units.iconSizes.huge + Kirigami.Units.gridUnit
        readonly property int backingSize: Math.ceil(badgeSize * Math.max(1, Screen.devicePixelRatio) * 2)

        spacing: 2

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: parent.badgeSize
            Layout.preferredHeight: Layout.preferredWidth

            TeamBadgeImage {
                anchors.fill: parent
                sourceUrl: heroTeam.badge
                fallbackIcon: "applications-games"
                fallbackOpacity: 0.9
            }

        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: name
            color: Kirigami.Theme.textColor
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.bold: true
            font.pixelSize: Math.max(Kirigami.Theme.defaultFont.pixelSize, Kirigami.Theme.smallFont.pixelSize + 2)
        }

    }

    component HeroMinuteBadge: Rectangle {
        property string text: ""

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: Math.max(height, minuteLabel.implicitWidth + Kirigami.Units.smallSpacing)
        height: Kirigami.Theme.defaultFont.pixelSize + Kirigami.Units.smallSpacing
        radius: 3
        color: root.withAlpha(root.liveColor, 0.16)
        border.width: 1
        border.color: root.withAlpha(root.liveColor, 0.65)

        PlasmaComponents.Label {
            id: minuteLabel

            anchors.centerIn: parent
            text: parent.text
            color: root.liveColor
            font.bold: true
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize + 2
        }
    }

    component WeatherStyleTab: Rectangle {
        id: tab

        property string label: ""
        property bool active: false

        signal clicked()

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 14
        color: active ? root.withAlpha(Kirigami.Theme.highlightColor, 0.5) : "transparent"

        PlasmaComponents.Label {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Kirigami.Units.largeSpacing)
            text: tab.label
            color: tab.active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            opacity: tab.active ? 1 : 0.65
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font.bold: tab.active

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }

            }

        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tab.clicked()
        }

        Behavior on color {
            ColorAnimation {
                duration: 140
            }

        }

    }

    component InfoNumber: ColumnLayout {
        property string label: ""
        property var value: ""
        property color accent: Kirigami.Theme.textColor

        Layout.fillWidth: true
        spacing: 0

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: label
            color: Kirigami.Theme.textColor
            horizontalAlignment: Text.AlignRight
            opacity: 0.9
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: value
            color: accent
            horizontalAlignment: Text.AlignRight
            font.bold: true
            font.pixelSize: Kirigami.Units.gridUnit
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
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: parent.parent.text
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

        }

    }

    component TableHeader: Rectangle {
        property string title: ""

        height: Kirigami.Units.gridUnit * 4.2
        color: "transparent"

        Column {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                width: parent.width
                text: parent.parent.title
                color: Kirigami.Theme.textColor
                elide: Text.ElideRight
                font.bold: true
                font.pixelSize: Kirigami.Units.gridUnit * 1.1
            }

            RowLayout {
                width: parent.width
                height: Kirigami.Units.gridUnit * 1.8
                spacing: Kirigami.Units.smallSpacing

                HeaderLabel {
                    text: "#"
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.35
                }

                HeaderLabel {
                    text: i18nc("@label", "Team")
                    Layout.fillWidth: true
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation games played", "Pl")
                    tooltip: i18nc("@label", "Played")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.4
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation games won", "W")
                    tooltip: i18nc("@label", "Won")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation games drawn", "D")
                    tooltip: i18nc("@label", "Drawn")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation games lost", "L")
                    tooltip: i18nc("@label", "Lost")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation goals for", "F")
                    tooltip: i18nc("@label", "Goals For")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation goals against", "A")
                    tooltip: i18nc("@label", "Goals Against")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.4
                }

                HeaderLabel {
                    text: i18nc("@label", "GD")
                    tooltip: i18nc("@label", "Goal Difference")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                }

                HeaderLabel {
                    text: i18nc("@label:abbreviation points", "Pts")
                    tooltip: i18nc("@label", "Points")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.8
                }

                HeaderLabel {
                    text: i18nc("@label", "Form")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 6.6
                }
            }

        }

    }

    component HeaderLabel: PlasmaComponents.Label {
        property string tooltip: ""

        color: Kirigami.Theme.disabledTextColor
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        ToolTip.text: tooltip
        ToolTip.visible: tooltip.length > 0 && hoverHandler.hovered

        HoverHandler {
            id: hoverHandler
        }
    }

    component TableRow: Rectangle {
        property int position: 0
        property string team: ""
        property int played: 0
        property int won: 0
        property int draw: 0
        property int lost: 0
        property int goalsFor: 0
        property int goalsAgainst: 0
        property int points: 0
        property int goalDifference: 0
        property string form: ""
        property string crest: ""
        property bool favorite: false

        height: Kirigami.Units.gridUnit * 2.7
        color: favorite ? root.withAlpha(Kirigami.Theme.alternateBackgroundColor, 0.5) : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.withAlpha(Kirigami.Theme.separatorColor, 0.5)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: position
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.35
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Kirigami.Units.gridUnit
            }

            TeamBadgeImage {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Layout.preferredWidth
                sourceUrl: crest
            }

            PlasmaComponents.Label {
                text: team
                color: Kirigami.Theme.textColor
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.bold: true
            }

            RowValue {
                text: played
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.4
            }

            RowValue {
                text: won
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }

            RowValue {
                text: draw
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
            }

            RowValue {
                text: lost
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }

            RowValue {
                text: goalsFor
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }

            RowValue {
                text: goalsAgainst
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.4
            }

            RowValue {
                text: goalDifference
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }

            RowValue {
                text: points
                color: Kirigami.Theme.textColor
                font.bold: true
                font.pixelSize: Kirigami.Units.gridUnit * 1.25
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.8
            }

            FormBadges {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6.6
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.3
                form: parent.parent.form
            }
        }

    }

    component FixtureRow: Rectangle {
        property string homeTeam: ""
        property string awayTeam: ""
        property string homeScore: ""
        property string awayScore: ""
        property string status: ""
        property string startTime: ""
        property string matchday: ""
        property string homeBadge: ""
        property string awayBadge: ""
        property bool favorite: false

        function scoreText(home, away) {
            if (home.length === 0 && away.length === 0)
                return "-";

            return home + " - " + away;
        }

        height: Kirigami.Units.gridUnit * 3
        color: favorite ? root.withAlpha(Kirigami.Theme.alternateBackgroundColor, 0.5) : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4.5
                text: startTime
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
            }

            TeamCompact {
                Layout.fillWidth: true
                name: homeTeam
                badge: homeBadge
            }

            PlasmaComponents.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                text: scoreText(homeScore, awayScore)
                color: Kirigami.Theme.textColor
                horizontalAlignment: Text.AlignHCenter
                font.bold: true
            }

            TeamCompact {
                Layout.fillWidth: true
                name: awayTeam
                badge: awayBadge
            }

            PlasmaComponents.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                text: status
                color: status === "Live" ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

        }

    }

    component TeamCompact: RowLayout {
        property string name: ""
        property string badge: ""

        spacing: Kirigami.Units.smallSpacing

        TeamBadgeImage {
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            sourceUrl: badge
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: name
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
        }

    }

    component RowValue: PlasmaComponents.Label {
        color: Kirigami.Theme.textColor
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    component FormBadges: Item {
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
                            return Kirigami.Theme.positiveTextColor;
                        if (result === "L")
                            return Kirigami.Theme.negativeTextColor;
                        return Kirigami.Theme.neutralTextColor;
                    }

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: String(modelData).charAt(0).toUpperCase()
                        color: Kirigami.Theme.backgroundColor
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
            color: Kirigami.Theme.disabledTextColor
        }
    }

}
