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
import "../../code/SportsApi.js" as SportsApi
import "../../code/providers/ProviderCountries.js" as ProviderCountries
import "../../code/providers/SportScoreSports.js" as SportScoreSports
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var configRoot
    property int deleteIndex: -1
    signal addRequested()

    spacing: Kirigami.Units.largeSpacing

    function parseEntry(entryJson) {
        try {
            const parsed = JSON.parse(entryJson || "{}");
            return parsed && typeof parsed === "object" ? parsed : {};
        } catch (error) {
            return {};
        }
    }

    function entryType(entry) {
        return root.configRoot ? root.configRoot.entryType(entry) : "competition";
    }

    function entryIsNationalTeam(entry) {
        entry = entry || {};
        if (entry.isNationalTeam === true)
            return true;

        const country = String(entry.country || "").trim().toLowerCase();
        const detectedCountry = ProviderCountries.nationalTeamCountry(entry.favoriteTeam);
        return country.length > 0 && detectedCountry === country;
    }

    function teamVisualSource(entry, providerBadge) {
        providerBadge = String(providerBadge || "").trim();
        if (!root.configRoot || root.configRoot.cfg_nationalTeamVisualStyle !== "flags" || !root.entryIsNationalTeam(entry))
            return providerBadge;

        const storedFlag = String(entry && entry.teamFlag || "").trim();
        if (storedFlag.indexOf("file://") === 0)
            return storedFlag;

        const countryFlag = String(root.configRoot.countryIconForEntry(entry) || "").trim();
        return countryFlag.indexOf("file://") === 0 ? countryFlag : providerBadge;
    }

    function appendEntry(model, entry, sourceIndex) {
        const safeEntry = Object.assign({}, entry || {});
        const type = root.entryType(safeEntry);
        const providerTeamBadge = String(safeEntry.teamBadge || safeEntry.crest || "").trim();
        const teamBadge = root.teamVisualSource(safeEntry, providerTeamBadge);
        const parts = [SportVisuals.label(safeEntry.sport), root.configRoot.displayCountryLabel(safeEntry)];
        if (type === "team") {
            parts.push(SportScoreSports.usesPlayers(safeEntry.sport) ? i18nc("@label", "Player") : i18nc("@label", "Team"));
            parts.push(i18nc("@label", "All competitions"));
        } else {
            parts.push(i18nc("@label", "Competition"));
            const favorite = root.configRoot.displayFavoriteTeam(safeEntry);
            if (favorite.length > 0)
                parts.push(i18nc("@label", "Highlight: %1", favorite));
        }

        model.append({
            entryJson: JSON.stringify(safeEntry),
            sourceIndex,
            entryType: type,
            sportValue: SportVisuals.normalizedSport(safeEntry.sport),
            sportLabel: SportVisuals.label(safeEntry.sport),
            titleLabel: root.configRoot.displaySavedTitle(safeEntry),
            metaLabel: parts.filter(part => String(part || "").length > 0).join(" · "),
            countryIcon: safeEntry.countryIcon || root.configRoot.countryIconForEntry(safeEntry),
            leagueBadge: String(safeEntry.leagueBadge || "").trim(),
            teamBadge,
            includeLive: safeEntry.includeLive !== false,
            includeSchedules: safeEntry.includeSchedules !== false,
            includeRecent: safeEntry.includeRecent !== false,
            includeTables: safeEntry.includeTables !== false && SportScoreSports.supportsStandings(safeEntry.sport),
            includePanel: safeEntry.includePanel !== false,
            includeTooltip: safeEntry.includeTooltip !== false,
            supportsTables: SportScoreSports.supportsStandings(safeEntry.sport)
        });

        if (type === "team" && teamBadge.length === 0)
            root.fetchTeamBadge(model, safeEntry, sourceIndex);
    }

    function setModelTeamBadge(model, sourceIndex, badge) {
        badge = String(badge || "").trim();
        if (badge.length === 0)
            return;

        for (let index = 0; index < model.count; index += 1) {
            if (model.get(index).sourceIndex === sourceIndex) {
                model.setProperty(index, "teamBadge", badge);
                if (root.configRoot) {
                    const saved = root.configRoot.savedLeagues();
                    if (sourceIndex >= 0 && sourceIndex < saved.length) {
                        if (String(saved[sourceIndex].teamBadge || "").trim() !== badge) {
                            saved[sourceIndex].teamBadge = badge;
                            root.configRoot.saveLeagues(saved);
                        }
                    }
                }
                return;
            }
        }
    }

    WizardCache {
        id: badgeCache
    }

    function fetchTeamBadge(model, entry, sourceIndex) {
        // Team badges are static, so serve a cached one and skip the (team-page)
        // request entirely.
        const cacheKey = "badge|" + (entry.sport || "football") + "|"
            + (entry.teamSlug || entry.favoriteTeam || "") + "|" + (entry.country || "");
        const cached = badgeCache.read(cacheKey);
        if (cached && typeof cached.value === "string" && cached.value.length > 0) {
            root.setModelTeamBadge(model, sourceIndex, cached.value);
            return;
        }

        SportsApi.fetchTeamBadge({
            "sports": entry.sport || "football",
            "country": entry.country || "",
            "favoriteTeam": entry.favoriteTeam || "",
            "teamSlug": entry.teamSlug || "",
            "teamPath": entry.teamPath || entry.teamUrl || ""
        }, badge => {
            badge = String(badge || "").trim();
            if (badge.length > 0) {
                badgeCache.write(cacheKey, badge);
                root.setModelTeamBadge(model, sourceIndex, badge);
            }
        });
    }

    function rebuildModel() {
        competitionModel.clear();
        teamModel.clear();
        if (!root.configRoot)
            return;

        const saved = root.configRoot.savedLeagues();
        let sports = [];
        saved.forEach(entry => {
            const sport = SportVisuals.normalizedSport(entry && entry.sport);
            if (sport.length > 0 && sports.indexOf(sport) < 0)
                sports.push(sport);
        });
        sports.forEach(sport => {
            saved.forEach((entry, index) => {
                if (SportVisuals.normalizedSport(entry && entry.sport) !== sport)
                    return;
                if (root.entryType(entry) === "team")
                    root.appendEntry(teamModel, entry, index);
                else
                    root.appendEntry(competitionModel, entry, index);
            });
        });
    }

    function modelEntries(model) {
        let entries = [];
        for (let index = 0; index < model.count; index += 1)
            entries.push(root.parseEntry(model.get(index).entryJson));
        return entries;
    }

    function applyModelOrder() {
        if (!root.configRoot)
            return;

        const previousSaved = root.configRoot.savedLeagues();
        const previousActive = previousSaved[root.configRoot.cfg_activeSavedLeagueIndex] || null;
        const reordered = root.modelEntries(competitionModel).concat(root.modelEntries(teamModel));
        root.configRoot.saveLeagues(reordered);

        if (!previousActive)
            return;

        for (let index = 0; index < reordered.length; index += 1) {
            if (root.configRoot.sameEntry(reordered[index], previousActive)) {
                root.configRoot.cfg_activeSavedLeagueIndex = index;
                return;
            }
        }
    }

    function requestRemoveSavedLeague(index) {
        if (!root.configRoot)
            return;

        if (root.configRoot.savedLeagues().length === 1) {
            root.deleteIndex = index;
            deleteLastLeagueDialog.open();
            return;
        }

        root.configRoot.removeSavedLeague(index);
    }

    function setDelegateInclude(listModel, rowIndex, sourceIndex, key, enabled) {
        if (!root.configRoot)
            return;

        root.configRoot.setEntryIncludes(sourceIndex, key, enabled);
        if (listModel && rowIndex >= 0 && rowIndex < listModel.count) {
            listModel.setProperty(rowIndex, key, Boolean(enabled));
            const entry = root.parseEntry(listModel.get(rowIndex).entryJson);
            entry[key] = Boolean(enabled);
            listModel.setProperty(rowIndex, "entryJson", JSON.stringify(entry));
        }
    }

    onConfigRootChanged: rebuildModel()
    Component.onCompleted: rebuildModel()

    Connections {
        target: root.configRoot
        ignoreUnknownSignals: true

        function onCfg_savedLeaguesChanged() {
            root.rebuildModel();
        }

        function onCfg_nationalTeamVisualStyleChanged() {
            root.rebuildModel();
        }
    }

    ListModel {
        id: competitionModel
    }

    ListModel {
        id: teamModel
    }

    SavedSection {
        Layout.fillWidth: true
        title: i18nc("@title:group", "Saved Competitions")
        addText: i18nc("@action:button", "Add")
        emptyText: i18nc("@info", "Save tournaments, leagues or cups here.")
        listModel: competitionModel
        onAddRequested: root.addRequested()
    }

    SavedSection {
        Layout.fillWidth: true
        title: i18nc("@title:group", "Saved Teams")
        addText: ""
        emptyText: i18nc("@info", "Save teams here to follow them across competitions.")
        listModel: teamModel
    }

    Kirigami.Dialog {
        id: deleteLastLeagueDialog

        title: i18nc("@title:window", "Remove last saved sport?")
        standardButtons: Kirigami.Dialog.NoButton
        leftPadding: Kirigami.Units.gridUnit * 2
        rightPadding: Kirigami.Units.gridUnit * 2
        topPadding: Kirigami.Units.gridUnit
        bottomPadding: Kirigami.Units.gridUnit

        contentItem: Item {
            implicitWidth: Kirigami.Units.gridUnit * 22
            implicitHeight: deleteLastLeagueColumn.implicitHeight

            ColumnLayout {
                id: deleteLastLeagueColumn

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                    source: "edit-delete"
                    isMask: true
                    color: Kirigami.Theme.negativeTextColor
                }

                Label {
                    Layout.fillWidth: true
                    text: i18nc("@info", "Are you sure? This is your last saved sport. If you remove it, the widget will no longer show sports information.")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Item {
                    Layout.preferredHeight: Kirigami.Units.smallSpacing
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Kirigami.Units.mediumSpacing

                    Button {
                        icon.name: "edit-delete"
                        text: i18nc("@action:button", "Yes, remove it")
                        onClicked: {
                            root.configRoot.removeSavedLeague(root.deleteIndex);
                            root.deleteIndex = -1;
                            deleteLastLeagueDialog.close();
                        }
                    }

                    Button {
                        icon.name: "dialog-cancel"
                        text: i18nc("@action:button", "Cancel")
                        onClicked: {
                            root.deleteIndex = -1;
                            deleteLastLeagueDialog.close();
                        }
                    }
                }

                Item {
                    Layout.preferredHeight: Kirigami.Units.smallSpacing
                }
            }
        }

        onClosed: root.deleteIndex = -1
    }

    component SavedSection: ColumnLayout {
        id: sectionRoot

        property string title: ""
        property string addText: ""
        property string emptyText: ""
        property var listModel

        signal addRequested()

        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                text: sectionRoot.title
                level: 4
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.disabledTextColor
                opacity: 0.6
            }

            Button {
                visible: sectionRoot.addText.length > 0
                icon.name: "list-add"
                text: sectionRoot.addText
                onClicked: sectionRoot.addRequested()
            }
        }

        Label {
            Layout.fillWidth: true
            visible: sectionRoot.listModel && sectionRoot.listModel.count === 0
            text: sectionRoot.emptyText
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
        }

        ListView {
            id: savedLeagueList

            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            interactive: false
            reuseItems: false
            clip: false
            spacing: Kirigami.Units.smallSpacing
            model: sectionRoot.listModel
            section.property: "sportLabel"
            section.criteria: ViewSection.FullString
            section.delegate: RowLayout {
                required property string section

                width: savedLeagueList.width
                height: Kirigami.Units.gridUnit * 1.8
                spacing: Kirigami.Units.smallSpacing

                Label {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Layout.preferredWidth
                    text: SportVisuals.emoji(section)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Math.round(Kirigami.Units.iconSizes.small * 0.8)
                }

                Label {
                    text: section
                    font.bold: true
                    color: Kirigami.Theme.textColor
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Kirigami.Theme.disabledTextColor
                    opacity: 0.35
                }
            }

            moveDisplaced: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }
            displaced: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }

            delegate: Item {
                id: savedDelegateRoot

                required property int index
                required property int sourceIndex
                required property string entryJson
                required property string titleLabel
                required property string metaLabel
                required property string countryIcon
                required property string leagueBadge
                required property string entryType
                required property string sportValue
                required property string sportLabel
                required property string teamBadge
                required property bool includeLive
                required property bool includeSchedules
                required property bool includeRecent
                required property bool includeTables
                required property bool includePanel
                required property bool includeTooltip
                required property bool supportsTables

                width: savedLeagueList.width
                implicitHeight: savedDelegate.implicitHeight

                ItemDelegate {
                    id: savedDelegate

                    width: parent.width
                    implicitHeight: Math.max(Kirigami.Units.gridUnit * 2.6, savedContent.implicitHeight + Kirigami.Units.smallSpacing * 2)
                    topPadding: Kirigami.Units.smallSpacing
                    bottomPadding: Kirigami.Units.smallSpacing
                    leftPadding: Kirigami.Units.smallSpacing
                    rightPadding: Kirigami.Units.smallSpacing
                    hoverEnabled: true
                    down: false

                    background: Rectangle {
                        radius: 4
                        color: savedDelegate.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.10) : "transparent"
                        border.color: "transparent"
                        border.width: 0
                    }

                    contentItem: RowLayout {
                        id: savedContent

                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.ListItemDragHandle {
                            Layout.alignment: Qt.AlignVCenter
                            listItem: savedDelegate
                            listView: savedLeagueList
                            onMoveRequested: function(oldIndex, newIndex) {
                                if (oldIndex !== newIndex)
                                    sectionRoot.listModel.move(oldIndex, newIndex, 1);
                            }
                            onDropped: root.applyModelOrder()
                        }

                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            Layout.minimumWidth: Layout.preferredWidth
                            Layout.maximumWidth: Layout.preferredWidth

                            Image {
                                anchors.fill: parent
                                source: savedDelegateRoot.entryType === "team"
                                    ? savedDelegateRoot.teamBadge
                                    : savedDelegateRoot.leagueBadge
                                visible: source.toString().length > 0
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                sourceSize.width: width
                                sourceSize.height: height
                            }

                            CountryFlag {
                                anchors.fill: parent
                                sourceUrl: savedDelegateRoot.countryIcon
                                visible: savedDelegateRoot.entryType !== "team" && savedDelegateRoot.leagueBadge.length === 0
                            }

                            Kirigami.Icon {
                                anchors.fill: parent
                                source: "im-user"
                                visible: savedDelegateRoot.entryType === "team" && savedDelegateRoot.teamBadge.length === 0
                                color: Kirigami.Theme.disabledTextColor
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                Layout.fillWidth: true
                                text: savedDelegateRoot.titleLabel
                                color: Kirigami.Theme.textColor
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Label {
                                Layout.fillWidth: true
                                text: savedDelegateRoot.metaLabel
                                color: Kirigami.Theme.disabledTextColor
                                elide: Text.ElideRight
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                Switch {
                                    text: i18nc("@label:switch", "Live")
                                    checked: savedDelegateRoot.includeLive
                                    onClicked: root.setDelegateInclude(sectionRoot.listModel, savedDelegateRoot.index, savedDelegateRoot.sourceIndex, "includeLive", checked)
                                }

                                Switch {
                                    text: i18nc("@label:switch", "Schedules")
                                    checked: savedDelegateRoot.includeSchedules
                                    onClicked: root.setDelegateInclude(sectionRoot.listModel, savedDelegateRoot.index, savedDelegateRoot.sourceIndex, "includeSchedules", checked)
                                }

                                Switch {
                                    text: i18nc("@label:switch", "Recent")
                                    checked: savedDelegateRoot.includeRecent
                                    onClicked: root.setDelegateInclude(sectionRoot.listModel, savedDelegateRoot.index, savedDelegateRoot.sourceIndex, "includeRecent", checked)
                                }

                                Switch {
                                    text: i18nc("@label:switch", "Tables")
                                    checked: savedDelegateRoot.includeTables
                                    enabled: savedDelegateRoot.supportsTables
                                    onClicked: root.setDelegateInclude(sectionRoot.listModel, savedDelegateRoot.index, savedDelegateRoot.sourceIndex, "includeTables", checked)
                                }

                                Switch {
                                    text: i18nc("@label:switch", "Panel")
                                    checked: savedDelegateRoot.includePanel
                                    onClicked: root.setDelegateInclude(sectionRoot.listModel, savedDelegateRoot.index, savedDelegateRoot.sourceIndex, "includePanel", checked)
                                }

                                Switch {
                                    text: i18nc("@label:switch", "Tooltip")
                                    checked: savedDelegateRoot.includeTooltip
                                    onClicked: root.setDelegateInclude(sectionRoot.listModel, savedDelegateRoot.index, savedDelegateRoot.sourceIndex, "includeTooltip", checked)
                                }

                                Item {
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        ToolButton {
                            icon.name: "edit-delete"
                            display: AbstractButton.IconOnly
                            text: i18nc("@action:button", "Delete")
                            ToolTip.visible: hovered
                            ToolTip.text: i18nc("@info:tooltip", "Remove saved sport")
                            onClicked: root.requestRemoveSavedLeague(savedDelegateRoot.sourceIndex)
                        }
                    }
                }
            }
        }
    }
}
