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

// Saved sports list: one card per sport, each card holding its own drag-reorderable
// ListView of that sport's saved competitions and teams (in saved order). Per-item
// rows are compact (icon + title + meta + drag handle + edit + remove); the include
// toggles live in a per-item Edit dialog. All persistence goes through the config
// root (ConfigSport.qml).
ColumnLayout {
    id: root

    property var configRoot
    property int deleteIndex: -1
    // Recomputed from savedLeagues(): [{ sportValue, sportLabel, items: [item...] }].
    // Each item is a flat object of the fields a row needs (no nesting in a ListModel).
    property var sportGroups: []
    // sourceIndex -> resolved team badge url (fetched lazily; survives rebuilds).
    property var badgeByIndex: ({})
    // The entry currently open in the Edit dialog.
    property int editIndex: -1
    property var editEntry: ({})

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

    // Flat display item for a saved entry. Stored in a per-card ListModel as plain
    // fields (entryJson re-parsed where the full object is needed); never nested.
    function buildItem(entry, sourceIndex) {
        const safeEntry = Object.assign({}, entry || {});
        const type = root.entryType(safeEntry);
        const providerTeamBadge = String(safeEntry.teamBadge || safeEntry.crest || "").trim();
        const teamBadge = root.teamVisualSource(safeEntry, providerTeamBadge);
        const parts = [root.configRoot.displayCountryLabel(safeEntry)];
        if (type === "team") {
            parts.push(SportScoreSports.usesPlayers(safeEntry.sport) ? i18nc("@label", "Player") : i18nc("@label", "Team"));
        } else {
            parts.push(i18nc("@label", "Competition"));
            const favorite = root.configRoot.displayFavoriteTeam(safeEntry);
            if (favorite.length > 0)
                parts.push(i18nc("@label", "Highlight: %1", favorite));
        }

        return {
            "entryJson": JSON.stringify(safeEntry),
            "sourceIndex": sourceIndex,
            "entryType": type,
            "titleLabel": root.configRoot.displaySavedTitle(safeEntry),
            "metaLabel": parts.filter(part => String(part || "").length > 0).join(" · "),
            "countryIcon": safeEntry.countryIcon || root.configRoot.countryIconForEntry(safeEntry),
            "leagueBadge": String(safeEntry.leagueBadge || "").trim(),
            "teamBadge": teamBadge
        };
    }

    function rebuildGroups() {
        if (!root.configRoot) {
            root.sportGroups = [];
            return;
        }

        const saved = root.configRoot.savedLeagues();
        const order = [];
        const bySport = {};
        saved.forEach((entry, index) => {
            const sport = SportVisuals.normalizedSport(entry && entry.sport);
            if (sport.length === 0)
                return;
            if (!bySport[sport]) {
                bySport[sport] = { "sportValue": sport, "sportLabel": SportVisuals.label(entry.sport), "items": [] };
                order.push(sport);
            }
            bySport[sport].items.push(root.buildItem(entry, index));
        });

        const groups = order.map(sport => bySport[sport]);
        root.sportGroups = groups;

        // Kick off lazy team-badge fetches for items that still lack one.
        groups.forEach(group => group.items.forEach(item => {
            if (item.entryType === "team" && item.teamBadge.length === 0
                    && String(root.badgeByIndex[item.sourceIndex] || "").length === 0)
                root.fetchTeamBadge(root.parseEntry(item.entryJson), item.sourceIndex);
        }));
    }

    function badgeForRow(entryType, sourceIndex, leagueBadge, teamBadge) {
        if (entryType === "team") {
            if (String(teamBadge || "").length > 0)
                return teamBadge;
            return String(root.badgeByIndex[sourceIndex] || "").trim();
        }
        return String(leagueBadge || "").trim();
    }

    WizardCache {
        id: badgeCache
    }

    function setBadge(sourceIndex, badge) {
        badge = String(badge || "").trim();
        if (badge.length === 0)
            return;
        const next = Object.assign({}, root.badgeByIndex);
        next[sourceIndex] = badge;
        root.badgeByIndex = next;

        if (root.configRoot) {
            const saved = root.configRoot.savedLeagues();
            if (sourceIndex >= 0 && sourceIndex < saved.length
                    && String(saved[sourceIndex].teamBadge || "").trim() !== badge) {
                saved[sourceIndex].teamBadge = badge;
                root.configRoot.saveLeagues(saved);
            }
        }
    }

    function fetchTeamBadge(entry, sourceIndex) {
        // Team badges are static, so serve a cached one and skip the request entirely.
        const cacheKey = "badge|" + (entry.sport || "football") + "|"
            + (entry.teamSlug || entry.favoriteTeam || "") + "|" + (entry.country || "");
        const cached = badgeCache.read(cacheKey);
        if (cached && typeof cached.value === "string" && cached.value.length > 0) {
            root.setBadge(sourceIndex, cached.value);
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
                root.setBadge(sourceIndex, badge);
            }
        });
    }

    // Persist a card's new internal order after a drag. `listModel` is the card's
    // model; its rows (in new display order) each carry their original saved index.
    // The reordered entries are written back into the global slots that sport group
    // occupied, so other sports keep their positions. Active selection preserved.
    function persistListModelOrder(listModel) {
        if (!root.configRoot || !listModel)
            return;

        const orderedSourceIndices = [];
        for (let i = 0; i < listModel.count; i += 1)
            orderedSourceIndices.push(listModel.get(i).sourceIndex);
        if (orderedSourceIndices.length === 0)
            return;

        const saved = root.configRoot.savedLeagues();
        const previousActive = saved[root.configRoot.cfg_activeSavedLeagueIndex] || null;

        const slots = orderedSourceIndices.slice().sort((a, b) => a - b);
        const reordered = orderedSourceIndices.map(index => saved[index]);

        const next = saved.slice();
        slots.forEach((slot, position) => { next[slot] = reordered[position]; });
        root.configRoot.saveLeagues(next);

        if (previousActive) {
            for (let index = 0; index < next.length; index += 1) {
                if (root.configRoot.sameEntry(next[index], previousActive)) {
                    root.configRoot.cfg_activeSavedLeagueIndex = index;
                    break;
                }
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

    function openEditDialog(entryJson) {
        const entry = root.parseEntry(entryJson);
        root.editIndex = root.indexOfEntry(entry);
        root.editEntry = entry;
        editDialog.open();
    }

    // Resolve an entry's current index in savedLeagues() by identity.
    function indexOfEntry(entry) {
        if (!root.configRoot)
            return -1;
        const saved = root.configRoot.savedLeagues();
        for (let index = 0; index < saved.length; index += 1) {
            if (root.configRoot.sameEntry(saved[index], entry))
                return index;
        }
        return -1;
    }

    function setEditInclude(key, enabled) {
        if (!root.configRoot || root.editIndex < 0)
            return;
        root.configRoot.setEntryIncludes(root.editIndex, key, enabled);
        const next = Object.assign({}, root.editEntry);
        next[key] = Boolean(enabled);
        root.editEntry = next;
    }

    function editIncludes(key) {
        return root.editEntry && root.editEntry[key] !== false;
    }

    onConfigRootChanged: rebuildGroups()
    Component.onCompleted: rebuildGroups()

    Connections {
        target: root.configRoot
        ignoreUnknownSignals: true

        function onCfg_savedLeaguesChanged() {
            root.rebuildGroups();
        }

        function onCfg_nationalTeamVisualStyleChanged() {
            root.rebuildGroups();
        }
    }

    // ── Empty state ─────────────────────────────────────────────────────────────
    Kirigami.PlaceholderMessage {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        visible: root.sportGroups.length === 0
        icon.name: "applications-sports-symbolic"
        text: i18nc("@info:placeholder", "No sports added yet")
        explanation: i18nc("@info", "Add a sport to follow its competitions and teams.")

        helpfulAction: Kirigami.Action {
            icon.name: "list-add"
            text: i18nc("@action:button", "Add Sport")
            onTriggered: root.addRequested()
        }
    }

    // ── One card per sport ──────────────────────────────────────────────────────
    Repeater {
        model: root.sportGroups

        delegate: Kirigami.AbstractCard {
            id: sportCard

            required property var modelData

            Layout.fillWidth: true

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Label {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Layout.preferredWidth
                        text: SportVisuals.emoji(sportCard.modelData.sportValue)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Math.round(Kirigami.Units.iconSizes.small * 0.9)
                    }

                    Kirigami.Heading {
                        text: sportCard.modelData.sportLabel
                        level: 3
                    }

                    Item { Layout.fillWidth: true }

                    ToolButton {
                        icon.name: "list-add"
                        text: i18nc("@action:button", "Add")
                        display: AbstractButton.TextBesideIcon
                        onClicked: root.addRequested()
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                ListModel {
                    id: cardItemModel
                }

                // Populate this card's drag model from its group's items as flat
                // fields (QML ListModel flattens nested objects, so never store one).
                function rebuildCardModel() {
                    cardItemModel.clear();
                    const items = sportCard.modelData.items || [];
                    for (let i = 0; i < items.length; i += 1)
                        cardItemModel.append(items[i]);
                }

                Component.onCompleted: rebuildCardModel()

                ListView {
                    id: cardListView

                    Layout.fillWidth: true
                    Layout.preferredHeight: contentHeight
                    interactive: false
                    reuseItems: false
                    clip: false
                    spacing: Kirigami.Units.smallSpacing
                    model: cardItemModel

                    moveDisplaced: Transition {
                        NumberAnimation { properties: "y"; duration: 120; easing.type: Easing.OutQuad }
                    }
                    displaced: Transition {
                        NumberAnimation { properties: "y"; duration: 120; easing.type: Easing.OutQuad }
                    }

                    // Delegate root is a plain Item with a stable width/implicitHeight,
                    // as Kirigami.ListItemDragHandle requires (otherwise drags overlap).
                    delegate: Item {
                        id: rowRoot

                        required property int index
                        required property int sourceIndex
                        required property string entryJson
                        required property string entryType
                        required property string titleLabel
                        required property string metaLabel
                        required property string countryIcon
                        required property string leagueBadge
                        required property string teamBadge

                        width: cardListView.width
                        implicitHeight: rowDelegate.implicitHeight

                        ItemDelegate {
                            id: rowDelegate

                            width: parent.width
                            implicitHeight: Math.max(Kirigami.Units.gridUnit * 2.4, rowContent.implicitHeight + Kirigami.Units.smallSpacing * 2)
                            topPadding: Kirigami.Units.smallSpacing
                            bottomPadding: Kirigami.Units.smallSpacing
                            leftPadding: Kirigami.Units.smallSpacing
                            rightPadding: Kirigami.Units.smallSpacing
                            hoverEnabled: true
                            down: false

                            background: Rectangle {
                                radius: 4
                                color: rowDelegate.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.10) : "transparent"
                            }

                            contentItem: RowLayout {
                                id: rowContent

                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.ListItemDragHandle {
                                    Layout.alignment: Qt.AlignVCenter
                                    listItem: rowRoot
                                    listView: cardListView
                                    onMoveRequested: function(oldIndex, newIndex) {
                                        if (oldIndex !== newIndex)
                                            cardItemModel.move(oldIndex, newIndex, 1);
                                    }
                                    onDropped: root.persistListModelOrder(cardItemModel)
                                }

                                Item {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                    Layout.minimumWidth: Layout.preferredWidth
                                    Layout.maximumWidth: Layout.preferredWidth

                                    Image {
                                        anchors.fill: parent
                                        source: root.badgeForRow(rowRoot.entryType, rowRoot.sourceIndex, rowRoot.leagueBadge, rowRoot.teamBadge)
                                        visible: source.toString().length > 0
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        sourceSize.width: width
                                        sourceSize.height: height
                                    }

                                    CountryFlag {
                                        anchors.fill: parent
                                        sourceUrl: rowRoot.countryIcon
                                        visible: rowRoot.entryType !== "team"
                                            && root.badgeForRow(rowRoot.entryType, rowRoot.sourceIndex, rowRoot.leagueBadge, rowRoot.teamBadge).length === 0
                                    }

                                    Kirigami.Icon {
                                        anchors.fill: parent
                                        source: "im-user"
                                        visible: rowRoot.entryType === "team"
                                            && root.badgeForRow(rowRoot.entryType, rowRoot.sourceIndex, rowRoot.leagueBadge, rowRoot.teamBadge).length === 0
                                        color: Kirigami.Theme.disabledTextColor
                                    }
                                }

                                ColumnLayout {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        Layout.fillWidth: true
                                        text: rowRoot.titleLabel
                                        color: Kirigami.Theme.textColor
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: rowRoot.metaLabel
                                        color: Kirigami.Theme.disabledTextColor
                                        elide: Text.ElideRight
                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    }
                                }

                                ToolButton {
                                    icon.name: "document-edit"
                                    display: AbstractButton.IconOnly
                                    text: i18nc("@action:button", "Edit")
                                    ToolTip.visible: hovered
                                    ToolTip.text: i18nc("@info:tooltip", "Edit what this item shows")
                                    onClicked: root.openEditDialog(rowRoot.entryJson)
                                }

                                ToolButton {
                                    icon.name: "edit-delete"
                                    display: AbstractButton.IconOnly
                                    text: i18nc("@action:button", "Remove")
                                    ToolTip.visible: hovered
                                    ToolTip.text: i18nc("@info:tooltip", "Remove saved sport")
                                    onClicked: root.requestRemoveSavedLeague(rowRoot.sourceIndex)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Per-item Edit dialog (include toggles) ──────────────────────────────────
    Kirigami.Dialog {
        id: editDialog

        title: i18nc("@title:window", "Edit %1", String(root.editEntry.favoriteTeam || (root.configRoot ? root.configRoot.displaySavedTitle(root.editEntry) : "") || ""))
        standardButtons: Kirigami.Dialog.Ok
        leftPadding: Kirigami.Units.gridUnit
        rightPadding: Kirigami.Units.gridUnit
        topPadding: Kirigami.Units.gridUnit
        bottomPadding: Kirigami.Units.gridUnit

        readonly property bool supportsTables: SportScoreSports.supportsStandings(root.editEntry.sport)

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            Label {
                Layout.fillWidth: true
                text: i18nc("@info", "Choose what this item contributes to the widget.")
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
            }

            Switch {
                text: i18nc("@option:check", "Live matches")
                checked: root.editIncludes("includeLive")
                onToggled: root.setEditInclude("includeLive", checked)
            }

            Switch {
                text: i18nc("@option:check", "Schedules")
                checked: root.editIncludes("includeSchedules")
                onToggled: root.setEditInclude("includeSchedules", checked)
            }

            Switch {
                text: i18nc("@option:check", "Recent results")
                checked: root.editIncludes("includeRecent")
                onToggled: root.setEditInclude("includeRecent", checked)
            }

            Switch {
                text: i18nc("@option:check", "League tables")
                enabled: editDialog.supportsTables
                checked: editDialog.supportsTables && root.editIncludes("includeTables")
                onToggled: root.setEditInclude("includeTables", checked)
            }

            Switch {
                text: i18nc("@option:check", "Panel")
                checked: root.editIncludes("includePanel")
                onToggled: root.setEditInclude("includePanel", checked)
            }

            Switch {
                text: i18nc("@option:check", "Tooltip")
                checked: root.editIncludes("includeTooltip")
                onToggled: root.setEditInclude("includeTooltip", checked)
            }
        }
    }

    // ── Remove-last confirmation ────────────────────────────────────────────────
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
            }
        }
    }
}
