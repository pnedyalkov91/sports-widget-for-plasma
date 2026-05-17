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

ColumnLayout {
    id: root

    property var configRoot
    property int renameIndex: -1
    property int deleteIndex: -1

    signal addSportRequested()

    spacing: Kirigami.Units.smallSpacing

    function parseEntry(entryJson) {
        try {
            const parsed = JSON.parse(entryJson || "{}");
            return parsed && typeof parsed === "object" ? parsed : {};
        } catch (error) {
            return {};
        }
    }

    function rebuildModel() {
        savedLeagueModel.clear();
        const saved = root.configRoot ? root.configRoot.savedLeagues() : [];
        saved.forEach(entry => {
            const safeEntry = Object.assign({}, entry || {});
            const parts = [SportVisuals.label(safeEntry.sport), root.configRoot.displayCountryLabel(safeEntry)];
            const favorite = root.configRoot.displayFavoriteTeam(safeEntry);
            if (favorite.length > 0)
                parts.push(i18nc("@label", "Favorite: %1", favorite));

            savedLeagueModel.append({
                entryJson: JSON.stringify(safeEntry),
                leagueLabel: root.configRoot.displayLeagueLabel(safeEntry),
                metaLabel: parts.filter(part => String(part || "").length > 0).join(" · "),
                countryIcon: safeEntry.countryIcon || root.configRoot.countryIconForEntry(safeEntry)
            });
        });
    }

    function applyModelOrder() {
        if (!root.configRoot)
            return;

        const previousSaved = root.configRoot.savedLeagues();
        const previousActive = previousSaved[root.configRoot.cfg_activeSavedLeagueIndex] || null;
        let reordered = [];
        for (let index = 0; index < savedLeagueModel.count; index += 1)
            reordered.push(root.parseEntry(savedLeagueModel.get(index).entryJson));

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

    onConfigRootChanged: rebuildModel()
    Component.onCompleted: rebuildModel()

    Connections {
        target: root.configRoot
        ignoreUnknownSignals: true

        function onCfg_savedLeaguesChanged() {
            root.rebuildModel();
        }
    }

    ListModel {
        id: savedLeagueModel
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            text: i18nc("@title:group", "Saved Leagues")
            level: 4
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.separatorColor
            opacity: 0.6
        }

        Button {
            icon.name: "list-add"
            text: i18nc("@action:button", "Add Sport")
            onClicked: root.addSportRequested()
        }
    }

    Label {
        Layout.fillWidth: true
        visible: root.configRoot && root.configRoot.savedLeagues().length === 0
        text: i18nc("@info", "Save leagues here to switch quickly between them with their favorite team.")
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
        model: savedLeagueModel

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
            required property string entryJson
            required property string leagueLabel
            required property string metaLabel
            required property string countryIcon

            width: savedLeagueList.width
            implicitHeight: savedDelegate.implicitHeight

            readonly property var entryData: root.parseEntry(entryJson)
            readonly property bool active: root.configRoot && root.configRoot.sameEntry(entryData, root.configRoot.currentEntry())

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
                onClicked: root.configRoot.applySavedLeague(savedDelegateRoot.entryData, savedDelegateRoot.index)

                background: Rectangle {
                    radius: 4
                    color: savedDelegateRoot.active ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.24) : savedDelegate.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.10) : "transparent"
                    border.color: savedDelegateRoot.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.separatorColor
                    border.width: savedDelegateRoot.active ? 1 : 0
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
                                savedLeagueModel.move(oldIndex, newIndex, 1);
                        }
                        onDropped: root.applyModelOrder()
                    }

                    CountryFlag {
                        Layout.alignment: Qt.AlignVCenter
                        sourceUrl: savedDelegateRoot.countryIcon
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            Layout.fillWidth: true
                            text: savedDelegateRoot.leagueLabel
                            color: Kirigami.Theme.textColor
                            font.bold: savedDelegateRoot.active
                            elide: Text.ElideRight
                        }

                        Label {
                            Layout.fillWidth: true
                            text: savedDelegateRoot.metaLabel
                            color: Kirigami.Theme.disabledTextColor
                            elide: Text.ElideRight
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }
                    }

                    ToolButton {
                        icon.name: "edit-rename"
                        display: AbstractButton.IconOnly
                        text: i18nc("@action:button", "Rename")
                        ToolTip.visible: hovered
                        ToolTip.text: i18nc("@info:tooltip", "Rename saved league labels")
                        onClicked: root.openRenameDialog(savedDelegateRoot.index, savedDelegateRoot.entryData)
                    }

                    ToolButton {
                        icon.name: "configure"
                        display: AbstractButton.IconOnly
                        text: i18nc("@action:button", "Edit")
                        ToolTip.visible: hovered
                        ToolTip.text: i18nc("@info:tooltip", "Change sport, country, league or favorite team")
                        onClicked: root.configRoot.openEditSavedLeague(savedDelegateRoot.entryData, savedDelegateRoot.index)
                    }

                    ToolButton {
                        icon.name: "edit-delete"
                        display: AbstractButton.IconOnly
                        text: i18nc("@action:button", "Delete")
                        ToolTip.visible: hovered
                        ToolTip.text: i18nc("@info:tooltip", "Remove saved league")
                        onClicked: root.requestRemoveSavedLeague(savedDelegateRoot.index)
                    }
                }
            }
        }
    }

    Dialog {
        id: renameDialog

        modal: true
        title: i18nc("@title:window", "Rename Saved League")
        standardButtons: Dialog.Ok | Dialog.Cancel

        GridLayout {
            columns: 2
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.largeSpacing

            Label {
                text: i18nc("@label:textbox", "League:")
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
                text: i18nc("@label:textbox", "Team:")
            }

            TextField {
                id: favoriteNameField

                Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                selectByMouse: true
                placeholderText: i18nc("@info:placeholder", "No favorite team")
            }
        }

        onAccepted: root.configRoot.renameSavedLeague(root.renameIndex, leagueNameField.text, countryNameField.text, favoriteNameField.text)
    }

    Kirigami.Dialog {
        id: deleteLastLeagueDialog

        title: i18nc("@title:window", "Remove last league?")
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
                    text: i18nc("@info", "Are you sure? This is your last saved league. If you remove it, the widget will no longer show sports information.")
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
}
