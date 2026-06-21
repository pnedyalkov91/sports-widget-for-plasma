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

// A simple, native-looking list of competitions. Each row has an emblem, name
// and a follow switch, plus a chevron that expands it in place to reveal its
// teams (loaded from the standings JSON API, with emblems, cached) — each team
// a follow switch too. `commitMode` selects how a switch commits:
//   "favorite" - add/remove a saved favorite instantly (Top page, cross-country)
//   "select"   - toggle it in the staged wizard selection (Browse flow)
ColumnLayout {
    id: root

    property var configRoot
    property string sport: ""
    property string commitMode: "favorite"
    property var competitions: []
    // lowercased competition name -> emblem url (best-effort, from matches API).
    property var competitionEmblems: ({})

    property string expandedSlug: ""
    property string loadingSlug: ""
    property var teamsBySlug: ({})

    spacing: 0

    WizardCache {
        id: teamCache
    }

    function competitionEntry(comp) {
        return {
            "sport": root.sport,
            "country": String(comp.country || ""),
            "league": String(comp.value || comp.slug || ""),
            "leagueLabel": String(comp.label || ""),
            "leagueBadge": root.competitionEmblem(comp),
            "favoriteTeam": "",
            "followMode": "league",
            "type": "competition"
        };
    }

    function teamEntry(team, comp) {
        return {
            "sport": root.sport,
            "country": String((team && team.country) || (comp && comp.country) || ""),
            "league": "",
            "favoriteTeam": String(team.label || ""),
            "teamSlug": String(team.teamSlug || team.value || ""),
            "teamPath": String(team.teamPath || ""),
            "teamBadge": String(team.badge || ""),
            "followMode": "team",
            "type": "team"
        };
    }

    function competitionEmblem(comp) {
        const key = String(comp.label || "").trim().toLowerCase();
        return root.competitionEmblems && root.competitionEmblems[key] ? String(root.competitionEmblems[key]) : "";
    }

    function isCompetitionChosen(comp) {
        if (!root.configRoot)
            return false;
        if (root.commitMode === "favorite")
            return root.configRoot.isFavoriteSaved(root.competitionEntry(comp));
        return root.configRoot.isLeagueSelected(String(comp.value || comp.slug || ""));
    }

    function isTeamChosen(team, comp) {
        if (!root.configRoot)
            return false;
        if (root.commitMode === "favorite")
            return root.configRoot.isFavoriteSaved(root.teamEntry(team, comp));
        return root.configRoot.isFavoriteTeamSelected(String(team.teamSlug || team.value || ""));
    }

    function setCompetitionChosen(comp, on) {
        if (!root.configRoot)
            return;
        if (on === root.isCompetitionChosen(comp))
            return;
        if (root.commitMode === "favorite")
            root.configRoot.toggleFavorite(root.competitionEntry(comp));
        else
            root.configRoot.selectLeague(String(comp.value || comp.slug || ""));
    }

    function setTeamChosen(team, comp, on) {
        if (!root.configRoot)
            return;
        if (on === root.isTeamChosen(team, comp))
            return;
        if (root.commitMode === "favorite") {
            root.configRoot.toggleFavorite(root.teamEntry(team, comp));
        } else {
            root.configRoot.selectFavoriteTeam(String(team.teamSlug || team.value || ""), {
                "teamSlug": String(team.teamSlug || team.value || ""),
                "teamPath": String(team.teamPath || ""),
                "badge": String(team.badge || "")
            });
        }
    }

    function toggleExpand(comp) {
        const slug = String(comp.slug || comp.value || "");
        if (root.expandedSlug === slug) {
            root.expandedSlug = "";
            return;
        }
        root.expandedSlug = slug;
        root.loadTeams(comp);
    }

    function setTeams(slug, teams) {
        const next = Object.assign({}, root.teamsBySlug);
        next[slug] = teams;
        root.teamsBySlug = next;
    }

    function loadTeams(comp) {
        const slug = String(comp.slug || comp.value || "");
        if (Array.isArray(root.teamsBySlug[slug]))
            return;

        const cacheKey = "compteams|" + root.sport + "|" + slug;
        const cached = teamCache.read(cacheKey);
        const hasCache = cached && Array.isArray(cached.value) && cached.value.length > 0;
        if (hasCache) {
            root.setTeams(slug, cached.value);
            if (cached.fresh)
                return;
        }

        root.loadingSlug = slug;
        SportsApi.fetchCompetitionTeams({
            "sports": root.sport,
            "league": slug,
            "country": String(comp.country || "")
        }, teams => {
            if (root.loadingSlug === slug)
                root.loadingSlug = "";
            if (Array.isArray(teams) && teams.length > 0) {
                teamCache.write(cacheKey, teams);
                root.setTeams(slug, teams);
            } else if (!hasCache) {
                root.setTeams(slug, []);
            }
        }, () => {
            if (root.loadingSlug === slug)
                root.loadingSlug = "";
            if (!hasCache)
                root.setTeams(slug, []);
        });
    }

    Repeater {
        model: root.competitions

        delegate: ColumnLayout {
            id: compDelegate

            required property var modelData
            readonly property string compSlug: String(compDelegate.modelData.slug || compDelegate.modelData.value || "")
            readonly property bool expanded: root.expandedSlug === compDelegate.compSlug
            readonly property var teams: root.teamsBySlug[compDelegate.compSlug]

            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Image {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                    source: root.competitionEmblem(compDelegate.modelData)
                    visible: source.toString().length > 0
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.width: width
                    sourceSize.height: height
                }

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Layout.preferredWidth
                    visible: root.competitionEmblem(compDelegate.modelData).length === 0
                    source: "applications-sports-symbolic"
                }

                Label {
                    Layout.fillWidth: true
                    text: compDelegate.modelData.label
                    elide: Text.ElideRight
                }

                Switch {
                    checked: root.isCompetitionChosen(compDelegate.modelData)
                    onToggled: {
                        const want = checked;
                        checked = Qt.binding(() => root.isCompetitionChosen(compDelegate.modelData));
                        root.setCompetitionChosen(compDelegate.modelData, want);
                    }
                }

                ToolButton {
                    icon.name: compDelegate.expanded ? "go-up-symbolic" : "go-down-symbolic"
                    display: AbstractButton.IconOnly
                    text: i18nc("@action:button", "Show teams")
                    ToolTip.visible: hovered
                    ToolTip.text: i18nc("@info:tooltip", "Show the teams in this competition")
                    onClicked: root.toggleExpand(compDelegate.modelData)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
                visible: compDelegate.expanded
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    visible: root.loadingSlug === compDelegate.compSlug
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

                Repeater {
                    model: Array.isArray(compDelegate.teams) ? compDelegate.teams : []

                    delegate: RowLayout {
                        id: teamRow

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Image {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Layout.preferredWidth
                            source: String(teamRow.modelData.badge || "")
                            visible: source.toString().length > 0
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: width
                            sourceSize.height: height
                        }

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Layout.preferredWidth
                            visible: String(teamRow.modelData.badge || "").length === 0
                            source: "im-user"
                        }

                        Label {
                            Layout.fillWidth: true
                            text: teamRow.modelData.label
                            elide: Text.ElideRight
                        }

                        Switch {
                            checked: root.isTeamChosen(teamRow.modelData, compDelegate.modelData)
                            onToggled: {
                                const want = checked;
                                checked = Qt.binding(() => root.isTeamChosen(teamRow.modelData, compDelegate.modelData));
                                root.setTeamChosen(teamRow.modelData, compDelegate.modelData, want);
                            }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    visible: root.loadingSlug !== compDelegate.compSlug
                        && Array.isArray(compDelegate.teams) && compDelegate.teams.length === 0
                    text: i18nc("@info", "No teams are available for this competition from the provider.")
                    color: Kirigami.Theme.disabledTextColor
                    wrapMode: Text.WordWrap
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }
        }
    }
}
