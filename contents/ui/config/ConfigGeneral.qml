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

import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: root

    property alias cfg_smartRefreshEnabled: smartRefreshEnabled.checked
    property alias cfg_refreshInterval: refreshInterval.value
    property alias cfg_liveRefreshEnabled: liveRefreshEnabled.checked
    property alias cfg_liveRefreshInterval: liveRefreshInterval.value
    property string cfg_nationalTeamVisualStyle: Plasmoid.configuration.nationalTeamVisualStyle
    property string cfg_provider: Plasmoid.configuration.provider
    property string cfg_defaultSport: Plasmoid.configuration.defaultSport
    // Keep all cfg_* keys available on every KCM page to avoid
    // "Setting initial properties failed" warnings from KConfigDialogManager.
    property string cfg_selectedSports: Plasmoid.configuration.selectedSports
    property string cfg_country: Plasmoid.configuration.country
    property string cfg_league: Plasmoid.configuration.league
    property string cfg_favoriteTeam: Plasmoid.configuration.favoriteTeam
    property string cfg_savedLeagues: Plasmoid.configuration.savedLeagues
    property bool cfg_defaultSelectionMigrated: Plasmoid.configuration.defaultSelectionMigrated
    property int cfg_selectionRevision: Plasmoid.configuration.selectionRevision
    property int cfg_activeSavedLeagueIndex: Plasmoid.configuration.activeSavedLeagueIndex
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
    property string cfg_widgetLayoutMode: Plasmoid.configuration.widgetLayoutMode
    property bool cfg_prioritizePopular: Plasmoid.configuration.prioritizePopular
    property string cfg_providerDefault: "sportscore"
    property string cfg_defaultSportDefault: "football"
    property string cfg_selectedSportsDefault: ""
    property string cfg_countryDefault: ""
    property string cfg_leagueDefault: ""
    property string cfg_favoriteTeamDefault: ""
    property string cfg_savedLeaguesDefault: "[]"
    property bool cfg_defaultSelectionMigratedDefault: false
    property int cfg_selectionRevisionDefault: 0
    property int cfg_activeSavedLeagueIndexDefault: 0
    property bool cfg_smartRefreshEnabledDefault: true
    property int cfg_refreshIntervalDefault: 30
    property bool cfg_liveRefreshEnabledDefault: true
    property int cfg_liveRefreshIntervalDefault: 60
    property string cfg_nationalTeamVisualStyleDefault: "emblems"
    property string cfg_panelLayoutModeDefault: "teamsAndBadges"
    property string cfg_panelAreaModeDefault: "auto"
    property int cfg_panelAreaSizeDefault: 240
    property bool cfg_panelUseSystemFontDefault: true
    property string cfg_panelFontFamilyDefault: ""
    property int cfg_panelFontSizeDefault: 0
    property bool cfg_panelFontBoldDefault: false
    property int cfg_panelEmblemSizeDefault: 0
    property bool cfg_panelMatchRotationEnabledDefault: true
    property int cfg_panelMatchRotationIntervalDefault: 30
    property bool cfg_widgetMatchRotationEnabledDefault: true
    property int cfg_widgetMatchRotationIntervalDefault: 30
    property string cfg_matchDateFormatDefault: "dd.MM"
    property string cfg_matchTimeFormatDefault: "HH:mm"
    property string cfg_widgetTabsDefault: "all"
    property string cfg_widgetLayoutModeDefault: "detailed"
    property bool cfg_prioritizePopularDefault: false

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
            id: layoutMode

            Kirigami.FormData.label: i18nc("@label:listbox", "Layout:")
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: [
                { "value": "detailed", "label": i18nc("@item:inlistbox widget layout", "Detailed") },
                { "value": "simple", "label": i18nc("@item:inlistbox widget layout", "Simple") }
            ]
            Component.onCompleted: currentIndex = root.indexFor(model, root.cfg_widgetLayoutMode)
            onActivated: root.cfg_widgetLayoutMode = currentValue
        }

        Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18nc("@info", "Detailed shows a featured match, tabs, standings and recent results. Simple shows only live and scheduled matches in a single scrolling list.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ComboBox {
            id: defaultSport

            Kirigami.FormData.label: i18nc("@label:listbox", "Default sport:")
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: ProviderCatalog.sportOptions("")
            Component.onCompleted: {
                currentIndex = root.indexFor(model, root.cfg_defaultSport);
                root.cfg_defaultSport = currentValue;
            }
            onActivated: root.cfg_defaultSport = currentValue
        }

        Switch {
            id: smartRefreshEnabled

            Kirigami.FormData.label: i18nc("@label:chooser", "Refresh:")
            text: i18nc("@option:check", "Smart")
            checked: true
        }

        Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18nc("@info", "Automatically checks for upcoming matches every 30 minutes, and live scores every 60 seconds while a match is in progress, to limit network requests. Turn off to set your own refresh times.")
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label:spinbox", "Full refresh:")
            spacing: Kirigami.Units.smallSpacing

            SpinBox {
                id: refreshInterval

                from: 1
                to: 1440
                stepSize: 5
                editable: true
                enabled: !smartRefreshEnabled.checked
            }

            Label {
                text: i18ncp("@label:spinbox", "minute", "minutes", refreshInterval.value)
            }
        }

        CheckBox {
            id: liveRefreshEnabled

            Kirigami.FormData.label: i18nc("@label:checkbox", "Live matches:")
            text: i18nc("@option:check", "Update separately")
            enabled: !smartRefreshEnabled.checked
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("@label:spinbox", "Live refresh:")
            spacing: Kirigami.Units.smallSpacing

            SpinBox {
                id: liveRefreshInterval

                from: 10
                to: 300
                stepSize: 5
                editable: true
                enabled: !smartRefreshEnabled.checked && liveRefreshEnabled.checked
            }

            Label {
                text: i18ncp("@label:spinbox", "second", "seconds", liveRefreshInterval.value)
            }
        }

        Switch {
            id: nationalTeamFlags

            Kirigami.FormData.label: i18nc("@label:chooser", "National teams:")
            text: checked ? i18nc("@option:check", "Flags") : i18nc("@option:check", "Emblems")
            checked: root.cfg_nationalTeamVisualStyle === "flags"
            onToggled: root.cfg_nationalTeamVisualStyle = checked ? "flags" : "emblems"
        }

    }

}
