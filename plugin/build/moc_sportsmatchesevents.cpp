/****************************************************************************
** Meta object code from reading C++ file 'sportsmatchesevents.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../sportsmatchesevents.h"
#include <QtCore/qmetatype.h>
#include <QtCore/qplugin.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'sportsmatchesevents.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.11.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN25SportsMatchesEventsPluginE_t {};
} // unnamed namespace

template <> constexpr inline auto SportsMatchesEventsPlugin::qt_create_metaobjectdata<qt_meta_tag_ZN25SportsMatchesEventsPluginE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "SportsMatchesEventsPlugin",
        "onSnapshotChanged",
        ""
    };

    QtMocHelpers::UintData qt_methods {
        // Slot 'onSnapshotChanged'
        QtMocHelpers::SlotData<void()>(1, 2, QMC::AccessPrivate, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<SportsMatchesEventsPlugin, qt_meta_tag_ZN25SportsMatchesEventsPluginE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject SportsMatchesEventsPlugin::staticMetaObject = { {
    QMetaObject::SuperData::link<CalendarEvents::CalendarEventsPlugin::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN25SportsMatchesEventsPluginE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN25SportsMatchesEventsPluginE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN25SportsMatchesEventsPluginE_t>.metaTypes,
    nullptr
} };

void SportsMatchesEventsPlugin::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<SportsMatchesEventsPlugin *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->onSnapshotChanged(); break;
        default: ;
        }
    }
    (void)_a;
}

const QMetaObject *SportsMatchesEventsPlugin::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *SportsMatchesEventsPlugin::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN25SportsMatchesEventsPluginE_t>.strings))
        return static_cast<void*>(this);
    if (!strcmp(_clname, "org.kde.CalendarEventsPlugin"))
        return static_cast< CalendarEvents::CalendarEventsPlugin*>(this);
    return CalendarEvents::CalendarEventsPlugin::qt_metacast(_clname);
}

int SportsMatchesEventsPlugin::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = CalendarEvents::CalendarEventsPlugin::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 1)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 1;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 1)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 1;
    }
    return _id;
}

#ifdef QT_MOC_EXPORT_PLUGIN_V2
static constexpr unsigned char qt_pluginMetaDataV2_SportsMatchesEventsPlugin[] = {
    0xbf, 
    // "IID"
    0x02,  0x78,  0x1c,  'o',  'r',  'g',  '.',  'k', 
    'd',  'e',  '.',  'C',  'a',  'l',  'e',  'n', 
    'd',  'a',  'r',  'E',  'v',  'e',  'n',  't', 
    's',  'P',  'l',  'u',  'g',  'i',  'n', 
    // "className"
    0x03,  0x78,  0x19,  'S',  'p',  'o',  'r',  't', 
    's',  'M',  'a',  't',  'c',  'h',  'e',  's', 
    'E',  'v',  'e',  'n',  't',  's',  'P',  'l', 
    'u',  'g',  'i',  'n', 
    // "MetaData"
    0x04,  0xa2,  0x67,  'K',  'P',  'l',  'u',  'g', 
    'i',  'n',  0xa6,  0x67,  'A',  'u',  't',  'h', 
    'o',  'r',  's',  0x81,  0xa2,  0x65,  'E',  'm', 
    'a',  'i',  'l',  0x78,  0x1b,  'p',  'e',  't', 
    'a',  'r',  '.',  'n',  'e',  'd',  'y',  'a', 
    'l',  'k',  'o',  'v',  '9',  '1',  '@',  'g', 
    'm',  'a',  'i',  'l',  '.',  'c',  'o',  'm', 
    0x64,  'N',  'a',  'm',  'e',  0x6f,  'P',  'e', 
    't',  'a',  'r',  ' ',  'N',  'e',  'd',  'y', 
    'a',  'l',  'k',  'o',  'v',  0x6b,  'D',  'e', 
    's',  'c',  'r',  'i',  'p',  't',  'i',  'o', 
    'n',  0x78,  0x51,  'S',  'h',  'o',  'w',  's', 
    ' ',  't',  'h',  'e',  ' ',  'm',  'a',  't', 
    'c',  'h',  'e',  's',  ' ',  'y',  'o',  'u', 
    ' ',  'f',  'o',  'l',  'l',  'o',  'w',  ' ', 
    'i',  'n',  ' ',  't',  'h',  'e',  ' ',  'S', 
    'p',  'o',  'r',  't',  's',  ' ',  'w',  'i', 
    'd',  'g',  'e',  't',  ' ',  'd',  'i',  'r', 
    'e',  'c',  't',  'l',  'y',  ' ',  'i',  'n', 
    ' ',  't',  'h',  'e',  ' ',  'P',  'l',  'a', 
    's',  'm',  'a',  ' ',  'c',  'a',  'l',  'e', 
    'n',  'd',  'a',  'r',  0x70,  'E',  'n',  'a', 
    'b',  'l',  'e',  'd',  'B',  'y',  'D',  'e', 
    'f',  'a',  'u',  'l',  't',  0xf5,  0x64,  'I', 
    'c',  'o',  'n',  0x71,  'v',  'i',  'e',  'w', 
    '-',  'c',  'a',  'l',  'e',  'n',  'd',  'a', 
    'r',  '-',  'd',  'a',  'y',  0x67,  'L',  'i', 
    'c',  'e',  'n',  's',  'e',  0x70,  'G',  'P', 
    'L',  '-',  '2',  '.',  '0',  '-',  'o',  'r', 
    '-',  'l',  'a',  't',  'e',  'r',  0x64,  'N', 
    'a',  'm',  'e',  0x75,  'S',  'p',  'o',  'r', 
    't',  's',  ' ',  'W',  'i',  'd',  'g',  'e', 
    't',  ' ',  'm',  'a',  't',  'c',  'h',  'e', 
    's',  0x78,  0x1d,  'X',  '-',  'K',  'D',  'E', 
    '-',  'P',  'l',  'a',  's',  'm',  'a',  'C', 
    'a',  'l',  'e',  'n',  'd',  'a',  'r',  '-', 
    'C',  'o',  'n',  'f',  'i',  'g',  'U',  'i', 
    0x78,  0x31,  's',  'p',  'o',  'r',  't',  's', 
    'm',  'a',  't',  'c',  'h',  'e',  's',  'e', 
    'v',  'e',  'n',  't',  's',  '/',  'S',  'p', 
    'o',  'r',  't',  's',  'M',  'a',  't',  'c', 
    'h',  'e',  's',  'E',  'v',  'e',  'n',  't', 
    's',  'C',  'o',  'n',  'f',  'i',  'g',  '.', 
    'q',  'm',  'l', 
    0xff, 
};
QT_MOC_EXPORT_PLUGIN_V2(SportsMatchesEventsPlugin, SportsMatchesEventsPlugin, qt_pluginMetaDataV2_SportsMatchesEventsPlugin)
#else
QT_PLUGIN_METADATA_SECTION
Q_CONSTINIT static constexpr unsigned char qt_pluginMetaData_SportsMatchesEventsPlugin[] = {
    'Q', 'T', 'M', 'E', 'T', 'A', 'D', 'A', 'T', 'A', ' ', '!',
    // metadata version, Qt version, architectural requirements
    0, QT_VERSION_MAJOR, QT_VERSION_MINOR, qPluginArchRequirements(),
    0xbf, 
    // "IID"
    0x02,  0x78,  0x1c,  'o',  'r',  'g',  '.',  'k', 
    'd',  'e',  '.',  'C',  'a',  'l',  'e',  'n', 
    'd',  'a',  'r',  'E',  'v',  'e',  'n',  't', 
    's',  'P',  'l',  'u',  'g',  'i',  'n', 
    // "className"
    0x03,  0x78,  0x19,  'S',  'p',  'o',  'r',  't', 
    's',  'M',  'a',  't',  'c',  'h',  'e',  's', 
    'E',  'v',  'e',  'n',  't',  's',  'P',  'l', 
    'u',  'g',  'i',  'n', 
    // "MetaData"
    0x04,  0xa2,  0x67,  'K',  'P',  'l',  'u',  'g', 
    'i',  'n',  0xa6,  0x67,  'A',  'u',  't',  'h', 
    'o',  'r',  's',  0x81,  0xa2,  0x65,  'E',  'm', 
    'a',  'i',  'l',  0x78,  0x1b,  'p',  'e',  't', 
    'a',  'r',  '.',  'n',  'e',  'd',  'y',  'a', 
    'l',  'k',  'o',  'v',  '9',  '1',  '@',  'g', 
    'm',  'a',  'i',  'l',  '.',  'c',  'o',  'm', 
    0x64,  'N',  'a',  'm',  'e',  0x6f,  'P',  'e', 
    't',  'a',  'r',  ' ',  'N',  'e',  'd',  'y', 
    'a',  'l',  'k',  'o',  'v',  0x6b,  'D',  'e', 
    's',  'c',  'r',  'i',  'p',  't',  'i',  'o', 
    'n',  0x78,  0x51,  'S',  'h',  'o',  'w',  's', 
    ' ',  't',  'h',  'e',  ' ',  'm',  'a',  't', 
    'c',  'h',  'e',  's',  ' ',  'y',  'o',  'u', 
    ' ',  'f',  'o',  'l',  'l',  'o',  'w',  ' ', 
    'i',  'n',  ' ',  't',  'h',  'e',  ' ',  'S', 
    'p',  'o',  'r',  't',  's',  ' ',  'w',  'i', 
    'd',  'g',  'e',  't',  ' ',  'd',  'i',  'r', 
    'e',  'c',  't',  'l',  'y',  ' ',  'i',  'n', 
    ' ',  't',  'h',  'e',  ' ',  'P',  'l',  'a', 
    's',  'm',  'a',  ' ',  'c',  'a',  'l',  'e', 
    'n',  'd',  'a',  'r',  0x70,  'E',  'n',  'a', 
    'b',  'l',  'e',  'd',  'B',  'y',  'D',  'e', 
    'f',  'a',  'u',  'l',  't',  0xf5,  0x64,  'I', 
    'c',  'o',  'n',  0x71,  'v',  'i',  'e',  'w', 
    '-',  'c',  'a',  'l',  'e',  'n',  'd',  'a', 
    'r',  '-',  'd',  'a',  'y',  0x67,  'L',  'i', 
    'c',  'e',  'n',  's',  'e',  0x70,  'G',  'P', 
    'L',  '-',  '2',  '.',  '0',  '-',  'o',  'r', 
    '-',  'l',  'a',  't',  'e',  'r',  0x64,  'N', 
    'a',  'm',  'e',  0x75,  'S',  'p',  'o',  'r', 
    't',  's',  ' ',  'W',  'i',  'd',  'g',  'e', 
    't',  ' ',  'm',  'a',  't',  'c',  'h',  'e', 
    's',  0x78,  0x1d,  'X',  '-',  'K',  'D',  'E', 
    '-',  'P',  'l',  'a',  's',  'm',  'a',  'C', 
    'a',  'l',  'e',  'n',  'd',  'a',  'r',  '-', 
    'C',  'o',  'n',  'f',  'i',  'g',  'U',  'i', 
    0x78,  0x31,  's',  'p',  'o',  'r',  't',  's', 
    'm',  'a',  't',  'c',  'h',  'e',  's',  'e', 
    'v',  'e',  'n',  't',  's',  '/',  'S',  'p', 
    'o',  'r',  't',  's',  'M',  'a',  't',  'c', 
    'h',  'e',  's',  'E',  'v',  'e',  'n',  't', 
    's',  'C',  'o',  'n',  'f',  'i',  'g',  '.', 
    'q',  'm',  'l', 
    0xff, 
};
QT_MOC_EXPORT_PLUGIN(SportsMatchesEventsPlugin, SportsMatchesEventsPlugin)
#endif  // QT_MOC_EXPORT_PLUGIN_V2

QT_WARNING_POP
