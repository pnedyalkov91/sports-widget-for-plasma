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
import org.kde.kcmutils as KCM
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import "tabs" as AppearanceTabs

KCM.SimpleKCM {
    id: root

    property string cfg_panelLayoutMode: Plasmoid.configuration.panelLayoutMode
    property string cfg_panelAreaMode: Plasmoid.configuration.panelAreaMode
    property int cfg_panelAreaSize: Plasmoid.configuration.panelAreaSize
    property bool cfg_panelUseSystemFont: Plasmoid.configuration.panelUseSystemFont
    property string cfg_panelFontFamily: Plasmoid.configuration.panelFontFamily
    property int cfg_panelFontSize: Plasmoid.configuration.panelFontSize
    property bool cfg_panelFontBold: Plasmoid.configuration.panelFontBold
    property int cfg_panelEmblemSize: Plasmoid.configuration.panelEmblemSize
    property bool cfg_panelMatchRotationEnabled: Plasmoid.configuration.panelMatchRotationEnabled
    property int cfg_panelMatchRotationInterval: Plasmoid.configuration.panelMatchRotationInterval
    property bool cfg_widgetMatchRotationEnabled: Plasmoid.configuration.widgetMatchRotationEnabled
    property int cfg_widgetMatchRotationInterval: Plasmoid.configuration.widgetMatchRotationInterval
    property string cfg_matchDateFormat: Plasmoid.configuration.matchDateFormat
    property string cfg_matchTimeFormat: Plasmoid.configuration.matchTimeFormat
    property string cfg_widgetTabs: Plasmoid.configuration.widgetTabs
    property int cfg_widgetRecentMatchesPerGroup: Plasmoid.configuration.widgetRecentMatchesPerGroup
    property string cfg_widgetRecentFilter: Plasmoid.configuration.widgetRecentFilter
    property int cfg_widgetScheduleDaysAhead: Plasmoid.configuration.widgetScheduleDaysAhead
    property int cfg_widgetScheduleMatchesPerGroup: Plasmoid.configuration.widgetScheduleMatchesPerGroup
    property string cfg_widgetLayoutMode: Plasmoid.configuration.widgetLayoutMode
    property string cfg_nationalTeamVisualStyle: Plasmoid.configuration.nationalTeamVisualStyle
    property string cfg_provider: Plasmoid.configuration.provider
    property bool cfg_notificationsEnabled: Plasmoid.configuration.notificationsEnabled
    property bool cfg_notifyKickoff: Plasmoid.configuration.notifyKickoff
    property bool cfg_notifyGoals: Plasmoid.configuration.notifyGoals
    property bool cfg_notifyHalfTime: Plasmoid.configuration.notifyHalfTime
    property bool cfg_notifyFullTime: Plasmoid.configuration.notifyFullTime
    property bool cfg_notifyDetailedEvents: Plasmoid.configuration.notifyDetailedEvents
    property bool cfg_notifyStartsSoon: Plasmoid.configuration.notifyStartsSoon
    property int cfg_notifyStartsSoonMinutes: Plasmoid.configuration.notifyStartsSoonMinutes
    property bool cfg_notifyFavoriteTeamsOnly: Plasmoid.configuration.notifyFavoriteTeamsOnly
    property bool cfg_calendarSyncEnabled: Plasmoid.configuration.calendarSyncEnabled
    property bool cfg_calendarIcsExportEnabled: Plasmoid.configuration.calendarIcsExportEnabled
    property bool cfg_calendarAkonadiEnabled: Plasmoid.configuration.calendarAkonadiEnabled
    property int cfg_calendarReminderMinutes: Plasmoid.configuration.calendarReminderMinutes
    property string cfg_notifyEntryExclusions: Plasmoid.configuration.notifyEntryExclusions
    property string cfg_calendarEntryExclusions: Plasmoid.configuration.calendarEntryExclusions
    readonly property bool isVerticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    header: PlasmaComponents.TabBar {
        id: appearanceTabs

        PlasmaComponents.TabButton {
            icon.name: "view-list-details"
            text: i18nc("@title:tab", "Panel")
        }

        PlasmaComponents.TabButton {
            icon.name: "plasma-symbolic"
            text: i18nc("@title:tab", "Widget")
        }

        PlasmaComponents.TabButton {
            icon.name: "preferences-desktop-feedback"
            text: i18nc("@title:tab", "Tooltip")
        }

        PlasmaComponents.TabButton {
            icon.name: "preferences-desktop"
            text: i18nc("@title:tab", "Misc")
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: appearanceTabs.currentIndex

        AppearanceTabs.AppearancePanelTab {
            configRoot: root
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        AppearanceTabs.AppearanceWidgetTab {
            configRoot: root
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        AppearanceTabs.AppearanceTooltipTab {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        AppearanceTabs.AppearanceMiscTab {
            configRoot: root
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
