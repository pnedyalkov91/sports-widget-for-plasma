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

import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Sport")
        icon: "applications-games"
        source: "config/ConfigSport.qml"
    }

    ConfigCategory {
        name: i18n("General")
        icon: "settings-configure"
        source: "config/ConfigGeneral.qml"
    }

    ConfigCategory {
        name: i18n("Notifications")
        icon: "preferences-desktop-notification"
        source: "config/ConfigNotifications.qml"
    }

    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "config/ConfigAppearance.qml"
    }

}
