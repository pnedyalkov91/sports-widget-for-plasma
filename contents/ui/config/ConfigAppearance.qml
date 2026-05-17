/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: root

    property string cfg_panelLayoutMode: Plasmoid.configuration.panelLayoutMode
    property string cfg_widgetTabs: Plasmoid.configuration.widgetTabs

    function indexFor(model, value) {
        for (let index = 0; index < model.length; index += 1) {
            if (model[index].value === value)
                return index;

        }
        return 0;
    }

    Kirigami.FormLayout {
        anchors.fill: parent

        ComboBox {
            id: panelLayoutMode

            Kirigami.FormData.label: i18nc("@label:listbox", "Panel layout:")
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: [{
                "label": i18nc("@item:inlistbox", "Single line"),
                "value": "singleLine"
            }, {
                "label": i18nc("@item:inlistbox", "Simple"),
                "value": "simple"
            }, {
                "label": i18nc("@item:inlistbox", "Multiline"),
                "value": "multiline"
            }]
            Component.onCompleted: currentIndex = root.indexFor(model, root.cfg_panelLayoutMode)
            onActivated: root.cfg_panelLayoutMode = currentValue
        }

        ComboBox {
            id: widgetTabs

            Kirigami.FormData.label: i18nc("@label:listbox", "Widget layout:")
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: [{
                "label": i18nc("@item:inlistbox", "All tabs"),
                "value": "all"
            }, {
                "label": i18nc("@item:inlistbox", "Live + Schedules + Stats"),
                "value": "liveStats"
            }, {
                "label": i18nc("@item:inlistbox", "Live + Schedules + Tables"),
                "value": "liveTables"
            }, {
                "label": i18nc("@item:inlistbox", "Live + Schedules + Fixtures"),
                "value": "liveFixtures"
            }, {
                "label": i18nc("@item:inlistbox", "Live + Schedules"),
                "value": "liveOnly"
            }]
            Component.onCompleted: currentIndex = root.indexFor(model, root.cfg_widgetTabs || "all")
            onActivated: root.cfg_widgetTabs = currentValue
        }

    }

}
