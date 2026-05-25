/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../../code/SportVisuals.js" as SportVisuals
import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var settingsRoot
    property int pageIndex: 0
    property var initialEntry: ({})
    property int editingIndex: -1
    property string cfg_selectedSports: ""
    property string cfg_country: ""
    property string cfg_league: ""
    property string cfg_favoriteTeam: ""
    property var cfg_selectedNationalTeams: []
    property var cfg_selectedLeagues: []
    property var cfg_selectedFavoriteTeams: []
    property bool showNationalTeamStep: false
    property string cfg_followMode: "league"
    property string cfg_type: "competition"
    property var pendingEntries: []
    readonly property bool multiSelectEnabled: root.editingIndex < 0
    readonly property int pageCount: root.cfg_type === "team" ? (root.showNationalTeamStep ? 4 : 3) : 3
    readonly property string currentProvider: settingsRoot ? settingsRoot.currentProvider : "sportscore"

    signal closeRequested()
    signal finishRequested(var entries)

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

        const options = ProviderCatalog.countryOptions(root.currentProvider, root.normalizedSport());
        return root.cfg_type === "team" ? options.filter(option => option.value !== "world") : options;
    }

    function leagueOptions() {
        if (root.normalizedSport().length === 0)
            return [];

        return ProviderCatalog.leagueOptions(root.currentProvider, root.normalizedSport(), root.cfg_country || ProviderCatalog.defaultCountry(root.currentProvider, root.normalizedSport()));
    }

    function favoriteOptions() {
        if (root.cfg_type === "team")
            return ProviderCatalog.countryTeamOptions(root.currentProvider, root.normalizedSport(), root.cfg_country);

        return [];
    }

    function normalizedFollowMode(value, favoriteTeam) {
        const favorite = String(favoriteTeam || "").trim();
        return String(value || "").trim() === "team" && favorite.length > 0 ? "team" : "league";
    }

    function canUseTeamFollowMode() {
        return root.cfg_favoriteTeam.length > 0;
    }

    function setFollowMode(value) {
        if (root.cfg_type === "team") {
            root.cfg_followMode = "team";
            return;
        }

        root.cfg_followMode = root.normalizedFollowMode(value, root.cfg_favoriteTeam);
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

    function leagueLabel() {
        if (!root.cfg_league || root.cfg_league.length === 0)
            return i18nc("@label", "No league selected");

        return ProviderCatalog.leagueLabel(root.cfg_league) || root.optionLabel(root.leagueOptions(), root.cfg_league) || root.cfg_league;
    }

    function selectedLeagueValues() {
        return Array.isArray(root.cfg_selectedLeagues) ? root.cfg_selectedLeagues.filter(value => String(value || "").trim().length > 0) : [];
    }

    function selectedFavoriteTeamValues() {
        return Array.isArray(root.cfg_selectedFavoriteTeams) ? root.cfg_selectedFavoriteTeams.filter(value => String(value || "").trim().length > 0) : [];
    }

    function selectedNationalTeamValues() {
        return Array.isArray(root.cfg_selectedNationalTeams) ? root.cfg_selectedNationalTeams.filter(value => String(value || "").trim().length > 0) : [];
    }

    function isLeagueSelected(value) {
        const league = String(value || "").trim();
        if (league.length === 0)
            return false;

        return root.selectedLeagueValues().indexOf(league) >= 0;
    }

    function isFavoriteTeamSelected(value) {
        const team = String(value || "").trim();
        if (team.length === 0)
            return false;

        return root.selectedFavoriteTeamValues().indexOf(team) >= 0;
    }

    function isNationalTeamSelected(value) {
        const team = String(value || "").trim();
        if (team.length === 0)
            return false;

        return root.selectedNationalTeamValues().indexOf(team) >= 0;
    }

    function filtered(options, filterText) {
        return settingsRoot ? settingsRoot.filtered(options, filterText) : options;
    }

    function canAdvance() {
        if (root.pageIndex === 0)
            return root.normalizedSport().length > 0;

        if (root.pageIndex === 1)
            return root.cfg_country.length > 0;

        if (root.cfg_type === "team" && root.pageIndex === 2)
            return root.showNationalTeamStep || root.selectedFavoriteTeamValues().length > 0 || root.selectedNationalTeamValues().length > 0;

        if (root.cfg_type === "team")
            return root.selectedNationalTeamValues().length > 0 || root.selectedFavoriteTeamValues().length > 0;

        return root.selectedLeagueValues().length > 0;
    }

    function selectSport(value) {
        root.cfg_selectedSports = value;
        root.cfg_country = "";
        root.cfg_league = "";
        root.cfg_favoriteTeam = "";
        root.cfg_selectedNationalTeams = [];
        root.cfg_selectedLeagues = [];
        root.cfg_selectedFavoriteTeams = [];
        root.showNationalTeamStep = false;
        root.cfg_followMode = root.cfg_type === "team" ? "team" : "league";
    }

    function selectCountry(value) {
        root.cfg_country = value;
        root.cfg_league = "";
        root.cfg_favoriteTeam = "";
        root.cfg_selectedNationalTeams = [];
        root.cfg_selectedLeagues = [];
        root.cfg_selectedFavoriteTeams = [];
        root.showNationalTeamStep = false;
        root.cfg_followMode = root.cfg_type === "team" ? "team" : "league";
    }

    function selectLeague(value) {
        const league = String(value || "").trim();
        if (league.length === 0)
            return;

        if (!root.multiSelectEnabled) {
            root.cfg_selectedLeagues = [league];
            root.cfg_league = league;
            root.cfg_favoriteTeam = "";
            root.cfg_selectedFavoriteTeams = [];
            root.cfg_followMode = root.cfg_type === "team" ? "team" : "league";
            return;
        }

        let next = root.selectedLeagueValues();
        const index = next.indexOf(league);
        if (index >= 0) {
            next.splice(index, 1);
        } else {
            next.push(league);
        }

        root.cfg_selectedLeagues = next;
        root.cfg_league = next.length > 0 ? next[0] : "";
        root.cfg_favoriteTeam = "";
        root.cfg_selectedFavoriteTeams = [];
        root.cfg_followMode = root.cfg_type === "team" ? "team" : "league";
    }

    function selectFavoriteTeam(value) {
        const team = String(value || "").trim();
        if (team.length === 0)
            return;

        if (!root.multiSelectEnabled) {
            root.cfg_selectedFavoriteTeams = [team];
            root.cfg_favoriteTeam = team;
            root.setFollowMode("team");
            return;
        }

        let next = root.selectedFavoriteTeamValues();
        const index = next.indexOf(team);
        if (index >= 0) {
            next.splice(index, 1);
        } else {
            next.push(team);
        }

        root.cfg_selectedFavoriteTeams = next;
        root.cfg_favoriteTeam = next.length > 0 ? next[0] : "";
        root.cfg_followMode = root.cfg_type === "team" ? "team" : "league";
    }

    function selectNationalTeam(value) {
        const team = String(value || "").trim();
        if (team.length === 0)
            return;

        root.showNationalTeamStep = true;

        if (!root.multiSelectEnabled) {
            root.cfg_selectedNationalTeams = [team];
            root.cfg_followMode = "team";
            return;
        }

        let next = root.selectedNationalTeamValues();
        const index = next.indexOf(team);
        if (index >= 0) {
            next.splice(index, 1);
        } else {
            next.push(team);
        }

        root.cfg_selectedNationalTeams = next;
        root.cfg_followMode = "team";
    }

    function openNationalTeamsStep() {
        if (root.cfg_type !== "team")
            return;
        root.showNationalTeamStep = true;
    }

    function currentEntry() {
        const entries = root.currentEntries();
        return entries.length > 0 ? entries[0] : {};
    }

    function currentEntries() {
        const sport = root.normalizedSport();
        const country = root.cfg_country || ProviderCatalog.defaultCountry(root.currentProvider, sport);
        const base = {
            sport,
            country,
            countryLabel: root.countryLabel(),
            countryIcon: root.countryIcon(root.cfg_country),
            followMode: root.cfg_type === "team" ? "team" : "league",
            type: root.cfg_type === "team" ? "team" : "competition"
        };

        if (root.cfg_type === "team") {
            const mergedTeams = root.selectedNationalTeamValues().concat(root.selectedFavoriteTeamValues())
                .filter((value, index, array) => array.indexOf(value) === index);
            return mergedTeams.map(team => {
                let item = Object.assign({}, base);
                item.league = "";
                item.leagueLabel = i18nc("@label", "All competitions");
                item.favoriteTeam = team;
                return item;
            });
        }

        return root.selectedLeagueValues().map(league => {
            let item = Object.assign({}, base);
            item.league = league;
            item.leagueLabel = ProviderCatalog.leagueLabel(league) || root.optionLabel(root.leagueOptions(), league) || league;
            item.favoriteTeam = "";
            return item;
        });
    }

    function entryType(entry) {
        entry = entry || {};
        const explicit = String(entry.type || "").trim();
        if (explicit === "team" || explicit === "competition")
            return explicit;
        return String(entry.followMode || "").trim() === "team" ? "team" : "competition";
    }

    function entryTitle(entry) {
        entry = entry || {};
        if (root.entryType(entry) === "team")
            return String(entry.favoriteTeam || "").trim();
        return String(entry.leagueLabel || ProviderCatalog.leagueLabel(entry.league) || entry.league || "").trim();
    }

    function entryMeta(entry) {
        entry = entry || {};
        const sport = SportVisuals.label(entry.sport);
        const country = String(entry.countryLabel || root.optionLabel(root.countryOptions(), entry.country) || entry.country || "").trim();
        return [sport, country].filter(part => String(part || "").length > 0).join(" · ");
    }

    function duplicateEntryMatches(entries) {
        const selectedEntries = Array.isArray(entries) ? entries : [];
        if (!root.settingsRoot)
            return [];

        const saved = root.settingsRoot.savedLeagues();
        let matches = [];
        selectedEntries.forEach(entry => {
            for (let index = 0; index < saved.length; index += 1) {
                if (root.editingIndex >= 0 && index === root.editingIndex)
                    continue;

                if (root.settingsRoot.sameEntry(entry, saved[index])) {
                    matches.push({
                        "entry": entry,
                        "savedIndex": index
                    });
                    break;
                }
            }
        });
        return matches;
    }

    function duplicateWarningText(entries) {
        const duplicates = root.duplicateEntryMatches(entries === undefined ? root.currentEntries() : entries);
        if (duplicates.length === 0)
            return "";

        const names = duplicates.map(item => root.entryTitle(item.entry)).filter(name => name.length > 0);
        const preview = names.slice(0, 3).join(", ");
        const suffix = names.length > 3 ? i18nc("@label", " and %1 more", names.length - 3) : "";
        if (duplicates.length === 1)
            return i18nc("@info", "Duplicate detected: %1 is already saved. Saving will update the existing item.", names[0] || root.entryTitle(duplicates[0].entry));

        return i18nc("@info", "Duplicate detected: %1 selected items are already saved (%2%3). Saving will update existing items.", duplicates.length, preview, suffix);
    }

    function hasDraftSelections() {
        return root.selectedLeagueValues().length > 0
            || root.selectedNationalTeamValues().length > 0
            || root.selectedFavoriteTeamValues().length > 0
            || String(root.cfg_country || "").trim().length > 0;
    }

    function selectedItems() {
        if (root.cfg_type === "team")
            return root.selectedNationalTeamValues().concat(root.selectedFavoriteTeamValues())
                .filter((value, index, array) => array.indexOf(value) === index);

        const leagues = root.selectedLeagueValues();
        return leagues.map(value => ProviderCatalog.leagueLabel(value) || root.optionLabel(root.leagueOptions(), value) || value);
    }

    function selectedItemsSummaryText() {
        const items = root.selectedItems();
        if (items.length === 0)
            return "";

        const preview = items.slice(0, 5).join(", ");
        const suffix = items.length > 5 ? i18nc("@label", " and %1 more", items.length - 5) : "";
        if (root.cfg_type === "team")
            return i18nc("@info", "Selected teams (%1): %2%3", items.length, preview, suffix);

        return i18nc("@info", "Selected competitions (%1): %2%3", items.length, preview, suffix);
    }

    function isNationalTeamLabel(teamName, countryLabel) {
        const team = String(teamName || "").trim().toLowerCase();
        const country = String(countryLabel || "").trim().toLowerCase();
        if (team.length === 0 || country.length === 0)
            return false;

        return team === country || team.indexOf(country + " ") === 0 || team.indexOf(country + "(") === 0;
    }

    function initializeDraft() {
        const entry = root.initialEntry || {};
        if (Object.keys(entry).length > 0) {
            root.cfg_type = String(entry.type || "").trim() === "team"
                    || (String(entry.followMode || "").trim() === "team" && String(entry.favoriteTeam || "").trim().length > 0) ? "team" : "competition";
            root.cfg_selectedSports = entry.sport || "";
            root.cfg_country = entry.country || "";
            root.cfg_league = root.cfg_type === "team" ? "" : entry.league || "";
            root.cfg_favoriteTeam = entry.favoriteTeam || "";
            const entryCountryLabel = root.optionLabel(root.countryOptions(), root.cfg_country);
            root.cfg_selectedNationalTeams = root.cfg_type === "team" && root.isNationalTeamLabel(root.cfg_favoriteTeam, entryCountryLabel)
                ? [root.cfg_favoriteTeam]
                : [];
            root.cfg_selectedLeagues = root.cfg_type === "team" ? [] : (root.cfg_league.length > 0 ? [root.cfg_league] : []);
            root.cfg_selectedFavoriteTeams = root.cfg_type === "team"
                ? (root.cfg_favoriteTeam.length > 0 && root.cfg_selectedNationalTeams.length === 0 ? [root.cfg_favoriteTeam] : [])
                : [];
            root.showNationalTeamStep = root.cfg_type === "team" && root.cfg_selectedNationalTeams.length > 0;
            root.cfg_followMode = root.cfg_type === "team" ? "team" : root.normalizedFollowMode(entry.followMode, root.cfg_favoriteTeam);
            return;
        }

        if (!root.settingsRoot)
            return;
        root.cfg_selectedSports = root.settingsRoot.cfg_selectedSports || "";
        root.cfg_country = root.settingsRoot.cfg_country || "";
        root.cfg_league = root.cfg_type === "team" ? "" : root.settingsRoot.cfg_league || "";
        root.cfg_favoriteTeam = root.cfg_type === "team" ? "" : root.settingsRoot.cfg_favoriteTeam || "";
        root.cfg_selectedNationalTeams = root.cfg_type === "team" ? [] : [];
        root.cfg_selectedLeagues = root.cfg_type === "team" ? [] : (root.cfg_league.length > 0 ? [root.cfg_league] : []);
        root.cfg_selectedFavoriteTeams = root.cfg_type === "team" ? (root.cfg_favoriteTeam.length > 0 ? [root.cfg_favoriteTeam] : []) : [];
        root.showNationalTeamStep = false;
        root.cfg_followMode = root.cfg_type === "team" ? "team" : "league";
    }

    function stackIndexForPage(page) {
        if (root.cfg_type === "team") {
            if (page === 2)
                return 4;
            if (page === 3)
                return 2;
            return page;
        }

        return page === 2 ? 3 : page;
    }

    Component.onCompleted: initializeDraft()
    onInitialEntryChanged: initializeDraft()

    ColumnLayout {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: implicitHeight
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Heading {
                id: chooseSportHeading

                text: root.cfg_type === "team" ? i18nc("@title:group", "Add Team") : i18nc("@title:group", "Add Competition")
                level: 2
                visible: root.pageIndex === 0
                Layout.fillWidth: true
            }

            Item {
                Layout.fillWidth: !chooseSportHeading.visible
            }

            Item {
                Layout.preferredWidth: 1
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                id: backButton

                icon.name: "go-previous"
                text: root.pageIndex > 0 ? i18nc("@action:button", "Back") : i18nc("@action:button", "Back to Sport")
                onClicked: {
                    if (root.pageIndex > 0) {
                        root.pageIndex -= 1;
                    } else if (root.hasDraftSelections()) {
                        discardSelectionsDialog.open();
                    } else {
                        root.closeRequested();
                    }
                }
            }

            Item {
                Layout.fillWidth: true

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing * 1.5

                    Repeater {
                        model: root.pageCount

                        delegate: Rectangle {
                            required property int index

                            Layout.preferredWidth: Kirigami.Units.smallSpacing * 1.4
                            Layout.preferredHeight: Layout.preferredWidth
                            radius: width / 2
                            color: index === root.pageIndex ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                            opacity: index === root.pageIndex ? 1 : 0.45
                        }
                    }
                }
            }

            Button {
                id: nextButton

                icon.name: root.pageIndex === root.pageCount - 1 ? "dialog-ok-apply" : "go-next"
                text: root.pageIndex === root.pageCount - 1 ? i18nc("@action:button", "Done") : i18nc("@action:button", "Next")
                enabled: root.canAdvance()
                onClicked: {
                    if (!root.canAdvance())
                        return;

                    if (root.pageIndex === root.pageCount - 1) {
                        root.pendingEntries = root.currentEntries();
                        reviewDialog.open();
                    } else {
                        root.pageIndex += 1;
                    }
                }
            }
        }
    }

    Kirigami.InlineMessage {
        id: duplicateInlineMessage

        anchors.top: header.bottom
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        type: Kirigami.MessageType.Warning
        text: root.duplicateWarningText()
        visible: root.pageIndex === root.pageCount - 1 && text.length > 0
    }

    Kirigami.InlineMessage {
        id: selectedItemsInlineMessage

        anchors.top: duplicateInlineMessage.visible ? duplicateInlineMessage.bottom : header.bottom
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        type: Kirigami.MessageType.Information
        text: root.selectedItemsSummaryText()
        visible: root.pageIndex === root.pageCount - 1 && text.length > 0
    }

    Dialog {
        id: discardSelectionsDialog

        modal: true
        title: i18nc("@title:window", "Discard Selections?")
        standardButtons: Dialog.NoButton

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            width: Kirigami.Units.gridUnit * 24

            Label {
                Layout.fillWidth: true
                text: root.cfg_type === "team"
                    ? i18nc("@info", "If you go back now, your selected teams will be lost.")
                    : i18nc("@info", "If you go back now, your selected competitions will be lost.")
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Kirigami.Units.smallSpacing

                Button {
                    icon.name: "dialog-cancel"
                    text: i18nc("@action:button", "Cancel")
                    onClicked: discardSelectionsDialog.close()
                }

                Button {
                    icon.name: "go-previous"
                    text: i18nc("@action:button", "Go Back")
                    onClicked: {
                        discardSelectionsDialog.close();
                        root.closeRequested();
                    }
                }
            }
        }
    }

    Dialog {
        id: reviewDialog

        modal: true
        title: root.cfg_type === "team" ? i18nc("@title:window", "Review Teams") : i18nc("@title:window", "Review Competitions")
        standardButtons: Dialog.NoButton

        contentItem: Item {
            implicitWidth: Kirigami.Units.gridUnit * 28
            implicitHeight: reviewColumn.implicitHeight

            ColumnLayout {
                id: reviewColumn

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Kirigami.Units.largeSpacing

                Label {
                    Layout.fillWidth: true
                    text: root.cfg_type === "team"
                        ? i18nc("@info", "You selected the teams below. If you click Save, they will be added to the Sports list. If you missed something, go back and add the missing teams.")
                        : i18nc("@info", "You selected the competitions below. If you click Save, they will be added to the Sports list. If you missed something, go back and add the missing tournaments/leagues.")
                    wrapMode: Text.WordWrap
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(Kirigami.Units.gridUnit * 11, reviewListColumn.implicitHeight + Kirigami.Units.smallSpacing * 2)
                    clip: true

                    ColumnLayout {
                        id: reviewListColumn

                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: root.pendingEntries

                            delegate: Label {
                                required property int index
                                required property var modelData

                                Layout.fillWidth: true
                                text: (index + 1) + ". " + root.entryTitle(modelData) + (root.entryMeta(modelData).length > 0 ? " - " + root.entryMeta(modelData) : "")
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    type: Kirigami.MessageType.Warning
                    text: root.duplicateWarningText(root.pendingEntries)
                    visible: text.length > 0
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Kirigami.Units.smallSpacing

                    Button {
                        icon.name: "go-previous"
                        text: i18nc("@action:button", "Back")
                        onClicked: reviewDialog.close()
                    }

                    Button {
                        icon.name: "document-save"
                        text: i18nc("@action:button", "Save")
                        enabled: root.pendingEntries.length > 0
                        onClicked: {
                            const entries = root.pendingEntries.slice();
                            reviewDialog.close();
                            root.finishRequested(entries);
                        }
                    }
                }
            }
        }
    }

    StackLayout {
        id: pageStack

        anchors.top: selectedItemsInlineMessage.visible
            ? selectedItemsInlineMessage.bottom
            : (duplicateInlineMessage.visible ? duplicateInlineMessage.bottom : header.bottom)
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        currentIndex: root.stackIndexForPage(root.pageIndex)

        SportSelectPage {
            configRoot: root
        }

        CountrySelectPage {
            configRoot: root
        }

        NationalTeamSelectPage {
            configRoot: root
        }

        LeagueSelectPage {
            configRoot: root
        }

        FavoriteTeamSelectPage {
            configRoot: root
        }
    }
}
