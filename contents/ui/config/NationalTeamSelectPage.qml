/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../../code/SportsApi.js" as SportsApi
import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

SportStepPage {
    id: root

    property var configRoot
    property string variantFilter: ""
    property var variantOptions: []
    property bool loading: false
    property int requestToken: 0
    readonly property bool pageActive: root.configRoot && root.configRoot.cfg_type === "team" && root.configRoot.pageIndex === 3
    readonly property var displayedOptions: root.configRoot ? root.configRoot.filtered(root.variantOptions, root.variantFilter) : []

    title: i18nc("@title:group", "National Teams")
    subtitle: i18nc("@info", "Choose optional national team variants from supported provider data.")
    filterText: root.variantFilter
    filterPlaceholder: i18nc("@info:placeholder", "Search national teams")
    onFilterEdited: text => root.variantFilter = text
    Component.onCompleted: root.refreshVariants()

    Connections {
        target: root.configRoot
        ignoreUnknownSignals: true

        function onCfg_countryChanged() {
            root.refreshVariants();
        }

        function onCfg_selectedSportsChanged() {
            root.refreshVariants();
        }

        function onCfg_typeChanged() {
            root.refreshVariants();
        }

        function onPageIndexChanged() {
            if (root.pageActive && root.variantOptions.length === 0)
                root.refreshVariants();
        }
    }

    function normalizeText(value) {
        return String(value || "").trim().toLowerCase().replace(/\s+/g, " ");
    }

    function countryName() {
        return root.configRoot ? String(root.configRoot.countryLabel() || "").trim() : "";
    }

    function countryCode() {
        return root.configRoot ? String(root.configRoot.cfg_country || "").trim().toLowerCase() : "";
    }

    function countryFlagSource() {
        return root.configRoot ? String(root.configRoot.countryIcon(root.configRoot.cfg_country) || "") : "";
    }

    function isNationalVariant(teamName) {
        const country = root.normalizeText(root.countryName());
        const team = root.normalizeText(teamName);
        if (country.length === 0 || team.length === 0)
            return false;

        return team === country || team.indexOf(country + " ") === 0 || team.indexOf(country + "(") === 0;
    }

    function addVariant(map, teamName) {
        const value = String(teamName || "").trim();
        if (value.length === 0 || !root.isNationalVariant(value))
            return;

        const key = root.normalizeText(value);
        if (map[key])
            return;

        map[key] = {
            label: value,
            value,
            flagSource: root.countryFlagSource()
        };
    }

    function nationalVariantCandidates() {
        const country = root.countryName();
        if (country.length === 0)
            return [];

        const baseCandidates = [country];
        const aliases = {
            "United States": "USA",
            "United States of America": "USA",
            "South Korea": "Korea Republic"
        };
        if (aliases[country])
            baseCandidates.push(aliases[country]);

        const suffixes = [" Women", " W", " U23", " U-23", " U22", " U-22", " U21", " U-21", " U20", " U-20", " U19", " U-19", " U18", " U-18", " U17", " U-17"];
        let rows = [];
        let seen = {};

        baseCandidates.forEach(base => {
            const baseValue = String(base || "").trim();
            if (baseValue.length === 0)
                return;

            const baseKey = root.normalizeText(baseValue);
            if (baseKey.length > 0 && !seen[baseKey]) {
                seen[baseKey] = true;
                rows.push(baseValue);
            }

            suffixes.forEach(suffix => {
                const value = `${baseValue}${suffix}`;
                const key = root.normalizeText(value);
                if (key.length === 0 || seen[key])
                    return;

                seen[key] = true;
                rows.push(value);
            });
        });

        return rows;
    }

    function variantPriority(option) {
        const country = root.normalizeText(root.countryName());
        const label = root.normalizeText(option && option.label);
        if (label === country)
            return 0;
        if (label.indexOf(country + " women") === 0 || label.indexOf(country + "(w") === 0)
            return 1;
        if (label.indexOf("u23") >= 0)
            return 2;
        if (label.indexOf("u21") >= 0)
            return 3;
        if (label.indexOf("u20") >= 0)
            return 4;
        if (label.indexOf("u19") >= 0)
            return 5;
        return 6;
    }

    function loadVariantLeagues() {
        const worldLeagues = ProviderCatalog.leagueOptions(root.configRoot ? root.configRoot.currentProvider : "", "football", "world");
        const filtered = (Array.isArray(worldLeagues) ? worldLeagues : []).filter(league => {
            const label = String(league && league.label || "").toLowerCase();
            return label.indexOf("world cup") >= 0
                || label.indexOf("nations league") >= 0
                || label.indexOf("european championship") >= 0
                || label.indexOf("gold cup") >= 0
                || label.indexOf("asian cup") >= 0
                || label.indexOf("africa cup") >= 0
                || label.indexOf("copa america") >= 0;
        });
        return filtered.slice(0, 6);
    }

    function refreshVariants() {
        root.requestToken += 1;
        root.loading = false;
        root.variantOptions = [];

        if (!root.pageActive || root.countryCode().length === 0 || root.countryCode() === "world" || root.countryCode() === "all")
            return;

        const token = root.requestToken;
        const variants = {};
        root.addVariant(variants, root.countryName());
        root.loading = true;
        let pendingSources = 2;

        function finishSource() {
            pendingSources -= 1;
            if (pendingSources > 0)
                return;

            if (token !== root.requestToken)
                return;

            let rows = Object.keys(variants).map(key => variants[key]);
            rows.sort((left, right) => root.variantPriority(left) - root.variantPriority(right) || String(left.label || "").localeCompare(String(right.label || "")));
            root.variantOptions = rows;
            root.loading = false;
        }

        function loadFromLeagues() {
            const leagues = root.loadVariantLeagues();
            if (leagues.length === 0) {
                finishSource();
                return;
            }

            let pending = leagues.length;

            function finishLeague() {
                pending -= 1;
                if (pending > 0)
                    return;
                finishSource();
            }

            leagues.forEach(league => {
                SportsApi.fetchLeagueTable({
                    "sports": "football",
                    "country": "world",
                    "league": String(league && league.value || "").trim(),
                    "followMode": "league"
                }, rows => {
                    if (token !== root.requestToken) {
                        finishLeague();
                        return;
                    }

                    (Array.isArray(rows) ? rows : []).forEach(row => {
                        root.addVariant(variants, row && row.team);
                    });
                    finishLeague();
                }, () => {
                    finishLeague();
                });
            });
        }

        function loadFromTeamProfiles() {
            const candidates = root.nationalVariantCandidates();
            if (candidates.length === 0) {
                finishSource();
                return;
            }

            let pending = candidates.length;

            function finishCandidate() {
                pending -= 1;
                if (pending > 0)
                    return;
                finishSource();
            }

            candidates.forEach(candidateName => {
                SportsApi.fetchTeamProfile({
                    "sports": "football",
                    "country": root.countryCode(),
                    "favoriteTeam": candidateName
                }, profile => {
                    if (token !== root.requestToken) {
                        finishCandidate();
                        return;
                    }

                    const teamName = String(profile && profile.name || "").trim();
                    if (teamName.length > 0)
                        root.addVariant(variants, teamName);
                    finishCandidate();
                }, () => {
                    finishCandidate();
                });
            });
        }

        loadFromLeagues();
        loadFromTeamProfiles();
    }

    headerContent: RowLayout {
        Layout.fillWidth: true
        visible: root.loading
        spacing: Kirigami.Units.smallSpacing

        BusyIndicator {
            running: parent.visible
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
        }

        Label {
            Layout.fillWidth: true
            text: i18nc("@info", "Loading national team variants from providers...")
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
        }
    }

    Repeater {
        model: root.displayedOptions

        delegate: SportChoiceCard {
            title: modelData.label
            flagSource: String(modelData.flagSource || "").indexOf("file://") === 0 ? modelData.flagSource : ""
            iconName: "im-user"
            selected: root.configRoot && root.configRoot.isNationalTeamSelected(modelData.value)
            onClicked: root.configRoot.selectNationalTeam(modelData.value)
        }
    }

    Label {
        Layout.fillWidth: true
        visible: !root.loading && root.displayedOptions.length === 0
        text: i18nc("@info", "No national team variants were found for this country.")
        color: Kirigami.Theme.disabledTextColor
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}
