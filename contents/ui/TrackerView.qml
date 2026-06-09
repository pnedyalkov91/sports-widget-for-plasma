/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import QtQuick
import QtWebEngine

WebEngineView {
    id: root

    property string trackerUrl: ""

    url: trackerUrl.length > 0 ? Qt.url(trackerUrl) : Qt.url("about:blank")

    settings.javascriptEnabled: true
}
