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
import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import "../../code/providers/SportScoreSports.js" as SportScoreSports

// Country detail subpage: a grid of the country's competitions as cards. Tapping
// a card opens the league subpage (follow the whole competition or its teams).
// Opened as a full-page overlay from the country cards in the Browse flow.
Item {
    id: root

    required property var configRoot
    required property string country
    property string countryLabel: ""
    property url flag: ""

    readonly property string sport: root.configRoot ? root.configRoot.normalizedSport() : ""
    readonly property int cardMinimumWidth: Kirigami.Units.gridUnit * 11
    readonly property int headerIconSize: Kirigami.Units.iconSizes.large

    property var competitions: []
    property bool loading: false
    property string loadError: ""
    // True only when the provider request itself failed (network/timeout), as
    // opposed to a successful-but-empty result — drives the "try again" error.
    property bool loadFailed: false
    property int requestToken: 0
    property var emblems: ({ "competitions": {}, "teams": {} })

    Component.onCompleted: {
        root.loadEmblems();
        root.loadCompetitions();
    }

    WizardCache {
        id: wizardCache
    }

    function applyEmblemMap(map) {
        if (map && typeof map === "object")
            root.emblems = map;
    }

    function loadEmblems() {
        if (root.sport.length === 0)
            return;

        const cacheKey = "emblems|" + root.sport;
        const cached = wizardCache.read(cacheKey);
        if (cached && cached.value && typeof cached.value === "object") {
            root.applyEmblemMap(cached.value);
            if (cached.fresh)
                return;
        }

        SportsApi.fetchPopularEmblems({ "sports": root.sport }, map => {
            if (map && typeof map === "object") {
                wizardCache.write(cacheKey, map);
                root.applyEmblemMap(map);
            }
        });
    }

    function competitionEmblem(comp) {
        const key = String(comp && comp.label || "").trim().toLowerCase();
        return root.emblems && root.emblems.competitions && root.emblems.competitions[key]
            ? String(root.emblems.competitions[key]) : "";
    }

    function mapLeagueRows(rows) {
        return (Array.isArray(rows) ? rows : []).map(row => ({
            "label": ProviderCatalog.normalizedCompetitionLabel(
                String(row && row.label || "").trim(),
                String(row && (row.slug || row.value) || "").trim()
            ),
            "value": String(row && (row.value || row.slug || row.label) || "").trim(),
            "slug": String(row && (row.slug || row.value) || "").trim(),
            "country": String(row && row.country || root.country).trim(),
            "path": String(row && row.path || "").trim(),
            "url": String(row && row.url || "").trim()
        })).filter(row => row.label.length > 0 && row.value.length > 0);
    }

    function loadCompetitions() {
        if (!root.configRoot || root.sport.length === 0 || root.country.length === 0)
            return;

        const token = root.requestToken + 1;
        root.requestToken = token;

        // Render instantly from the local cache; only hit the network when the
        // cache is missing or stale, and keep the cached list if the fetch fails.
        const cacheKey = "competitions|" + root.sport + "|" + root.country;
        const cached = wizardCache.read(cacheKey);
        const hasCache = cached && Array.isArray(cached.value) && cached.value.length > 0;
        if (hasCache) {
            root.competitions = root.mapLeagueRows(cached.value);
            if (cached.fresh)
                return;
        }

        root.loading = true;
        root.loadError = "";
        root.loadFailed = false;
        SportsApi.fetchCountryCompetitions({
            "provider": root.configRoot.currentProvider,
            "sports": root.sport,
            "country": root.country
        }, rows => {
            if (token !== root.requestToken)
                return;
            root.loading = false;
            root.loadFailed = false;
            if (Array.isArray(rows) && rows.length > 0) {
                wizardCache.write(cacheKey, rows);
                root.competitions = root.mapLeagueRows(rows);
            } else if (!hasCache) {
                root.competitions = [];
                root.loadError = i18nc("@info", "No leagues or cups were found for this country.");
            }
        }, message => {
            if (token !== root.requestToken)
                return;
            root.loading = false;
            // The provider failed (and ESPN could not cover this) — keep any cached
            // list and surface a retry message.
            if (!hasCache)
                root.loadFailed = true;
        });
    }

    // Opaque backdrop so the underlying wizard (and its buttons) are hidden.
    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            ToolButton {
                icon.name: "go-previous"
                text: i18nc("@action:button", "Back")
                display: AbstractButton.IconOnly
                onClicked: {
                    if (root.configRoot)
                        root.configRoot.closeCountryPage();
                }
            }

            Image {
                Layout.preferredWidth: root.headerIconSize
                Layout.preferredHeight: root.headerIconSize
                source: root.flag
                visible: source.toString().length > 0
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: width
                sourceSize.height: height
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 2
                text: root.countryLabel.length > 0 ? root.countryLabel : root.country
                elide: Text.ElideRight
            }

            ToolButton {
                icon.name: "dialog-close"
                text: i18nc("@action:button", "Close")
                display: AbstractButton.IconOnly
                onClicked: {
                    if (root.configRoot)
                        root.configRoot.closeCountryPage();
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
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
                    type: Kirigami.MessageType.Information
                    text: i18nc("@info", "Open a competition to follow the whole competition or pick teams inside it. Changes are saved when you click Apply (or OK).")
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    // Only football/basketball/cricket/tennis use SportScore; other
                    // sports are ESPN-only, so don't blame SportScore there.
                    // Hidden while (re)loading so "Try again" shows progress first.
                    visible: root.loadFailed && !root.loading && SportScoreSports.supports(root.sport)
                    type: Kirigami.MessageType.Error
                    text: i18nc("@info", "SportScore is not responding right now, so this country's competitions could not be loaded. Please try again later.")
                    actions: [
                        Kirigami.Action {
                            icon.name: "view-refresh"
                            text: i18nc("@action:button", "Try again")
                            onTriggered: root.loadCompetitions()
                        }
                    ]
                }

                Kirigami.Heading {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    level: 4
                    text: i18nc("@title:group", "Competitions")
                    visible: root.competitions.length > 0
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.loading
                    spacing: Kirigami.Units.smallSpacing

                    BusyIndicator {
                        running: parent.visible
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }

                    Label {
                        text: i18nc("@info", "Loading competitions from provider…")
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    visible: root.competitions.length > 0
                    columns: Math.max(1, Math.floor((width + columnSpacing) / (root.cardMinimumWidth + columnSpacing)))
                    columnSpacing: Kirigami.Units.smallSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: root.competitions

                        delegate: SportChoiceCard {
                            required property var modelData

                            title: modelData.label
                            iconSource: root.competitionEmblem(modelData)
                            iconName: "view-calendar-list"
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
                    visible: !root.loading && !root.loadFailed && root.competitions.length === 0
                    text: root.loadError.length > 0
                        ? root.loadError
                        : i18nc("@info", "No competitions found for this country.")
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.WordWrap
                }

                Item {
                    Layout.preferredHeight: Kirigami.Units.gridUnit
                }
            }
        }
    }
}
