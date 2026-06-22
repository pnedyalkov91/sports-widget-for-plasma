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
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// The Plasma calendar config page expects every enabled plugin to provide a
// config UI (X-KDE-PlasmaCalendar-ConfigUi). This plugin has nothing to
// configure here — all options live in the Sports widget settings — so this is
// just an explanatory page that satisfies the expected saveConfig()/changed API.
KCM.SimpleKCM {
    id: configPage

    // Expected API of a Plasma calendar plugin config page.
    signal configurationChanged

    property bool unsavedChanges: false

    function saveConfig() {
        unsavedChanges = false;
    }

    ColumnLayout {
        width: parent.width
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: true
            type: Kirigami.MessageType.Information
            text: i18nd("plasma_calendar_sportsmatchesevents",
                "Matches shown here come from the Sports Widget and update automatically.")
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18nd("plasma_calendar_sportsmatchesevents",
                "There is nothing to configure here. To choose which competitions and teams appear in the calendar, open the Sports Widget settings and go to Notifications → Calendar.")
        }

        Item { Layout.fillHeight: true }
    }
}
