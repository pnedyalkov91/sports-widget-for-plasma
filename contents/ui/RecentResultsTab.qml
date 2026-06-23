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

    property var resultsModel
    property string favoriteTeam: ""
    property bool loading: false
    property int selectedIndex: 0
    property string emptyText: i18nc("@info:placeholder", "No recent results")
    property var collapsedGroups: ({})
    // Groups whose data is currently being fetched (lazy expand), so the section
    // header can show a spinner.
    property var loadingGroups: ({})

    signal matchSelected(int index)
    // Emitted when a group header is toggled. The host owns the collapsed map
    // (collapsedGroups is bound from it) and lazily fetches a group on expand.
    signal groupExpanded(string group)
    signal groupCollapsed(string group)

    onResultsModelChanged: resultsList.expandedIndex = -1

    function isGroupCollapsed(group) {
        return Boolean(root.collapsedGroups[String(group || "")]);
    }

    function isGroupLoading(group) {
        return Boolean(root.loadingGroups[String(group || "")]);
    }

    function toggleGroup(group) {
        const key = String(group || "");
        if (root.isGroupCollapsed(key))
            root.groupExpanded(key);
        else
            root.groupCollapsed(key);
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
        // Delegate heights here are variable (collapsed groups, placeholder rows,
        // an inline-expanded match whose details load async). With item reuse the
        // ListView estimates off-screen heights from recycled items and corrects
        // contentHeight mid-scroll — which makes the scrollbar resize and the view
        // jump. Disabling reuse keeps each realized row's measured height, and a
        // moderate cache buffer avoids re-measuring at the scroll edges. The fixed
        // non-expanded delegate height (below) keeps contentHeight stable.
        reuseItems: false
        cacheBuffer: Kirigami.Units.gridUnit * 20
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
            loading: root.isGroupLoading(section)
            onToggled: root.toggleGroup(section)
        }

        EmptyState {
            anchors.fill: parent
            visible: resultsList.count === 0 && !root.loading
        }

        delegate: Item {
            id: recentRow

            required property var model
            required property int index

            width: resultsList.contentColumnWidth
            // Explicit row kind ("header" | "match" | "notice") so the discriminator
            // is reliable with the model's dynamic roles — header rows only exist so
            // the section header renders, notice rows say "no recent matches".
            readonly property string rowType: String(recentRow.model.rowType || "match")
            readonly property bool isNotice: rowType === "notice"
            readonly property bool shown: rowType !== "header"
                && !root.isGroupCollapsed(recentRow.model.leagueGroup)
            readonly property real matchRowHeight: String(recentRow.model.stadium || "").length > 0 ? Kirigami.Units.gridUnit * 5.4 : Kirigami.Units.gridUnit * 4.6
            visible: shown
            height: !shown ? 0 : (isNotice ? noticeLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
                : (matchLoader.item && matchLoader.item.expanded ? matchLoader.item.implicitHeight : matchRowHeight))

            PlasmaComponents.Label {
                id: noticeLabel

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Kirigami.Units.gridUnit
                visible: recentRow.isNotice
                text: i18nc("@info:placeholder", "No recent matches")
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
            }

            Loader {
                id: matchLoader

                width: parent.width
                active: recentRow.shown && !recentRow.isNotice
                visible: active
                sourceComponent: LiveMatchDelegate {
                    width: recentRow.width
                    scoreRowHeight: recentRow.matchRowHeight
                    sport: recentRow.model.sport
                    league: recentRow.model.league
                    homeTeam: recentRow.model.homeTeam
                    awayTeam: recentRow.model.awayTeam
                    homeScore: recentRow.model.homeScore
                    awayScore: recentRow.model.awayScore
                    homePenaltyScore: recentRow.model.homePenaltyScore || ""
                    awayPenaltyScore: recentRow.model.awayPenaltyScore || ""
                    status: recentRow.model.status
                    minute: recentRow.model.minute
                    startTime: recentRow.model.startTime
                    timestamp: Number(recentRow.model.timestamp || 0)
                    splitLeagueAndTimeLines: true
                    stadium: recentRow.model.stadium || ""
                    homeBadge: recentRow.model.homeBadge
                    awayBadge: recentRow.model.awayBadge
                    poster: recentRow.model.poster
                    popular: recentRow.model.popular
                    showScore: recentRow.model.showScore !== false
                    favorite: root.isFavoriteTeam(recentRow.model.homeTeam) || root.isFavoriteTeam(recentRow.model.awayTeam)
                    selected: recentRow.index === root.selectedIndex
                    expanded: recentRow.index === resultsList.expandedIndex
                    matchPath: recentRow.model.matchPath || ""
                    liveUrl: recentRow.model.liveUrl || ""
                    detailsProvider: recentRow.model.detailsProvider || ""
                    espnEventId: recentRow.model.espnEventId || ""
                    espnSport: recentRow.model.espnSport || ""
                    espnLeague: recentRow.model.espnLeague || ""
                    onClicked: {
                        root.matchSelected(recentRow.index);
                        resultsList.expandedIndex = resultsList.expandedIndex === recentRow.index ? -1 : recentRow.index;
                    }
                    onRequestExpand: resultsList.expandedIndex = recentRow.index
                }
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
