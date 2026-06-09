/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../../code/SportVisuals.js" as SportVisuals
import "../../code/SportsApi.js" as SportsApi
import "../../code/providers/ProviderCatalog.js" as ProviderCatalog
import "../../code/providers/ProviderCountries.js" as ProviderCountries
import "../../code/providers/SportScoreSports.js" as SportScoreSports
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    property var configRoot
    property int renameIndex: -1
    property int deleteIndex: -1
    property string renameType: "competition"
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

    function fetchTeamBadgeFromCountryLeagues(model, entry, sourceIndex) {
        if (!root.configRoot)
            return;

        const favoriteTeam = String(entry.favoriteTeam || "").trim();
        if (favoriteTeam.length === 0)
            return;

        const leagues = ProviderCatalog.leagueOptions(root.configRoot.currentProvider, entry.sport || "football", entry.country || "");
        if (!Array.isArray(leagues) || leagues.length === 0)
            return;

        const maxLookups = Math.min(6, leagues.length);
        let leagueIndex = 0;

        function lookupNextLeague() {
            if (leagueIndex >= maxLookups)
                return;

            const leagueValue = String(leagues[leagueIndex] && leagues[leagueIndex].value || "").trim();
            leagueIndex += 1;
            if (leagueValue.length === 0) {
                lookupNextLeague();
                return;
            }

            SportsApi.fetchLeagueTable({
                "sports": entry.sport || "football",
                "country": entry.country || "",
                "league": leagueValue,
                "favoriteTeam": favoriteTeam,
                "followMode": "league"
            }, rows => {
                const tableRows = Array.isArray(rows) ? rows : [];
                for (let rowIndex = 0; rowIndex < tableRows.length; rowIndex += 1) {
                    const row = tableRows[rowIndex] || {};
                    if (SportsApi.sameTeamName(row.team, favoriteTeam)) {
                        const crest = String(row.crest || row.team_logo || "").trim();
                        if (crest.length > 0) {
                            root.setModelTeamBadge(model, sourceIndex, crest);
                            return;
                        }
                    }
                }

                lookupNextLeague();
            }, () => {
                lookupNextLeague();
            });
        }

        lookupNextLeague();
    }

    function fetchTeamBadge(model, entry, sourceIndex) {
        SportsApi.fetchTeamBadge({
            "sports": entry.sport || "football",
            "country": entry.country || "",
            "favoriteTeam": entry.favoriteTeam || "",
            "teamSlug": entry.teamSlug || "",
            "teamPath": entry.teamPath || entry.teamUrl || ""
        }, badge => {
            badge = String(badge || "").trim();
            if (badge.length > 0) {
                root.setModelTeamBadge(model, sourceIndex, badge);
                return;
            }

            root.fetchTeamBadgeFromCountryLeagues(model, entry, sourceIndex);
        }, () => {
            root.fetchTeamBadgeFromCountryLeagues(model, entry, sourceIndex);
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

    function openRenameDialog(index, entry) {
        root.renameIndex = index;
        root.renameType = root.entryType(entry);
        leagueNameField.text = root.configRoot.displayLeagueLabel(entry);
        countryNameField.text = root.configRoot.displayCountryLabel(entry);
        favoriteNameField.text = root.configRoot.displayFavoriteTeam(entry);
        renameDialog.open();
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

    Dialog {
        id: renameDialog

        modal: true
        title: root.renameType === "team" ? i18nc("@title:window", "Rename Saved Team") : i18nc("@title:window", "Rename Saved Competition")
        standardButtons: Dialog.Ok | Dialog.Cancel

        GridLayout {
            columns: 2
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.largeSpacing

            Label {
                text: i18nc("@label:textbox", "Competition:")
            }

            TextField {
                id: leagueNameField

                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                selectByMouse: true
            }

            Label {
                text: i18nc("@label:textbox", "Country:")
            }

            TextField {
                id: countryNameField

                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                selectByMouse: true
            }

            Label {
                text: root.renameType === "team" ? i18nc("@label:textbox", "Team:") : i18nc("@label:textbox", "Highlighted team:")
            }

            TextField {
                id: favoriteNameField

                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                selectByMouse: true
                placeholderText: root.renameType === "team" ? i18nc("@info:placeholder", "Team name") : i18nc("@info:placeholder", "No highlighted team")
            }
        }

        onAccepted: root.configRoot.renameSavedLeague(root.renameIndex, leagueNameField.text, countryNameField.text, favoriteNameField.text)
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

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Layout.preferredWidth
                    source: Qt.resolvedUrl("../../icons/sports/" + SportVisuals.iconName(section))
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

                readonly property var entryData: root.parseEntry(entryJson)

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
                                source: savedDelegateRoot.entryType === "team" ? savedDelegateRoot.teamBadge : ""
                                visible: source.toString().length > 0
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                sourceSize.width: width
                                sourceSize.height: height
                            }

                            CountryFlag {
                                anchors.fill: parent
                                sourceUrl: savedDelegateRoot.countryIcon
                                visible: savedDelegateRoot.entryType !== "team"
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

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

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
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

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
                        }

                        ToolButton {
                            icon.name: "edit-rename"
                            display: AbstractButton.IconOnly
                            text: i18nc("@action:button", "Rename")
                            ToolTip.visible: hovered
                            ToolTip.text: i18nc("@info:tooltip", "Rename saved labels")
                            onClicked: root.openRenameDialog(savedDelegateRoot.sourceIndex, savedDelegateRoot.entryData)
                        }

                        ToolButton {
                            icon.name: "configure"
                            display: AbstractButton.IconOnly
                            text: i18nc("@action:button", "Edit")
                            ToolTip.visible: hovered
                            ToolTip.text: i18nc("@info:tooltip", "Change this saved sport")
                            onClicked: root.configRoot.openEditSavedLeague(savedDelegateRoot.entryData, savedDelegateRoot.sourceIndex)
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
