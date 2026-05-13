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
    property string cfg_league: Plasmoid.configuration.league
    property string cfg_favoriteTeam: Plasmoid.configuration.favoriteTeam
    readonly property string currentProvider: Plasmoid.configuration.provider || "auto"

    function firstSport() {
        return String(root.cfg_selectedSports || "football").split(",")[0];
    }

    function indexFor(model, value) {
        for (let index = 0; index < model.length; index += 1) {
            if (model[index].value === value)
                return index;

        }
        return 0;
    }

    function refreshLeagueModel() {
        league.model = ProviderCatalog.leagueOptions(root.currentProvider, selectedSports.currentValue);
        league.currentIndex = root.indexFor(league.model, root.cfg_league);
        if (league.model.length > 0 && league.currentIndex < 0)
            league.currentIndex = 0;

        root.cfg_league = league.currentValue || "";
        refreshFavoriteModel();
    }

    function refreshFavoriteModel() {
        favoriteTeam.model = ProviderCatalog.favoriteTeamOptions(root.cfg_league || league.currentValue);
        favoriteTeam.currentIndex = root.indexFor(favoriteTeam.model, root.cfg_favoriteTeam);
        if (favoriteTeam.currentIndex < 0)
            favoriteTeam.currentIndex = 0;

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
                root.cfg_selectedSports = currentValue;
                root.refreshLeagueModel();
            }
            onActivated: {
                root.cfg_selectedSports = currentValue;
                root.refreshLeagueModel();
            }
        }

        ComboBox {
            id: league

            Kirigami.FormData.label: i18nc("@label:listbox", "League:")
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: ProviderCatalog.leagueOptions(root.currentProvider, selectedSports.currentValue || root.firstSport())
            Component.onCompleted: {
                currentIndex = root.indexFor(model, root.cfg_league || "PL");
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
            model: ProviderCatalog.favoriteTeamOptions(root.cfg_league || "PL")
            Component.onCompleted: currentIndex = root.indexFor(model, root.cfg_favoriteTeam)
            onActivated: root.cfg_favoriteTeam = currentValue
        }

        CheckBox {
            id: prioritizePopular

            text: i18nc("@option:check", "Show popular matches first")
        }

    }

}
