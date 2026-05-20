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
    property alias cfg_liveRefreshEnabled: liveRefreshEnabled.checked
    property alias cfg_liveRefreshInterval: liveRefreshInterval.value
    property string cfg_provider: Plasmoid.configuration.provider

    function indexFor(model, value) {
        for (let index = 0; index < model.length; index += 1) {
            if (model[index].value === value)
                return index;

        }
        return 0;
    }

    function providerNeedsKey(providerId) {
        return false;
    }

    function providerPlaceholder(providerId) {
        return ProviderCatalog.defaultBaseUrl("sportscore");
    }

    function apiKeyPlaceholder(providerId) {
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
            Component.onCompleted: {
                currentIndex = root.indexFor(model, root.cfg_provider);
                root.cfg_provider = currentValue;
            }
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

    }

}
