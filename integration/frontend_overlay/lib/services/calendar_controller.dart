import 'package:flutter/foundation.dart';

import '../models/calendar_event.dart';
import 'rooms_controller.dart';
import 'planit_api.dart';

/// Shared by the home and calendar routes for this local login session.
class CalendarController extends ChangeNotifier {
  CalendarController({required this.roomsController}) {
    roomsController.addListener(_roomsChanged);
  }

  final RoomsController roomsController;
  final Map<String, CalendarEvent> _personalEvents = {};
  final Map<String, int> _remoteVersions = {};
  int _refreshGeneration = 0;
  bool _disposed = false;
  bool get online => roomsController.online;
  final Map<EventCategory, int> _categoryColors = {};
  int _nextId = 0;
  String? _ddayEventId;

  String? get ddayEventId => _ddayEventId;

  void setDday(String? eventId) {
    if (eventId != null && !events.any((event) => event.id == eventId)) {
      throw ArgumentError('Choose an existing calendar event.');
    }
    if (_ddayEventId == eventId) return;
    _ddayEventId = eventId;
    notifyListeners();
  }

  List<CalendarEntry> upcomingEntries(DateTime now) {
    final entries = events
        .map((event) => event.nextEntry(now))
        .whereType<CalendarEntry>()
        .toList();
    entries.sort((a, b) => a.start.compareTo(b.start));
    return entries;
  }

  /// One choice per event; repeating events use the next active occurrence.
  List<CalendarEntry> ddayChoices(DateTime now) {
    final entries = events
        .map(
          (event) =>
              event.nextEntry(now) ??
              CalendarEntry(event: event, start: event.start, end: event.end),
        )
        .toList();
    entries.sort((a, b) {
      final aPast = !a.end.isAfter(now);
      final bPast = !b.end.isAfter(now);
      if (aPast != bPast) return aPast ? 1 : -1;
      return aPast ? b.start.compareTo(a.start) : a.start.compareTo(b.start);
    });
    return entries;
  }

  CalendarEntry? featuredEntry(DateTime now) {
    if (_ddayEventId != null) {
      for (final entry in ddayChoices(now)) {
        if (entry.event.id == _ddayEventId) return entry;
      }
    }
    final upcoming = upcomingEntries(now);
    return upcoming.isEmpty ? null : upcoming.first;
  }

  String newEventId() => 'personal-${_nextId++}';

  int colorFor(EventCategory category) =>
      _categoryColors[category] ?? category.colorValue;

  void setCategoryColor(EventCategory category, int colorValue) {
    if (colorFor(category) == colorValue) return;
    _categoryColors[category] = colorValue;
    notifyListeners();
  }

  List<CalendarEvent> get events => [
    ..._personalEvents.values,
    for (final room in roomsController.rooms)
      if (room.date != null)
        CalendarEvent(
          id: 'room-${room.id}',
          roomId: room.id,
          title: room.title,
          start: room.date!,
          // Rooms currently have only a start time; do not invent a duration.
          end: room.date!.add(const Duration(microseconds: 1)),
          category: room.category,
          location: room.region == '지역 미정' ? '' : room.region,
          notes: room.status.label,
        ),
  ];

  List<CalendarEntry> entriesOn(DateTime day) {
    final entries = events.expand((event) => event.entriesOn(day)).toList();
    entries.sort((a, b) {
      if (a.event.allDay != b.event.allDay) return a.event.allDay ? -1 : 1;
      return a.start.compareTo(b.start);
    });
    return entries;
  }

  void save(CalendarEvent event) {
    if (event.roomId != null || event.id.startsWith('room-')) {
      throw ArgumentError('Room events are managed by RoomsController.');
    }
    if (event.title.trim().isEmpty || !event.end.isAfter(event.start)) {
      throw ArgumentError(
        'A title and a positive event duration are required.',
      );
    }
    _personalEvents[event.id] = event;
    notifyListeners();
  }

  void delete(String id) {
    if (_personalEvents.remove(id) != null) {
      if (_ddayEventId == id) _ddayEventId = null;
      notifyListeners();
    }
  }

