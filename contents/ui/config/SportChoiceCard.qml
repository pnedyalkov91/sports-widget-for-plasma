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

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ItemDelegate {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property url iconSource: ""
    property string iconEmoji: ""
    property string flagSource: ""
    property string infoText: ""
    property string cardToolTipText: root.title
    property bool selected: false
    readonly property bool remoteIconSource: {
        const source = root.iconSource.toString();
        return source.indexOf("http://") === 0 || source.indexOf("https://") === 0;
    }
    readonly property color safeHighlightColor: root.themeColorOr(Kirigami.Theme.highlightColor, Qt.rgba(0.25, 0.5, 0.95, 1))
    readonly property color safeAlternateColor: root.themeColorOr(Kirigami.Theme.alternateBackgroundColor, Qt.rgba(0.16, 0.16, 0.16, 1))
    readonly property color safeSeparatorColor: root.themeColorOr(Kirigami.Theme.separatorColor, Qt.rgba(0.5, 0.5, 0.5, 0.35))

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
    Layout.preferredHeight: Kirigami.Units.gridUnit * 2.8
    hoverEnabled: true
    ToolTip.visible: root.hovered && !infoButton.hovered && root.cardToolTipText.length > 0
    ToolTip.text: root.cardToolTipText

    background: Rectangle {
        radius: 6
        color: root.selected ? Qt.rgba(root.safeHighlightColor.r, root.safeHighlightColor.g, root.safeHighlightColor.b, 0.22) : root.hovered ? Qt.rgba(root.safeHighlightColor.r, root.safeHighlightColor.g, root.safeHighlightColor.b, 0.10) : root.safeAlternateColor
        border.color: root.selected ? root.safeHighlightColor : root.safeSeparatorColor
        border.width: 1
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        CountryFlag {
            visible: root.flagSource.length > 0
            sourceUrl: root.flagSource
        }

        Image {
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            visible: root.flagSource.length === 0 && root.iconEmoji.length === 0 && root.remoteIconSource
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize.width: width
            sourceSize.height: height
        }

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            visible: root.flagSource.length === 0 && root.iconEmoji.length === 0 && !root.remoteIconSource
            source: root.iconSource.toString().length > 0 ? root.iconSource : root.iconName
            isMask: root.iconSource.toString().length > 0 && !root.remoteIconSource
            color: root.selected ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        }

        Label {
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            visible: root.flagSource.length === 0 && root.iconEmoji.length > 0
            text: root.iconEmoji
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Math.round(Kirigami.Units.iconSizes.smallMedium * 0.8)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: root.title
                color: Kirigami.Theme.textColor
                font.bold: true
                elide: Text.ElideRight
            }

            Label {
                Layout.fillWidth: true
                text: root.subtitle
                visible: root.subtitle.length > 0
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }

        ToolButton {
            id: infoButton

            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Layout.preferredWidth
            visible: root.infoText.length > 0
            display: AbstractButton.IconOnly
            icon.name: "documentinfo"
            text: i18nc("@action:button", "Information")
            ToolTip.visible: hovered
            ToolTip.text: i18nc("@info:tooltip", "Show tournaments")
            onClicked: {
                infoDialogLoader.active = true;
                infoDialogLoader.item.open();
            }
        }

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Layout.preferredWidth
            source: "dialog-ok-apply"
            opacity: root.selected ? 1 : 0
            color: Kirigami.Theme.highlightColor
        }
    }

    // Loaded on demand: most cards never set infoText, so avoid paying for
    // a Dialog instance (window/overlay machinery) on every card.
    Loader {
        id: infoDialogLoader
        active: false
        sourceComponent: Dialog {
            anchors.centerIn: Overlay.overlay
            modal: true
            title: root.title
            standardButtons: Dialog.Ok

            Label {
                width: Math.min(Kirigami.Units.gridUnit * 26, Overlay.overlay ? Overlay.overlay.width - Kirigami.Units.gridUnit * 4 : Kirigami.Units.gridUnit * 26)
                text: root.infoText
                wrapMode: Text.WordWrap
            }
        }
    }

    function themeColorOr(color, fallback) {
        if (!color || color.r === undefined || color.g === undefined || color.b === undefined)
            return fallback;
        return color;
    }
}
