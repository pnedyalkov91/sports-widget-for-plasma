/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../code/SportVisuals.js" as SportVisuals
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var scoreModel
    property var tableModel
    property var tableRows: []
    property var fixturesModel
    property var statsModel
    property bool loading: false
    property string errorMessage: ""
    property string tableErrorMessage: ""
    property string lastUpdatedText: ""
    property string providerLabel: ""
    property string sourceText: ""
    property string primaryText: ""
    property string secondaryText: ""
    property string league: "PL"
    property string favoriteTeam: ""
    property string sport: "football"
    property int sportCount: 0
    property int tableCount: 0
    property int fixtureCount: 0
    property int statsCount: 0
    property string widgetTabs: "all"
    property string nowText: Qt.formatDateTime(new Date(), "dd.MM.yyyy hh:mm:ss")
    property int activeTab: 0
    readonly property bool hasMatches: scoreModel && scoreModel.count > 0

    signal refreshRequested()
    signal configureRequested()

    function isFavoriteTeam(teamName) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(teamName || "").toLowerCase().indexOf(favorite) >= 0;
    }

    function tabVisible(tab) {
        if (tab === 0)
            return true;

        if (root.widgetTabs === "all")
            return true;

        if (root.widgetTabs === "liveStats")
            return tab === 1;

        if (root.widgetTabs === "liveTables")
            return tab === 2;

        if (root.widgetTabs === "liveFixtures")
            return tab === 3;

        return false;
    }

    function activateTab(tab) {
        root.activeTab = root.tabVisible(tab) ? tab : 0;
    }

    onWidgetTabsChanged: activateTab(activeTab)
    Layout.minimumWidth: Kirigami.Units.gridUnit * 30
    Layout.minimumHeight: Kirigami.Units.gridUnit * 30
    Layout.preferredWidth: Kirigami.Units.gridUnit * 40
    Layout.preferredHeight: Kirigami.Units.gridUnit * 43

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.nowText = Qt.formatDateTime(new Date(), "dd.MM.yyyy hh:mm:ss")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Image {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                    source: Qt.resolvedUrl("../icons/sports/" + SportVisuals.iconName(root.sport))
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: SportVisuals.label(root.sport)
                    color: "#e7fbff"
                    elide: Text.ElideRight
                    font.bold: true
                }
            }

            PlasmaComponents.Label {
                text: root.nowText
                color: "#e7fbff"
                font.bold: true
            }

            ToolButton {
                icon.name: "view-refresh"
                display: AbstractButton.IconOnly
                text: i18nc("@action:button", "Refresh")
                onClicked: root.refreshRequested()
            }

            ToolButton {
                icon.name: "configure"
                display: AbstractButton.IconOnly
                text: i18nc("@action:button", "Configure")
                onClicked: root.configureRequested()
            }

        }

        MatchHero {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 7
            homeTeam: root.hasMatches ? root.scoreModel.get(0).homeTeam : i18nc("@info:placeholder", "Home team")
            awayTeam: root.hasMatches ? root.scoreModel.get(0).awayTeam : i18nc("@info:placeholder", "Away team")
            homeScore: root.hasMatches ? root.scoreModel.get(0).homeScore : ""
            awayScore: root.hasMatches ? root.scoreModel.get(0).awayScore : ""
            status: root.hasMatches ? root.scoreModel.get(0).status : i18nc("@info:status", "No live scores")
            minute: root.hasMatches ? root.scoreModel.get(0).minute : ""
            startTime: root.hasMatches ? root.scoreModel.get(0).startTime : ""
            homeBadge: root.hasMatches ? root.scoreModel.get(0).homeBadge : ""
            awayBadge: root.hasMatches ? root.scoreModel.get(0).awayBadge : ""
            loading: root.loading
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            Layout.leftMargin: -Kirigami.Units.largeSpacing
            Layout.rightMargin: -Kirigami.Units.largeSpacing
            radius: height / 2
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 0

                WeatherStyleTab {
                    label: i18n("Live Score")
                    active: root.activeTab === 0
                    visible: root.tabVisible(0)
                    onClicked: root.activateTab(0)
                }

                WeatherStyleTab {
                    label: i18n("Stats")
                    active: root.activeTab === 1
                    visible: root.tabVisible(1)
                    onClicked: root.activateTab(1)
                }

                WeatherStyleTab {
                    label: i18n("Tables")
                    active: root.activeTab === 2
                    visible: root.tabVisible(2)
                    onClicked: root.activateTab(2)
                }

                WeatherStyleTab {
                    label: i18n("Fixtures")
                    active: root.activeTab === 3
                    visible: root.tabVisible(3)
                    onClicked: root.activateTab(3)
                }

            }

        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.errorMessage.length > 0
            type: Kirigami.MessageType.Information
            text: root.errorMessage
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.activeTab

            ListView {
                id: scoreList

                clip: true
                spacing: 0
                model: root.scoreModel

                EmptyState {
                    anchors.fill: parent
                    visible: scoreList.count === 0
                    text: i18nc("@info:placeholder", "No live scores")
                }

                delegate: ScoreDelegate {
                    width: scoreList.width
                    sport: model.sport
                    league: model.league
                    homeTeam: model.homeTeam
                    awayTeam: model.awayTeam
                    homeScore: model.homeScore
                    awayScore: model.awayScore
                    status: model.status
                    minute: model.minute
                    startTime: model.startTime
                    homeBadge: model.homeBadge
                    awayBadge: model.awayBadge
                    poster: model.poster
                    popular: model.popular
                    favorite: root.isFavoriteTeam(model.homeTeam) || root.isFavoriteTeam(model.awayTeam)
                }

            }

            ListView {
                id: statsList

                clip: true
                spacing: Kirigami.Units.smallSpacing
                model: root.statsModel

                EmptyState {
                    anchors.fill: parent
                    visible: statsList.count === 0
                    text: i18nc("@info:placeholder", "No match stats available")
                }

                delegate: StatsRow {
                    width: statsList.width
                    label: model.label
                    homeValue: model.homeValue
                    awayValue: model.awayValue
                    homeRatio: model.homeRatio
                    awayRatio: model.awayRatio
                    homeHighlight: model.homeHighlight
                    awayHighlight: model.awayHighlight
                }

            }

            TableTab {
                tableModel: root.tableModel
                tableRows: root.tableRows
                tableCount: root.tableCount
                tableErrorMessage: root.tableErrorMessage
                league: root.league
                sport: root.sport
                favoriteTeam: root.favoriteTeam
            }

            ListView {
                id: fixturesList

                clip: true
                spacing: 0
                model: root.fixturesModel

                EmptyState {
                    anchors.fill: parent
                    visible: fixturesList.count === 0
                    text: i18nc("@info:placeholder", "No scores or fixtures")
                }

                delegate: FixtureRow {
                    width: fixturesList.width
                    homeTeam: model.homeTeam
                    awayTeam: model.awayTeam
                    homeScore: model.homeScore
                    awayScore: model.awayScore
                    status: model.status
                    startTime: model.startTime
                    matchday: model.matchday
                    homeBadge: model.homeBadge
                    awayBadge: model.awayBadge
                    favorite: root.isFavoriteTeam(model.homeTeam) || root.isFavoriteTeam(model.awayTeam)
                }

            }

        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: (root.lastUpdatedText.length > 0 ? root.lastUpdatedText : i18nc("@info:status", "Waiting for update")) + " · " + i18nc("@label", "Provider: %1", root.providerLabel)
            color: "#e7fbff"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
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
        property string homeBadge: ""
        property string awayBadge: ""
        property bool loading: false

        function scoreText() {
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

        radius: 0
        color: "transparent"
        clip: false

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.largeSpacing

            HeroTeam {
                Layout.fillWidth: true
                Layout.fillHeight: true
                name: hero.homeTeam
                badge: hero.homeBadge
            }

            ColumnLayout {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: hero.scoreText()
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    font.bold: true
                    font.pixelSize: Kirigami.Units.gridUnit * 1.25
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: hero.detailText()
                    color: "#ff7a00"
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.bold: true
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

            }

            HeroTeam {
                Layout.fillWidth: true
                Layout.fillHeight: true
                name: hero.awayTeam
                badge: hero.awayBadge
            }

        }

    }

    component HeroTeam: ColumnLayout {
        property string name: ""
        property string badge: ""

        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Layout.preferredWidth

            Image {
                anchors.fill: parent
                source: badge
                visible: badge.length > 0
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Kirigami.Icon {
                anchors.fill: parent
                source: "applications-games"
                visible: badge.length === 0
                color: "#f4f4f4"
                opacity: 0.9
            }

        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: name
            color: "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.bold: true
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
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
        color: active ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.17) : "transparent"

        PlasmaComponents.Label {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Kirigami.Units.largeSpacing)
            text: tab.label
            color: Kirigami.Theme.textColor
            opacity: tab.active ? 1 : 0.42
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
        property color accent: "#ffffff"

        Layout.fillWidth: true
        spacing: 0

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: label
            color: "#e7fbff"
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
                color: "#9db7be"
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: parent.parent.text
                color: "#9db7be"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

        }

    }

    component StatsRow: Item {
        id: statsRow

        property string label: ""
        property string homeValue: ""
        property string awayValue: ""
        property real homeRatio: 0
        property real awayRatio: 0
        property bool homeHighlight: false
        property bool awayHighlight: false

        height: Kirigami.Units.gridUnit * 2.6

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: 3

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit

                PlasmaComponents.Label {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: statsRow.homeValue
                    color: "#d9d9d9"
                    font.bold: statsRow.homeHighlight
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: statsRow.label
                    color: "#a8a8a8"
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 5)
                    horizontalAlignment: Text.AlignHCenter
                }

                PlasmaComponents.Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: statsRow.awayValue
                    color: "#d9d9d9"
                    font.bold: statsRow.awayHighlight
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                }

            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                spacing: Kirigami.Units.smallSpacing

                StatHalfBar {
                    Layout.fillWidth: true
                    ratio: statsRow.homeRatio
                    highlight: statsRow.homeHighlight
                    mirrored: true
                }

                StatHalfBar {
                    Layout.fillWidth: true
                    ratio: statsRow.awayRatio
                    highlight: statsRow.awayHighlight
                    mirrored: false
                }

            }

        }

    }

    component StatHalfBar: Rectangle {
        property real ratio: 0
        property bool highlight: false
        property bool mirrored: false

        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.1)

        Rectangle {
            height: parent.height
            width: Math.max(0, parent.width * Math.min(1, Math.max(0, ratio)))
            x: mirrored ? parent.width - width : 0
            radius: parent.radius
            color: highlight ? "#ff7a00" : Qt.rgba(1, 1, 1, 0.62)
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
                color: "#ffffff"
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

        color: "#9db7be"
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
        color: favorite ? Qt.rgba(1, 0.59, 0.31, 0.14) : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Qt.rgba(1, 1, 1, 0.09)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: position
                color: "#e7fbff"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.35
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Kirigami.Units.gridUnit
            }

            Image {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Layout.preferredWidth
                source: crest
                visible: crest.length > 0
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            PlasmaComponents.Label {
                text: team
                color: "#e7fbff"
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
                color: "#ffffff"
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
        color: favorite ? Qt.rgba(1, 0.59, 0.31, 0.14) : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4.5
                text: startTime
                color: "#9db7be"
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
                color: "#ffffff"
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
                color: status === "Live" ? "#6ee7a7" : "#9db7be"
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

        }

    }

    component TeamCompact: RowLayout {
        property string name: ""
        property string badge: ""

        spacing: Kirigami.Units.smallSpacing

        Image {
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            source: badge
            visible: badge.length > 0
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: name
            color: "#e7fbff"
            elide: Text.ElideRight
        }

    }

    component RowValue: PlasmaComponents.Label {
        color: "#d7eef2"
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    component FormBadges: Item {
        property string form: ""

        function results() {
            return String(form || "").replace(/[^A-Za-z]+/g, ",").split(",").filter(item => item.length > 0).slice(-6);
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
            color: "#9db7be"
        }
    }

}
