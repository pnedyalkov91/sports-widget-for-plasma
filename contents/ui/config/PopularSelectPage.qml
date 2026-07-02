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

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../code/SportsApi.js" as SportsApi
import "../../code/providers/PopularCatalog.js" as PopularCatalog

// "Top in the World" landing page: a grid of top-competition cards. Tapping a
// card opens its league subpage (enable the competition, follow its teams).
// "Browse all" opens the per-country browsing flow.
ColumnLayout {
    id: root

    property var configRoot

    readonly property string sport: root.configRoot ? root.configRoot.normalizedSport() : ""
    readonly property bool browseDisabled: root.configRoot ? root.configRoot.browseDisabled : false
    // Tennis shows its full ATP/WTA list right here, and "Browse all" only leads to
    // an International page with the same two competitions - so hide it for tennis
    // too, just like the fixed-league ESPN-native sports.
    readonly property bool hideBrowse: root.browseDisabled || root.sport === "tennis"
    readonly property var curatedCompetitions: PopularCatalog.popularCompetitions(root.sport)
    // Competitions discovered live from the matches feed (valid slugs). Used for
    // sports without a hand-validated curated list (basketball, cricket, tennis…).
    property var derivedCompetitions: []
    readonly property var popularCompetitions: {
        // Football and tennis have a reliable curated list (tennis = ESPN ATP/WTA),
        // so keep it instead of the flakier SportScore-derived competitions.
        if (root.sport === "football" || root.sport === "tennis")
            return root.curatedCompetitions;
        if (Array.isArray(root.derivedCompetitions) && root.derivedCompetitions.length > 0)
            return root.derivedCompetitions;
        return root.curatedCompetitions;
    }
    readonly property int cardMinimumWidth: Kirigami.Units.gridUnit * 11
    property var emblems: ({
            "competitions": {},
            "teams": {}
        })

    spacing: Kirigami.Units.largeSpacing
    onSportChanged: root.loadEmblems()
    Component.onCompleted: root.loadEmblems()

    WizardCache {
        id: emblemCache
    }

    function applyEmblemMap(map) {
        if (!map || typeof map !== "object")
            return;
        root.emblems = map;
        root.derivedCompetitions = Array.isArray(map.competitionList) ? map.competitionList : [];
    }

    function loadEmblems() {
        if (root.sport.length === 0)
            return;

        const cacheKey = "emblems|" + root.sport;
        const cached = emblemCache.read(cacheKey);
        if (cached && cached.value && typeof cached.value === "object") {
            root.applyEmblemMap(cached.value);
            if (cached.fresh)
                return;
        }

        SportsApi.fetchPopularEmblems({
            "sports": root.sport
        }, map => {
            if (map && typeof map === "object") {
                emblemCache.write(cacheKey, map);
                root.applyEmblemMap(map);
            }
        });
    }

    function competitionEmblem(comp) {
        const direct = String(comp && comp.logo || "").trim();
        if (direct.length > 0)
            return direct;
        const key = String(comp && comp.label || "").trim().toLowerCase();
        return root.emblems && root.emblems.competitions && root.emblems.competitions[key] ? String(root.emblems.competitions[key]) : "";
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            level: 2
            text: i18nc("@title:group", "Top in the World")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: true
            showCloseButton: true
            type: Kirigami.MessageType.Information
            text: i18nc("@info", "The most popular competitions. Open one to follow the competition or pick teams inside it.")
        }
    }

    ScrollView {
        id: scroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: scroll.availableWidth
            spacing: Kirigami.Units.smallSpacing

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: true
                showCloseButton: true
                type: Kirigami.MessageType.Information
                text: root.hideBrowse ? i18nc("@info", "Tap a competition to open it, then enable the whole competition or follow individual teams.") : i18nc("@info", "Tap a competition to open it, then enable the whole competition or follow individual teams. Use Browse all for every country and international competition.")
            }

            Button {
                Layout.fillWidth: true
                visible: !root.hideBrowse
                icon.name: "globe"
                text: i18nc("@action:button", "Browse all leagues & countries…")
                onClicked: {
                    if (root.configRoot)
                        root.configRoot.pageIndex += 1;
                }
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                level: 4
                text: i18nc("@title:group", "Top competitions")
                visible: root.popularCompetitions.length > 0
            }

            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(1, Math.floor((width + columnSpacing) / (root.cardMinimumWidth + columnSpacing)))
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: root.popularCompetitions

                    delegate: SportChoiceCard {
                        required property var modelData

                        title: modelData.label
                        iconSource: root.competitionEmblem(modelData)
                        hideFallbackIcon: true
                        cardToolTipText: i18nc("@info:tooltip", "Open %1", modelData.label)
                        onClicked: {
                            if (root.configRoot)
                                root.configRoot.openLeaguePage(modelData, root.competitionEmblem(modelData));
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                visible: root.popularCompetitions.length === 0
                text: i18nc("@info", "There is no curated top list for this sport yet - use Browse all to pick competitions and teams.")
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
            }

            Item {
                Layout.preferredHeight: Kirigami.Units.gridUnit
            }
        }
    }
}
