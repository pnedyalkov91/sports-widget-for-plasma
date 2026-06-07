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
    property string leagueFilter: ""
    property bool loadingLeagues: false
    property string leagueLoadError: ""
    property int leagueRequestToken: 0
    readonly property bool pageActive: root.configRoot && root.configRoot.pageIndex === 2 && root.configRoot.cfg_type !== "team"
    readonly property var displayedOptions: root.pageActive && root.configRoot && !root.loadingLeagues ? root.configRoot.filtered(root.configRoot.leagueOptions(), root.leagueFilter) : []

    title: i18nc("@title:group", "League")
    subtitle: root.configRoot ? root.configRoot.multiSelectEnabled ? i18nc("@info", "Pick one or more leagues/cups to follow for %1.", root.configRoot.countryLabel()) : i18nc("@info", "Pick the league or cup to follow for %1.", root.configRoot.countryLabel()) : ""
    filterText: root.leagueFilter
    filterPlaceholder: i18nc("@info:placeholder", "Search leagues")
    onFilterEdited: text => root.leagueFilter = text

    onPageActiveChanged: {
        if (root.pageActive)
            root.loadLeagues();
    }

    Connections {
        target: root.configRoot

        function onCfg_countryChanged() {
            if (root.pageActive)
                root.loadLeagues();
        }

        function onCfg_selectedSportsChanged() {
            if (root.pageActive)
                root.loadLeagues();
        }
    }

    function loadLeagues() {
        if (!root.configRoot || !root.pageActive)
            return;

        const country = String(root.configRoot.cfg_country || "").trim();
        const sport = String(root.configRoot.normalizedSport() || "").trim();
        if (country.length === 0 || sport.length === 0)
            return;

        if (root.configRoot.cfg_providerLeagueCountry === country && Array.isArray(root.configRoot.cfg_providerLeagueOptions) && root.configRoot.cfg_providerLeagueOptions.length > 0)
            return;

        const token = root.leagueRequestToken + 1;
        root.leagueRequestToken = token;
        root.loadingLeagues = true;
        root.leagueLoadError = "";
        root.configRoot.cfg_providerLeagueCountry = "";
        root.configRoot.cfg_providerLeagueOptions = [];

        SportsApi.fetchCountryCompetitions({
            "provider": root.configRoot.currentProvider,
            "sports": sport,
            "country": country
        }, rows => {
            if (token !== root.leagueRequestToken)
                return;

            root.loadingLeagues = false;
            const options = (Array.isArray(rows) ? rows : []).map(row => ({
                "label": ProviderCatalog.normalizedCompetitionLabel(
                    String(row && row.label || "").trim(),
                    String(row && (row.slug || row.value) || "").trim()
                ),
                "value": String(row && (row.value || row.slug || row.label) || "").trim(),
                "slug": String(row && (row.slug || row.value) || "").trim(),
                "country": String(row && row.country || country).trim(),
                "path": String(row && row.path || "").trim(),
                "url": String(row && row.url || "").trim()
            })).filter(row => row.label.length > 0 && row.value.length > 0);
            root.configRoot.cfg_providerLeagueCountry = country;
            root.configRoot.cfg_providerLeagueOptions = options;
            if (options.length === 0)
                root.leagueLoadError = i18nc("@info", "No leagues or cups were found for this country.");
        }, message => {
            if (token !== root.leagueRequestToken)
                return;

            root.loadingLeagues = false;
            root.configRoot.cfg_providerLeagueCountry = country;
            root.configRoot.cfg_providerLeagueOptions = [];
            root.leagueLoadError = String(message || i18nc("@info", "Unable to load leagues from provider.")).trim();
        });
    }

    Item {
        Layout.columnSpan: Math.max(1, root.contentColumns)
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 8, root.height * 0.42)
        visible: root.loadingLeagues

        RowLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            BusyIndicator {
                running: root.loadingLeagues
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }

            Label {
                text: i18nc("@info", "Loading leagues from provider...")
                opacity: 0.78
            }
        }
    }

    Label {
        Layout.fillWidth: true
        visible: !root.loadingLeagues && root.displayedOptions.length === 0
        text: root.leagueLoadError.length > 0 ? root.leagueLoadError : i18nc("@info", "No leagues or cups were found for this country.")
        horizontalAlignment: Text.AlignHCenter
        opacity: 0.78
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.displayedOptions

        delegate: SportChoiceCard {
            title: modelData.label
            iconName: "view-calendar-list"
            selected: root.configRoot && root.configRoot.isLeagueSelected(modelData.value)
            onClicked: root.configRoot.selectLeague(modelData.value)
        }
    }
}
