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

import "../../code/SportVisuals.js" as SportVisuals
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var configRoot
    readonly property int cardMinimumWidth: Kirigami.Units.gridUnit * 10

    spacing: Kirigami.Units.largeSpacing

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            text: i18nc("@title:group", "Sport")
            level: 2
        }

        Label {
            Layout.fillWidth: true
            text: i18nc("@info", "Select the sport that should drive schedules, tables and fixtures.")
            opacity: 0.72
            wrapMode: Text.WordWrap
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: Math.max(1, Math.floor((width + columnSpacing) / (root.cardMinimumWidth + columnSpacing)))
        columnSpacing: Kirigami.Units.smallSpacing
        rowSpacing: Kirigami.Units.smallSpacing

        Repeater {
            model: root.configRoot ? root.configRoot.sportOptions() : []

            delegate: SportChoiceCard {
                title: modelData.label
                iconEmoji: SportVisuals.emoji(modelData.value)
                selected: root.configRoot && root.configRoot.normalizedSport() === modelData.value
                onClicked: root.configRoot.selectSport(modelData.value)
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
