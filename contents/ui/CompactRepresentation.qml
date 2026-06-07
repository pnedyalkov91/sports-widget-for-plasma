/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

import "../code/SportVisuals.js" as SportVisuals
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Control {
    id: compact

    property int liveCount: 0
    property bool loading: false
    property string layoutMode: "teamsAndBadges"
    property string primaryText: ""
    property string secondaryText: ""
    property string panelText: ""
    property string liveText: ""
    property bool isLive: false
    property string homeTeam: ""
    property string awayTeam: ""
    property string homeScore: ""
    property string awayScore: ""
    property bool showScore: true
    property string statusText: ""
    property string stadium: ""
    property string homeBadge: ""
    property string awayBadge: ""
    property string favoriteTeam: ""
    property int favoriteRotationInterval: 4000
    property bool favoriteDetailsVisible: false
    property bool panelUseSystemFont: true
    property string panelFontFamily: ""
    property int panelFontSize: 0
    property bool panelFontBold: false
    property int panelEmblemSize: 0
    property string panelAreaMode: "auto"
    property int panelAreaSize: 240
    property string sport: "sports"
    property bool matchRotationEnabled: true
    property int matchRotationInterval: 30
    property int matchRotationCount: 0
    readonly property color liveColor: Kirigami.Theme.negativeTextColor
    readonly property int effectiveManualFontPointSize: Math.max(6, compact.panelFontSize > 0 ? compact.panelFontSize : Kirigami.Theme.defaultFont.pointSize > 0 ? Kirigami.Theme.defaultFont.pointSize : 11)
    readonly property font effectivePanelFont: compact.useCustomFont()
        ? Qt.font({
            family: compact.panelFontFamily,
            pointSize: compact.effectiveManualFontPointSize,
            bold: compact.panelFontBold
        })
        : Kirigami.Theme.defaultFont
    readonly property font effectivePanelSecondaryFont: compact.useCustomFont()
        ? Qt.font({
            family: compact.panelFontFamily,
            pointSize: Math.max(6, compact.effectiveManualFontPointSize - 2),
            bold: compact.panelFontBold
        })
        : Kirigami.Theme.smallFont

    function displayText() {
        const text = compact.panelText.trim();
        return text.length > 0 ? text : compact.primaryText;
    }

    function displayLiveText() {
        const value = compact.liveText.trim();
        if (value.length === 0)
            return i18nc("@info:live match status", "Live");

        return value;
    }

    function normalizedLayoutMode() {
        if (compact.layoutMode === "badgesOnly" || compact.layoutMode === "teamsOnly" || compact.layoutMode === "teamsAndBadges")
            return compact.layoutMode;

        return "teamsAndBadges";
    }

    function hasMatchDetails() {
        return compact.homeTeam.trim().length > 0 || compact.awayTeam.trim().length > 0;
    }

    function showBadges() {
        if (compact.favoritePanelMode)
            return true;

        const mode = compact.normalizedLayoutMode();
        return mode === "teamsAndBadges" || mode === "badgesOnly";
    }

    function showTeamNames() {
        if (compact.favoritePanelMode)
            return true;

        const mode = compact.normalizedLayoutMode();
        return mode === "teamsAndBadges" || mode === "teamsOnly";
    }

    function scoreText() {
        if (compact.favoritePanelMode)
            return "-";

        if (!compact.showScore)
            return compact.statusText.trim();

        const home = compact.homeScore.trim();
        const away = compact.awayScore.trim();
        return (home.length > 0 ? home : "0") + " - " + (away.length > 0 ? away : "0");
    }

    function useCustomFont() {
        return !compact.panelUseSystemFont && compact.panelFontFamily.trim().length > 0;
    }

    function favoriteDetailsText() {
        const parts = [];
        const status = compact.statusText.trim();
        const stadium = compact.stadium.trim();
        if (status.length > 0)
            parts.push(status);
        if (stadium.length > 0)
            parts.push(stadium);

        return parts.join(" · ");
    }

    function normalizedPanelAreaMode() {
        if (compact.panelAreaMode === "fill" || compact.panelAreaMode === "manual")
            return compact.panelAreaMode;

        return "auto";
    }

    readonly property int contentMargin: Kirigami.Units.smallSpacing
    readonly property int matchColumnSpacing: Kirigami.Units.smallSpacing
    readonly property int teamContentSpacing: Math.max(2, Math.round(Kirigami.Units.smallSpacing / 2))
    readonly property bool favoritePanelMode: compact.favoriteTeam.trim().length > 0 && compact.hasMatchDetails() && !compact.isLive
    readonly property bool favoriteRotationEnabled: compact.favoritePanelMode && compact.favoriteDetailsText().length > 0
    readonly property int estimatedLogoSize: compact.panelEmblemSize > 0
        ? Math.max(8, Math.min(64, compact.panelEmblemSize))
        : Math.max(8, Math.min(Math.max(8, compact.height - Math.max(2, Kirigami.Units.smallSpacing)), Kirigami.Units.iconSizes.large))
    readonly property int homeTeamNaturalWidth: compact.showTeamNames() ? Math.ceil(homeTeamMetrics.advanceWidth) : 0
    readonly property int awayTeamNaturalWidth: compact.showTeamNames() ? Math.ceil(awayTeamMetrics.advanceWidth) : 0
    readonly property int scoreNaturalWidth: Math.ceil(scoreMetrics.advanceWidth)
    readonly property int liveDotNaturalWidth: compact.isLive ? 7 + compact.teamContentSpacing : 0
    readonly property int liveStatusNaturalWidth: compact.isLive ? Math.ceil(liveTextMetrics.advanceWidth) : 0
    readonly property int centerNaturalWidth: Math.max(scoreNaturalWidth, liveStatusNaturalWidth)
    readonly property int homeSideNaturalWidth: (compact.showBadges() ? compact.estimatedLogoSize : 0) + (compact.showBadges() && compact.showTeamNames() ? compact.teamContentSpacing : 0) + homeTeamNaturalWidth
    readonly property int awaySideNaturalWidth: (compact.showBadges() ? compact.estimatedLogoSize : 0) + (compact.showBadges() && compact.showTeamNames() ? compact.teamContentSpacing : 0) + awayTeamNaturalWidth
    readonly property int favoriteMatchNaturalWidth: homeSideNaturalWidth + Math.ceil(favoriteSeparatorMetrics.advanceWidth) + awaySideNaturalWidth + compact.matchColumnSpacing * 2 + compact.contentMargin * 2
    readonly property int favoriteDetailsNaturalWidth: Math.ceil(favoriteDetailsMetrics.advanceWidth) + compact.contentMargin * 2
    readonly property int matchNaturalWidth: compact.favoritePanelMode ? Math.max(favoriteMatchNaturalWidth, favoriteDetailsNaturalWidth) : compact.liveDotNaturalWidth + homeSideNaturalWidth + centerNaturalWidth + awaySideNaturalWidth + compact.matchColumnSpacing * 2 + compact.contentMargin * 2
    readonly property int fallbackNaturalWidth: Math.ceil(fallbackTextMetrics.advanceWidth) + Kirigami.Units.iconSizes.medium + compact.matchColumnSpacing * 2 + (compact.liveCount > 0 ? Kirigami.Units.iconSizes.smallMedium + compact.matchColumnSpacing : 0)
    readonly property int naturalPanelWidth: compact.hasMatchDetails() ? matchNaturalWidth : fallbackNaturalWidth
    readonly property int minimumPanelWidth: compact.normalizedLayoutMode() === "badgesOnly" ? Kirigami.Units.gridUnit * 5 : Kirigami.Units.gridUnit * 9
    readonly property string effectivePanelAreaMode: compact.normalizedPanelAreaMode()
    readonly property int manualPanelAreaSize: Math.max(20, compact.panelAreaSize || 240)
    readonly property int requestedPanelWidth: compact.effectivePanelAreaMode === "manual" ? Math.max(compact.minimumPanelWidth, compact.manualPanelAreaSize) : Math.max(compact.minimumPanelWidth, compact.naturalPanelWidth)

    signal rotateMatchRequested()

    TextMetrics {
        id: homeTeamMetrics

        font: compact.effectivePanelFont
        text: compact.homeTeam
    }

    TextMetrics {
        id: awayTeamMetrics

        font: compact.effectivePanelFont
        text: compact.awayTeam
    }

    TextMetrics {
        id: scoreMetrics

        font: compact.effectivePanelFont
        text: compact.scoreText()
    }

    TextMetrics {
        id: liveTextMetrics

        font: compact.effectivePanelSecondaryFont
        text: compact.displayLiveText()
    }

    TextMetrics {
        id: favoriteSeparatorMetrics

        font: compact.effectivePanelFont
        text: "-"
    }

    TextMetrics {
        id: favoriteDetailsMetrics

        font: compact.effectivePanelFont
        text: compact.favoriteDetailsText()
    }

    TextMetrics {
        id: fallbackTextMetrics

        font: compact.effectivePanelFont
        text: compact.displayText()
    }

    Layout.fillWidth: compact.effectivePanelAreaMode === "fill"
    Layout.minimumWidth: compact.effectivePanelAreaMode === "fill" ? compact.minimumPanelWidth : compact.requestedPanelWidth
    Layout.minimumHeight: Kirigami.Units.iconSizes.medium
    Layout.preferredWidth: compact.effectivePanelAreaMode === "fill" ? -1 : compact.requestedPanelWidth
    Layout.preferredHeight: Kirigami.Units.iconSizes.large
    implicitWidth: compact.effectivePanelAreaMode === "fill" ? Math.max(compact.minimumPanelWidth, compact.naturalPanelWidth) : compact.requestedPanelWidth
    implicitHeight: Layout.preferredHeight
    padding: 0

    onFavoriteRotationEnabledChanged: {
        if (!compact.favoriteRotationEnabled)
            compact.favoriteDetailsVisible = false;
    }
    onHomeTeamChanged: compact.favoriteDetailsVisible = false
    onAwayTeamChanged: compact.favoriteDetailsVisible = false
    onStatusTextChanged: compact.favoriteDetailsVisible = false
    onStadiumChanged: compact.favoriteDetailsVisible = false

    Timer {
        interval: compact.favoriteRotationInterval
        repeat: true
        running: compact.favoriteRotationEnabled
        onTriggered: compact.favoriteDetailsVisible = !compact.favoriteDetailsVisible
    }

    Timer {
        interval: Math.max(5, compact.matchRotationInterval || 30) * 1000
        repeat: true
        running: compact.matchRotationEnabled && compact.matchRotationCount > 1
        onTriggered: matchRotationAnimation.restart()
    }

    SequentialAnimation {
        id: matchRotationAnimation

        NumberAnimation {
            target: compactContent
            property: "opacity"
            to: 0
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutQuad
        }

        ScriptAction {
            script: compact.rotateMatchRequested()
        }

        NumberAnimation {
            target: compactContent
            property: "opacity"
            to: 1
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutQuad
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.expanded = !root.expanded
    }

    contentItem: Item {
        id: compactContent

        RowLayout {
            id: matchRow

            anchors.centerIn: parent
            width: Math.min(implicitWidth, Math.max(0, parent.width - compact.contentMargin * 2))
            height: implicitHeight
            spacing: compact.matchColumnSpacing
            visible: compact.hasMatchDetails() && !compact.favoritePanelMode

            LiveDot {
                Layout.alignment: Qt.AlignVCenter
                visible: compact.isLive
            }

            RowLayout {
                Layout.fillWidth: compact.showTeamNames()
                Layout.minimumWidth: compact.homeSideNaturalWidth
                Layout.alignment: Qt.AlignVCenter
                spacing: compact.teamContentSpacing

                TeamLogo {
                    sourceUrl: compact.homeBadge
                    visible: compact.showBadges()
                }

                PanelLabel {
                    Layout.fillWidth: true
                    Layout.minimumWidth: compact.homeTeamNaturalWidth
                    Layout.preferredWidth: compact.homeTeamNaturalWidth
                    Layout.alignment: Qt.AlignVCenter
                    text: compact.homeTeam
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    visible: compact.showTeamNames()
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: compact.centerNaturalWidth
                spacing: 0

                PanelLabel {
                    id: scoreLabel

                    Layout.alignment: Qt.AlignHCenter
                    text: compact.scoreText()
                    visible: text.length > 0
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    visible: compact.isLive
                    spacing: Math.max(2, Math.round(compact.teamContentSpacing / 2))

                    PanelSecondaryLabel {
                        Layout.alignment: Qt.AlignVCenter
                        text: compact.displayLiveText()
                        color: compact.liveColor
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: compact.showTeamNames()
                Layout.minimumWidth: compact.awaySideNaturalWidth
                Layout.alignment: Qt.AlignVCenter
                spacing: compact.teamContentSpacing

                PanelLabel {
                    Layout.fillWidth: true
                    Layout.minimumWidth: compact.awayTeamNaturalWidth
                    Layout.preferredWidth: compact.awayTeamNaturalWidth
                    Layout.alignment: Qt.AlignVCenter
                    text: compact.awayTeam
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    visible: compact.showTeamNames()
                }

                TeamLogo {
                    sourceUrl: compact.awayBadge
                    visible: compact.showBadges()
                }
            }
        }

        RowLayout {
            id: favoriteMatchRow

            anchors.centerIn: parent
            width: Math.min(implicitWidth, Math.max(0, parent.width - compact.contentMargin * 2))
            height: implicitHeight
            spacing: compact.matchColumnSpacing
            visible: compact.favoritePanelMode && !compact.favoriteDetailsVisible

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: compact.homeSideNaturalWidth
                Layout.alignment: Qt.AlignVCenter
                spacing: compact.teamContentSpacing

                TeamLogo {
                    sourceUrl: compact.homeBadge
                }

                PanelLabel {
                    Layout.fillWidth: true
                    Layout.minimumWidth: compact.homeTeamNaturalWidth
                    Layout.preferredWidth: compact.homeTeamNaturalWidth
                    Layout.alignment: Qt.AlignVCenter
                    text: compact.homeTeam
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                }
            }

            PanelLabel {
                Layout.alignment: Qt.AlignVCenter
                text: "-"
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: compact.awaySideNaturalWidth
                Layout.alignment: Qt.AlignVCenter
                spacing: compact.teamContentSpacing

                PanelLabel {
                    Layout.fillWidth: true
                    Layout.minimumWidth: compact.awayTeamNaturalWidth
                    Layout.preferredWidth: compact.awayTeamNaturalWidth
                    Layout.alignment: Qt.AlignVCenter
                    text: compact.awayTeam
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                TeamLogo {
                    sourceUrl: compact.awayBadge
                }
            }
        }

        PanelLabel {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - compact.contentMargin * 2)
            text: compact.favoriteDetailsText()
            visible: compact.favoritePanelMode && compact.favoriteDetailsVisible && text.length > 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            visible: !compact.hasMatchDetails()

            SportGlyph {
                Layout.preferredWidth: Math.min(parent.height, Kirigami.Units.iconSizes.medium)
                Layout.preferredHeight: Layout.preferredWidth
                loading: compact.loading
                sport: compact.sport
            }

            PanelLabel {
                Layout.fillWidth: true
                text: compact.displayText()
                elide: Text.ElideRight
            }

            CountBadge {
                count: compact.liveCount
                visible: compact.liveCount > 0
            }

        }
    }

    component SportGlyph: Item {
        property bool loading: false
        property string sport: "football"

        Kirigami.Icon {
            anchors.fill: parent
            source: "view-refresh"
            visible: parent.loading
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: Qt.resolvedUrl("../icons/sports/" + SportVisuals.iconName(parent.sport))
            visible: !parent.loading
            isMask: true
            color: Kirigami.Theme.textColor
        }

    }

    component PanelLabel: Label {
        color: Kirigami.Theme.textColor
        font: compact.effectivePanelFont
    }

    component PanelSecondaryLabel: Label {
        color: Kirigami.Theme.textColor
        font: compact.effectivePanelSecondaryFont
    }

    component LiveDot: Rectangle {
        Layout.preferredWidth: 5
        Layout.preferredHeight: Layout.preferredWidth
        radius: width / 2
        color: compact.liveColor

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: compact.isLive

            NumberAnimation {
                from: 1
                to: 0.35
                duration: 650
                easing.type: Easing.InOutQuad
            }

            NumberAnimation {
                from: 0.35
                to: 1
                duration: 650
                easing.type: Easing.InOutQuad
            }
        }
    }

    component TeamLogo: Item {
        property string sourceUrl: ""
        readonly property int automaticLogoSize: Math.max(8, Math.min(
            Math.max(8, compact.height - Math.max(2, Kirigami.Units.smallSpacing)),
            Math.max(8, compact.width * (compact.showTeamNames() ? 0.14 : 0.32)),
            Kirigami.Units.iconSizes.large
        ))
        readonly property int logoSize: compact.panelEmblemSize > 0 ? Math.max(8, Math.min(64, compact.panelEmblemSize)) : automaticLogoSize
        Layout.preferredWidth: logoSize
        Layout.preferredHeight: logoSize
        Layout.alignment: Qt.AlignVCenter

        TeamBadgeImage {
            anchors.fill: parent
            sourceUrl: parent.sourceUrl
            fallbackIcon: "emblem-favorite"
        }
    }

    component CountBadge: Rectangle {
        property int count: 0

        Layout.preferredWidth: Math.max(Kirigami.Units.iconSizes.smallMedium, countLabel.implicitWidth + Kirigami.Units.smallSpacing * 2)
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        radius: height / 2
        color: Kirigami.Theme.positiveTextColor

        Label {
            id: countLabel

            anchors.centerIn: parent
            text: parent.count > 99 ? "99+" : parent.count
            color: Kirigami.Theme.backgroundColor
            font.bold: true
            font.pixelSize: Math.max(8, Kirigami.Theme.smallFont.pixelSize)
        }

    }

}
