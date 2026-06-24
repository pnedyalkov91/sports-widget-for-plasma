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

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../code/SportsApi.js" as SportsApi
import "../../code/providers/SportScoreSports.js" as SportScoreSports

// League detail subpage: enable the whole competition and/or follow individual
// teams in it (teams + emblems from the standings JSON API, cached). Opened as a
// full-page overlay from the league cards on the Top page. Teams you follow move
// up into the "Following" section; while the whole competition is followed the
// per-team switches are disabled.
Item {
    id: root

    required property var configRoot
    required property var league
    property url emblem: ""
    // "favorite" - add/remove a saved favorite instantly (Top page, cross-country)
    // "select"   - toggle it in the staged wizard selection (Browse flow)
    property string commitMode: "favorite"

    readonly property string sport: root.configRoot ? root.configRoot.normalizedSport() : ""
    readonly property string slug: root.league ? String(root.league.value || root.league.slug || "") : ""
    readonly property string country: root.league ? String(root.league.country || "") : ""
    readonly property string label: root.league ? String(root.league.label || "") : ""

    // Emblems scale with the Plasma font: a row is one line of text tall, so its
    // badge tracks Kirigami.Units.iconSizes which already follow the font/DPI.
    readonly property int rowIconSize: Kirigami.Units.iconSizes.medium
    readonly property int headerIconSize: Kirigami.Units.iconSizes.large

    property var teams: []
    property bool loading: false
    // True only when the provider request failed (and ESPN could not cover it),
    // as opposed to a successful-but-empty result.
    property bool loadFailed: false
    // Guards against stale callbacks from an earlier (slow) load clobbering the
    // state of a newer one (e.g. after the user clicks "Try again").
    property int teamsToken: 0
    property int savedRevision: 0

    Component.onCompleted: root.loadTeams()

    WizardCache {
        id: teamCache
    }

    // A single followable team row (emblem + name + switch). Reused by the
    // "Following" and "Teams" sections so both look identical.
    component TeamRow: RowLayout {
        id: teamRow

        required property var team

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Image {
            Layout.preferredWidth: root.rowIconSize
            Layout.preferredHeight: root.rowIconSize
            source: String(teamRow.team.badge || "")
            visible: source.toString().length > 0
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize.width: width
            sourceSize.height: height
        }

        Kirigami.Icon {
            Layout.preferredWidth: root.rowIconSize
            Layout.preferredHeight: root.rowIconSize
            visible: String(teamRow.team.badge || "").length === 0
            source: "im-user"
        }

        Label {
            Layout.fillWidth: true
            text: teamRow.team.label
            elide: Text.ElideRight
        }

        Switch {
            // Following the whole competition supersedes per-team choices.
            enabled: !(root.savedRevision >= 0 && root.leagueEnabled())
            checked: root.savedRevision >= 0 && root.isTeamFollowed(teamRow.team)
            onToggled: {
                const want = checked;
                checked = Qt.binding(() => root.savedRevision >= 0 && root.isTeamFollowed(teamRow.team));
                root.setTeamFollowed(teamRow.team, want);
            }
        }
    }

    function competitionEntry() {
        return {
            "sport": root.sport,
            "country": root.country,
            "league": root.slug,
            "leagueLabel": root.label,
            "leagueBadge": String(root.emblem),
            "favoriteTeam": "",
            "followMode": "league",
            "type": "competition"
        };
    }

    function teamEntry(team) {
        return {
            "sport": root.sport,
            "country": String(team.country || root.country),
            "league": "",
            // The competition this team was followed from. A followed team's matches
            // are league-scoped on ESPN, and country alone can't pick the league for
            // international/multi-league competitions (e.g. FIFA World Cup → world).
            // Keeping the originating league lets ESPN resolve it (see espnPlan).
            "teamLeague": root.slug,
            "favoriteTeam": String(team.label || ""),
            "teamSlug": String(team.teamSlug || team.value || ""),
            "teamPath": String(team.teamPath || ""),
            "teamBadge": String(team.badge || ""),
            "followMode": "team",
            "type": "team"
        };
    }

    function leagueEnabled() {
        if (!root.configRoot)
            return false;
        if (root.commitMode === "select")
            return root.configRoot.isLeagueSelected(root.slug);
        return root.configRoot.isFavoriteSaved(root.competitionEntry());
    }

    function setLeagueEnabled(on) {
        if (!root.configRoot || on === root.leagueEnabled())
            return;
        if (root.commitMode === "select")
            root.configRoot.selectLeague(root.slug);
        else
            root.configRoot.toggleFavorite(root.competitionEntry());
        root.savedRevision += 1;
    }

    function isTeamFollowed(team) {
        if (!root.configRoot)
            return false;
        if (root.commitMode === "select")
            return root.configRoot.isFavoriteTeamSelected(String(team.label || ""));
        return root.configRoot.isFavoriteSaved(root.teamEntry(team));
    }

    function setTeamFollowed(team, on) {
        if (!root.configRoot || on === root.isTeamFollowed(team))
            return;
        if (root.commitMode === "select") {
            root.configRoot.selectFavoriteTeam(String(team.label || ""), {
                "teamSlug": String(team.teamSlug || team.value || ""),
                "teamPath": String(team.teamPath || ""),
                "badge": String(team.badge || "")
            });
        } else {
            root.configRoot.toggleFavorite(root.teamEntry(team));
        }
        root.savedRevision += 1;
    }

    function followedTeams() {
        return (Array.isArray(root.teams) ? root.teams : []).filter(team => root.isTeamFollowed(team));
    }

    function unfollowedTeams() {
        return (Array.isArray(root.teams) ? root.teams : []).filter(team => !root.isTeamFollowed(team));
    }

    function loadTeams() {
        if (root.slug.length === 0)
            return;

        const token = root.teamsToken + 1;
        root.teamsToken = token;

        const cacheKey = "compteams|" + root.sport + "|" + root.slug;
        const cached = teamCache.read(cacheKey);
        const hasCache = cached && Array.isArray(cached.value) && cached.value.length > 0;
        if (hasCache) {
            root.teams = cached.value;
            if (cached.fresh) {
                root.loadFailed = false;
                return;
            }
        }

        root.loading = true;
        root.loadFailed = false;
        SportsApi.fetchCompetitionTeams({
            "sports": root.sport,
            "league": root.slug,
            "country": root.country
        }, teams => {
            if (token !== root.teamsToken)
                return;
            root.loading = false;
            root.loadFailed = false;
            if (Array.isArray(teams) && teams.length > 0) {
                teamCache.write(cacheKey, teams);
                root.teams = teams;
            } else if (!hasCache) {
                root.teams = [];
            }
        }, () => {
            if (token !== root.teamsToken)
                return;
            root.loading = false;
            if (!hasCache)
                root.loadFailed = true;
        });
    }

    // Opaque backdrop so the underlying wizard (and its buttons) are hidden.
    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            ToolButton {
                icon.name: "go-previous"
                text: i18nc("@action:button", "Back")
                display: AbstractButton.IconOnly
                onClicked: {
                    if (root.configRoot)
                        root.configRoot.closeLeaguePage();
                }
            }

            Image {
                Layout.preferredWidth: root.headerIconSize
                Layout.preferredHeight: root.headerIconSize
                source: root.emblem
                visible: source.toString().length > 0
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: width
                sourceSize.height: height
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 2
                text: root.label
                elide: Text.ElideRight
            }

            ToolButton {
                icon.name: "list-add"
                text: i18nc("@action:button", "Add Another Sport")
                display: AbstractButton.TextBesideIcon
                visible: root.configRoot && root.configRoot.multiSelectEnabled
                onClicked: {
                    if (root.configRoot)
                        root.configRoot.addAnotherSport();
                }
            }

            ToolButton {
                icon.name: "dialog-close"
                text: i18nc("@action:button", "Close")
                display: AbstractButton.IconOnly
                onClicked: {
                    if (root.configRoot)
                        root.configRoot.closeLeaguePage();
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        ScrollView {
            id: scroll

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: scroll.availableWidth
                spacing: Kirigami.Units.largeSpacing

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: true
                    type: Kirigami.MessageType.Information
                    text: root.commitMode === "select"
                        ? i18nc("@info", "Your picks are added to this sport's selection. They are saved when you finish the wizard and click Apply (or OK).")
                        : i18nc("@info", "Changes here are not applied immediately. Click Apply (or OK) at the bottom of the window to save them.")
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    type: Kirigami.MessageType.Positive
                    // savedRevision bumps on every follow/unfollow, re-evaluating this.
                    // Shows the session-wide summary (all sports/countries added,
                    // excluding already-saved items) so it matches the wizard pages.
                    text: root.savedRevision >= 0 && root.configRoot ? root.configRoot.sessionSummaryText() : ""
                    visible: text.length > 0
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    // SportScore only backs football/basketball/cricket/tennis;
                    // other sports are ESPN-only, so don't blame SportScore there.
                    // Hidden while (re)loading so "Try again" shows progress first.
                    visible: root.loadFailed && !root.loading && SportScoreSports.supports(root.sport)
                    type: Kirigami.MessageType.Error
                    text: i18nc("@info", "SportScore is not responding right now, so this competition's teams could not be loaded. Please try again later.")
                    actions: [
                        Kirigami.Action {
                            icon.name: "view-refresh"
                            text: i18nc("@action:button", "Try again")
                            onTriggered: root.loadTeams()
                        }
                    ]
                }

                // --- League settings ------------------------------------
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 4
                    text: i18nc("@title:group", "League settings")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Label {
                        Layout.fillWidth: true
                        text: i18nc("@option:check", "Follow the whole competition")
                        wrapMode: Text.WordWrap
                    }

                    Switch {
                        checked: root.savedRevision >= 0 && root.leagueEnabled()
                        onToggled: {
                            const want = checked;
                            checked = Qt.binding(() => root.savedRevision >= 0 && root.leagueEnabled());
                            root.setLeagueEnabled(want);
                        }
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                // --- Following ------------------------------------------
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 4
                    text: i18nc("@title:group", "Following")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    Repeater {
                        model: root.savedRevision >= 0 ? root.followedTeams() : []

                        delegate: TeamRow {
                            required property var modelData
                            team: modelData
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: root.savedRevision >= 0 && root.followedTeams().length === 0
                        text: root.leagueEnabled()
                            ? i18nc("@info", "Following the whole competition.")
                            : i18nc("@info", "No teams followed")
                        color: Kirigami.Theme.disabledTextColor
                        wrapMode: Text.WordWrap
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                // --- Teams ----------------------------------------------
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 4
                    text: i18nc("@title:group", "Teams")
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.loading
                    spacing: Kirigami.Units.smallSpacing

                    BusyIndicator {
                        running: parent.visible
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }

                    Label {
                        text: i18nc("@info", "Loading teams…")
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    Repeater {
                        model: root.savedRevision >= 0 ? root.unfollowedTeams() : []

                        delegate: TeamRow {
                            required property var modelData
                            team: modelData
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: !root.loading && Array.isArray(root.teams) && root.teams.length === 0
                    text: i18nc("@info", "No teams are available for this competition from the provider.")
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.WordWrap
                }

                Item {
                    Layout.preferredHeight: Kirigami.Units.gridUnit
                }
            }
        }
    }
}
