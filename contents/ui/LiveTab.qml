/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick

Item {
    id: root

    property var liveModel
    property string favoriteTeam: ""
    property bool loading: false
    property int selectedIndex: 0

    signal matchSelected(int index)

    ScheduleTab {
        anchors.fill: parent
        scheduleModel: root.liveModel
        favoriteTeam: root.favoriteTeam
        loading: root.loading
        selectedIndex: root.selectedIndex
        emptyText: i18nc("@info:placeholder", "No live matches")
        loadingText: i18nc("@info:status", "Loading live matches")
        emptyIconName: "media-playback-start"
        onMatchSelected: (index) => {
            root.matchSelected(index);
        }
    }
}
