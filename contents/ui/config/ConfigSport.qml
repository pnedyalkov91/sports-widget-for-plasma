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

    property bool cfg_prioritizePopular: Plasmoid.configuration.prioritizePopular
    property string cfg_selectedSports: Plasmoid.configuration.selectedSports
    property string cfg_country: Plasmoid.configuration.country
    property string cfg_league: Plasmoid.configuration.league
    property string cfg_favoriteTeam: Plasmoid.configuration.favoriteTeam
    property string cfg_savedLeagues: Plasmoid.configuration.savedLeagues
    property bool cfg_defaultSelectionMigrated: Plasmoid.configuration.defaultSelectionMigrated
    property int cfg_selectionRevision: Plasmoid.configuration.selectionRevision
    property int cfg_activeSavedLeagueIndex: Plasmoid.configuration.activeSavedLeagueIndex

    readonly property string currentProvider: "sportscore"
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

        return ProviderCatalog.leagueOptions(root.currentProvider, root.normalizedSport(), root.cfg_country || ProviderCatalog.defaultCountry(root.currentProvider, root.normalizedSport()));
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

    function displayLeagueLabel(entry) {
        entry = entry || {};
        return String(entry.customLeagueLabel || entry.leagueLabel || ProviderCatalog.leagueLabel(entry.league) || entry.league || "").trim();
    }

    function displayCountryLabel(entry) {
        entry = entry || {};
        return String(entry.customCountryLabel || entry.countryLabel || entry.country || "").trim();
    }

    function displayFavoriteTeam(entry) {
        entry = entry || {};
        return String(entry.customFavoriteTeamLabel || entry.favoriteTeam || "").trim();
    }

    function filtered(options, filterText) {
        const needle = String(filterText || "").trim().toLowerCase();
        if (needle.length === 0)
            return options;

        return options.filter(option => String(option.label || "").toLowerCase().indexOf(needle) >= 0);
    }

    function selectSport(value) {
        root.cfg_selectedSports = value;
        const defaultCountry = ProviderCatalog.defaultCountry(root.currentProvider, value);
        const countries = ProviderCatalog.countryOptions(root.currentProvider, value);
        root.cfg_country = countries.length > 0 ? defaultCountry : "";
        const leagues = ProviderCatalog.leagueOptions(root.currentProvider, value, root.cfg_country);
        root.cfg_league = leagues.length > 0 ? leagues[0].value : "";
        root.cfg_favoriteTeam = "";
    }

    function selectCountry(value) {
        root.cfg_country = value;
        const leagues = root.leagueOptions();
        root.cfg_league = leagues.length > 0 ? leagues[0].value : "";
        root.cfg_favoriteTeam = "";
    }

    function selectLeague(value) {
        root.cfg_league = value;
        root.cfg_favoriteTeam = "";
    }

    function savedLeagues() {
        try {
            const parsed = JSON.parse(root.cfg_savedLeagues || "[]");
            return Array.isArray(parsed) ? parsed : [];
        } catch (error) {
            return [];
        }
    }

    function saveLeagues(items) {
        root.cfg_savedLeagues = JSON.stringify(items);
    }

    function currentEntry() {
        return {
            sport: root.normalizedSport(),
            country: root.cfg_country || ProviderCatalog.defaultCountry(root.currentProvider, root.normalizedSport()),
            countryLabel: root.countryLabel(),
            countryIcon: root.countryIcon(root.cfg_country),
            league: root.cfg_league || "",
            leagueLabel: root.leagueLabel(),
            favoriteTeam: root.cfg_favoriteTeam || ""
        };
    }

    function sameEntry(left, right) {
        return String(left.sport || "") === String(right.sport || "")
            && String(left.country || "") === String(right.country || "")
            && String(left.league || "") === String(right.league || "")
            && String(left.favoriteTeam || "") === String(right.favoriteTeam || "");
    }

    function saveOrReplaceLeague(entry, replaceIndex) {
        if (entry.league.length === 0)
            return -1;

        const saved = root.savedLeagues();
        const copy = Object.assign({}, entry);

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
        root.cfg_country = entry.country || ProviderCatalog.defaultCountry(root.currentProvider, root.cfg_selectedSports);
        root.cfg_league = entry.league || "";
        root.cfg_favoriteTeam = entry.favoriteTeam || "";
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
            return;
        }

        const nextIndex = Math.min(index, saved.length - 1);
        root.cfg_activeSavedLeagueIndex = nextIndex;
        root.applySavedLeague(saved[nextIndex], nextIndex);
    }

    function finishWizard(entry) {
        if (root.wizardEditingIndex >= 0) {
            const saved = root.savedLeagues();
            const previous = saved[root.wizardEditingIndex] || {};
            entry = Object.assign({}, previous, entry);
        }
        root.saveOrReplaceLeague(entry, root.wizardEditingIndex);
        root.cfg_selectionRevision += 1;
        root.pageIndex = 0;
    }

    function openAddSportWizard() {
        root.wizardInitialEntry = {
            sport: "",
            country: "",
            league: "",
            favoriteTeam: ""
        };
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
                onAddSportRequested: root.openAddSportWizard()
            }

            Item {
                Layout.preferredHeight: Kirigami.Units.smallSpacing
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.pageIndex === 1
            sourceComponent: sportWizardComponent
        }
    }

}
