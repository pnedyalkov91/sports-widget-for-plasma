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
import QtWebEngine

Item {
    id: root

    property string trackerUrl: ""

    // WebEngineView always renders at this width so the browser uses native
    // quality (no pixel-scaling). Increase/decrease to taste.
    readonly property real referenceWidth: 700

    clip: true

    WebEngineView {
        // Fixed render width - never scales, so text and images are crisp.
        width: root.referenceWidth
        height: root.height

        // Centre when the widget is wider; stick to the left edge when narrower
        // (clip:true above hides any right-side overflow on narrow widgets).
        x: root.width > root.referenceWidth
            ? Math.round((root.width - root.referenceWidth) / 2)
            : 0
        y: 0

        url: root.trackerUrl.length > 0 ? Qt.url(root.trackerUrl) : Qt.url("about:blank")

        settings.javascriptEnabled: true
        settings.showScrollBars: false
    }
}
