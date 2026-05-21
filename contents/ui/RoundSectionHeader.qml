/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: root

    property string text: ""

    function withAlpha(color, alpha) {
        try {
            if (!color || color.r === undefined || color.g === undefined || color.b === undefined)
                return Qt.rgba(0, 0, 0, 0);

            return Qt.rgba(color.r, color.g, color.b, alpha);
        } catch (error) {
            return Qt.rgba(0, 0, 0, 0);
        }
    }

    visible: text.length > 0
    height: visible ? Kirigami.Units.gridUnit * 1.8 : 0

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        visible: root.visible

        PlasmaComponents.Label {
            text: root.text
            color: Kirigami.Theme.disabledTextColor
            font.bold: true
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.withAlpha(Kirigami.Theme.separatorColor, 0.5)
        }
    }
}
