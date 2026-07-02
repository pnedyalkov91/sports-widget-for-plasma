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

Kirigami.FormLayout {
    id: miscTab

    required property var configRoot

    function indexFor(model, value) {
        for (let index = 0; index < model.length; index += 1) {
            if (model[index].value === value)
                return index;
        }

        return model.length - 1;
    }

    function isPresetValue(model, value) {
        for (let index = 0; index < model.length - 1; index += 1) {
            if (model[index].value === value)
                return true;
        }

        return false;
    }

    function formatPreviewDate(date) {
        const format = String(miscTab.configRoot.cfg_matchDateFormat || "dd.MM").trim();
        if (format === "locale-long")
            return date.toLocaleDateString(Qt.locale(), Locale.LongFormat);
        if (format === "locale-short")
            return date.toLocaleDateString(Qt.locale(), Locale.ShortFormat);
        if (format.length === 0)
            return "";

        return Qt.formatDate(date, format);
    }

    function formatPreviewTime(date) {
        const format = String(miscTab.configRoot.cfg_matchTimeFormat || "HH:mm").trim();
        if (format === "locale")
            return date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
        if (format.length === 0)
            return "";

        return Qt.formatTime(date, format);
    }

    Kirigami.Separator {
        Kirigami.FormData.label: i18nc("@title:group", "Date and Time")
        Kirigami.FormData.isSection: true
    }

    RowLayout {
        Kirigami.FormData.label: i18nc("@label:listbox", "Date format:")
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        ComboBox {
            id: matchDateFormatCombo

            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            textRole: "label"
            valueRole: "value"
            readonly property var presets: [{
                "label": i18nc("@item:inlistbox", "22.05"),
                "value": "dd.MM"
            }, {
                "label": i18nc("@item:inlistbox", "22.05.26"),
                "value": "dd.MM.yy"
            }, {
                "label": i18nc("@item:inlistbox", "22.05.2026"),
                "value": "dd.MM.yyyy"
            }, {
                "label": i18nc("@item:inlistbox", "2026-05-22"),
                "value": "yyyy-MM-dd"
            }, {
                "label": i18nc("@item:inlistbox", "22 May"),
                "value": "d MMM"
            }, {
                "label": i18nc("@item:inlistbox", "Region default (short)"),
                "value": "locale-short"
            }, {
                "label": i18nc("@item:inlistbox", "Region default (long)"),
                "value": "locale-long"
            }, {
                "label": i18nc("@item:inlistbox", "Custom..."),
                "value": "__custom__"
            }]
            model: presets
            Component.onCompleted: currentIndex = miscTab.indexFor(presets, miscTab.configRoot.cfg_matchDateFormat || "dd.MM")
            onActivated: {
                if (currentValue !== "__custom__")
                    miscTab.configRoot.cfg_matchDateFormat = currentValue;
            }
        }

        TextField {
            visible: matchDateFormatCombo.currentValue === "__custom__"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
            placeholderText: "dd.MM"
            text: miscTab.isPresetValue(matchDateFormatCombo.presets, miscTab.configRoot.cfg_matchDateFormat || "dd.MM") ? "" : miscTab.configRoot.cfg_matchDateFormat
            selectByMouse: true
            onEditingFinished: {
                const value = text.trim();
                if (value.length > 0)
                    miscTab.configRoot.cfg_matchDateFormat = value;
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18nc("@label:listbox", "Time format:")
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        ComboBox {
            id: matchTimeFormatCombo

            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            textRole: "label"
            valueRole: "value"
            readonly property var presets: [{
                "label": i18nc("@item:inlistbox", "20:30"),
                "value": "HH:mm"
            }, {
                "label": i18nc("@item:inlistbox", "20:30:05"),
                "value": "HH:mm:ss"
            }, {
                "label": i18nc("@item:inlistbox", "8:30 PM"),
                "value": "h:mm AP"
            }, {
                "label": i18nc("@item:inlistbox", "8:30:05 PM"),
                "value": "h:mm:ss AP"
            }, {
                "label": i18nc("@item:inlistbox", "Region default"),
                "value": "locale"
            }, {
                "label": i18nc("@item:inlistbox", "Custom..."),
                "value": "__custom__"
            }]
            model: presets
            Component.onCompleted: currentIndex = miscTab.indexFor(presets, miscTab.configRoot.cfg_matchTimeFormat || "HH:mm")
            onActivated: {
                if (currentValue !== "__custom__")
                    miscTab.configRoot.cfg_matchTimeFormat = currentValue;
            }
        }

        TextField {
            visible: matchTimeFormatCombo.currentValue === "__custom__"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
            placeholderText: "HH:mm"
            text: miscTab.isPresetValue(matchTimeFormatCombo.presets, miscTab.configRoot.cfg_matchTimeFormat || "HH:mm") ? "" : miscTab.configRoot.cfg_matchTimeFormat
            selectByMouse: true
            onEditingFinished: {
                const value = text.trim();
                if (value.length > 0)
                    miscTab.configRoot.cfg_matchTimeFormat = value;
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    Label {
        Kirigami.FormData.label: i18nc("@label", "Preview:")
        Layout.fillWidth: true
        opacity: 0.75
        text: {
            const now = new Date();
            const dateText = miscTab.formatPreviewDate(now);
            const timeText = miscTab.formatPreviewTime(now);
            return [dateText, timeText].filter(part => part.length > 0).join(" ");
        }
        wrapMode: Text.WordWrap
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.preferredWidth: Kirigami.Units.gridUnit * 25
        Kirigami.FormData.label: ""
        showCloseButton: true
        type: Kirigami.MessageType.Information
        text: i18nc("@info", "These formats are used for match dates and update times in the panel and widget. Custom values use Qt date/time patterns.")
    }
}
