import 'package:flutter/foundation.dart';

import '../models/calendar_event.dart';
import 'rooms_controller.dart';

/// Shared by the home and calendar routes for this local login session.
class CalendarController extends ChangeNotifier {
  CalendarController({required this.roomsController}) {
    roomsController.addListener(_roomsChanged);
  }

  final RoomsController roomsController;
  final Map<String, CalendarEvent> _personalEvents = {};
  int _nextId = 0;

  String newEventId() => 'personal-${_nextId++}';

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
  void dispose() {
    roomsController.removeListener(_roomsChanged);
    super.dispose();
  }
}
