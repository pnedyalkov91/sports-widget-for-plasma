/*
    SPDX-FileCopyrightText: 2026 Petar Nedyalkov <petar.nedyalkov91@gmail.com>
    SPDX-License-Identifier: GPL-3.0-only
*/

.pragma library

function providerId(configuration) {
    return "sportscore";
}

function baseUrl(configuration, sport) {
    return "https://sportscore.com";
}

function apiKey(configuration, sport) {
    return "";
}
