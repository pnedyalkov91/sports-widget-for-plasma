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

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property var liveModel
    property string favoriteTeam: ""
    property bool loading: false
    property int selectedIndex: 0
    property var collapsedGroups: ({})

    signal matchSelected(int index)

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

    PlasmaComponents.BusyIndicator {
        id: refreshingIndicator

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.smallSpacing
        z: 1
        width: Kirigami.Units.iconSizes.small
        height: width
        visible: root.loading && liveList.count > 0
        running: visible
    }

    ListView {
        id: liveList

        anchors.fill: parent
        clip: true
        spacing: 0
        model: root.liveModel
        boundsBehavior: Flickable.StopAtBounds
        readonly property int contentColumnWidth: Math.max(0, width - Kirigami.Units.gridUnit)

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        section.property: "leagueGroup"
        section.criteria: ViewSection.FullString
        section.delegate: RoundSectionHeader {
            width: liveList.contentColumnWidth
            text: section
            collapsible: true
            collapsed: root.isGroupCollapsed(section)
            onToggled: root.toggleGroup(section)
        }

        EmptyState {
            anchors.fill: parent
            visible: liveList.count === 0 && !root.loading
            text: i18nc("@info:placeholder", "No live matches")
        }

        delegate: LiveMatchDelegate {
            width: liveList.contentColumnWidth
            visible: !root.isGroupCollapsed(model.leagueGroup)
            height: visible ? implicitHeight : 0
            enabled: visible
            sport: model.sport || ""
            league: model.league || ""
            homeTeam: model.homeTeam || ""
            awayTeam: model.awayTeam || ""
            homeScore: model.homeScore || ""
            awayScore: model.awayScore || ""
            homePenaltyScore: model.homePenaltyScore || ""
            awayPenaltyScore: model.awayPenaltyScore || ""
            status: model.status || ""
            minute: model.minute || ""
            startTime: model.startTime || ""
            splitLeagueAndTimeLines: true
            scoreRowHeight: Kirigami.Units.gridUnit * 5.2
            timestamp: Number(model.timestamp || 0)
            stadium: model.stadium || ""
            homeBadge: model.homeBadge || ""
            awayBadge: model.awayBadge || ""
            poster: model.poster || ""
            popular: Boolean(model.popular)
            showScore: model.showScore !== false
            favorite: root.isFavoriteTeam(model.homeTeam) || root.isFavoriteTeam(model.awayTeam)
            selected: index === root.selectedIndex
            expanded: visible && index === liveList.expandedIndex
            matchPath: model.matchPath || ""
            liveUrl: model.liveUrl || ""
            detailsProvider: model.detailsProvider || ""
            espnEventId: model.espnEventId || ""
            espnSport: model.espnSport || ""
            espnLeague: model.espnLeague || ""
            onClicked: {
                root.matchSelected(index);
                liveList.expandedIndex = liveList.expandedIndex === index ? -1 : index;
            }
            onRequestExpand: liveList.expandedIndex = index
        }

        property int expandedIndex: -1
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
        visible: root.loading && liveList.count === 0
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Layout.preferredWidth
            running: root.loading
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: i18nc("@info:status", "Loading live matches")
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
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
                source: "media-playback-start"
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
}
