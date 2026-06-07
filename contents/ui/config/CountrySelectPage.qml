/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../code/SportsApi.js" as SportsApi
import "../../code/providers/ProviderCatalog.js" as ProviderCatalog

SportStepPage {
    id: root

    property var configRoot
    property string countryFilter: ""
    property bool loadingCountries: false
    property string countryLoadError: ""
    property int countryRequestToken: 0
    readonly property bool pageActive: root.configRoot && root.configRoot.pageIndex === 1
    readonly property bool tennisMode: root.configRoot && root.configRoot.normalizedSport() === "tennis"
    readonly property var displayedOptions: root.pageActive && root.configRoot && !root.loadingCountries ? root.configRoot.filtered(root.configRoot.countryOptions(), root.countryFilter) : []

    title: i18nc("@title:group", "Country")
    subtitle: root.tennisMode
        ? i18nc("@info", "SportScore lists tennis competitions and players internationally.")
        : i18nc("@info", "Only one country can be active for the selected sport.")
    filterText: root.countryFilter
    filterPlaceholder: i18nc("@info:placeholder", "Search countries")
    onFilterEdited: text => root.countryFilter = text

    onPageActiveChanged: {
        if (root.pageActive)
            root.loadCountries();
    }

    Connections {
        target: root.configRoot

        function onCfg_selectedSportsChanged() {
            if (root.pageActive)
                root.loadCountries();
        }
    }

    function staticCountryOption(value) {
        const options = ProviderCatalog.countryOptions(root.configRoot ? root.configRoot.currentProvider : "", root.configRoot ? root.configRoot.normalizedSport() : "");
        for (let index = 0; index < options.length; index += 1) {
            if (String(options[index] && options[index].value || "") === String(value || ""))
                return options[index] || {};
        }
        return {};
    }

    function loadCountries() {
        if (!root.configRoot || !root.pageActive)
            return;

        const sport = String(root.configRoot.normalizedSport() || "").trim();
        if (sport.length === 0)
            return;
        if (root.configRoot.cfg_providerCountrySport === sport && Array.isArray(root.configRoot.cfg_providerCountryOptions) && root.configRoot.cfg_providerCountryOptions.length > 0)
            return;

        const token = root.countryRequestToken + 1;
        root.countryRequestToken = token;
        root.loadingCountries = true;
        root.countryLoadError = "";
        root.configRoot.cfg_providerCountrySport = "";
        root.configRoot.cfg_providerCountryOptions = [];
        SportsApi.fetchSportCountries({
            "provider": root.configRoot.currentProvider,
            "sports": sport
        }, rows => {
            if (token !== root.countryRequestToken)
                return;

            root.loadingCountries = false;
            let options = (Array.isArray(rows) ? rows : []).map(row => {
                const value = String(row && row.value || "").trim();
                const fallback = root.staticCountryOption(value);
                return {
                    label: String(row && row.label || fallback.label || ProviderCatalog.leagueLabel(value)).trim(),
                    value,
                    icon: String(row && row.icon || fallback.icon || "").trim(),
                    infoText: String(row && row.infoText || "").trim()
                };
            }).filter(row => row.value.length > 0);
            if (root.configRoot.cfg_type === "team" && sport !== "tennis")
                options = options.filter(option => option.value !== "world");
            root.configRoot.cfg_providerCountrySport = sport;
            root.configRoot.cfg_providerCountryOptions = options;
            if (options.length === 0)
                root.countryLoadError = i18nc("@info", "No countries were found for this sport.");
        }, message => {
            if (token !== root.countryRequestToken)
                return;

            root.loadingCountries = false;
            root.countryLoadError = String(message || i18nc("@info", "Unable to load countries from provider.")).trim();
        });
    }

    Item {
        Layout.columnSpan: Math.max(1, root.contentColumns)
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 8, root.height * 0.42)
        visible: root.loadingCountries

        RowLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            BusyIndicator {
                running: root.loadingCountries
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }

            Label {
                text: i18nc("@info", "Loading countries from provider...")
                opacity: 0.78
            }
        }
    }

    Label {
        Layout.columnSpan: Math.max(1, root.contentColumns)
        Layout.fillWidth: true
        visible: !root.loadingCountries && root.displayedOptions.length === 0
        text: root.countryLoadError.length > 0 ? root.countryLoadError : i18nc("@info", "No countries were found for this sport.")
        horizontalAlignment: Text.AlignHCenter
        opacity: 0.78
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.displayedOptions

        delegate: SportChoiceCard {
            title: modelData.label
            flagSource: String(modelData.icon || "").indexOf("file://") === 0 ? modelData.icon : ""
            iconName: String(modelData.icon || "").indexOf("file://") === 0 ? "" : modelData.icon || ""
            infoText: modelData.infoText || ""
            selected: root.configRoot && root.configRoot.cfg_country === modelData.value
            onClicked: root.configRoot.selectCountry(modelData.value)
        }
    }
}
