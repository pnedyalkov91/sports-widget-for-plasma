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
import org.kde.kirigami as Kirigami
import "../code/SportVisuals.js" as SportVisuals

Item {
    id: root

    property string sourceUrl: ""
    property string fallbackIcon: ""
    // Emoji shown when there is no image and no country-flag emoji - e.g. the sport
    // emoji (⚽) in place of a generic KDE placeholder icon. Takes precedence over
    // fallbackIcon when set.
    property string fallbackEmoji: ""
    property real fallbackOpacity: 0.5
    property int fillMode: Image.PreserveAspectFit
    readonly property bool systemL10nFlag: sourceUrl.indexOf("file:///usr/share/locale/l10n/") === 0
    readonly property string flagEmoji: SportVisuals.flagEmojiFromUrl(root.sourceUrl)

    Image {
        id: badgeImage

        anchors.fill: parent
        source: root.systemL10nFlag ? "" : root.sourceUrl
        visible: root.sourceUrl.length > 0 && !root.systemL10nFlag && status !== Image.Error
        fillMode: root.fillMode
        asynchronous: true
        cache: true
        smooth: true
        sourceSize.width: Math.ceil(width * Math.max(1, Screen.devicePixelRatio) * 2)
        sourceSize.height: Math.ceil(height * Math.max(1, Screen.devicePixelRatio) * 2)
    }

    // True when no badge image is being shown (none given, or it failed to load).
    readonly property bool imageMissing: root.sourceUrl.length === 0 || root.systemL10nFlag || badgeImage.status === Image.Error

    // Country flag emoji - shown for national teams whose flag image is missing.
    Text {
        anchors.centerIn: parent
        visible: root.flagEmoji.length > 0 && root.imageMissing
        text: root.flagEmoji
        font.pixelSize: Math.max(10, Math.floor(parent.height * 0.9))
    }

    // Sport emoji (or any caller-supplied emoji) - the placeholder when there is no
    // image and no flag emoji, used instead of a generic KDE icon.
    Text {
        anchors.centerIn: parent
        visible: root.fallbackEmoji.length > 0 && root.flagEmoji.length === 0 && root.imageMissing
        text: root.fallbackEmoji
        opacity: root.fallbackOpacity
        font.pixelSize: Math.max(10, Math.floor(parent.height * 0.7))
    }

    // Last-resort KDE icon, only when no emoji fallback applies.
    Kirigami.Icon {
        anchors.fill: parent
        visible: root.fallbackIcon.length > 0 && root.fallbackEmoji.length === 0
            && root.flagEmoji.length === 0 && root.imageMissing
        source: root.fallbackIcon
        color: Kirigami.Theme.disabledTextColor
        opacity: root.fallbackOpacity
    }
}
