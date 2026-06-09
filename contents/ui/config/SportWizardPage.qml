/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../../code/SportVisuals.js" as SportVisuals
import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import "../../code/providers/SportScoreSports.js" as SportScoreSports
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
    property var cfg_selectedFavoriteTeamMeta: ({})
    property string cfg_providerLeagueCountry: ""
    property var cfg_providerLeagueOptions: []
    property string cfg_providerCountrySport: ""
    property var cfg_providerCountryOptions: []
    property var pendingEntries: []
    readonly property bool multiSelectEnabled: root.editingIndex < 0
    readonly property bool tennisMode: {
        const s = String(root.cfg_selectedSports || "").split(",")[0].trim().toLowerCase();
        return s === "tennis";
    }
    readonly property int pageCount: root.tennisMode ? 2 : 3
    readonly property int combinedPageIndex: root.tennisMode ? 1 : 2
    readonly property string currentProvider: settingsRoot ? settingsRoot.currentProvider : ""

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

        if (root.cfg_providerCountrySport === root.normalizedSport() && Array.isArray(root.cfg_providerCountryOptions) && root.cfg_providerCountryOptions.length > 0)
            return root.cfg_providerCountryOptions;

        return ProviderCatalog.countryOptions(root.currentProvider, root.normalizedSport());
    }

    function leagueOptions() {
        if (root.normalizedSport().length === 0)
            return [];

        if (root.cfg_providerLeagueCountry === root.cfg_country && Array.isArray(root.cfg_providerLeagueOptions) && root.cfg_providerLeagueOptions.length > 0) {
            return root.cfg_providerLeagueOptions.map(option => {
                const copy = Object.assign({}, option || {});
                copy.label = ProviderCatalog.normalizedCompetitionLabel(copy.label, copy.slug || copy.value);
                return copy;
            });
        }

        return ProviderCatalog.leagueOptions(root.currentProvider, root.normalizedSport(), root.cfg_country || "").map(option => {
            const copy = Object.assign({}, option || {});
            copy.label = ProviderCatalog.normalizedCompetitionLabel(copy.label, copy.slug || copy.value);
            return copy;
        });
    }

    function favoriteOptions() {
        return ProviderCatalog.countryTeamOptions(root.currentProvider, root.normalizedSport(), root.cfg_country);
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

    function leagueOption(value) {
        const wanted = String(value || "").trim();
        const options = root.leagueOptions();
        for (let index = 0; index < options.length; index += 1) {
            if (String(options[index] && options[index].value || "").trim() === wanted)
                return options[index] || {};
        }
        return {};
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

        return root.selectedLeagueValues().length > 0
            || root.selectedFavoriteTeamValues().length > 0
            || root.selectedNationalTeamValues().length > 0;
    }

    function selectSport(value) {
        root.cfg_selectedSports = value;
        root.cfg_country = "";
        root.cfg_league = "";
        root.cfg_favoriteTeam = "";
        root.cfg_selectedNationalTeams = [];
        root.cfg_selectedLeagues = [];
        root.cfg_selectedFavoriteTeams = [];
        root.cfg_selectedFavoriteTeamMeta = ({});
        root.cfg_providerLeagueCountry = "";
        root.cfg_providerLeagueOptions = [];
        root.cfg_providerCountrySport = "";
        root.cfg_providerCountryOptions = [];
    }

    function selectCountry(value) {
        root.cfg_country = value;
        root.cfg_league = "";
        root.cfg_favoriteTeam = "";
        root.cfg_selectedNationalTeams = [];
        root.cfg_selectedLeagues = [];
        root.cfg_selectedFavoriteTeams = [];
        root.cfg_selectedFavoriteTeamMeta = ({});
        root.cfg_providerLeagueCountry = "";
        root.cfg_providerLeagueOptions = [];
    }

    function selectLeague(value) {
        const league = String(value || "").trim();
        if (league.length === 0)
            return;

        if (!root.multiSelectEnabled) {
            root.cfg_selectedLeagues = [league];
            root.cfg_league = league;
            root.cfg_selectedFavoriteTeams = [];
            root.cfg_selectedNationalTeams = [];
            root.cfg_favoriteTeam = "";
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
    }

    function selectFavoriteTeam(value, option) {
        const team = String(value || "").trim();
        if (team.length === 0)
            return;

        const meta = Object.assign({}, root.cfg_selectedFavoriteTeamMeta || {});
        meta[team.toLowerCase()] = {
            teamSlug: String(option && (option.teamSlug || option.team_slug) || "").trim(),
            teamPath: String(option && (option.teamPath || option.teamUrl || option.url) || "").trim(),
            badge: String(option && option.badge || "").trim()
        };
        root.cfg_selectedFavoriteTeamMeta = meta;

        if (!root.multiSelectEnabled) {
            root.cfg_selectedFavoriteTeams = [team];
            root.cfg_favoriteTeam = team;
            root.cfg_selectedLeagues = [];
            root.cfg_selectedNationalTeams = [];
            root.cfg_league = "";
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
    }

    function selectNationalTeam(value) {
        const team = String(value || "").trim();
        if (team.length === 0)
            return;

        if (!root.multiSelectEnabled) {
            root.cfg_selectedNationalTeams = [team];
            root.cfg_selectedLeagues = [];
            root.cfg_selectedFavoriteTeams = [];
            root.cfg_league = "";
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
    }

    function currentEntry() {
        const entries = root.currentEntries();
        return entries.length > 0 ? entries[0] : {};
    }

    function currentEntries() {
        const sport = root.normalizedSport();
        const country = root.cfg_country || "";
        const base = {
            sport,
            country,
            countryLabel: root.countryLabel(),
            countryIcon: root.countryIcon(root.cfg_country),
            includeTables: SportScoreSports.supportsStandings(sport)
        };

        let entries = [];

        root.selectedLeagueValues().forEach(league => {
            let item = Object.assign({}, base);
            const option = root.leagueOption(league);
            item.league = league;
            item.leagueLabel = String(option.label || "").trim() || ProviderCatalog.leagueLabel(league) || league;
            item.competitionPath = String(option.path || option.url || "").trim();
            item.favoriteTeam = "";
            item.followMode = "league";
            item.type = "competition";
            entries.push(item);
        });

        const nationalTeams = root.selectedNationalTeamValues();
        const allTeams = nationalTeams.concat(root.selectedFavoriteTeamValues())
            .filter((value, index, array) => array.indexOf(value) === index);

        allTeams.forEach(team => {
            let item = Object.assign({}, base);
            item.league = "";
            item.leagueLabel = i18nc("@label", "All competitions");
            item.favoriteTeam = team;
            item.followMode = "team";
            item.type = "team";
            item.isNationalTeam = nationalTeams.indexOf(team) >= 0;
            if (item.isNationalTeam)
                item.teamFlag = base.countryIcon;
            const meta = root.cfg_selectedFavoriteTeamMeta[String(team || "").trim().toLowerCase()] || {};
            if (String(meta.teamSlug || "").trim().length > 0)
                item.teamSlug = meta.teamSlug;
            if (String(meta.teamPath || "").trim().length > 0)
                item.teamPath = meta.teamPath;
            if (String(meta.badge || "").trim().length > 0)
                item.teamBadge = meta.badge;
            entries.push(item);
        });

        return entries;
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
        const leagues = root.selectedLeagueValues();
        const leagueLabels = leagues.map(value => ProviderCatalog.leagueLabel(value) || root.optionLabel(root.leagueOptions(), value) || value);
        const teamValues = root.selectedNationalTeamValues().concat(root.selectedFavoriteTeamValues())
            .filter((value, index, array) => array.indexOf(value) === index);
        return leagueLabels.concat(teamValues);
    }

    function selectedItemsSummaryText() {
        const leagues = root.selectedLeagueValues();
        const teamValues = root.selectedNationalTeamValues().concat(root.selectedFavoriteTeamValues())
            .filter((value, index, array) => array.indexOf(value) === index);
        const parts = [];

        if (leagues.length > 0) {
            const leagueNames = leagues.map(value => ProviderCatalog.leagueLabel(value) || root.optionLabel(root.leagueOptions(), value) || value);
            const preview = leagueNames.slice(0, 3).join(", ");
            const suffix = leagueNames.length > 3 ? i18nc("@label", " and %1 more", leagueNames.length - 3) : "";
            parts.push(i18nc("@info", "Competitions (%1): %2%3", leagues.length, preview, suffix));
        }

        if (teamValues.length > 0) {
            const preview = teamValues.slice(0, 3).join(", ");
            const suffix = teamValues.length > 3 ? i18nc("@label", " and %1 more", teamValues.length - 3) : "";
            const usesPlayers = SportScoreSports.usesPlayers(root.normalizedSport());
            parts.push(usesPlayers
                ? i18nc("@info", "Players (%1): %2%3", teamValues.length, preview, suffix)
                : i18nc("@info", "Teams (%1): %2%3", teamValues.length, preview, suffix));
        }

        return parts.join(" | ");
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
            const isTeam = String(entry.type || "").trim() === "team"
                || (String(entry.followMode || "").trim() === "team" && String(entry.favoriteTeam || "").trim().length > 0);
            root.cfg_selectedSports = entry.sport || "";
            root.cfg_country = entry.country || "";
            root.cfg_league = isTeam ? "" : entry.league || "";
            root.cfg_favoriteTeam = isTeam ? entry.favoriteTeam || "" : "";
            const entryCountryLabel = root.optionLabel(root.countryOptions(), root.cfg_country);
            root.cfg_selectedNationalTeams = isTeam && root.isNationalTeamLabel(root.cfg_favoriteTeam, entryCountryLabel)
                ? [root.cfg_favoriteTeam]
                : [];
            root.cfg_selectedLeagues = !isTeam && root.cfg_league.length > 0 ? [root.cfg_league] : [];
            root.cfg_selectedFavoriteTeams = isTeam && root.cfg_favoriteTeam.length > 0 && root.cfg_selectedNationalTeams.length === 0
                ? [root.cfg_favoriteTeam]
                : [];
            root.cfg_selectedFavoriteTeamMeta = ({});
            return;
        }

        if (!root.settingsRoot)
            return;
        root.cfg_selectedSports = root.settingsRoot.cfg_selectedSports || "";
        root.cfg_country = root.settingsRoot.cfg_country || "";
        root.cfg_league = root.settingsRoot.cfg_league || "";
        root.cfg_favoriteTeam = root.settingsRoot.cfg_favoriteTeam || "";
        root.cfg_selectedNationalTeams = [];
        root.cfg_selectedLeagues = root.cfg_league.length > 0 ? [root.cfg_league] : [];
        root.cfg_selectedFavoriteTeams = root.cfg_favoriteTeam.length > 0 ? [root.cfg_favoriteTeam] : [];
        root.cfg_selectedFavoriteTeamMeta = ({});
    }

    function stackIndexForPage(page) {
        return page;
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

                text: i18nc("@title:group", "Add Sport")
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
                        if (root.tennisMode && root.pageIndex === 0)
                            root.cfg_country = "";
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
                        if (root.tennisMode && root.pageIndex === 0)
                            root.cfg_country = "world";
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
                text: i18nc("@info", "If you go back now, your selected competitions and teams will be lost.")
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
        title: i18nc("@title:window", "Review Selections")
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
                    text: i18nc("@info", "You selected the competitions and teams below. If you click Save, they will be added to the Sports list. If you missed something, go back and add the missing items.")
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
        currentIndex: root.tennisMode && root.pageIndex >= 1 ? root.pageIndex + 1 : root.pageIndex

        SportSelectPage {
            configRoot: root
        }

        CountrySelectPage {
            configRoot: root
        }

        CombinedSelectPage {
            configRoot: root
        }
    }
}
