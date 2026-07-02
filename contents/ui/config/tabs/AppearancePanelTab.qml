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
import Qt.labs.platform as Platform
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: panelTab

    required property var configRoot

    function indexFor(model, value) {
        for (let index = 0; index < model.length; index += 1) {
            if (model[index].value === value)
                return index;

        }
        return 0;
    }

    function defaultFontPointSize() {
        return Kirigami.Theme.defaultFont.pointSize > 0 ? Kirigami.Theme.defaultFont.pointSize : 11;
    }

    function defaultPanelEmblemSize() {
        return Math.max(16, Kirigami.Units.iconSizes.smallMedium);
    }

    Platform.FontDialog {
        id: panelFontDialog

        title: i18nc("@title:window", "Choose Panel Font")
        currentFont: Qt.font({
            family: panelTab.configRoot.cfg_panelFontFamily || Kirigami.Theme.defaultFont.family,
            pointSize: panelTab.configRoot.cfg_panelFontSize > 0 ? panelTab.configRoot.cfg_panelFontSize : panelTab.defaultFontPointSize(),
            bold: panelTab.configRoot.cfg_panelFontBold
        })
        onAccepted: {
            panelTab.configRoot.cfg_panelFontFamily = font.family;
            panelTab.configRoot.cfg_panelFontSize = Math.max(6, font.pointSize > 0 ? font.pointSize : panelTab.defaultFontPointSize());
            panelTab.configRoot.cfg_panelFontBold = font.bold;
            panelTab.configRoot.cfg_panelUseSystemFont = false;
        }
    }

    Kirigami.Separator {
        Kirigami.FormData.label: i18nc("@title:group", "Panel")
        Kirigami.FormData.isSection: true
    }

    // Whether the panel shows the match in detail or just a compact match count.
    readonly property bool simpleMode: panelMode.currentValue === "simple"

    ComboBox {
        id: panelMode

        Kirigami.FormData.label: i18nc("@label:listbox", "Panel mode:")
        Layout.fillWidth: true
        textRole: "label"
        valueRole: "value"
        model: [{
            "label": i18nc("@item:inlistbox panel mode", "Detailed (show the match)"),
            "value": "detailed"
        }, {
            "label": i18nc("@item:inlistbox panel mode", "Simple (match counts only)"),
            "value": "simple"
        }]
        Component.onCompleted: currentIndex = panelTab.indexFor(model, panelTab.configRoot.cfg_panelMode || "detailed")
        onActivated: panelTab.configRoot.cfg_panelMode = currentValue
    }

    ComboBox {
        id: panelCountsFormat

        Kirigami.FormData.label: i18nc("@label:listbox", "Show:")
        visible: panelTab.simpleMode
        Layout.fillWidth: true
        textRole: "label"
        valueRole: "value"
        model: [{
            "label": i18nc("@item:inlistbox", "Live / remaining (e.g. 3 / 11)"),
            "value": "liveRemaining"
        }, {
            "label": i18nc("@item:inlistbox", "Remaining only (e.g. 11)"),
            "value": "remaining"
        }]
        Component.onCompleted: currentIndex = panelTab.indexFor(model, panelTab.configRoot.cfg_panelCountsFormat || "liveRemaining")
        onActivated: panelTab.configRoot.cfg_panelCountsFormat = currentValue
    }

    ComboBox {
        id: panelSimpleScheduleWindow

        Kirigami.FormData.label: i18nc("@label:listbox", "Count scheduled matches:")
        visible: panelTab.simpleMode
        Layout.fillWidth: true
        textRole: "label"
        valueRole: "value"
        model: [{
            "label": i18nc("@item:inlistbox scheduled matches window", "Next 24 hours"),
            "value": "next24h"
        }, {
            "label": i18nc("@item:inlistbox scheduled matches window", "All future matches"),
            "value": "all"
        }]
        Component.onCompleted: currentIndex = panelTab.indexFor(model, panelTab.configRoot.cfg_panelSimpleScheduleWindow || "next24h")
        onActivated: panelTab.configRoot.cfg_panelSimpleScheduleWindow = currentValue
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: panelTab.simpleMode && panelSimpleScheduleWindow.currentValue === "all"
        showCloseButton: true
        type: Kirigami.MessageType.Information
        text: i18nc("@info", "\"All future matches\" counts every upcoming fixture that is fetched, so the panel number can be higher than the widget list, which shows at most \"Matches per team/competition\" fixtures per competition (Widget → Scheduled).")
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        visible: panelTab.simpleMode
        showCloseButton: true
        type: Kirigami.MessageType.Information
        text: i18nc("@info", "Simple mode shows the sport icon and a match count instead of a match. The layout, rotation and emblem options below do not apply.")
    }

    ComboBox {
        id: panelLayoutMode

        Kirigami.FormData.label: i18nc("@label:listbox", "Panel information:")
        Layout.fillWidth: true
        visible: !panelTab.simpleMode
        textRole: "label"
        valueRole: "value"
        model: [{
            "label": i18nc("@item:inlistbox", "Emblems, teams and score"),
            "value": "teamsAndBadges"
        }, {
            "label": i18nc("@item:inlistbox", "Emblems and score"),
            "value": "badgesOnly"
        }, {
            "label": i18nc("@item:inlistbox", "Teams and score"),
            "value": "teamsOnly"
        }]
        Component.onCompleted: currentIndex = panelTab.indexFor(model, panelTab.configRoot.cfg_panelLayoutMode || "teamsAndBadges")
        onActivated: panelTab.configRoot.cfg_panelLayoutMode = currentValue
    }

    Switch {
        id: panelMatchRotation

        Kirigami.FormData.label: i18nc("@label:checkbox", "Match rotation:")
        text: checked ? i18nc("@option:check", "Enabled") : i18nc("@option:check", "Disabled")
        visible: !panelTab.simpleMode
        checked: panelTab.configRoot.cfg_panelMatchRotationEnabled
        onToggled: panelTab.configRoot.cfg_panelMatchRotationEnabled = checked
    }

    RowLayout {
        Kirigami.FormData.label: i18nc("@label:spinbox", "Rotation interval:")
        visible: !panelTab.simpleMode && panelMatchRotation.checked && panelMultiMatchMode.currentValue !== "stack"
        spacing: Kirigami.Units.smallSpacing

        SpinBox {
            id: panelRotationInterval

            from: 5
            to: 300
            stepSize: 5
            editable: true
            value: Math.max(5, panelTab.configRoot.cfg_panelMatchRotationInterval || 30)
            onValueModified: panelTab.configRoot.cfg_panelMatchRotationInterval = value
        }

        Label {
            text: i18ncp("@label:spinbox", "second", "seconds", panelRotationInterval.value)
        }
    }

    ComboBox {
        id: panelMultiMatchMode

        Kirigami.FormData.label: i18nc("@label:listbox", "Multiple matches:")
        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
        visible: !panelTab.simpleMode
        textRole: "label"
        valueRole: "value"
        model: [
            { "value": "rotate", "label": i18nc("@item:inlistbox panel multi-match mode", "Rotate one at a time") },
            { "value": "stack", "label": i18nc("@item:inlistbox panel multi-match mode", "Show several side by side") }
        ]
        Component.onCompleted: currentIndex = panelTab.indexFor(model, panelTab.configRoot.cfg_panelMultiMatchMode || "rotate")
        onActivated: panelTab.configRoot.cfg_panelMultiMatchMode = currentValue
    }

    RowLayout {
        Kirigami.FormData.label: i18nc("@label:spinbox", "Max matches shown:")
        visible: !panelTab.simpleMode && panelMultiMatchMode.currentValue === "stack"
        spacing: Kirigami.Units.smallSpacing

        SpinBox {
            id: panelStackMax

            from: 2
            to: 8
            editable: true
            value: Math.max(2, panelTab.configRoot.cfg_panelStackMaxMatches || 3)
            onValueModified: panelTab.configRoot.cfg_panelStackMaxMatches = value
        }

        Label {
            text: i18ncp("@label:spinbox", "match", "matches", panelStackMax.value)
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18nc("@label:listbox", "Widget panel area:")
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        ComboBox {
            id: panelAreaMode

            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
            textRole: "label"
            valueRole: "value"
            model: [{
                "label": i18nc("@item:inlistbox", "Auto"),
                "value": "auto"
            }, {
                "label": i18nc("@item:inlistbox", "Fill panel"),
                "value": "fill"
            }, {
                "label": i18nc("@item:inlistbox", "Manual"),
                "value": "manual"
            }]
            Component.onCompleted: currentIndex = panelTab.indexFor(model, panelTab.configRoot.cfg_panelAreaMode || "auto")
            onActivated: panelTab.configRoot.cfg_panelAreaMode = currentValue
        }

        SpinBox {
            visible: panelTab.configRoot.cfg_panelAreaMode === "manual"
            enabled: visible
            from: 20
            to: 1000
            stepSize: 10
            editable: true
            value: Math.max(20, panelTab.configRoot.cfg_panelAreaSize || 240)
            onValueModified: panelTab.configRoot.cfg_panelAreaSize = value
        }

        Label {
            visible: panelTab.configRoot.cfg_panelAreaMode === "manual"
            text: panelTab.configRoot.isVerticalPanel ? i18nc("@label:manual area unit", "px height") : i18nc("@label:manual area unit", "px width")
            opacity: 0.65
        }

        Item {
            Layout.fillWidth: true
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18nc("@label:checkbox", "Panel font:")
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Switch {
            id: manualPanelFont

            text: checked ? i18nc("@option:check", "Manual") : i18nc("@option:check", "Auto")
            checked: !panelTab.configRoot.cfg_panelUseSystemFont
            onToggled: {
                panelTab.configRoot.cfg_panelUseSystemFont = !checked;
                if (checked && panelTab.configRoot.cfg_panelFontFamily.length === 0) {
                    panelTab.configRoot.cfg_panelFontFamily = Kirigami.Theme.defaultFont.family;
                    panelTab.configRoot.cfg_panelFontSize = panelTab.defaultFontPointSize();
                }
            }
        }

        Button {
            text: i18nc("@action:button", "Choose...")
            icon.name: "preferences-desktop-font"
            visible: manualPanelFont.checked
            onClicked: panelFontDialog.open()
        }

        Label {
            Layout.fillWidth: true
            text: manualPanelFont.checked && panelTab.configRoot.cfg_panelFontFamily.length > 0
                ? i18nc("@info:font preview; %1 is point size, %2 is family", "%1 pt %2", panelTab.configRoot.cfg_panelFontSize > 0 ? panelTab.configRoot.cfg_panelFontSize : panelTab.defaultFontPointSize(), panelTab.configRoot.cfg_panelFontFamily)
                : i18nc("@info:font preview", "System font")
            elide: Text.ElideRight
            opacity: 0.75
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18nc("@label:checkbox", "Emblem size:")
        Layout.fillWidth: true
        enabled: !panelTab.simpleMode
        spacing: Kirigami.Units.smallSpacing

        Switch {
            id: manualPanelEmblemSize

            text: checked ? i18nc("@option:check", "Manual") : i18nc("@option:check", "Auto")
            checked: panelTab.configRoot.cfg_panelEmblemSize > 0
            onToggled: {
                if (checked) {
                    if (panelTab.configRoot.cfg_panelEmblemSize <= 0)
                        panelTab.configRoot.cfg_panelEmblemSize = panelTab.defaultPanelEmblemSize();
                } else {
                    panelTab.configRoot.cfg_panelEmblemSize = 0;
                }
            }
        }

        SpinBox {
            id: panelEmblemSize

            visible: manualPanelEmblemSize.checked
            enabled: manualPanelEmblemSize.checked
            from: 8
            to: 64
            stepSize: 2
            editable: true
            value: panelTab.configRoot.cfg_panelEmblemSize > 0 ? panelTab.configRoot.cfg_panelEmblemSize : panelTab.defaultPanelEmblemSize()
            onValueModified: panelTab.configRoot.cfg_panelEmblemSize = value
        }

        Label {
            visible: manualPanelEmblemSize.checked
            text: i18nc("@label:spinbox pixels unit", "px")
            opacity: 0.65
        }

        Item {
            Layout.fillWidth: true
        }
    }
}