  void _roomsChanged() {
    if (_ddayEventId != null &&
        !events.any((event) => event.id == _ddayEventId)) {
      _ddayEventId = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshGeneration++;
    roomsController.removeListener(_roomsChanged);
    super.dispose();
  }
  CalendarEvent? _decodeEvent(Map<String, dynamic> source) {
    final start = DateTime.tryParse(source['starts_at']?.toString() ?? '')?.toLocal();
    final end = DateTime.tryParse(source['ends_at']?.toString() ?? '')?.toLocal();
    if (start == null || end == null || !end.isAfter(start)) return null;
    final category = EventCategory.selectable
        .where((c) => c.name == source['category']).firstOrNull
        ?? EventCategory.personal;
    final repeat = EventRepeat.values
        .where((r) => r.name == source['repeat']).firstOrNull
        ?? EventRepeat.none;
    return CalendarEvent(
      id: source['id']?.toString() ?? '',
      title: source['title']?.toString() ?? '일정',
      start: start, end: end,
      allDay: source['all_day'] == true,
      repeat: repeat, category: category,
      location: source['location']?.toString() ?? '',
      notes: source['memo']?.toString() ?? '',
      reminderMinutes: (source['reminder_minutes'] as num?)?.toInt(),
    );
  }

  Future<void> refreshRemote() async {
    final service = roomsController.api;
    if (service == null || _disposed) return;
    final generation = ++_refreshGeneration;
    final now = DateTime.now();
    // Query windows stay below FastAPI's one-year limit.
    final windows = [
      [DateTime(now.year - 1, now.month, now.day), now],
      [now, DateTime(now.year + 1, now.month, now.day)],
    ];
    final fetched = <String, CalendarEvent>{};
    final versions = <String, int>{};
    for (final window in windows) {
      final result = await service.request('GET', '/calendar/events', query: {
        'starts_from': window[0].toUtc().toIso8601String(),
        'starts_before': window[1].toUtc().toIso8601String(),
      });
      for (final raw in result['events'] as List? ?? []) {
        if (raw is! Map<String, dynamic>) continue;
        final event = _decodeEvent(raw);
        if (event != null) {
          fetched[event.id] = event;
          versions[event.id] = (raw['version'] as num?)?.toInt() ?? 1;
        }
      }
    }
    final recurring = await service.request('GET', '/calendar/recurring-events');
    for (final raw in recurring['events'] as List? ?? []) {
      if (raw is! Map<String, dynamic>) continue;
      final event = _decodeEvent(raw);
      if (event != null) {
        fetched[event.id] = event;
        versions[event.id] = (raw['version'] as num?)?.toInt() ?? 1;
      }
    }
    if (_disposed || generation != _refreshGeneration) return;
    _personalEvents..clear()..addAll(fetched);
    _remoteVersions..clear()..addAll(versions);
    notifyListeners();
  }

  Map<String, dynamic> _encodeEvent(CalendarEvent event) => {
    'title': event.title,
    'starts_at': event.start.toUtc().toIso8601String(),
    'ends_at': event.end.toUtc().toIso8601String(),
    'location': event.location,
    'memo': event.notes,
    'all_day': event.allDay,
    'repeat': event.repeat.name,
    'category': event.category.name,
    'reminder_minutes': event.reminderMinutes,
  };

  Future<void> saveRemote(CalendarEvent event) async {
    final service = roomsController.api;
    if (service == null) {
      save(event);
      return;
    }
    if (event.roomId != null || event.id.startsWith('room-')) {
      throw ArgumentError('Room events must be changed from room settings.');
    }
    if (event.title.trim().isEmpty || !event.end.isAfter(event.start)) {
      throw ArgumentError('Invalid calendar event.');
    }
    final version = _remoteVersions[event.id];
    final Map<String, dynamic> saved;
    if (version == null) {
      saved = await service.request('POST', '/calendar/events',
          body: _encodeEvent(event));
    } else {
      saved = await service.request('PUT',
          '/calendar/events/${Uri.encodeComponent(event.id)}',
          body: {..._encodeEvent(event), 'version': version});
    }
    final updated = _decodeEvent(saved);
    if (updated == null || updated.id.isEmpty) {
      throw const PlanitApiException('서버에 저장했지만 일정 정보를 해석하지 못했습니다. 목록을 새로고침해 주세요.');
    }
    if (_disposed) return;
    _refreshGeneration++;
    _personalEvents.remove(event.id);
    _remoteVersions.remove(event.id);
    _personalEvents[updated.id] = updated;
    _remoteVersions[updated.id] = (saved['version'] as num?)?.toInt() ?? 1;
    notifyListeners();
    // A following read failure must not make the user repeat a successful
    // save and accidentally create a duplicate event.
    try {
      await refreshRemote();
    } on PlanitApiException {
      // Preserve the authoritative event returned by the successful write.
    }
  }

  Future<void> deleteRemote(String id) async {
    final service = roomsController.api;
    if (service == null) {
      delete(id);
      return;
    }
    final version = _remoteVersions[id];
    if (version == null) throw const PlanitApiException('일정을 찾을 수 없습니다.');
    await service.request('DELETE',
        '/calendar/events/${Uri.encodeComponent(id)}',
        query: {'version': '$version'});
    if (_disposed) return;
    _refreshGeneration++;
    _personalEvents.remove(id);
    _remoteVersions.remove(id);
    if (_ddayEventId == id) _ddayEventId = null;
    notifyListeners();
    try {
      await refreshRemote();
    } on PlanitApiException {
      // The deletion has already succeeded on the server.
    }
  }

}
