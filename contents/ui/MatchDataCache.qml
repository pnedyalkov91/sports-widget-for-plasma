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
import QtQuick.LocalStorage

// Persistent on-disk cache (SQLite) for the widget's live data - upcoming
// matches, recent results and league tables. Used to seed the views instantly
// on startup and to fall back to the last-known data when SportScore is slow
// or unreachable, so the widget never goes blank.
QtObject {
    id: cache

    property var _db: null

    // Bump whenever the SHAPE or PARSING of cached payloads changes, so stale entries
    // written by an older build are dropped instead of served forever. The details
    // cache in particular survives reinstalls (it's on-disk SQLite), so a parsing fix
    // - e.g. excluding goal-kicks from goals - would otherwise keep showing the old,
    // wrong cached details for already-finished matches. Increment to invalidate.
    readonly property int cacheVersion: 2

    function _database() {
        if (cache._db)
            return cache._db;

        const db = LocalStorage.openDatabaseSync("SportsWidgetMatchCache", "1.0", "Sports Widget for Plasma match data cache", 12000000);
        db.transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS entries(key TEXT PRIMARY KEY, payload TEXT, ts INTEGER)");
            tx.executeSql("CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT)");
            // Drop all cached entries when the stored cache version is older than the
            // current one, so a payload-format/parsing change can't serve stale data.
            let stored = 0;
            const result = tx.executeSql("SELECT value FROM meta WHERE key = 'version'");
            if (result.rows.length > 0)
                stored = Number(result.rows.item(0).value) || 0;
            if (stored < cache.cacheVersion) {
                tx.executeSql("DELETE FROM entries");
                tx.executeSql("INSERT OR REPLACE INTO meta(key, value) VALUES('version', ?)", [String(cache.cacheVersion)]);
            }
        });
        cache._db = db;
        return db;
    }

    // Returns { value, ts } for a key, or null when absent/unreadable.
    function read(key) {
        try {
            let entry = null;
            cache._database().readTransaction(function (tx) {
                const result = tx.executeSql("SELECT payload, ts FROM entries WHERE key = ?", [String(key)]);
                if (result.rows.length > 0) {
                    entry = {
                        "value": JSON.parse(result.rows.item(0).payload),
                        "ts": Number(result.rows.item(0).ts) || 0
                    };
                }
            });
            return entry;
        } catch (error) {
            return null;
        }
    }

    function write(key, value) {
        try {
            const payload = JSON.stringify(value === undefined || value === null ? null : value);
            cache._database().transaction(function (tx) {
                tx.executeSql("INSERT OR REPLACE INTO entries(key, payload, ts) VALUES(?, ?, ?)", [String(key), payload, Date.now()]);
            });
        } catch (error) {
        }
    }
}
