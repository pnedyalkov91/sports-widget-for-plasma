/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
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

    property alias cfg_apiBaseUrl: apiBaseUrl.text
    property alias cfg_apiKey: apiKey.text
    property alias cfg_theSportsDBApiKey: theSportsDBApiKey.text
    property alias cfg_allSportsApiKey: allSportsApiKey.text
    property alias cfg_apiSportsFootballKey: apiSportsFootballKey.text
    property alias cfg_apiSportsBasketballKey: apiSportsBasketballKey.text
    property alias cfg_apiSportsTennisKey: apiSportsTennisKey.text
    property alias cfg_apiSportsCricketKey: apiSportsCricketKey.text
    property alias cfg_apiSportsBaseballKey: apiSportsBaseballKey.text
    property alias cfg_apiSportsHockeyKey: apiSportsHockeyKey.text
    property alias cfg_apiSportsVolleyballKey: apiSportsVolleyballKey.text
    property alias cfg_apiSportsAmericanFootballKey: apiSportsAmericanFootballKey.text
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
    property bool cfg_prioritizePopular: Plasmoid.configuration.prioritizePopular
    property string cfg_providerDefault: "sportscore"
    property string cfg_defaultSportDefault: "football"
    property string cfg_apiBaseUrlDefault: ""
    property string cfg_apiKeyDefault: ""
    property string cfg_theSportsDBApiKeyDefault: ""
    property string cfg_allSportsApiKeyDefault: ""
    property string cfg_apiSportsFootballKeyDefault: ""
    property string cfg_apiSportsBasketballKeyDefault: ""
    property string cfg_apiSportsTennisKeyDefault: ""
    property string cfg_apiSportsCricketKeyDefault: ""
    property string cfg_apiSportsBaseballKeyDefault: ""
    property string cfg_apiSportsHockeyKeyDefault: ""
    property string cfg_apiSportsVolleyballKeyDefault: ""
    property string cfg_apiSportsAmericanFootballKeyDefault: ""
    property string cfg_selectedSportsDefault: ""
    property string cfg_countryDefault: ""
    property string cfg_leagueDefault: ""
    property string cfg_favoriteTeamDefault: ""
    property string cfg_savedLeaguesDefault: "[]"
    property bool cfg_defaultSelectionMigratedDefault: false
    property int cfg_selectionRevisionDefault: 0
    property int cfg_activeSavedLeagueIndexDefault: 0
    property int cfg_refreshIntervalDefault: 15
    property bool cfg_liveRefreshEnabledDefault: true
    property int cfg_liveRefreshIntervalDefault: 30
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
    property bool cfg_prioritizePopularDefault: false

    function indexFor(model, value) {
        for (let index = 0; index < model.length; index += 1) {
            if (model[index].value === value)
                return index;

        }
        return 0;
    }

    function providerNeedsKey(providerId) {
        return ProviderCatalog.requiresApiKey(providerId);
    }

    function providerPlaceholder(providerId) {
        return ProviderCatalog.defaultBaseUrl(providerId);
    }

    function apiKeyPlaceholder(providerId) {
        if (providerId === "thesportsdb-premium")
            return i18nc("@info:placeholder", "TheSportsDB premium API key");
        if (providerId === "allsportsapi")
            return i18nc("@info:placeholder", "AllSportsAPI key");
        if (providerId === "api-sports")
            return i18nc("@info:placeholder", "API-Sports key for this sport");

        return i18nc("@info:placeholder", "Optional API key");
    }

    function providerIs(providerId) {
        return provider.currentValue === providerId;
    }

    function providerUsesSportKeys() {
        return ProviderCatalog.providerUsesSportKeys(provider.currentValue);
    }

    function providerUsesBuiltInKey() {
        return ProviderCatalog.providerUsesBuiltInKey(provider.currentValue);
    }

    Kirigami.FormLayout {
        anchors.fill: parent

        ComboBox {
            id: provider

            Kirigami.FormData.label: i18nc("@label:listbox", "Provider:")
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: ProviderCatalog.providerOptions()
            Component.onCompleted: {
                currentIndex = root.indexFor(model, root.cfg_provider);
                root.cfg_provider = currentValue;
            }
            onActivated: root.cfg_provider = currentValue
        }

        ComboBox {
            id: defaultSport

            Kirigami.FormData.label: i18nc("@label:listbox", "Default sport:")
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: ProviderCatalog.sportOptions(provider.currentValue)
            Component.onCompleted: {
                currentIndex = root.indexFor(model, root.cfg_defaultSport);
                root.cfg_defaultSport = currentValue;
            }
            onActivated: root.cfg_defaultSport = currentValue
        }

        TextField {
            id: apiBaseUrl

            Kirigami.FormData.label: i18nc("@label:textbox", "API base URL:")
            Layout.fillWidth: true
            visible: false
            placeholderText: root.providerPlaceholder(provider.currentValue)
        }

        TextField {
            id: apiKey

            Kirigami.FormData.label: i18nc("@label:textbox", "API key:")
            Layout.fillWidth: true
            visible: false
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder(provider.currentValue)
        }

        Label {
            Kirigami.FormData.label: i18nc("@label", "API key:")
            Layout.fillWidth: true
            visible: root.providerUsesBuiltInKey()
            text: i18nc("@info", "TheSportsDB Free uses the public key 123.")
            wrapMode: Text.WordWrap
        }

        TextField {
            id: theSportsDBApiKey

            Kirigami.FormData.label: i18nc("@label:textbox", "TheSportsDB key:")
            Layout.fillWidth: true
            visible: root.providerIs("thesportsdb-premium")
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder("thesportsdb-premium")
        }

        TextField {
            id: allSportsApiKey

            Kirigami.FormData.label: i18nc("@label:textbox", "AllSportsAPI key:")
            Layout.fillWidth: true
            visible: root.providerIs("allsportsapi")
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder("allsportsapi")
        }

        Label {
            Kirigami.FormData.label: i18nc("@label", "API-Sports keys:")
            Layout.fillWidth: true
            visible: root.providerUsesSportKeys()
            text: i18nc("@info", "API-Sports uses a separate key for each sport API.")
            wrapMode: Text.WordWrap
        }

        TextField {
            id: apiSportsFootballKey

            Kirigami.FormData.label: i18nc("@label:textbox", "Football:")
            Layout.fillWidth: true
            visible: root.providerUsesSportKeys()
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder("api-sports")
        }

        TextField {
            id: apiSportsBasketballKey

            Kirigami.FormData.label: i18nc("@label:textbox", "Basketball:")
            Layout.fillWidth: true
            visible: root.providerUsesSportKeys()
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder("api-sports")
        }

        TextField {
            id: apiSportsTennisKey

            Kirigami.FormData.label: i18nc("@label:textbox", "Tennis:")
            Layout.fillWidth: true
            visible: root.providerUsesSportKeys()
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder("api-sports")
        }

        TextField {
            id: apiSportsCricketKey

            Kirigami.FormData.label: i18nc("@label:textbox", "Cricket:")
            Layout.fillWidth: true
            visible: root.providerUsesSportKeys()
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder("api-sports")
        }

        TextField {
            id: apiSportsBaseballKey

            Kirigami.FormData.label: i18nc("@label:textbox", "Baseball:")
            Layout.fillWidth: true
            visible: root.providerUsesSportKeys()
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder("api-sports")
        }

        TextField {
            id: apiSportsHockeyKey

            Kirigami.FormData.label: i18nc("@label:textbox", "Hockey:")
            Layout.fillWidth: true
            visible: root.providerUsesSportKeys()
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder("api-sports")
        }

        TextField {
            id: apiSportsVolleyballKey

            Kirigami.FormData.label: i18nc("@label:textbox", "Volleyball:")
            Layout.fillWidth: true
            visible: root.providerUsesSportKeys()
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder("api-sports")
        }

        TextField {
            id: apiSportsAmericanFootballKey

            Kirigami.FormData.label: i18nc("@label:textbox", "American Football:")
            Layout.fillWidth: true
            visible: root.providerUsesSportKeys()
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder("api-sports")
        }

        SpinBox {
            id: refreshInterval

            Kirigami.FormData.label: i18nc("@label:spinbox", "Full refresh:")
            from: 1
            to: 1440
            stepSize: 5
            editable: true
            textFromValue: (value) => {
                return i18ncp("@item:valuesuffix minutes", "%1 minute", "%1 minutes", value);
            }
            valueFromText: (text) => {
                return parseInt(text, 10);
            }
        }

        CheckBox {
            id: liveRefreshEnabled

            Kirigami.FormData.label: i18nc("@label:checkbox", "Live matches:")
            text: i18nc("@option:check", "Update separately")
        }

        SpinBox {
            id: liveRefreshInterval

            Kirigami.FormData.label: i18nc("@label:spinbox", "Live refresh:")
            from: 10
            to: 300
            stepSize: 5
            editable: true
            enabled: liveRefreshEnabled.checked
            textFromValue: (value) => {
                return i18ncp("@item:valuesuffix seconds", "%1 second", "%1 seconds", value);
            }
            valueFromText: (text) => {
                return parseInt(text, 10);
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
