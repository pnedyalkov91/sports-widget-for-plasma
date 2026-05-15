/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: root

    property alias cfg_prioritizePopular: prioritizePopular.checked
    property string cfg_selectedSports: Plasmoid.configuration.selectedSports
    property string cfg_country: Plasmoid.configuration.country
    property string cfg_league: Plasmoid.configuration.league
    property string cfg_favoriteTeam: Plasmoid.configuration.favoriteTeam
    readonly property string currentProvider: "sportscore"

    function firstSport() {
        return String(root.cfg_selectedSports || "football").split(",")[0];
    }

    function indexFor(model, value) {
        for (let index = 0; index < model.length; index += 1) {
            if (model[index].value === value)
                return index;

        }
        return -1;
    }

    function refreshLeagueModel() {
        const sport = selectedSports.currentValue || root.firstSport();
        const selectedCountry = country.currentValue || root.cfg_country || ProviderCatalog.defaultCountry(root.currentProvider, sport);
        const selectedLeague = ProviderCatalog.sportScoreSlug(root.cfg_league || "english-premier-league");
        league.model = ProviderCatalog.leagueOptions(root.currentProvider, sport, selectedCountry);
        league.currentIndex = root.indexFor(league.model, selectedLeague);
        if (league.model.length > 0 && league.currentIndex < 0)
            league.currentIndex = 0;

        root.cfg_league = league.currentValue || "";
        refreshFavoriteModel();
    }

    function refreshCountryModel() {
        const sport = selectedSports.currentValue || root.firstSport();
        country.model = ProviderCatalog.countryOptions(root.currentProvider, sport);
        country.currentIndex = root.indexFor(country.model, root.cfg_country || ProviderCatalog.defaultCountry(root.currentProvider, sport));
        if (country.model.length > 0 && country.currentIndex < 0)
            country.currentIndex = 0;

        root.cfg_country = country.currentValue || ProviderCatalog.defaultCountry(root.currentProvider, sport);
        refreshLeagueModel();
    }

    function refreshFavoriteModel() {
        favoriteTeam.model = ProviderCatalog.favoriteTeamOptions(root.cfg_league || league.currentValue);
        favoriteTeam.currentIndex = root.indexFor(favoriteTeam.model, root.cfg_favoriteTeam);
        if (favoriteTeam.currentIndex < 0)
            favoriteTeam.currentIndex = 0;

    }

    function countryEntry(index) {
        if (index < 0 || index >= country.model.length)
            return { label: "", value: "", icon: "" };

        return country.model[index];
    }

    Kirigami.FormLayout {
        anchors.fill: parent

        ComboBox {
            id: selectedSports

            Kirigami.FormData.label: i18nc("@label:listbox", "Sport:")
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: ProviderCatalog.sportOptions(root.currentProvider)
            Component.onCompleted: {
                currentIndex = root.indexFor(model, root.firstSport());
                if (model.length > 0 && currentIndex < 0)
                    currentIndex = 0;
                root.cfg_selectedSports = currentValue;
                root.refreshCountryModel();
            }
            onActivated: {
                root.cfg_selectedSports = currentValue;
                root.refreshCountryModel();
            }
        }

        ComboBox {
            id: country

            Kirigami.FormData.label: i18nc("@label:listbox", "Country:")
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: ProviderCatalog.countryOptions(root.currentProvider, selectedSports.currentValue || root.firstSport())
            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                    source: root.countryEntry(country.currentIndex).icon || ""
                    visible: source.length > 0
                }

                Label {
                    Layout.fillWidth: true
                    text: root.countryEntry(country.currentIndex).label
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }
            delegate: ItemDelegate {
                width: country.width
                highlighted: country.highlightedIndex === index

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Layout.preferredWidth
                        source: modelData.icon || ""
                        visible: source.length > 0
                    }

                    Label {
                        Layout.fillWidth: true
                        text: modelData.label
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            Component.onCompleted: {
                currentIndex = root.indexFor(model, root.cfg_country || ProviderCatalog.defaultCountry(root.currentProvider, selectedSports.currentValue || root.firstSport()));
                if (model.length > 0 && currentIndex < 0)
                    currentIndex = 0;
                root.cfg_country = currentValue || "";
            }
            onActivated: {
                root.cfg_country = currentValue;
                root.refreshLeagueModel();
            }
        }

        ComboBox {
            id: league

            Kirigami.FormData.label: i18nc("@label:listbox", "League:")
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: ProviderCatalog.leagueOptions(root.currentProvider, selectedSports.currentValue || root.firstSport(), country.currentValue || root.cfg_country || ProviderCatalog.defaultCountry(root.currentProvider, selectedSports.currentValue || root.firstSport()))
            Component.onCompleted: {
                currentIndex = root.indexFor(model, ProviderCatalog.sportScoreSlug(root.cfg_league || "english-premier-league"));
                if (model.length > 0 && currentIndex < 0)
                    currentIndex = 0;
                root.cfg_league = currentValue || "";
                root.refreshFavoriteModel();
            }
            onActivated: {
                root.cfg_league = currentValue;
                root.refreshFavoriteModel();
            }
        }

        ComboBox {
            id: favoriteTeam

            Kirigami.FormData.label: i18nc("@label:listbox", "Favorite team:")
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: ProviderCatalog.favoriteTeamOptions(root.cfg_league || "english-premier-league")
            Component.onCompleted: {
                currentIndex = root.indexFor(model, root.cfg_favoriteTeam);
                if (currentIndex < 0)
                    currentIndex = 0;
            }
            onActivated: root.cfg_favoriteTeam = currentValue
        }

        CheckBox {
            id: prioritizePopular

            text: i18nc("@option:check", "Show popular matches first")
        }

    }

}
