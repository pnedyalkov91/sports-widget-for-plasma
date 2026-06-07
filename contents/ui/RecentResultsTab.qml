/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var resultsModel
    property string favoriteTeam: ""
    property bool loading: false
    property int selectedIndex: 0
    property string emptyText: i18nc("@info:placeholder", "No recent results")
    property var collapsedGroups: ({})

    signal matchSelected(int index)

    onResultsModelChanged: resultsList.expandedIndex = -1

    function isGroupCollapsed(group) {
        return Boolean(root.collapsedGroups[String(group || "")]);
    }

    function toggleGroup(group) {
        const key = String(group || "");
        const next = {};
        for (let existingKey in root.collapsedGroups)
            next[existingKey] = root.collapsedGroups[existingKey];
        next[key] = !root.isGroupCollapsed(key);
        root.collapsedGroups = next;
    }

    function isFavoriteTeam(teamName) {
        const favorite = root.favoriteTeam.toLowerCase();
        if (favorite.length === 0)
            return false;

        return String(teamName || "").toLowerCase().indexOf(favorite) >= 0;
    }

    ListView {
        id: resultsList

        anchors.fill: parent
        clip: true
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds
        model: root.resultsModel
        reuseItems: true
        cacheBuffer: Kirigami.Units.gridUnit * 10
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        readonly property int contentColumnWidth: Math.max(0, width - Kirigami.Units.gridUnit)

        section.property: "leagueGroup"
        section.criteria: ViewSection.FullString
        section.delegate: RoundSectionHeader {
            width: resultsList.contentColumnWidth
            text: section
            collapsible: true
            collapsed: root.isGroupCollapsed(section)
            onToggled: root.toggleGroup(section)
        }

        EmptyState {
            anchors.fill: parent
            visible: resultsList.count === 0 && !root.loading
        }

        delegate: LiveMatchDelegate {
            width: resultsList.contentColumnWidth
            visible: !root.isGroupCollapsed(model.leagueGroup)
            height: visible ? implicitHeight : 0
            enabled: visible
            scoreRowHeight: String(model.stadium || "").length > 0 ? Kirigami.Units.gridUnit * 5.4 : Kirigami.Units.gridUnit * 4.6
            sport: model.sport
            league: model.league
            homeTeam: model.homeTeam
            awayTeam: model.awayTeam
            homeScore: model.homeScore
            awayScore: model.awayScore
            homePenaltyScore: model.homePenaltyScore || ""
            awayPenaltyScore: model.awayPenaltyScore || ""
            status: model.status
            minute: model.minute
            startTime: model.startTime
            timestamp: Number(model.timestamp || 0)
            splitLeagueAndTimeLines: true
            stadium: model.stadium || ""
            homeBadge: model.homeBadge
            awayBadge: model.awayBadge
            poster: model.poster
            popular: model.popular
            showScore: model.showScore !== false
            favorite: root.isFavoriteTeam(model.homeTeam) || root.isFavoriteTeam(model.awayTeam)
            selected: index === root.selectedIndex
            expanded: visible && index === resultsList.expandedIndex
            matchPath: model.matchPath || ""
            liveUrl: model.liveUrl || ""
            detailsProvider: model.detailsProvider || ""
            onClicked: {
                root.matchSelected(index);
                resultsList.expandedIndex = resultsList.expandedIndex === index ? -1 : index;
            }
        }

        property int expandedIndex: -1
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
        visible: root.loading && resultsList.count === 0
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Layout.preferredWidth
            running: root.loading
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: i18nc("@info:status", "Loading recent results")
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    component EmptyState: Item {
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Layout.preferredWidth
                source: "view-history"
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.emptyText
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
