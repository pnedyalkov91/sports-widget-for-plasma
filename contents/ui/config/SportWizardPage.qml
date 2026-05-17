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
    readonly property int pageCount: 4
    readonly property string currentProvider: settingsRoot ? settingsRoot.currentProvider : "sportscore"

    signal closeRequested()
    signal finishRequested(var entry)

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

    function filtered(options, filterText) {
        return settingsRoot ? settingsRoot.filtered(options, filterText) : options;
    }

    function canAdvance() {
        if (root.pageIndex === 0)
            return root.normalizedSport().length > 0;

        if (root.pageIndex === 1)
            return root.cfg_country.length > 0;

        if (root.pageIndex === 2)
            return root.cfg_league.length > 0;

        return root.cfg_league.length > 0;
    }

    function selectSport(value) {
        root.cfg_selectedSports = value;
        root.cfg_country = "";
        root.cfg_league = "";
        root.cfg_favoriteTeam = "";
    }

    function selectCountry(value) {
        root.cfg_country = value;
        root.cfg_league = "";
        root.cfg_favoriteTeam = "";
    }

    function selectLeague(value) {
        root.cfg_league = value;
        root.cfg_favoriteTeam = "";
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

    function initializeDraft() {
        const entry = root.initialEntry || {};
        if (Object.keys(entry).length > 0) {
            root.cfg_selectedSports = entry.sport || "";
            root.cfg_country = entry.country || "";
            root.cfg_league = entry.league || "";
            root.cfg_favoriteTeam = entry.favoriteTeam || "";
            return;
        }

        if (!root.settingsRoot)
            return;
        root.cfg_selectedSports = root.settingsRoot.cfg_selectedSports || "";
        root.cfg_country = root.settingsRoot.cfg_country || "";
        root.cfg_league = root.settingsRoot.cfg_league || "";
        root.cfg_favoriteTeam = root.settingsRoot.cfg_favoriteTeam || "";
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

                text: i18nc("@title:group", "Choose Sport")
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
                        root.finishRequested(root.currentEntry());
                    } else {
                        root.pageIndex += 1;
                    }
                }
            }
        }
    }

    StackLayout {
        id: pageStack

        anchors.top: header.bottom
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        currentIndex: root.pageIndex

        SportSelectPage {
            configRoot: root
        }

        CountrySelectPage {
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
