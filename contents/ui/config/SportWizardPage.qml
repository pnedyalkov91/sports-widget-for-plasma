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

import "../../code/SportVisuals.js" as SportVisuals
import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import "../../code/providers/ProviderCountries.js" as ProviderCountries
import "../../code/providers/SportScoreSports.js" as SportScoreSports
import "../../code/providers/EspnSports.js" as EspnSports
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
    // Entries followed instantly during this wizard session (the "favorite" flow
    // saves competitions/teams straight to the saved list). Tracked so the summary
    // can show them; entries saved before this session stay excluded.
    property var sessionAddedEntries: []
    readonly property bool multiSelectEnabled: root.editingIndex < 0
    // Sports whose whole league set is the curated "Top" list (fixed-league ESPN
    // sports): the wizard skips the Country + Competition browse steps and ends on
    // the Top page. Everything else (incl. tennis, now SportScore-browsable) uses
    // the full flow.
    readonly property bool browseDisabled: {
        const s = String(root.cfg_selectedSports || "").split(",")[0].trim();
        return s.length > 0 && !EspnSports.hasCountryBrowse(s);
    }
    // Full flow: Sport(0) → Top/Popular(1) → Country(2) → Competition(3).
    // Browse-disabled sports stop after Top: Sport(0) → Top(1).
    readonly property int pageCount: root.browseDisabled ? 2 : 4
    readonly property int combinedPageIndex: 3
    readonly property int countryPageIndex: root.browseDisabled ? -1 : 2
    readonly property bool onPopularPage: root.pageIndex === 1
    // On the country page the competition picking happens in the country subpage
    // overlay (immediate add), so it is a terminal step for the browse flow.
    readonly property bool onCountryPage: !root.browseDisabled && root.pageIndex === root.countryPageIndex
    readonly property string currentProvider: settingsRoot ? settingsRoot.currentProvider : ""
    // True while a full-page subpage overlay (league or country) covers the wizard.
    // The host KCM uses this to drop its outer scrollbar so only the overlay's own
    // ScrollView scrolls (avoids a double scrollbar).
    readonly property bool overlayActive: root.openedLeague !== null || root.openedCountry.length > 0

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

    // Cached so typing in the wizard's search field doesn't re-run the
    // label normalization (regex-heavy) over every competition on each keystroke.
    readonly property var leagueOptionsCache: {
        if (root.normalizedSport().length === 0)
            return [];

        if (root.cfg_providerLeagueCountry === root.cfg_country && Array.isArray(root.cfg_providerLeagueOptions) && root.cfg_providerLeagueOptions.length > 0) {
            return root.cfg_providerLeagueOptions.map(option => {
                const copy = Object.assign({}, option || {});
                copy.label = ProviderCatalog.normalizedCompetitionLabel(copy.label, copy.slug || copy.value);
                return copy;
            });
        }

        return [];
    }

    function leagueOptions() {
        return root.leagueOptionsCache;
    }

    function favoriteOptions() {
        return [];
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

    // Immediate add/remove of a saved favorite (used by the "Top in the World"
    // page, whose items span multiple countries and so cannot use the single
    // country-scoped staged selection). Reuses the settings page's own helpers.
    function isFavoriteSaved(entry) {
        if (!root.settingsRoot || !entry)
            return false;

        const saved = root.settingsRoot.savedLeagues();
        for (let index = 0; index < saved.length; index += 1) {
            if (root.settingsRoot.sameEntry(saved[index], entry))
                return true;
        }
        return false;
    }

    // Stable identity for a saved/working entry, matching settingsRoot.sameEntry's
    // fields, so session-added entries can be tracked in a list.
    function entryKey(entry) {
        entry = entry || {};
        const type = root.entryType(entry);
        const tail = type === "team" ? String(entry.favoriteTeam || "").trim().toLowerCase() : String(entry.league || "").trim().toLowerCase();
        return [String(entry.sport || "").trim().toLowerCase(), String(entry.country || "").trim().toLowerCase(), type, tail].join("|");
    }

    function toggleFavorite(entry) {
        if (!root.settingsRoot || !entry)
            return;

        const key = root.entryKey(entry);
        const saved = root.settingsRoot.savedLeagues();
        for (let index = 0; index < saved.length; index += 1) {
            if (root.settingsRoot.sameEntry(saved[index], entry)) {
                saved.splice(index, 1);
                root.settingsRoot.saveLeagues(saved);
                root.sessionAddedEntries = root.sessionAddedEntries.filter(item => root.entryKey(item) !== key);
                return;
            }
        }
        root.settingsRoot.saveOrReplaceLeague(entry, -1);
        // Record it (with the labels the summary needs) as added this session.
        if (!root.sessionAddedEntries.some(item => root.entryKey(item) === key))
            root.sessionAddedEntries = root.sessionAddedEntries.concat([entry]);
    }

    function filtered(options, filterText) {
        return settingsRoot ? settingsRoot.filtered(options, filterText) : options;
    }

    function canAdvance() {
        if (root.pageIndex === 0)
            return root.normalizedSport().length > 0;

        if (root.pageIndex === root.combinedPageIndex)
            return root.selectedLeagueValues().length > 0
                || root.selectedFavoriteTeamValues().length > 0
                || root.selectedNationalTeamValues().length > 0;

        // Popular landing page and country page: favourites are added instantly
        // (via their subpages), so the user can always move on or finish.
        return true;
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
        return root.pendingEntries.length > 0
            || (Array.isArray(root.sessionAddedEntries) && root.sessionAddedEntries.length > 0)
            || root.selectedLeagueValues().length > 0
            || root.selectedNationalTeamValues().length > 0
            || root.selectedFavoriteTeamValues().length > 0
            || String(root.cfg_country || "").trim().length > 0;
    }

    function allPendingEntries() {
        return root.pendingEntries.concat(root.currentEntries());
    }

    // Summary of new additions in this wizard session — grouped by
    // "<sport> - <country>". Two sources, deduped by entryKey:
    //   • sessionAddedEntries — competitions/teams followed instantly this session;
    //   • staged current-sport picks (cfg_selected*) and entries banked via
    //     "Add Another Sport", minus anything saved before this wizard opened.
    function sessionSummaryText() {
        const staged = root.allPendingEntries().filter(entry => {
            if (!root.settingsRoot)
                return true;
            const saved = root.settingsRoot.savedLeagues();
            for (let index = 0; index < saved.length; index += 1) {
                if (root.editingIndex >= 0 && index === root.editingIndex)
                    continue;
                if (root.settingsRoot.sameEntry(entry, saved[index]))
                    return false;
            }
            return true;
        });

        const seen = {};
        const entries = [];
        const sessionAdded = Array.isArray(root.sessionAddedEntries) ? root.sessionAddedEntries : [];
        sessionAdded.concat(staged).forEach(entry => {
            const key = root.entryKey(entry);
            if (seen[key])
                return;
            seen[key] = true;
            entries.push(entry);
        });
        if (entries.length === 0)
            return "";

        const order = [];
        const groups = {};
        entries.forEach(entry => {
            const sport = SportVisuals.label(entry.sport || "");
            const explicit = String(entry.countryLabel || root.optionLabel(root.countryOptions(), entry.country) || "").trim();
            const country = explicit.length > 0 ? explicit : ProviderCountries.countryDisplayName(entry.country);
            const key = country.length > 0 ? sport + " - " + country : sport;
            if (!groups[key]) {
                groups[key] = [];
                order.push(key);
            }
            const title = root.entryTitle(entry);
            if (title.length > 0)
                groups[key].push(title);
        });

        // One "<sport> - <country> - <items>" group per line.
        return order.map(key => {
            const names = groups[key];
            const preview = names.slice(0, 3).join(", ");
            const suffix = names.length > 3 ? i18nc("@label", " and %1 more", names.length - 3) : "";
            return key + " - " + preview + suffix;
        }).join("\n");
    }

    function isNationalTeamLabel(teamName, countryLabel) {
        const team = String(teamName || "").trim().toLowerCase();
        const country = String(countryLabel || "").trim().toLowerCase();
        if (team.length === 0 || country.length === 0)
            return false;

        return team === country || team.indexOf(country + " ") === 0 || team.indexOf(country + "(") === 0;
    }

    function initializeDraft() {
        // Fresh session: forget instant-follow tracking from a previous wizard open.
        root.sessionAddedEntries = [];

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
        root.cfg_league = "";
        root.cfg_favoriteTeam = "";
        // Start with no selections: cfg_league/cfg_favoriteTeam are leftovers from a
        // previously saved entry, and pre-selecting them here would mark that saved
        // competition/team as chosen and flag it as a duplicate before the user
        // touches anything.
        root.cfg_selectedNationalTeams = [];
        root.cfg_selectedLeagues = [];
        root.cfg_selectedFavoriteTeams = [];
        root.cfg_selectedFavoriteTeamMeta = ({});
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
                    } else if (root.hasDraftSelections()) {
                        discardSelectionsDialog.open();
                    } else {
                        root.closeRequested();
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                id: addSportButton

                visible: root.pageIndex === root.pageCount - 1
                icon.name: "list-add"
                text: i18nc("@action:button", "Add Another Sport")
                enabled: root.canAdvance()
                onClicked: {
                    if (!root.canAdvance())
                        return;

                    root.pendingEntries = root.pendingEntries.concat(root.currentEntries());
                    root.selectSport("");
                    root.pageIndex = 0;
                }
            }

            Button {
                id: nextButton

                // On the Top/Country pages favourites are saved instantly and the
                // dialog's own Apply/OK persists everything, so no "Done" button is
                // needed there — hide it. It only appears to advance ("Next") or to
                // open the review on the staged-flow's final page.
                visible: !root.onPopularPage && !root.onCountryPage
                icon.name: root.pageIndex === root.pageCount - 1 ? "dialog-ok-apply" : "go-next"
                text: root.pageIndex === root.pageCount - 1 ? i18nc("@action:button", "Done") : i18nc("@action:button", "Next")
                enabled: root.canAdvance()
                onClicked: {
                    if (!root.canAdvance())
                        return;

                    if (root.pageIndex === root.pageCount - 1) {
                        reviewDialog.open();
                    } else {
                        root.pageIndex += 1;
                    }
                }
            }
        }
    }

    Kirigami.InlineMessage {
        id: pendingEntriesInlineMessage

        anchors.top: header.bottom
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        type: Kirigami.MessageType.Information
        // Session summary of new additions (staged + banked), shown on every page so
        // the user always sees what they have added so far, including countries. The
        // cfg_selected* / pendingEntries reads make the binding track staged changes.
        readonly property string summary: {
            void root.cfg_selectedLeagues;
            void root.cfg_selectedFavoriteTeams;
            void root.cfg_selectedNationalTeams;
            void root.pendingEntries;
            void root.sessionAddedEntries;
            return root.sessionSummaryText();
        }
        text: i18nc("@info", "Added so far:") + "\n" + summary + "\n"
            + i18nc("@info", "Click Apply (or OK) to save everything.")
        visible: summary.length > 0
    }

    Kirigami.InlineMessage {
        id: duplicateInlineMessage

        anchors.top: pendingEntriesInlineMessage.visible ? pendingEntriesInlineMessage.bottom : header.bottom
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        type: Kirigami.MessageType.Warning
        text: root.duplicateWarningText()
        visible: root.pageIndex === root.pageCount - 1 && text.length > 0
    }

    Dialog {
        id: discardSelectionsDialog

        modal: true
        title: i18nc("@title:window", "Leave the wizard?")
        standardButtons: Dialog.NoButton

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing
            width: Kirigami.Units.gridUnit * 24

            Label {
                Layout.fillWidth: true
                text: i18nc("@info", "Are you sure? Competitions and teams you have enabled are kept, but any picks you have not yet confirmed will be discarded.")
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
                        root.pendingEntries = [];
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
                            model: root.allPendingEntries()

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
                    text: root.duplicateWarningText(root.allPendingEntries())
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
                        enabled: root.allPendingEntries().length > 0
                        onClicked: {
                            const entries = root.allPendingEntries();
                            reviewDialog.close();
                            root.pendingEntries = [];
                            root.finishRequested(entries);
                        }
                    }
                }
            }
        }
    }

    StackLayout {
        id: pageStack

        anchors.top: duplicateInlineMessage.visible
            ? duplicateInlineMessage.bottom
            : (pendingEntriesInlineMessage.visible ? pendingEntriesInlineMessage.bottom : header.bottom)
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // Items: Sport(0), Popular(1), Country(2), Competition(3). pageIndex maps
        // 1:1; browse-disabled sports simply never advance past Popular(1).
        currentIndex: root.pageIndex

        SportSelectPage {
            configRoot: root
        }

        PopularSelectPage {
            configRoot: root
        }

        CountrySelectPage {
            configRoot: root
        }

        CombinedSelectPage {
            configRoot: root
        }
    }

    // League detail subpage, opened from the league cards as a full-page overlay
    // that covers the wizard (including its navigation bar).
    property var openedLeague: null
    property url openedLeagueEmblem: ""
    // "favorite" = add/remove a saved favorite instantly (Top page); "select" =
    // toggle it in the staged wizard selection committed on Done (Browse flow).
    property string openedLeagueMode: "favorite"

    function openLeaguePage(league, emblem, mode) {
        root.openedLeagueEmblem = emblem || "";
        root.openedLeagueMode = String(mode || "favorite");
        root.openedLeague = league || null;
    }

    function closeLeaguePage() {
        root.openedLeague = null;
        root.openedLeagueEmblem = "";
        root.openedLeagueMode = "favorite";
    }

    Component {
        id: leagueSubPageComponent

        LeagueSubPage {
            configRoot: root
            league: root.openedLeague
            emblem: root.openedLeagueEmblem
            commitMode: root.openedLeagueMode
        }
    }

    // Country detail subpage, opened from the country cards in the Browse flow as
    // a full-page overlay. Its league cards open the league subpage on top of it.
    property string openedCountry: ""
    property string openedCountryLabel: ""
    property url openedCountryFlag: ""

    function openCountryPage(country, label, flag) {
        root.openedCountryLabel = String(label || "");
        root.openedCountryFlag = flag || "";
        root.openedCountry = String(country || "");
    }

    function closeCountryPage() {
        root.openedCountry = "";
        root.openedCountryLabel = "";
        root.openedCountryFlag = "";
    }

    // Stage the current sport's selections and restart the wizard at the Sport
    // picker, so several sports can be added in one session. Mirrors the
    // "Add Another Sport" button on the last wizard page. Invoked from a subpage
    // overlay (league/country), so close any open overlay first.
    function addAnotherSport() {
        root.closeLeaguePage();
        root.closeCountryPage();
        // In the browse ("select") flow the staged picks live in cfg_selected*;
        // fold them into pendingEntries. In the "favorite" flow they are already
        // saved instantly, so currentEntries() is empty and this is a no-op.
        root.pendingEntries = root.pendingEntries.concat(root.currentEntries());
        root.selectSport("");
        root.pageIndex = 0;
    }

    Component {
        id: countrySubPageComponent

        CountrySubPage {
            configRoot: root
            country: root.openedCountry
            countryLabel: root.openedCountryLabel
            flag: root.openedCountryFlag
        }
    }

    // Country overlay sits below the league overlay (z 90 < 100), so opening a
    // league from inside the country subpage covers it cleanly.
    Loader {
        anchors.fill: parent
        z: 90
        active: root.openedCountry.length > 0
        visible: active
        sourceComponent: countrySubPageComponent
    }

    Loader {
        anchors.fill: parent
        z: 100
        active: root.openedLeague !== null
        visible: active
        sourceComponent: leagueSubPageComponent
    }
}
