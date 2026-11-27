import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/planit_l10n.dart';

import '../../models/calendar_event.dart';
import '../../services/calendar_controller.dart';
import '../../widgets/scroll_time_picker.dart';
import '../profile/profile_widgets.dart';

String calendarTimeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

Future<bool?> showEventEditor(
  BuildContext context, {
  required CalendarController controller,
  required DateTime date,
  CalendarEvent? event,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (sheetContext) => Theme(
    data: profileTheme(sheetContext),
    child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: .94,
        child: EventEditorSheet(
          controller: controller,
          initialDate: date,
          event: event,
        ),
      ),
    ),
  ),
);

class EventEditorSheet extends StatefulWidget {
  const EventEditorSheet({
    super.key,
    required this.controller,
    required this.initialDate,
    this.event,
  });

  final CalendarController controller;
  final DateTime initialDate;
  final CalendarEvent? event;

  @override
  State<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<EventEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late final DateTime _startDate;
  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  late EventRepeat _repeat;
  late EventCategory _category;
  int? _reminderMinutes;

  bool get _endUses24Hour => !_allDay && _end.hour == 0 && _end.minute == 0;
  bool get _startUses24Hour => !_allDay && calendarDay(_start) != _startDate;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: event?.title);
    _location = TextEditingController(text: event?.location);
    _notes = TextEditingController(text: event?.notes);
    final date = widget.initialDate;
    _start = event?.start ?? DateTime(date.year, date.month, date.day, 9);
    _startDate = calendarDay(_start);
    _end = event?.end ?? _start.add(const Duration(hours: 1));
    _allDay = event?.allDay ?? false;
    _repeat = event?.repeat ?? EventRepeat.none;
    _category = event?.category ?? EventCategory.personal;
    _reminderMinutes = event?.reminderMinutes;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final initial = isStart
        ? _startDate
        : _allDay || _endUses24Hour
        ? DateTime(_end.year, _end.month, _end.day - 1)
        : _end;
    var date = calendarDay(initial);
    if (!isStart) {
      final selectedDate = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200, 12, 31),
        helpText: l10n(context).endDate,
      );
      if (selectedDate == null || !mounted) return;
      date = selectedDate;
    }
    DateTime picked = date;
    if (!_allDay) {
      final time = await showScrollTimePicker(
        context,
        initialMinutes: isStart
            ? _startUses24Hour
                  ? 1440
                  : _start.hour * 60 + _start.minute
            : _endUses24Hour
            ? 1440
            : initial.hour * 60 + initial.minute,
        title: isStart ? l10n(context).startTime : l10n(context).endTime,
      );
      if (time == null || !mounted) return;
      picked = scrollTimeOnDate(date, time);
    } else if (!isStart) {
      picked = DateTime(date.year, date.month, date.day + 1);
    }
    if (!isStart && !picked.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n(context).chooseAnEndTimeAfterTheStart)),
      );
      return;
    }
    setState(() {
      if (isStart) {
        _start = picked;
        if (!_end.isAfter(_start)) {
          _end = _allDay
              ? DateTime(picked.year, picked.month, picked.day + 1)
              : picked.add(const Duration(hours: 1));
        }
      } else {
        _end = picked;
      }
    });
  }

  void _toggleAllDay() {
    setState(() {
      if (!_allDay) {
        _start = _startDate;
        _end = _end == calendarDay(_end)
            ? _end
            : DateTime(_end.year, _end.month, _end.day + 1);
      } else {
        _start = DateTime(_startDate.year, _startDate.month, _startDate.day, 9);
        _end = DateTime(_end.year, _end.month, _end.day - 1, 10);
      }
      _allDay = !_allDay;
    });
  }

  bool _submitting = false;

  Future<void> _save() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.controller.saveRemote(
        CalendarEvent(
          id: widget.event?.id ?? widget.controller.newEventId(),
          title: _title.text.trim(),
          start: _start,
          end: _end,
          allDay: _allDay,
          repeat: _repeat,
          category: _category,
          reminderMinutes: _reminderMinutes,
          location: _location.text.trim(),
          notes: _notes.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n(context).eventSaveFailed(displayError(context, error)),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n(context).deleteThisEvent),
        content: Text(
          _repeat == EventRepeat.none
              ? l10n(context).deletingThisEventIsPermanent
              : l10n(context).allOccurrencesOfThisEventWillBe,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n(context).delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.controller.deleteRemote(widget.event!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n(context).eventDeleteFailed(displayError(context, error)),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _reminderLabel => switch (_reminderMinutes) {
    null => l10n(context).noReminder,
    0 => l10n(context).startTime,
    60 => l10n(context).oneHourBefore,
    1440 => l10n(context).oneDayBefore,
    final minutes => l10n(context).minutesBefore(minutes),
  };

  @override
  Widget build(BuildContext context) => Material(
    color: profileSurface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 34,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFBFD8E8),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n(context).closeEventEditor,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 21),
                ),
                const Spacer(),
                if (widget.event != null)
                  PopupMenuButton<String>(
                    tooltip: l10n(context).eventMenu,
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (_) => _delete(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n(context).deleteEvent),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      key: const ValueKey('event-title'),
                      controller: _title,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLength: 100,
                      maxLengthEnforcement:
                          MaxLengthEnforcement.truncateAfterCompositionEnds,
                      decoration: InputDecoration(
                        hintText: l10n(context).title,
                        counterText: '',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Color(0xFF91ADBF)),
                      ),
                      validator: (text) => text == null || text.trim().isEmpty
                          ? l10n(context).enterATitle
                          : null,
                    ),
                    if (widget.event != null && _repeat != EventRepeat.none)
                      Text(
                        l10n(context).changesApplyToAllOccurrences,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6C879A),
                        ),
                      ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          color: Color(0xFF6C879A),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _dateButton(true)),
                        const Icon(Icons.chevron_right, size: 18),
                        Expanded(child: _dateButton(false)),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilterChip(
                        key: const ValueKey('event-all-day'),
                        label: Text(l10n(context).allDay),
                        selected: _allDay,
                        onSelected: (_) => _toggleAllDay(),
                        showCheckmark: false,
                        backgroundColor: Colors.white,
                        selectedColor: profileButton,
                        side: const BorderSide(color: Color(0xFFD5E6EF)),
                        shape: const StadiumBorder(),
                      ),
                    ),
                    _optionRow(
                      Icons.repeat,
                      PopupMenuButton<EventRepeat>(
                        tooltip: l10n(context).repeatSettings,
                        initialValue: _repeat,
                        onSelected: (value) => setState(() => _repeat = value),
                        itemBuilder: (_) => [
                          for (final value in EventRepeat.values)
                            PopupMenuItem(
                              value: value,
                              child: Text(displayLabel(context, value.label)),
                            ),
                        ],
                        child: _pill(displayLabel(context, _repeat.label)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _optionRow(
                      Icons.calendar_month_outlined,
                      PopupMenuButton<EventCategory>(
                        tooltip: l10n(context).calendarCategory,
                        initialValue: _category,
                        onSelected: (value) =>
                            setState(() => _category = value),
                        itemBuilder: (_) => [
                          for (final value in EventCategory.selectable)
                            PopupMenuItem(
                              value: value,
                              child: Text(displayLabel(context, value.label)),
                            ),
                        ],
                        child: _pill(
                          '●  ${displayLabel(context, _category.label)}',
                          color: Color(widget.controller.colorFor(_category)),
                        ),
                      ),
                    ),
                    _optionRow(
                      Icons.notifications_none_outlined,
                      PopupMenuButton<int>(
                        tooltip: l10n(context).reminderTime,
                        initialValue: _reminderMinutes ?? -1,
                        onSelected: (value) => setState(
                          () => _reminderMinutes = value == -1 ? null : value,
                        ),
                        itemBuilder: (_) => [
                          for (final entry in {
                            -1: l10n(context).noReminder,
                            0: l10n(context).startTime,
                            5: l10n(context).fiveMinutesBefore,
                            10: l10n(context).tenMinutesBefore,
                            30: l10n(context).thirtyMinutesBefore,
                            60: l10n(context).oneHourBefore,
                            1440: l10n(context).oneDayBefore,
                          }.entries)
                            PopupMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        child: _pill(_reminderLabel),
                      ),
                    ),
                    if (_reminderMinutes != null)
                      Padding(
                        padding: EdgeInsets.only(left: 36, bottom: 8),
                        child: Text(
                          l10n(
                            context,
                          ).reminderTimesAreSavedDeviceNotificationsWill,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6C879A),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('event-location'),
                      controller: _location,
                      maxLength: 200,
                      maxLengthEnforcement:
                          MaxLengthEnforcement.truncateAfterCompositionEnds,
                      decoration: InputDecoration(
                        icon: Icon(Icons.location_on_outlined),
                        hintText: l10n(context).location,
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    const Divider(color: Color(0xFFE1EDF5)),
                    TextFormField(
                      key: const ValueKey('event-notes'),
                      controller: _notes,
                      maxLength: 2000,
                      maxLengthEnforcement:
                          MaxLengthEnforcement.truncateAfterCompositionEnds,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        icon: Icon(Icons.notes_outlined),
                        hintText: l10n(context).notes,
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey('save-event'),
                onPressed: _submitting ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: profileBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 16,
                  ),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check),
                label: Text(l10n(context).save, style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _dateButton(bool isStart) {
    final date = isStart
        ? _startDate
        : _allDay || _endUses24Hour
        ? DateTime(_end.year, _end.month, _end.day - 1)
        : _end;
    return TextButton(
      key: ValueKey(isStart ? 'event-start' : 'event-end'),
      onPressed: isStart && _allDay ? null : () => _pickDateTime(isStart),
      style: TextButton.styleFrom(
        foregroundColor: profileInk,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            child: Text(
              planDateLabel(context, date, includeYear: false),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              _allDay
                  ? l10n(context).allDay
                  : isStart
                  ? _startUses24Hour
                        ? '24:00'
                        : calendarTimeLabel(_start)
                  : !isStart && _endUses24Hour
                  ? '24:00'
                  : calendarTimeLabel(date),
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionRow(IconData icon, Widget child) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF6C879A), size: 22),
        const SizedBox(width: 14),
        child,
      ],
    ),
  );

  Widget _pill(String label, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: profileWell,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      label,
      style: TextStyle(color: color ?? profileInk, fontSize: 15),
    ),
  );
}
