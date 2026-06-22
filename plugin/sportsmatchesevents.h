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

#ifndef SPORTSMATCHESEVENTS_H
#define SPORTSMATCHESEVENTS_H

#include <CalendarEvents/CalendarEventsPlugin>

#include <QDate>
#include <QString>

class QFileSystemWatcher;

// A Plasma calendar-events plugin that surfaces the matches the Sports widget
// follows directly inside the Plasma calendar (the date-menu dropdown), entirely
// in memory. It reads a small, inert JSON snapshot written by the widget and
// never touches Akonadi, an .ics resource, or the PIM indexer — so it cannot
// make plasmashell hang (the failure mode the previous Akonadi path had).
class SportsMatchesEventsPlugin : public CalendarEvents::CalendarEventsPlugin
{
    Q_OBJECT
    Q_INTERFACES(CalendarEvents::CalendarEventsPlugin)
    Q_PLUGIN_METADATA(IID "org.kde.CalendarEventsPlugin" FILE "metadata.json")

public:
    explicit SportsMatchesEventsPlugin(QObject *parent = nullptr);
    ~SportsMatchesEventsPlugin() override;

    void loadEventsForDateRange(const QDate &startDate, const QDate &endDate) override;

private Q_SLOTS:
    void onSnapshotChanged();

private:
    void emitEventsForCurrentRange();
    QString snapshotPath() const;

    QFileSystemWatcher *m_watcher = nullptr;
    QDate m_rangeStart;
    QDate m_rangeEnd;
};

#endif // SPORTSMATCHESEVENTS_H
