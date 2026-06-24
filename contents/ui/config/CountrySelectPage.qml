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
import "../../code/SportsApi.js" as SportsApi
import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import "../../code/providers/ProviderCountries.js" as ProviderCountries
import "../../code/providers/SportScoreSports.js" as SportScoreSports

SportStepPage {
    id: root

    property var configRoot
    property string countryFilter: ""
    property bool loadingCountries: false
    property string countryLoadError: ""
    // True only when the provider request failed (network/timeout), not when it
    // simply returned no countries.
    property bool countryLoadFailed: false
    property int countryRequestToken: 0
    readonly property bool pageActive: root.configRoot && root.configRoot.countryPageIndex >= 0 && root.configRoot.pageIndex === root.configRoot.countryPageIndex
    readonly property bool tennisMode: root.configRoot && root.configRoot.normalizedSport() === "tennis"
    readonly property var displayedOptions: root.pageActive && root.configRoot && !root.loadingCountries ? root.configRoot.filtered(root.configRoot.countryOptions(), root.countryFilter) : []

    title: i18nc("@title:group", "Country")
    subtitle: root.tennisMode
        ? i18nc("@info", "Open a region to follow its tennis competitions and players.")
        : i18nc("@info", "Open a country to follow its leagues and teams.")
    filterText: root.countryFilter
    filterPlaceholder: i18nc("@info:placeholder", "Search countries")
    onFilterEdited: text => root.countryFilter = text

    onPageActiveChanged: {
        if (root.pageActive)
            root.loadCountries();
    }

    // SportScore only backs football/basketball/cricket/tennis; other sports are
    // ESPN-only, so the SportScore failure message must not appear for them.
    readonly property bool sportScoreSport: root.configRoot && SportScoreSports.supports(root.configRoot.normalizedSport())
    readonly property bool showCountryError: root.countryLoadFailed && !root.loadingCountries && root.sportScoreSport

    headerContent: Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: true
        type: root.showCountryError ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
        text: root.showCountryError
            ? i18nc("@info", "SportScore is not responding right now, so the list of countries could not be loaded. Please try again later.")
            : (root.tennisMode
                ? i18nc("@info", "Open International to browse the ATP, WTA and Grand Slam competitions and follow players.")
                : i18nc("@info", "Open a country to browse its competitions and follow the ones you want. You can follow competitions from several countries."))
        actions: root.showCountryError ? [retryCountriesAction] : []
    }

    Kirigami.Action {
        id: retryCountriesAction
        icon.name: "view-refresh"
        text: i18nc("@action:button", "Try again")
        onTriggered: root.loadCountries()
    }

    Connections {
        target: root.configRoot

        function onCfg_selectedSportsChanged() {
            if (root.pageActive)
                root.loadCountries();
        }
    }

    WizardCache {
        id: wizardCache
    }

    function staticCountryOption(value) {
        const options = ProviderCatalog.countryOptions(root.configRoot ? root.configRoot.currentProvider : "", root.configRoot ? root.configRoot.normalizedSport() : "");
        for (let index = 0; index < options.length; index += 1) {
            if (String(options[index] && options[index].value || "") === String(value || ""))
                return options[index] || {};
        }
        return {};
    }

    function applyCountryRows(sport, rows) {
        const options = (Array.isArray(rows) ? rows : []).map(row => {
            const value = String(row && row.value || "").trim();
            const fallback = root.staticCountryOption(value);
            return {
                label: String(row && row.label || fallback.label || ProviderCatalog.leagueLabel(value)).trim(),
                value,
                icon: String(row && row.icon || fallback.icon || "").trim(),
                infoText: String(row && row.infoText || "").trim()
            };
        }).filter(row => row.value.length > 0);
        root.configRoot.cfg_providerCountrySport = sport;
        root.configRoot.cfg_providerCountryOptions = options;
        return options.length;
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
        root.countryLoadFailed = false;
        root.configRoot.cfg_providerCountrySport = "";
        root.configRoot.cfg_providerCountryOptions = [];

        // Render instantly from the local cache; only hit the network when the
        // cache is missing or stale, and keep the cached list if the fetch fails.
        const cacheKey = "countries|" + sport;
        const cached = wizardCache.read(cacheKey);
        const hasCache = cached && Array.isArray(cached.value) && cached.value.length > 0;
        if (hasCache) {
            root.applyCountryRows(sport, cached.value);
            root.loadingCountries = false;
            if (cached.fresh)
                return;
        }

        SportsApi.fetchSportCountries({
            "provider": root.configRoot.currentProvider,
            "sports": sport
        }, rows => {
            if (token !== root.countryRequestToken)
                return;

            root.loadingCountries = false;
            root.countryLoadFailed = false;
            if (Array.isArray(rows) && rows.length > 0)
                wizardCache.write(cacheKey, rows);
            const count = root.applyCountryRows(sport, rows);
            if (count === 0 && !hasCache)
                root.countryLoadError = i18nc("@info", "No countries were found for this sport.");
        }, message => {
            if (token !== root.countryRequestToken)
                return;

            root.loadingCountries = false;
            // Provider failed (no ESPN fallback for the country catalog).
            if (!hasCache)
                root.countryLoadFailed = true;
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
        // The provider-failure case is shown by the error banner in the header.
        visible: !root.loadingCountries && !root.showCountryError && root.displayedOptions.length === 0
        text: root.countryLoadError.length > 0 ? root.countryLoadError : i18nc("@info", "No countries were found for this sport.")
        horizontalAlignment: Text.AlignHCenter
        opacity: 0.78
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.displayedOptions

        delegate: SportChoiceCard {
            // Prefer an emoji flag; fall back to the l10n image / named icon.
            readonly property string countryEmoji: String(modelData.iconEmoji || "").length > 0
                ? String(modelData.iconEmoji)
                : ProviderCountries.flagEmoji(modelData.value)

            title: modelData.label
            iconEmoji: countryEmoji
            flagSource: countryEmoji.length === 0 && String(modelData.icon || "").indexOf("file://") === 0 ? modelData.icon : ""
            iconName: countryEmoji.length === 0 && String(modelData.icon || "").indexOf("file://") === 0 ? "" : (countryEmoji.length > 0 ? "" : modelData.icon || "")
            infoText: modelData.infoText || ""
            cardToolTipText: i18nc("@info:tooltip", "Open %1", modelData.label)
            selected: root.configRoot && root.configRoot.cfg_country === modelData.value
            onClicked: {
                root.configRoot.selectCountry(modelData.value);
                root.configRoot.openCountryPage(
                    modelData.value,
                    modelData.label,
                    String(modelData.icon || "").indexOf("file://") === 0 ? modelData.icon : "");
            }
        }
    }
}
