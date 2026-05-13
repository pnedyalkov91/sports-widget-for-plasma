/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "settings-configure"
        source: "config/ConfigGeneral.qml"
    }

    ConfigCategory {
        name: i18n("Sport")
        icon: "applications-games"
        source: "config/ConfigSport.qml"
    }

    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-theme"
        source: "config/ConfigAppearance.qml"
    }

}
