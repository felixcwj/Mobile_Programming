enum EventRepeat {
  none('반복되지 않음'),
  daily('매일'),
  weekly('매주'),
  monthly('매월'),
  yearly('매년');

  const EventRepeat(this.label);
  final String label;
}

enum EventCategory {
  personal('개인', 0xFF69AD94),
  school('대학', 0xFF7772C8),
  work('업무', 0xFF6099C8),
  appointment('약속방', 0xFFED986A);

  const EventCategory(this.label, this.colorValue);
  final String label;
  final int colorValue;
}

DateTime calendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _dayDistance(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// End is exclusive, including for all-day events.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.repeat = EventRepeat.none,
    this.category = EventCategory.personal,
    this.reminderMinutes,
    this.location = '',
    this.notes = '',
    this.roomId,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final EventRepeat repeat;
  final EventCategory category;
  final int? reminderMinutes;
  final String location;
  final String notes;
  final String? roomId;

  Iterable<CalendarEntry> entriesOn(DateTime value) sync* {
    final day = calendarDay(value);
    final nextDay = DateTime(day.year, day.month, day.day + 1);
    if (repeat == EventRepeat.none) {
      if (start.isBefore(nextDay) && end.isAfter(day)) {
        yield CalendarEntry(event: this, start: start, end: end);
      }
      return;
    }
    final span = _dayDistance(start, end);
    for (var offset = span; offset >= 0; offset--) {
      final candidate = DateTime(day.year, day.month, day.day - offset);
      final distance = _dayDistance(start, candidate);
      if (distance < 0) continue;
      final matches = switch (repeat) {
        EventRepeat.none => false,
        EventRepeat.daily => true,
        EventRepeat.weekly => distance % 7 == 0,
        EventRepeat.monthly => candidate.day == start.day,
        EventRepeat.yearly =>
          candidate.month == start.month && candidate.day == start.day,
      };
      if (!matches) continue;
      final occurrenceStart = DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        start.hour,
        start.minute,
        start.second,
      );
      final occurrenceEnd = DateTime(
        candidate.year,
        candidate.month,
        candidate.day + span,
        end.hour,
        end.minute,
        end.second,
      );
      if (occurrenceStart.isBefore(nextDay) && occurrenceEnd.isAfter(day)) {
        yield CalendarEntry(
          event: this,
          start: occurrenceStart,
          end: occurrenceEnd,
        );
      }
    }
  }
}

class CalendarEntry {
  const CalendarEntry({
    required this.event,
    required this.start,
    required this.end,
  });
  final CalendarEvent event;
  final DateTime start;
  final DateTime end;
}
