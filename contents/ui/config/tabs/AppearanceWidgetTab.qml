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
    id: widgetTab

    required property var configRoot

    function indexFor(model, value) {
        for (let index = 0; index < model.length; index += 1) {
            if (model[index].value === value)
                return index;

        }
        return 0;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.TabBar {
            id: widgetSubTabs

            Layout.fillWidth: true

            PlasmaComponents.TabButton {
                text: i18nc("@title:tab", "General")
            }

            PlasmaComponents.TabButton {
                text: i18nc("@title:tab", "Live")
            }

            PlasmaComponents.TabButton {
                text: i18nc("@title:tab", "Scheduled")
            }

            PlasmaComponents.TabButton {
                text: i18nc("@title:tab", "Recent")
            }

            PlasmaComponents.TabButton {
                text: i18nc("@title:tab", "Tables")
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: widgetSubTabs.currentIndex

            // ── General ──────────────────────────────────────────────────────
            Kirigami.FormLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

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
                        "label": i18nc("@item:inlistbox", "Live + Schedules + Recent Results"),
                        "value": "liveStats"
                    }, {
                        "label": i18nc("@item:inlistbox", "Live + Schedules + Tables"),
                        "value": "liveTables"
                    }, {
                        "label": i18nc("@item:inlistbox", "Live + Schedules"),
                        "value": "liveOnly"
                    }]
                    Component.onCompleted: currentIndex = widgetTab.indexFor(model, widgetTab.configRoot.cfg_widgetTabs || "all")
                    onActivated: widgetTab.configRoot.cfg_widgetTabs = currentValue
                }

                Switch {
                    id: widgetMatchRotation

                    Kirigami.FormData.label: i18nc("@label:checkbox", "Match rotation:")
                    text: checked ? i18nc("@option:check", "Enabled") : i18nc("@option:check", "Disabled")
                    checked: widgetTab.configRoot.cfg_widgetMatchRotationEnabled
                    onToggled: widgetTab.configRoot.cfg_widgetMatchRotationEnabled = checked
                }

                RowLayout {
                    Kirigami.FormData.label: i18nc("@label:spinbox", "Rotation interval:")
                    visible: widgetMatchRotation.checked
                    spacing: Kirigami.Units.smallSpacing

                    SpinBox {
                        id: widgetRotationInterval

                        from: 5
                        to: 300
                        stepSize: 5
                        editable: true
                        value: Math.max(5, widgetTab.configRoot.cfg_widgetMatchRotationInterval || 30)
                        onValueModified: widgetTab.configRoot.cfg_widgetMatchRotationInterval = value
                    }

                    PlasmaComponents.Label {
                        text: i18ncp("@label:spinbox", "second", "seconds", widgetRotationInterval.value)
                    }
                }
            }

            // ── Live ─────────────────────────────────────────────────────────
            Kirigami.FormLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                PlasmaComponents.Label {
                    Kirigami.FormData.isSection: true
                    text: i18nc("@info:placeholder", "No options yet.")
                    opacity: 0.7
                }
            }

            // ── Scheduled ────────────────────────────────────────────────────
            Kirigami.FormLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    Kirigami.FormData.label: i18nc("@label:spinbox", "Schedules days ahead:")
                    spacing: Kirigami.Units.smallSpacing

                    SpinBox {
                        id: scheduleDaysAhead

                        from: 1
                        to: 365
                        stepSize: 5
                        editable: true
                        value: Math.min(365, Math.max(1, widgetTab.configRoot.cfg_widgetScheduleDaysAhead || 150))
                        onValueModified: widgetTab.configRoot.cfg_widgetScheduleDaysAhead = value
                    }

                    PlasmaComponents.Label {
                        text: i18ncp("@label:spinbox", "day", "days", scheduleDaysAhead.value)
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18nc("@label:spinbox", "Matches per team/competition:")
                    spacing: Kirigami.Units.smallSpacing

                    SpinBox {
                        id: scheduleMatchesPerGroup

                        from: 1
                        to: 30
                        stepSize: 1
                        editable: true
                        value: Math.min(30, Math.max(1, widgetTab.configRoot.cfg_widgetScheduleMatchesPerGroup || 5))
                        onValueModified: widgetTab.configRoot.cfg_widgetScheduleMatchesPerGroup = value
                    }

                    PlasmaComponents.Label {
                        text: i18ncp("@label:spinbox", "match", "matches", scheduleMatchesPerGroup.value)
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: i18nc("@info", "How far ahead to look for fixtures, and how many upcoming matches to show under each team or competition group.")
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                }
            }

            // ── Recent ───────────────────────────────────────────────────────
            Kirigami.FormLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ComboBox {
                    id: recentFilter

                    Kirigami.FormData.label: i18nc("@label:listbox", "Show:")
                    Layout.fillWidth: true
                    textRole: "label"
                    valueRole: "value"
                    model: [{
                        "label": i18nc("@item:inlistbox", "Teams and competitions"),
                        "value": "both"
                    }, {
                        "label": i18nc("@item:inlistbox", "Teams only"),
                        "value": "teams"
                    }, {
                        "label": i18nc("@item:inlistbox", "Competitions only"),
                        "value": "competitions"
                    }]
                    Component.onCompleted: currentIndex = widgetTab.indexFor(model, widgetTab.configRoot.cfg_widgetRecentFilter || "both")
                    onActivated: widgetTab.configRoot.cfg_widgetRecentFilter = currentValue
                }

                RowLayout {
                    Kirigami.FormData.label: i18nc("@label:spinbox", "Matches per team/competition:")
                    spacing: Kirigami.Units.smallSpacing

                    SpinBox {
                        id: recentMatchesPerGroup

                        from: 1
                        to: 30
                        stepSize: 1
                        editable: true
                        value: Math.min(30, Math.max(1, widgetTab.configRoot.cfg_widgetRecentMatchesPerGroup || 5))
                        onValueModified: widgetTab.configRoot.cfg_widgetRecentMatchesPerGroup = value
                    }

                    PlasmaComponents.Label {
                        text: i18ncp("@label:spinbox", "match", "matches", recentMatchesPerGroup.value)
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: i18nc("@info", "How many recent matches to show under each team or competition group.")
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                }
            }

            // ── Tables ───────────────────────────────────────────────────────
            Kirigami.FormLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                PlasmaComponents.Label {
                    Kirigami.FormData.isSection: true
                    text: i18nc("@info:placeholder", "No options yet.")
                    opacity: 0.7
                }
            }
        }
    }
}
