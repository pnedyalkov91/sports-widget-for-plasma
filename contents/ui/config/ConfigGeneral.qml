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
    property alias cfg_refreshInterval: refreshInterval.value
    property string cfg_provider: Plasmoid.configuration.provider

    function indexFor(model, value) {
        for (let index = 0; index < model.length; index += 1) {
            if (model[index].value === value)
                return index;

        }
        return 0;
    }

    function providerNeedsKey(providerId) {
        return providerId === "sportdb" || providerId === "thesportsdb" || ProviderCatalog.requiresApiKey(providerId);
    }

    function providerPlaceholder(providerId) {
        if (providerId === "auto")
            return i18nc("@info:placeholder", "Automatic no-key sources");

        if (providerId === "sportsrc")
            return "https://api.sportsrc.org";

        if (providerId === "espn")
            return "https://site.api.espn.com/apis/site/v2/sports";

        if (providerId === "sportdb")
            return "https://api.sportdb.dev";

        if (ProviderCatalog.isProvider(providerId))
            return ProviderCatalog.defaultBaseUrl(providerId);

        return "";
    }

    function apiKeyPlaceholder(providerId) {
        if (providerId === "sportdb")
            return i18nc("@info:placeholder", "SportDB.dev API key");

        if (providerId === "football-data")
            return i18nc("@info:placeholder", "football-data.org X-Auth-Token");

        if (providerId === "balldontlie")
            return i18nc("@info:placeholder", "balldontlie Authorization key");

        if (providerId === "apisports")
            return i18nc("@info:placeholder", "API-SPORTS x-apisports-key");

        if (providerId === "highlightly")
            return i18nc("@info:placeholder", "Highlightly x-rapidapi-key");

        if (providerId === "thesportsdb")
            return i18nc("@info:placeholder", "Optional premium key; empty uses free key 123");

        return i18nc("@info:placeholder", "Optional API key");
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
            Component.onCompleted: currentIndex = root.indexFor(model, root.cfg_provider)
            onActivated: root.cfg_provider = currentValue
        }

        TextField {
            id: apiBaseUrl

            Kirigami.FormData.label: i18nc("@label:textbox", "API base URL:")
            Layout.fillWidth: true
            placeholderText: root.providerPlaceholder(provider.currentValue)
        }

        TextField {
            id: apiKey

            Kirigami.FormData.label: i18nc("@label:textbox", "API key:")
            Layout.fillWidth: true
            visible: root.providerNeedsKey(provider.currentValue)
            echoMode: TextInput.Password
            placeholderText: root.apiKeyPlaceholder(provider.currentValue)
        }

        SpinBox {
            id: refreshInterval

            Kirigami.FormData.label: i18nc("@label:spinbox", "Refresh:")
            from: 30
            to: 900
            stepSize: 15
            editable: true
            textFromValue: (value) => {
                return i18ncp("@item:valuesuffix seconds", "%1 second", "%1 seconds", value);
            }
            valueFromText: (text) => {
                return parseInt(text, 10);
            }
        }

    }

}
