/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string sourceUrl: ""
    readonly property bool fileImageSource: sourceUrl.indexOf("file://") === 0
    readonly property bool systemL10nPath: sourceUrl.indexOf("file:///usr/share/locale/l10n/") === 0
    readonly property string fallbackFlagEmoji: fallbackEmojiFromSource()

    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
    Layout.preferredHeight: Kirigami.Units.iconSizes.small
    Layout.minimumWidth: Layout.preferredWidth
    Layout.maximumWidth: Layout.preferredWidth
    clip: true
    visible: sourceUrl.length > 0

    Image {
        id: flagImage

        anchors.fill: parent
        source: root.fileImageSource && !root.systemL10nPath ? root.sourceUrl : ""
        visible: root.fileImageSource && !root.systemL10nPath && status !== Image.Error
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: width
        sourceSize.height: height
    }

    Text {
        anchors.centerIn: parent
        visible: root.fileImageSource && (root.systemL10nPath || flagImage.status === Image.Error) && root.fallbackFlagEmoji.length > 0
        text: root.fallbackFlagEmoji
        font.pixelSize: Math.max(10, Math.floor(parent.height * 0.9))
    }

    Kirigami.Icon {
        anchors.fill: parent
        source: root.fileImageSource ? "flag" : root.sourceUrl
        visible: (root.sourceUrl.length > 0 && !root.fileImageSource)
            || (root.fileImageSource && (root.systemL10nPath || flagImage.status === Image.Error) && root.fallbackFlagEmoji.length === 0)
        isMask: true
        color: Kirigami.Theme.textColor
    }

    function fallbackEmojiFromSource() {
        if (!root.fileImageSource)
            return "";

        const match = String(root.sourceUrl || "").match(/\/([a-z]{2})\/flag\.(png|svg)$/i);
        if (!match || !match[1])
            return "";

        const code = String(match[1]).toUpperCase();
        if (code.length !== 2)
            return "";

        const base = 0x1F1E6;
        const first = code.charCodeAt(0) - 65;
        const second = code.charCodeAt(1) - 65;
        if (first < 0 || first > 25 || second < 0 || second > 25)
            return "";

        return String.fromCodePoint(base + first) + String.fromCodePoint(base + second);
    }
}
