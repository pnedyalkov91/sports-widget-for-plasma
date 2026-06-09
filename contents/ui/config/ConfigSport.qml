/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../../code/SportVisuals.js" as SportVisuals
import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: root

    implicitHeight: Kirigami.Units.gridUnit * 22
    readonly property bool wizardFirstStepActive: root.pageIndex === 1 && wizardLoader.item && wizardLoader.item.pageIndex === 0
    verticalScrollBarPolicy: root.wizardFirstStepActive ? Qt.ScrollBarAlwaysOff : Qt.ScrollBarAsNeeded
    horizontalScrollBarPolicy: Qt.ScrollBarAlwaysOff
    flickable.interactive: !root.wizardFirstStepActive
    flickable.flickableDirection: root.wizardFirstStepActive ? Flickable.HorizontalFlick : Flickable.VerticalFlick

    onWizardFirstStepActiveChanged: {
        if (root.wizardFirstStepActive && flickable.contentY !== 0)
            flickable.contentY = 0;
    }

    Connections {
        target: root.flickable

        function onContentYChanged() {
            if (root.wizardFirstStepActive && root.flickable.contentY !== 0)
                root.flickable.contentY = 0;
        }
    }

    property bool cfg_prioritizePopular: Plasmoid.configuration.prioritizePopular
    property string cfg_provider: Plasmoid.configuration.provider
    property string cfg_defaultSport: Plasmoid.configuration.defaultSport
    property string cfg_selectedSports: Plasmoid.configuration.selectedSports
    property string cfg_country: Plasmoid.configuration.country
    property string cfg_league: Plasmoid.configuration.league
    property string cfg_favoriteTeam: Plasmoid.configuration.favoriteTeam
    property string cfg_savedLeagues: Plasmoid.configuration.savedLeagues
    property bool cfg_defaultSelectionMigrated: Plasmoid.configuration.defaultSelectionMigrated
    property int cfg_selectionRevision: Plasmoid.configuration.selectionRevision
    property int cfg_activeSavedLeagueIndex: Plasmoid.configuration.activeSavedLeagueIndex
    property int cfg_refreshInterval: Plasmoid.configuration.refreshInterval
    property bool cfg_liveRefreshEnabled: Plasmoid.configuration.liveRefreshEnabled
    property int cfg_liveRefreshInterval: Plasmoid.configuration.liveRefreshInterval
    property string cfg_nationalTeamVisualStyle: Plasmoid.configuration.nationalTeamVisualStyle
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
    readonly property string currentProvider: String(root.cfg_provider || "").trim()
    property string currentFollowMode: "league"
    property string currentEntryType: "competition"
    property int pageIndex: 0
    property var wizardInitialEntry: ({})
    property int wizardEditingIndex: -1

    function firstSport() {
        return String(root.cfg_selectedSports || "").split(",")[0];
    }

    function normalizedSport() {
        const sport = root.firstSport();
        return sport.length > 0 ? SportVisuals.normalizedSport(sport) : "";
    }

    function optionLabel(options, value) {
        for (let index = 0; index < options.length; index += 1) {
            if (options[index].value === value)
                return options[index].label || "";
        }
        return "";
    }

    function sportOptions() {
        return ProviderCatalog.sportOptions(root.currentProvider);
    }

    function countryOptions() {
        if (root.normalizedSport().length === 0)
            return [];

        return ProviderCatalog.countryOptions(root.currentProvider, root.normalizedSport());
    }

    function leagueOptions() {
        if (root.normalizedSport().length === 0)
            return [];

        return ProviderCatalog.leagueOptions(root.currentProvider, root.normalizedSport(), root.cfg_country || "");
    }

    function favoriteOptions() {
        if (!root.cfg_league || root.cfg_league.length === 0)
            return [{ label: i18nc("@label", "No favorite team"), value: "" }];

        return ProviderCatalog.favoriteTeamOptions(root.cfg_league || "");
    }

    function sportLabel() {
        if (root.normalizedSport().length === 0)
            return i18nc("@label", "No sport selected");

        return root.optionLabel(root.sportOptions(), root.normalizedSport()) || SportVisuals.label(root.normalizedSport());
    }

    function countryLabel() {
        if (!root.cfg_country || root.cfg_country.length === 0)
            return i18nc("@label", "No country selected");

        return root.optionLabel(root.countryOptions(), root.cfg_country) || i18nc("@label", "All countries");
    }

    function countryIcon(countryValue) {
        const countries = root.countryOptions();
        for (let index = 0; index < countries.length; index += 1) {
            if (countries[index].value === countryValue)
                return countries[index].icon || "";
        }
        return "";
    }

    function countryIconForEntry(entry) {
        const countries = ProviderCatalog.countryOptions(root.currentProvider, entry.sport || "football");
        for (let index = 0; index < countries.length; index += 1) {
            if (countries[index].value === entry.country)
                return countries[index].icon || "";
        }
        return "";
    }

    function leagueLabel() {
        if (!root.cfg_league || root.cfg_league.length === 0)
            return i18nc("@label", "No league selected");

        return ProviderCatalog.leagueLabel(root.cfg_league) || root.optionLabel(root.leagueOptions(), root.cfg_league) || root.cfg_league;
    }

    function favoriteLabel() {
        return root.cfg_favoriteTeam && root.cfg_favoriteTeam.length > 0 ? root.cfg_favoriteTeam : i18nc("@label", "No favorite team");
    }

    function normalizedFollowMode(value, favoriteTeam) {
        const favorite = String(favoriteTeam || "").trim();
        return String(value || "").trim() === "team" && favorite.length > 0 ? "team" : "league";
    }

    function optionValues(options) {
        return (Array.isArray(options) ? options : []).map(option => String(option && option.value || "").trim().toLowerCase()).filter(value => value.length > 0);
    }

    function knownLeagueValues(sport, country) {
        return root.optionValues(ProviderCatalog.leagueOptions(root.currentProvider, String(sport || "football").trim(), String(country || "").trim()));
    }

    function knownCountryTeamValues(sport, country) {
        return root.optionValues(ProviderCatalog.countryTeamOptions(root.currentProvider, String(sport || "football").trim(), String(country || "").trim()));
    }

    function isLikelyLegacyTeamEntry(entry) {
        entry = entry || {};
        const league = String(entry.league || "").trim().toLowerCase();
        const favoriteTeam = String(entry.favoriteTeam || "").trim();
        const followMode = String(entry.followMode || "").trim();
        if (league.length === 0 || favoriteTeam.length > 0 || followMode === "team")
            return false;

        const leagues = root.knownLeagueValues(entry.sport, entry.country);
        if (leagues.indexOf(league) >= 0)
            return false;

        const teams = root.knownCountryTeamValues(entry.sport, entry.country);
        return teams.indexOf(league) >= 0;
    }

    function entryType(entry) {
        entry = entry || {};
        const explicit = String(entry.type || "").trim();
        const followMode = String(entry.followMode || "").trim();
        const favoriteTeam = String(entry.favoriteTeam || "").trim();
        const league = String(entry.league || "").trim();
        const legacyLabel = String(entry.customLeagueLabel || entry.leagueLabel || "").trim();
        const legacyStarredLabel = /^[★*]\s*/.test(legacyLabel);
        const looksLikeTeam = followMode === "team" || legacyStarredLabel || (favoriteTeam.length > 0 && league.length === 0) || root.isLikelyLegacyTeamEntry(entry);
        if (explicit === "team")
            return "team";
        if (explicit === "competition")
            return looksLikeTeam ? "team" : "competition";

        return looksLikeTeam ? "team" : "competition";
    }

    function followModeLabel(entry) {
        return root.entryType(entry) === "team" ? i18nc("@label", "Team · All competitions") : i18nc("@label", "Competition");
    }

    function displayLeagueLabel(entry) {
        entry = entry || {};
        return String(entry.customLeagueLabel || entry.leagueLabel || ProviderCatalog.leagueLabel(entry.league) || entry.league || "").trim();
    }

    function stripLegacyTeamPrefix(value) {
        return String(value || "").replace(/^[★*]\s*/, "").trim();
    }

    function displayCountryLabel(entry) {
        entry = entry || {};
        return String(entry.customCountryLabel || entry.countryLabel || entry.country || "").trim();
    }

    function displayFavoriteTeam(entry) {
        entry = entry || {};
        return root.stripLegacyTeamPrefix(entry.customFavoriteTeamLabel || entry.favoriteTeam || "");
    }

    function displaySavedTitle(entry) {
        entry = entry || {};
        if (root.entryType(entry) === "team") {
            const favorite = root.displayFavoriteTeam(entry);
            return favorite.length > 0 ? favorite : root.stripLegacyTeamPrefix(root.displayLeagueLabel(entry));
        }

        return root.displayLeagueLabel(entry);
    }

    function filtered(options, filterText) {
        const needle = String(filterText || "").trim().toLowerCase();
        if (needle.length === 0)
            return options;

        return options.filter(option => String(option.label || "").toLowerCase().indexOf(needle) >= 0);
    }

    function selectSport(value) {
        root.cfg_selectedSports = value;
        root.cfg_country = "";
        root.cfg_league = "";
        root.cfg_favoriteTeam = "";
        root.currentFollowMode = "league";
        root.currentEntryType = "competition";
    }

    function selectCountry(value) {
        root.cfg_country = value;
        const leagues = root.leagueOptions();
        root.cfg_league = leagues.length > 0 ? leagues[0].value : "";
        root.cfg_favoriteTeam = "";
        root.currentFollowMode = "league";
        root.currentEntryType = "competition";
    }

    function selectLeague(value) {
        root.cfg_league = value;
        root.cfg_favoriteTeam = "";
        root.currentFollowMode = "league";
        root.currentEntryType = "competition";
    }

    function savedLeagues() {
        try {
            const parsed = JSON.parse(root.cfg_savedLeagues || "[]");
            return Array.isArray(parsed) ? parsed.map(entry => root.normalizedSavedEntry(entry)) : [];
        } catch (error) {
            return [];
        }
    }

    function normalizedSavedEntry(entry) {
        const copy = Object.assign({}, entry || {});
        copy.type = root.entryType(copy);
        copy.followMode = copy.type === "team" ? "team" : "league";
        copy.includeLive = copy.includeLive !== false;
        copy.includeSchedules = copy.includeSchedules !== false;
        copy.includeRecent = copy.includeRecent !== false;
        copy.includeTables = copy.includeTables !== false;
        copy.includePanel = copy.includePanel !== false;
        copy.includeTooltip = copy.includeTooltip !== false;
        if (copy.type === "team") {
            copy.favoriteTeam = root.stripLegacyTeamPrefix(copy.customFavoriteTeamLabel || copy.favoriteTeam || copy.customLeagueLabel || copy.leagueLabel || copy.league || "");
            copy.league = "";
            copy.leagueLabel = i18nc("@label", "All competitions");
        } else {
            copy.favoriteTeam = String(copy.favoriteTeam || "").trim();
        }
        delete copy.starred;
        return copy;
    }

    function saveLeagues(items) {
        const normalizedItems = Array.isArray(items) ? items.map(entry => root.normalizedSavedEntry(entry)) : [];
        root.cfg_savedLeagues = JSON.stringify(normalizedItems);
    }

    function currentEntry() {
        return {
            sport: root.normalizedSport(),
            country: root.cfg_country || "",
            countryLabel: root.countryLabel(),
            countryIcon: root.countryIcon(root.cfg_country),
            league: root.currentEntryType === "team" ? "" : root.cfg_league || "",
            leagueLabel: root.currentEntryType === "team" ? i18nc("@label", "All competitions") : root.leagueLabel(),
            favoriteTeam: root.currentEntryType === "team" ? root.cfg_favoriteTeam || "" : "",
            followMode: root.currentEntryType === "team" ? "team" : "league",
            type: root.currentEntryType === "team" ? "team" : "competition",
            includeLive: true,
            includeSchedules: true,
            includeRecent: true,
            includeTables: true,
            includePanel: true,
            includeTooltip: true
        };
    }

    function sameEntry(left, right) {
        const leftType = root.entryType(left);
        const rightType = root.entryType(right);
        return String(left.sport || "") === String(right.sport || "")
            && String(left.country || "") === String(right.country || "")
            && ((leftType === "team" && rightType === "team") || String(left.league || "") === String(right.league || ""))
            && String(left.favoriteTeam || "") === String(right.favoriteTeam || "")
            && leftType === rightType;
    }

    function saveOrReplaceLeague(entry, replaceIndex) {
        if (root.entryType(entry) === "competition" && String(entry.league || "").length === 0)
            return -1;
        if (root.entryType(entry) === "team" && String(entry.favoriteTeam || "").trim().length === 0)
            return -1;

        const saved = root.savedLeagues();
        const copy = root.normalizedSavedEntry(entry);
        copy.type = root.entryType(copy);
        copy.followMode = copy.type === "team" ? "team" : "league";
        if (copy.type === "team") {
            copy.league = "";
            copy.leagueLabel = i18nc("@label", "All competitions");
        } else {
            copy.favoriteTeam = "";
        }
        copy.includeLive = copy.includeLive !== false;
        copy.includeSchedules = copy.includeSchedules !== false;
        copy.includeRecent = copy.includeRecent !== false;
        copy.includeTables = copy.includeTables !== false;
        copy.includePanel = copy.includePanel !== false;
        copy.includeTooltip = copy.includeTooltip !== false;
        delete copy.starred;

        let targetIndex = replaceIndex;
        if (targetIndex < 0 || targetIndex >= saved.length) {
            targetIndex = -1;
            for (let index = 0; index < saved.length; index += 1) {
                if (root.sameEntry(saved[index], copy)) {
                    targetIndex = index;
                    break;
                }
            }
        }

        if (targetIndex >= 0) {
            saved[targetIndex] = copy;
        } else {
            saved.push(copy);
            targetIndex = saved.length - 1;
        }

        root.saveLeagues(saved);
        root.cfg_activeSavedLeagueIndex = targetIndex;
        root.applySavedLeague(saved[targetIndex], targetIndex);
        return targetIndex;
    }

    function applySavedLeague(entry, index) {
        root.cfg_selectedSports = entry.sport || "football";
        root.cfg_country = entry.country || "";
        root.cfg_league = entry.league || "";
        root.cfg_favoriteTeam = entry.favoriteTeam || "";
        root.currentEntryType = root.entryType(entry);
        root.currentFollowMode = root.currentEntryType === "team" ? "team" : "league";
        if (index !== undefined && index >= 0)
            root.cfg_activeSavedLeagueIndex = index;
    }

    function removeSavedLeague(index) {
        const saved = root.savedLeagues();
        if (index < 0 || index >= saved.length)
            return;

        saved.splice(index, 1);
        root.saveLeagues(saved);
        if (saved.length === 0) {
            root.cfg_activeSavedLeagueIndex = 0;
            root.cfg_selectedSports = "";
            root.cfg_country = "";
            root.cfg_league = "";
            root.cfg_favoriteTeam = "";
            root.currentFollowMode = "league";
            root.currentEntryType = "competition";
            return;
        }

        const nextIndex = Math.min(index, saved.length - 1);
        root.cfg_activeSavedLeagueIndex = nextIndex;
        root.applySavedLeague(saved[nextIndex], nextIndex);
    }

    function finishWizard(entryList) {
        const entries = Array.isArray(entryList) ? entryList : [entryList];
        if (entries.length === 0)
            return;

        if (root.wizardEditingIndex >= 0) {
            const saved = root.savedLeagues();
            const previous = saved[root.wizardEditingIndex] || {};
            const merged = Object.assign({}, previous, entries[0] || {});
            root.saveOrReplaceLeague(merged, root.wizardEditingIndex);
        } else {
            entries.forEach(entry => {
                root.saveOrReplaceLeague(entry, -1);
            });
        }

        root.cfg_selectionRevision += 1;
        root.pageIndex = 0;
    }

    function openAddSportWizard() {
        root.wizardInitialEntry = {};
        root.wizardEditingIndex = -1;
        root.pageIndex = 1;
    }

    function openEditSavedLeague(entry, index) {
        root.wizardInitialEntry = Object.assign({}, entry);
        root.wizardEditingIndex = index;
        root.pageIndex = 1;
    }

    function renameSavedLeague(index, leagueName, countryName, favoriteName) {
        const saved = root.savedLeagues();
        if (index < 0 || index >= saved.length)
            return;

        saved[index].customLeagueLabel = String(leagueName || "").trim();
        saved[index].customCountryLabel = String(countryName || "").trim();
        saved[index].customFavoriteTeamLabel = String(favoriteName || "").trim();
        if (saved[index].customLeagueLabel.length === 0)
            delete saved[index].customLeagueLabel;
        if (saved[index].customCountryLabel.length === 0)
            delete saved[index].customCountryLabel;
        if (saved[index].customFavoriteTeamLabel.length === 0)
            delete saved[index].customFavoriteTeamLabel;
        root.saveLeagues(saved);
    }

    function setEntryIncludes(index, key, enabled) {
        const allowed = {
            "includeLive": true,
            "includeSchedules": true,
            "includeRecent": true,
            "includeTables": true,
            "includePanel": true,
            "includeTooltip": true
        };
        if (!allowed[key])
            return;

        const saved = root.savedLeagues();
        if (index < 0 || index >= saved.length)
            return;

        saved[index][key] = Boolean(enabled);
        root.saveLeagues(saved);
    }

    Component.onCompleted: {
        if (!root.cfg_defaultSelectionMigrated
                && root.cfg_selectedSports === "football"
                && root.cfg_country === "england"
                && root.cfg_league === "english-premier-league"
                && root.cfg_favoriteTeam.length === 0
                && root.savedLeagues().length === 0) {
            root.cfg_selectedSports = "";
            root.cfg_country = "";
            root.cfg_league = "";
        }
        root.cfg_defaultSelectionMigrated = true;
        const saved = root.savedLeagues();
        if (saved.length > 0) {
            const index = Math.max(0, Math.min(root.cfg_activeSavedLeagueIndex, saved.length - 1));
            const active = saved[index] || {};
            root.currentEntryType = root.entryType(active);
            root.currentFollowMode = root.currentEntryType === "team" ? "team" : "league";
        }
    }

    Component {
        id: sportWizardComponent

        SportWizardPage {
            settingsRoot: root
            initialEntry: root.wizardInitialEntry
            editingIndex: root.wizardEditingIndex
            onCloseRequested: root.pageIndex = 0
            onFinishRequested: (entry) => root.finishWizard(entry)
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: root.pageIndex

        ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            SavedLeaguesList {
                Layout.fillWidth: true
                configRoot: root
                onAddRequested: root.openAddSportWizard()
            }

            Item {
                Layout.preferredHeight: Kirigami.Units.smallSpacing
            }
        }

        Loader {
            id: wizardLoader

            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.pageIndex === 1
            sourceComponent: sportWizardComponent
        }
    }

}
