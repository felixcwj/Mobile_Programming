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
  int _nextId = 0;
  final Map<String, int> _versions = {};
  final Map<String, CalendarEvent> _remoteRoomEvents = {};
  bool _serverRoomEventsLoaded = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  int _activeYear = DateTime.now().year;

  String newEventId() => 'personal-${_nextId++}';

  /// Loads private and recurring events from the current Firebase-backed user.
  Future<void> loadRemote({int? year}) async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    final targetYear = year ?? _activeYear;
    final start = DateTime(targetYear, 1, 1).toUtc().toIso8601String();
    final end = DateTime(targetYear + 1, 1, 1).toUtc().toIso8601String();
    final api = PlanitApi.instance;
    final current = await api.request('GET', '/calendar/events',
        query: {'starts_from': start, 'starts_before': end});
    final recurring = await api.request('GET', '/calendar/recurring-events');
    final records = <String, Map<String, dynamic>>{};
    for (final result in [current, recurring]) {
      for (final raw in result['events'] as List<dynamic>? ?? []) {
        if (raw is Map<String, dynamic>) {
          final id = raw['id']?.toString();
          if (id != null) records[id] = raw;
        }
      }
    }
    final personalEvents = <String, CalendarEvent>{};
    final versions = <String, int>{};
    for (final entry in records.entries) {
      final raw = entry.value;
      if (raw['deleted'] == true || raw['source'] == 'meeting') continue;
      final starts = DateTime.tryParse(raw['starts_at']?.toString() ?? '');
      final ends = DateTime.tryParse(raw['ends_at']?.toString() ?? '');
      if (starts == null || ends == null) continue;
      EventRepeat repeat = EventRepeat.none;
      for (final item in EventRepeat.values) {
        if (item.name == raw['repeat']) repeat = item;
      }
      EventCategory category = EventCategory.personal;
      for (final item in EventCategory.values) {
        if (item.name == raw['category'] && item != EventCategory.appointment) {
          category = item;
        }
      }
      versions[entry.key] = (raw['version'] as num?)?.toInt() ?? 1;
      personalEvents[entry.key] = CalendarEvent(
        id: entry.key,
        title: raw['title']?.toString() ?? '',
        start: starts.toLocal(),
        end: ends.toLocal(),
        allDay: raw['all_day'] == true,
        repeat: repeat,
        category: category,
        reminderMinutes: (raw['reminder_minutes'] as num?)?.toInt(),
        location: raw['location']?.toString() ?? '',
        notes: raw['memo']?.toString() ?? '',
      );
    }
    final roomsResponse = await api.request('GET', '/calendar/room-appointments');
    final remoteRoomEvents = <String, CalendarEvent>{};
    for (final raw in roomsResponse['events'] as List<dynamic>? ?? []) {
      if (raw is! Map<String, dynamic>) continue;
      final id = raw['id']?.toString();
      final start = DateTime.tryParse(raw['starts_at']?.toString() ?? '')?.toLocal();
      if (id == null || start == null) continue;
      final end = DateTime.tryParse(raw['ends_at']?.toString() ?? '')?.toLocal();
      remoteRoomEvents[id] = CalendarEvent(
        id: id,
        title: raw['title']?.toString() ?? '약속',
        start: start,
        end: end != null && end.isAfter(start)
            ? end
            : start.add(const Duration(microseconds: 1)),
        roomId: raw['room_id']?.toString(),
        location: raw['location']?.toString() ?? '',
        category: EventCategory.appointment,
        notes: raw['status'] == 'confirmed' ? '확정된 약속' : '예정된 약속',
      );
    }
    if (_disposed || generation != _loadGeneration) return;
    _personalEvents
      ..clear()
      ..addAll(personalEvents);
    _versions
      ..clear()
      ..addAll(versions);
    _remoteRoomEvents
      ..clear()
      ..addAll(remoteRoomEvents);
    _serverRoomEventsLoaded = true;
    _activeYear = targetYear;
    notifyListeners();
  }

  Future<void> saveRemote(CalendarEvent event) async {
    if (event.roomId != null || event.category == EventCategory.appointment) {
      throw const PlanitApiException('약속 방 일정은 방 화면에서 수정해 주세요.');
    }
    final payload = {
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
    final version = _versions[event.id];
    if (version == null) {
      await PlanitApi.instance.request('POST', '/calendar/events', body: payload);
    } else {
      await PlanitApi.instance.request('PUT', '/calendar/events/${Uri.encodeComponent(event.id)}',
          body: {...payload, 'version': version});
    }
    await loadRemote();
  }

  Future<void> deleteRemote(String id) async {
    final version = _versions[id];
    if (version == null) {
      throw const PlanitApiException('서버에서 일정을 찾을 수 없습니다.');
    }
    await PlanitApi.instance.request('DELETE',
        '/calendar/events/${Uri.encodeComponent(id)}',
        query: {'version': '$version'});
    await loadRemote();
  }

  List<CalendarEvent> get events => [
    ..._personalEvents.values,
    if (_serverRoomEventsLoaded)
      ..._remoteRoomEvents.values,
    if (!_serverRoomEventsLoaded)
      for (final room in roomsController.rooms)
      if (room.date != null)
        CalendarEvent(
          id: 'room-${room.id}',
          roomId: room.id,
          title: room.title,
          start: room.date!,
          // Rooms currently have only a start time; do not invent a duration.
          end: room.date!.add(const Duration(microseconds: 1)),
          category: EventCategory.appointment,
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
    if (_personalEvents.remove(id) != null) notifyListeners();
  }

  void _roomsChanged() => notifyListeners();

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    roomsController.removeListener(_roomsChanged);
    super.dispose();
  }
}
