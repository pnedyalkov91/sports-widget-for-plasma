/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string sourceUrl: ""
    property string fallbackIcon: ""
    property real fallbackOpacity: 0.5
    readonly property bool systemL10nFlag: sourceUrl.indexOf("file:///usr/share/locale/l10n/") === 0
    readonly property string flagEmoji: flagEmojiFromSource()

    Image {
        id: badgeImage

        anchors.fill: parent
        source: root.systemL10nFlag ? "" : root.sourceUrl
        visible: root.sourceUrl.length > 0 && !root.systemL10nFlag && status !== Image.Error
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        sourceSize.width: Math.ceil(width * Math.max(1, Screen.devicePixelRatio) * 2)
        sourceSize.height: Math.ceil(height * Math.max(1, Screen.devicePixelRatio) * 2)
    }

    Text {
        anchors.centerIn: parent
        visible: root.flagEmoji.length > 0 && (root.systemL10nFlag || badgeImage.status === Image.Error)
        text: root.flagEmoji
        font.pixelSize: Math.max(10, Math.floor(parent.height * 0.9))
    }

    Kirigami.Icon {
        anchors.fill: parent
        visible: root.fallbackIcon.length > 0
            && (root.sourceUrl.length === 0 || (badgeImage.status === Image.Error && root.flagEmoji.length === 0))
        source: root.fallbackIcon
        color: Kirigami.Theme.disabledTextColor
        opacity: root.fallbackOpacity
    }

    function flagEmojiFromSource() {
        const match = String(root.sourceUrl || "").match(/\/([a-z]{2})\/flag\.(png|svg)$/i);
        if (!match || !match[1])
            return "";

        const code = String(match[1]).toUpperCase();
        const base = 0x1F1E6;
        const first = code.charCodeAt(0) - 65;
        const second = code.charCodeAt(1) - 65;
        if (first < 0 || first > 25 || second < 0 || second > 25)
            return "";

        return String.fromCodePoint(base + first) + String.fromCodePoint(base + second);
    }
}
