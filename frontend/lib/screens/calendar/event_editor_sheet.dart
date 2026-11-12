import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../services/calendar_controller.dart';

String calendarDateLabel(DateTime date) {
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.month}월 ${date.day}일 (${days[date.weekday - 1]})';
}

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
  builder: (sheetContext) => Padding(
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
  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  late EventRepeat _repeat;
  late EventCategory _category;
  int? _reminderMinutes;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: event?.title);
    _location = TextEditingController(text: event?.location);
    _notes = TextEditingController(text: event?.notes);
    final date = widget.initialDate;
    _start = event?.start ?? DateTime(date.year, date.month, date.day, 9);
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
        ? _start
        : _allDay
        ? DateTime(_end.year, _end.month, _end.day - 1)
        : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: isStart ? '시작 날짜' : '종료 날짜',
    );
    if (date == null || !mounted) return;
    DateTime picked = date;
    if (!_allDay) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        helpText: isStart ? '시작 시간' : '종료 시간',
      );
      if (time == null || !mounted) return;
      picked = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    } else if (!isStart) {
      picked = DateTime(date.year, date.month, date.day + 1);
    }
    if (!isStart && !picked.isAfter(_start)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종료는 시작보다 나중으로 선택해 주세요.')));
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
        _start = calendarDay(_start);
        _end = _end == calendarDay(_end)
            ? _end
            : DateTime(_end.year, _end.month, _end.day + 1);
      } else {
        _start = DateTime(_start.year, _start.month, _start.day, 9);
        _end = DateTime(_end.year, _end.month, _end.day - 1, 10);
      }
      _allDay = !_allDay;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.controller.save(
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
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정을 삭제할까요?'),
        content: Text(
          _repeat == EventRepeat.none
              ? '삭제한 일정은 되돌릴 수 없어요.'
              : '이 일정의 모든 반복 일정이 함께 삭제돼요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.controller.delete(widget.event!.id);
    Navigator.of(context).pop(true);
  }

  String get _reminderLabel => switch (_reminderMinutes) {
    null => '알림 없음',
    0 => '시작 시간',
    60 => '1시간 전',
    1440 => '1일 전',
    final minutes => '$minutes분 전',
  };

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
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
              color: const Color(0xFFCCCCCE),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: '일정 편집 닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 21),
                ),
                const Spacer(),
                if (widget.event != null)
                  PopupMenuButton<String>(
                    tooltip: '일정 메뉴',
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (_) => _delete(),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('일정 삭제'),
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
                      decoration: const InputDecoration(
                        hintText: '제목',
                        counterText: '',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Color(0xFFCCCCCE)),
                      ),
                      validator: (text) => text == null || text.trim().isEmpty
                          ? '제목을 입력해 주세요.'
                          : null,
                    ),
                    if (widget.event != null && _repeat != EventRepeat.none)
                      const Text(
                        '수정하면 모든 반복 일정에 적용돼요.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          color: Color(0xFF757578),
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
                        label: const Text('하루종일'),
                        selected: _allDay,
                        onSelected: (_) => _toggleAllDay(),
                        showCheckmark: false,
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFFEDEBF8),
                        side: const BorderSide(color: Color(0xFFE1E1E5)),
                        shape: const StadiumBorder(),
                      ),
                    ),
                    _optionRow(
                      Icons.repeat,
                      PopupMenuButton<EventRepeat>(
                        tooltip: '반복 설정',
                        initialValue: _repeat,
                        onSelected: (value) => setState(() => _repeat = value),
                        itemBuilder: (_) => [
                          for (final value in EventRepeat.values)
                            PopupMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                        ],
                        child: _pill(_repeat.label),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _optionRow(
                      Icons.calendar_month_outlined,
                      PopupMenuButton<EventCategory>(
                        tooltip: '캘린더 분류',
                        initialValue: _category,
                        onSelected: (value) =>
                            setState(() => _category = value),
                        itemBuilder: (_) => [
                          for (final value in EventCategory.values.where(
                            (v) => v != EventCategory.appointment,
                          ))
                            PopupMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                        ],
                        child: _pill(
                          '●  ${_category.label}',
                          color: Color(_category.colorValue),
                        ),
                      ),
                    ),
                    _optionRow(
                      Icons.notifications_none_outlined,
                      PopupMenuButton<int>(
                        tooltip: '알림 시간 설정',
                        initialValue: _reminderMinutes ?? -1,
                        onSelected: (value) => setState(
                          () => _reminderMinutes = value == -1 ? null : value,
                        ),
                        itemBuilder: (_) => [
                          for (final entry in {
                            -1: '알림 없음',
                            0: '시작 시간',
                            5: '5분 전',
                            10: '10분 전',
                            30: '30분 전',
                            60: '1시간 전',
                            1440: '1일 전',
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
                      const Padding(
                        padding: EdgeInsets.only(left: 36, bottom: 8),
                        child: Text(
                          '알림 시간은 저장되며, 기기 알림은 추후 지원 예정이에요.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('event-location'),
                      controller: _location,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        icon: Icon(Icons.location_on_outlined),
                        hintText: '위치',
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    const Divider(color: Color(0xFFF2F2F4)),
                    TextFormField(
                      key: const ValueKey('event-notes'),
                      controller: _notes,
                      maxLength: 2000,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        icon: Icon(Icons.notes_outlined),
                        hintText: '메모',
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
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF292929),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 16,
                  ),
                  shape: const StadiumBorder(),
                  elevation: 8,
                ),
                icon: const Icon(Icons.check),
                label: const Text('저장', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _dateButton(bool isStart) {
    final date = isStart
        ? _start
        : _allDay
        ? DateTime(_end.year, _end.month, _end.day - 1)
        : _end;
    return TextButton(
      key: ValueKey(isStart ? 'event-start' : 'event-end'),
      onPressed: () => _pickDateTime(isStart),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF292929),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            child: Text(
              calendarDateLabel(date),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              _allDay ? '하루종일' : calendarTimeLabel(date),
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
        Icon(icon, color: const Color(0xFF757578), size: 22),
        const SizedBox(width: 14),
        child,
      ],
    ),
  );

  Widget _pill(String label, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F7),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Text(
      label,
      style: TextStyle(color: color ?? const Color(0xFF454548), fontSize: 15),
    ),
  );
}
