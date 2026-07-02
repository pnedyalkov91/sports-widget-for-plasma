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
    readonly property bool simpleLayout: configRoot && configRoot.cfg_widgetLayoutMode === "simple"

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

                // Detailed = tabbed layout; Simple = one scrolling list of live +
                // scheduled matches. In Simple mode the per-tab switches don't
                // apply, so they are shown read-only.
                ComboBox {
                    id: layoutMode

                    Kirigami.FormData.label: i18nc("@label:listbox", "Layout:")
                    Layout.fillWidth: true
                    textRole: "label"
                    valueRole: "value"
                    model: [
                        { "value": "detailed", "label": i18nc("@item:inlistbox widget layout", "Detailed") },
                        { "value": "simple", "label": i18nc("@item:inlistbox widget layout", "Simple") }
                    ]
                    Component.onCompleted: currentIndex = widgetTab.indexFor(model, widgetTab.configRoot.cfg_widgetLayoutMode || "detailed")
                    onActivated: widgetTab.configRoot.cfg_widgetLayoutMode = currentValue
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 25
                    visible: true
                    showCloseButton: true
                    type: Kirigami.MessageType.Information
                    text: i18nc("@info", "Detailed shows a featured match, tabs, standings and recent results. Simple shows only live and scheduled matches in a single scrolling list.")
                }

                ComboBox {
                    id: simpleScheduleWindow

                    Kirigami.FormData.label: i18nc("@label:listbox", "Scheduled matches:")
                    Layout.fillWidth: true
                    visible: widgetTab.simpleLayout
                    textRole: "label"
                    valueRole: "value"
                    model: [
                        { "value": "all", "label": i18nc("@item:inlistbox scheduled matches window", "All future matches") },
                        { "value": "next24h", "label": i18nc("@item:inlistbox scheduled matches window", "Next 24 hours") }
                    ]
                    Component.onCompleted: currentIndex = widgetTab.indexFor(model, widgetTab.configRoot.cfg_widgetSimpleScheduleWindow || "all")
                    onActivated: widgetTab.configRoot.cfg_widgetSimpleScheduleWindow = currentValue
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 25
                    visible: widgetTab.simpleLayout && simpleScheduleWindow.currentValue === "all"
                    showCloseButton: true
                    type: Kirigami.MessageType.Information
                    text: i18nc("@info", "\"All future matches\" is still limited by the Scheduled tab options: at most \"Matches per team/competition\" fixtures are listed per competition, within \"Schedules days ahead\". Raise those to list more.")
                }

                Switch {
                    Kirigami.FormData.label: i18nc("@label:checkbox", "Featured match:")
                    text: checked ? i18nc("@option:check", "Shown") : i18nc("@option:check", "Hidden")
                    visible: !widgetTab.simpleLayout
                    checked: widgetTab.configRoot.cfg_widgetHeroEnabled
                    onToggled: widgetTab.configRoot.cfg_widgetHeroEnabled = checked
                }

                ComboBox {
                    id: tabsPosition

                    Kirigami.FormData.label: i18nc("@label:listbox", "Tabs position:")
                    Layout.fillWidth: true
                    visible: !widgetTab.simpleLayout
                    textRole: "label"
                    valueRole: "value"
                    model: [
                        { "value": "top", "label": i18nc("@item:inlistbox tabs position", "Top") },
                        { "value": "bottom", "label": i18nc("@item:inlistbox tabs position", "Bottom") }
                    ]
                    Component.onCompleted: currentIndex = widgetTab.indexFor(model, widgetTab.configRoot.cfg_widgetTabsPosition || "top")
                    onActivated: widgetTab.configRoot.cfg_widgetTabsPosition = currentValue
                }

                Item {
                    Kirigami.FormData.isSection: true
                    visible: !widgetTab.simpleLayout
                }

                Kirigami.Separator {
                    Kirigami.FormData.label: i18nc("@title:group", "Visible tabs")
                    Kirigami.FormData.isSection: true
                    visible: !widgetTab.simpleLayout
                }

                Switch {
                    Kirigami.FormData.label: i18nc("@label:checkbox", "Live:")
                    text: checked ? i18nc("@option:check", "Shown") : i18nc("@option:check", "Hidden")
                    visible: !widgetTab.simpleLayout
                    checked: widgetTab.configRoot.cfg_showTabLive
                    onToggled: widgetTab.configRoot.cfg_showTabLive = checked
                }

                Switch {
                    Kirigami.FormData.label: i18nc("@label:checkbox", "Schedules:")
                    text: checked ? i18nc("@option:check", "Shown") : i18nc("@option:check", "Hidden")
                    visible: !widgetTab.simpleLayout
                    checked: widgetTab.configRoot.cfg_showTabSchedules
                    onToggled: widgetTab.configRoot.cfg_showTabSchedules = checked
                }

                Switch {
                    Kirigami.FormData.label: i18nc("@label:checkbox", "Recent Results:")
                    text: checked ? i18nc("@option:check", "Shown") : i18nc("@option:check", "Hidden")
                    visible: !widgetTab.simpleLayout
                    checked: widgetTab.configRoot.cfg_showTabRecent
                    onToggled: widgetTab.configRoot.cfg_showTabRecent = checked
                }

                Switch {
                    Kirigami.FormData.label: i18nc("@label:checkbox", "Tables:")
                    text: checked ? i18nc("@option:check", "Shown") : i18nc("@option:check", "Hidden")
                    visible: !widgetTab.simpleLayout
                    checked: widgetTab.configRoot.cfg_showTabTables
                    onToggled: widgetTab.configRoot.cfg_showTabTables = checked
                }

                Item {
                    Kirigami.FormData.isSection: true
                    visible: !widgetTab.simpleLayout
                }

                Switch {
                    Kirigami.FormData.label: i18nc("@label:checkbox", "Match quick actions:")
                    text: checked ? i18nc("@option:check", "Shown") : i18nc("@option:check", "Hidden")
                    visible: !widgetTab.simpleLayout
                    checked: widgetTab.configRoot.cfg_showMatchRowActions
                    onToggled: widgetTab.configRoot.cfg_showMatchRowActions = checked
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 25
                    visible: !widgetTab.simpleLayout
                    showCloseButton: true
                    type: Kirigami.MessageType.Information
                    text: i18nc("@info", "Show one-click star, bell and pin icons on each match row to favourite a team, get notifications for that match, or pin it to the panel.")
                }

                Switch {
                    id: widgetMatchRotation

                    Kirigami.FormData.label: i18nc("@label:checkbox", "Match rotation:")
                    text: checked ? i18nc("@option:check", "Enabled") : i18nc("@option:check", "Disabled")
                    visible: !widgetTab.simpleLayout
                    checked: widgetTab.configRoot.cfg_widgetMatchRotationEnabled
                    onToggled: widgetTab.configRoot.cfg_widgetMatchRotationEnabled = checked
                }

                RowLayout {
                    Kirigami.FormData.label: i18nc("@label:spinbox", "Rotation interval:")
                    visible: !widgetTab.simpleLayout && widgetMatchRotation.checked
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

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 25
                    visible: true
                    showCloseButton: true
                    type: Kirigami.MessageType.Information
                    text: i18nc("@info", "How far ahead to look for fixtures, and how many upcoming matches to show under each team or competition group.")
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

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 25
                    visible: true
                    showCloseButton: true
                    type: Kirigami.MessageType.Information
                    text: i18nc("@info", "How many recent matches to show under each team or competition group.")
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
