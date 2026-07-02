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

    property var scheduleModel
    property string favoriteTeam: ""
    property bool loading: false
    property int selectedIndex: 0
    property string emptyText: i18nc("@info:placeholder", "No scheduled matches")
    property string loadingText: i18nc("@info:status", "Loading schedules")
    property string emptyIconName: "view-calendar-day"
    property var collapsedGroups: ({})
    // Groups whose data is currently being fetched (lazy expand), so the section
    // header can show a spinner.
    property var loadingGroups: ({})
    // Per-match one-click bell / star / pin actions, same wiring as the Live tab.
    property bool showMatchActions: false
    property int matchActionsTick: 0
    property var matchNotifyState: function(match) { return false; }
    property var matchPinnedState: function(match) { return false; }
    property var matchFavoriteState: function(match) { return false; }
    property var teamFavoriteState: function(teamName) { return false; }

    signal matchSelected(int index)
    // Emitted when a group header is toggled. The host owns the collapsed map
    // (collapsedGroups is bound from it) and lazily fetches a group on expand.
    signal groupExpanded(string group)
    signal groupCollapsed(string group)
    signal matchNotifyToggled(var match)
    signal matchFavoriteToggled(string teamName, var match)
    signal matchPanelPinToggled(var match)

    function modelMatch(model) {
        return {
            "sport": model.sport || "",
            "league": model.league || "",
            "homeTeam": model.homeTeam || "",
            "awayTeam": model.awayTeam || "",
            "homeBadge": model.homeBadge || "",
            "awayBadge": model.awayBadge || "",
            "startTime": model.startTime || "",
            "timestamp": Number(model.timestamp || 0)
        };
    }

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
        id: scheduleList

        anchors.fill: parent
        clip: true
        spacing: 0
        boundsBehavior: Flickable.StopAtBounds
        model: root.scheduleModel
        // Keep rows non-reused so contentHeight stays stable while scrolling
        // collapsed/placeholder groups (mirrors the Recent Results tab).
        reuseItems: false
        cacheBuffer: Kirigami.Units.gridUnit * 20
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        readonly property int contentColumnWidth: Math.max(0, width - Kirigami.Units.gridUnit)

        section.property: "leagueGroup"
        section.criteria: ViewSection.FullString
        section.delegate: RoundSectionHeader {
            width: scheduleList.contentColumnWidth
            text: section
            collapsible: true
            collapsed: root.isGroupCollapsed(section)
            loading: root.isGroupLoading(section)
            onToggled: root.toggleGroup(section)
        }

        EmptyState {
            anchors.fill: parent
            visible: scheduleList.count === 0 && !root.loading
            text: root.emptyText
            iconName: root.emptyIconName
        }

        delegate: Item {
            id: scheduleRow

            required property var model
            required property int index

            width: scheduleList.contentColumnWidth
            // Row kind is carried explicitly ("header" | "match" | "notice") so the
            // discriminator is reliable: a header row only exists so the section
            // header renders (never shown itself), a notice row shows "no upcoming
            // matches", and a match row loads the score delegate.
            readonly property string rowType: String(scheduleRow.model.rowType || "match")
            readonly property bool isNotice: rowType === "notice"
            readonly property bool shown: rowType !== "header"
                && !root.isGroupCollapsed(scheduleRow.model.leagueGroup)
            visible: shown
            // Fixed match-row height (ScoreDelegate's own implicitHeight) so the row
            // height never drifts as the Loader's item settles - keeps the ListView
            // contentHeight stable and the scroll from jumping.
            readonly property real matchRowHeight: Kirigami.Units.gridUnit * 4.2
            height: visible ? (isNotice ? noticeLabel.implicitHeight + Kirigami.Units.smallSpacing * 2 : matchRowHeight) : 0

            PlasmaComponents.Label {
                id: noticeLabel

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Kirigami.Units.gridUnit
                visible: scheduleRow.isNotice
                text: i18nc("@info:placeholder", "No upcoming matches")
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
            }

            Loader {
                id: scoreLoader

                anchors.fill: parent
                active: scheduleRow.shown && !scheduleRow.isNotice
                visible: active
                sourceComponent: ScoreDelegate {
                    width: scheduleRow.width
                    sport: scheduleRow.model.sport
                    league: scheduleRow.model.league
                    homeTeam: scheduleRow.model.homeTeam
                    awayTeam: scheduleRow.model.awayTeam
                    homeScore: scheduleRow.model.homeScore
                    awayScore: scheduleRow.model.awayScore
                    status: scheduleRow.model.status
                    minute: scheduleRow.model.minute
                    startTime: scheduleRow.model.startTime
                    matchday: scheduleRow.model.matchday || ""
                    stadium: scheduleRow.model.stadium || ""
                    homeBadge: scheduleRow.model.homeBadge
                    awayBadge: scheduleRow.model.awayBadge
                    poster: scheduleRow.model.poster
                    popular: scheduleRow.model.popular
                    showScore: scheduleRow.model.showScore !== false
                    splitLeagueAndTimeLines: true
                    splitDateAndTimeLines: false
                    favorite: root.isFavoriteTeam(scheduleRow.model.homeTeam) || root.isFavoriteTeam(scheduleRow.model.awayTeam) || (root.matchActionsTick, root.matchFavoriteState(root.modelMatch(scheduleRow.model)))
                    selected: scheduleRow.index === root.selectedIndex
                    showMatchActions: root.showMatchActions
                    matchNotifyOn: (root.matchActionsTick, root.matchNotifyState(root.modelMatch(scheduleRow.model)))
                    matchPinnedToPanel: (root.matchActionsTick, root.matchPinnedState(root.modelMatch(scheduleRow.model)))
                    homeIsFavorite: (root.matchActionsTick, root.teamFavoriteState(scheduleRow.model.homeTeam || ""))
                    awayIsFavorite: (root.matchActionsTick, root.teamFavoriteState(scheduleRow.model.awayTeam || ""))
                    onNotifyToggled: root.matchNotifyToggled(root.modelMatch(scheduleRow.model))
                    onFavoriteToggled: (teamName) => root.matchFavoriteToggled(teamName, root.modelMatch(scheduleRow.model))
                    onPanelPinToggled: root.matchPanelPinToggled(root.modelMatch(scheduleRow.model))
                    onClicked: root.matchSelected(scheduleRow.index)
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
        visible: root.loading && scheduleList.count === 0
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Layout.preferredWidth
            running: root.loading
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: root.loadingText
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    component EmptyState: Item {
        property string text: ""
        property string iconName: "view-calendar-day"

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Kirigami.Units.gridUnit * 2)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Layout.preferredWidth
                source: parent.parent.iconName
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
