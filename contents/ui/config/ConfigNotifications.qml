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
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import "tabs" as NotificationsTabs

KCM.SimpleKCM {
    id: root

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
    property string cfg_notifyEntryInclusions: Plasmoid.configuration.notifyEntryInclusions
    property string cfg_calendarEntryInclusions: Plasmoid.configuration.calendarEntryInclusions
    property string cfg_perMatchNotify: Plasmoid.configuration.perMatchNotify

    property bool cfg_notificationsEnabledDefault: false
    property bool cfg_notifyKickoffDefault: true
    property bool cfg_notifyGoalsDefault: true
    property bool cfg_notifyHalfTimeDefault: true
    property bool cfg_notifyFullTimeDefault: true
    property bool cfg_notifyDetailedEventsDefault: false
    property bool cfg_notifyStartsSoonDefault: true
    property int cfg_notifyStartsSoonMinutesDefault: 15
    property bool cfg_notifyFavoriteTeamsOnlyDefault: false
    property bool cfg_calendarSyncEnabledDefault: false
    property bool cfg_calendarIcsExportEnabledDefault: false
    property bool cfg_calendarAkonadiEnabledDefault: false
    property string cfg_notifyEntryInclusionsDefault: "[]"
    property string cfg_calendarEntryInclusionsDefault: "[]"
    property string cfg_perMatchNotifyDefault: "{}"

    header: PlasmaComponents.TabBar {
        id: notificationsTabs

        PlasmaComponents.TabButton {
            icon.name: "preferences-desktop-notification"
            text: i18nc("@title:tab", "Notifications")
        }

        PlasmaComponents.TabButton {
            icon.name: "view-calendar"
            text: i18nc("@title:tab", "Calendar")
        }

        PlasmaComponents.TabButton {
            icon.name: "games-config-tiles"
            text: i18nc("@title:tab", "Competitions & teams")
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: notificationsTabs.currentIndex

        NotificationsTabs.NotificationsAlertsTab {
            configRoot: root
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        NotificationsTabs.NotificationsCalendarTab {
            configRoot: root
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        NotificationsTabs.NotificationsCompetitionsTab {
            configRoot: root
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
