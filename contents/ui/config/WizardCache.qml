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

// Persistent on-disk cache (SQLite) for the configuration wizard's
// countries / competitions / teams. Lets the wizard render instantly from
// local storage on repeat visits and keep working when SportScore is slow or
// unreachable. Shared across pages via the database name.
QtObject {
    id: cache

    property var _db: null
    // How long cached data is considered fresh enough to skip a network refresh.
    // After this, the wizard still shows the cached data instantly but refreshes
    // it quietly in the background, so selections stay roughly daily-fresh
    // without any proactive background scraping.
    readonly property int freshMs: 24 * 60 * 60 * 1000

    function _database() {
        if (cache._db)
            return cache._db;

        const db = LocalStorage.openDatabaseSync("SportsWidgetWizardCache", "1.0", "Sports Widget for Plasma wizard cache", 8000000);
        db.transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS entries(key TEXT PRIMARY KEY, payload TEXT, ts INTEGER)");
        });
        cache._db = db;
        return db;
    }

    // Returns { value, ts, fresh } for a key, or null when absent/unreadable.
    function read(key) {
        try {
            let entry = null;
            cache._database().readTransaction(function (tx) {
                const result = tx.executeSql("SELECT payload, ts FROM entries WHERE key = ?", [String(key)]);
                if (result.rows.length > 0) {
                    const ts = Number(result.rows.item(0).ts) || 0;
                    entry = {
                        "value": JSON.parse(result.rows.item(0).payload),
                        "ts": ts,
                        "fresh": (Date.now() - ts) < cache.freshMs
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
