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

#include "sportsmatchesevents.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMultiHash>
#include <QStandardPaths>
#include <QTimeZone>

// The widget writes this inert JSON snapshot of the upcoming matches it follows.
// It is NOT an iCalendar resource: nothing parses, reconciles or indexes it, so
// reading it here is cheap and cannot stall the calendar.
static const QString kSnapshotRelPath = QStringLiteral("sports-widget-for-plasma/sports-matches.json");

SportsMatchesEventsPlugin::SportsMatchesEventsPlugin(QObject *parent)
    : CalendarEvents::CalendarEventsPlugin(parent)
    , m_watcher(new QFileSystemWatcher(this))
{
    const QString path = snapshotPath();
    const QFileInfo info(path);

    // Watch the file if it exists, otherwise watch its directory so we pick the
    // file up as soon as the widget first writes it. Watching is in-process and
    // event-driven; there is no polling and no calendar backend involved.
    if (info.exists()) {
        m_watcher->addPath(path);
    }
    QDir().mkpath(info.absolutePath());
    m_watcher->addPath(info.absolutePath());

    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, &SportsMatchesEventsPlugin::onSnapshotChanged);
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, &SportsMatchesEventsPlugin::onSnapshotChanged);
}

SportsMatchesEventsPlugin::~SportsMatchesEventsPlugin() = default;

QString SportsMatchesEventsPlugin::snapshotPath() const
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    return base + QLatin1Char('/') + kSnapshotRelPath;
}

void SportsMatchesEventsPlugin::loadEventsForDateRange(const QDate &startDate, const QDate &endDate)
{
    m_rangeStart = startDate;
    m_rangeEnd = endDate;

    // Re-arm the file watch in case the file appeared after construction (a
    // QFileSystemWatcher drops paths that did not exist when added).
    const QString path = snapshotPath();
    if (QFileInfo::exists(path) && !m_watcher->files().contains(path)) {
        m_watcher->addPath(path);
    }

    emitEventsForCurrentRange();
}

void SportsMatchesEventsPlugin::onSnapshotChanged()
{
    // Some editors replace the file (write tmp + rename), which drops the watch;
    // re-add it so subsequent updates keep arriving.
    const QString path = snapshotPath();
    if (QFileInfo::exists(path) && !m_watcher->files().contains(path)) {
        m_watcher->addPath(path);
    }

    if (m_rangeStart.isValid() && m_rangeEnd.isValid()) {
        emitEventsForCurrentRange();
    }
}

void SportsMatchesEventsPlugin::emitEventsForCurrentRange()
{
    QMultiHash<QDate, CalendarEvents::EventData> data;

    QFile file(snapshotPath());
    if (!file.open(QIODevice::ReadOnly)) {
        // No snapshot yet (or unreadable): report an empty range. This clears any
        // previously shown events and never blocks.
        Q_EMIT dataReady(data);
        return;
    }

    const QByteArray raw = file.readAll();
    file.close();

    const QJsonDocument doc = QJsonDocument::fromJson(raw);
    if (!doc.isObject()) {
        Q_EMIT dataReady(data);
        return;
    }

    const QJsonArray matches = doc.object().value(QStringLiteral("matches")).toArray();
    for (const QJsonValue &value : matches) {
        const QJsonObject match = value.toObject();

        // Start time: epoch milliseconds (UTC). Skip anything without a usable time.
        const qint64 startMs = static_cast<qint64>(match.value(QStringLiteral("startMs")).toDouble());
        if (startMs <= 0) {
            continue;
        }

        const QDateTime start = QDateTime::fromMSecsSinceEpoch(startMs, QTimeZone::UTC);
        const QDate localDate = start.toLocalTime().date();
        if (localDate < m_rangeStart || localDate > m_rangeEnd) {
            continue;
        }

        const int durationMinutes = qMax(1, match.value(QStringLiteral("durationMinutes")).toInt(120));

        CalendarEvents::EventData event;
        event.setEventType(CalendarEvents::EventData::Event);
        event.setStartDateTime(start);
        event.setEndDateTime(start.addSecs(durationMinutes * 60));
        event.setIsAllDay(false);
        event.setTitle(match.value(QStringLiteral("title")).toString());
        event.setDescription(match.value(QStringLiteral("description")).toString());

        const QString color = match.value(QStringLiteral("color")).toString();
        if (!color.isEmpty()) {
            event.setEventColor(color);
        }

        const QString uid = match.value(QStringLiteral("uid")).toString();
        if (!uid.isEmpty()) {
            event.setUid(uid);
        }

        data.insert(localDate, event);
    }

    Q_EMIT dataReady(data);
}

#include "moc_sportsmatchesevents.cpp"
