/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

SportStepPage {
    id: root

    property var configRoot
    property string leagueFilter: ""
    readonly property bool pageActive: root.configRoot && root.configRoot.pageIndex === 2 && root.configRoot.cfg_type !== "team"
    readonly property var displayedOptions: root.pageActive && root.configRoot ? root.configRoot.filtered(root.configRoot.leagueOptions(), root.leagueFilter) : []

    title: i18nc("@title:group", "League")
    subtitle: root.configRoot ? root.configRoot.multiSelectEnabled ? i18nc("@info", "Pick one or more leagues/cups to follow for %1.", root.configRoot.countryLabel()) : i18nc("@info", "Pick the league or cup to follow for %1.", root.configRoot.countryLabel()) : ""
    filterText: root.leagueFilter
    filterPlaceholder: i18nc("@info:placeholder", "Search leagues")
    onFilterEdited: text => root.leagueFilter = text

    Repeater {
        model: root.displayedOptions

        delegate: SportChoiceCard {
            title: modelData.label
            iconName: "view-calendar-list"
            selected: root.configRoot && root.configRoot.isLeagueSelected(modelData.value)
            onClicked: root.configRoot.selectLeague(modelData.value)
        }
    }
}
