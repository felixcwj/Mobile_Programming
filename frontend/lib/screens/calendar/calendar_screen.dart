import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../services/calendar_controller.dart';
import '../../services/planit_api.dart';
import 'event_editor_sheet.dart';

const _ink = Color(0xFF2D2D2F);
const _muted = Color(0xFF929295);

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.controller,
    this.onOpenRoom,
    this.initialDate,
    this.today,
  });

  final CalendarController controller;
  final ValueChanged<String>? onOpenRoom;
  final DateTime? initialDate;
  final DateTime? today;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selected;
  late DateTime _month;
  bool _mondayFirst = false;
  bool _colorWeekends = false;
  Timer? _yearRefreshTimer;

  DateTime get _today => calendarDay(widget.today ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    _selected = calendarDay(widget.initialDate ?? _today);
    _month = DateTime(_selected.year, _selected.month);
  }

  void _select(DateTime day) {
    final yearChanged = _month.year != day.year;
    setState(() {
      _selected = calendarDay(day);
      _month = DateTime(day.year, day.month);
    });
    if (yearChanged && PlanitApi.instance.hasSession) {
      _yearRefreshTimer?.cancel();
      _yearRefreshTimer = Timer(const Duration(milliseconds: 350), () async {
        try {
          await widget.controller.loadRemote(year: day.year);
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('해당 연도 일정을 불러오지 못했습니다: $error')),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _yearRefreshTimer?.cancel();
    super.dispose();
  }

  void _changeMonth(int offset) {
    final month = DateTime(_month.year, _month.month + offset);
    if (month.year < 1900 || month.year > 2200) return;
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    _select(
      DateTime(
        month.year,
        month.month,
        _selected.day > lastDay ? lastDay : _selected.day,
      ),
    );
  }

  Future<void> _jumpToDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: '이동할 날짜',
    );
    if (date != null && mounted) _select(date);
  }

  Future<void> _search() async {
    final event = await showSearch<CalendarEvent?>(
      context: context,
      delegate: _EventSearch(widget.controller),
    );
    if (event != null && mounted) _select(event.start);
  }

  void _edit([CalendarEvent? event]) {
    if (event?.roomId != null) {
      widget.onOpenRoom?.call(event!.roomId!);
      return;
    }
    showEventEditor(
      context,
      controller: widget.controller,
      date: _selected,
      event: event,
    );
  }

  List<DateTime> get _days {
    final offset = _mondayFirst ? _month.weekday - 1 : _month.weekday % 7;
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final total = ((offset + count) / 7).ceil() * 7;
    return List.generate(
      total,
      (i) => DateTime(_month.year, _month.month, 1 - offset + i),
    );
  }

  void _showMonthAgenda() {
    final monthDays = DateTime(_month.year, _month.month + 1, 0).day;
    final entries = <({DateTime day, CalendarEntry entry})>[
      for (var d = 1; d <= monthDays; d++)
        for (final entry in widget.controller.entriesOn(
          DateTime(_month.year, _month.month, d),
        ))
          (day: DateTime(_month.year, _month.month, d), entry: entry),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${_month.year}년 ${_month.month}월 일정 목록',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text('이번 달에 등록된 일정이 없어요.'))
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (_, index) {
                          final item = entries[index];
                          return ListTile(
                            leading: Text(
                              '${item.day.day}',
                              style: const TextStyle(fontSize: 23),
                            ),
                            title: Text(item.entry.event.title),
                            subtitle: Text(
                              '${item.entry.event.category.label} · ${item.entry.event.allDay ? '하루종일' : calendarTimeLabel(item.entry.start)}',
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _select(item.day);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final days = _days;
                final weeks = days.length ~/ 7;
                final cellHeight = (constraints.maxHeight * .57 / weeks).clamp(
                  64.0,
                  108.0,
                );
                final selectedEntries = widget.controller.entriesOn(_selected);
                return Column(
                  children: [
                    _header(),
                    Padding(
                      padding: const EdgeInsets.only(left: 18, right: 8),
                      child: Row(
                        children: [
                          Text(
                            '${_month.year}년 ${_month.month}월',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: '이전 달',
                            onPressed: () => _changeMonth(-1),
                            icon: const Icon(Icons.chevron_left, size: 21),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            tooltip: '다음 달',
                            onPressed: () => _changeMonth(1),
                            icon: const Icon(Icons.chevron_right, size: 21),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: GestureDetector(
                                onHorizontalDragEnd: (details) {
                                  final speed = details.primaryVelocity ?? 0;
                                  if (speed.abs() > 150) {
                                    _changeMonth(speed < 0 ? 1 : -1);
                                  }
                                },
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        for (final weekday
                                            in _mondayFirst
                                                ? [
                                                    '월',
                                                    '화',
                                                    '수',
                                                    '목',
                                                    '금',
                                                    '토',
                                                    '일',
                                                  ]
                                                : [
                                                    '일',
                                                    '월',
                                                    '화',
                                                    '수',
                                                    '목',
                                                    '금',
                                                    '토',
                                                  ])
                                          Expanded(
                                            child: Center(
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 10,
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  weekday,
                                                  style: const TextStyle(
                                                    color: _muted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    for (var week = 0; week < weeks; week++)
                                      SizedBox(
                                        height: cellHeight,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            for (var d = 0; d < 7; d++)
                                              Expanded(
                                                child: _dayCell(
                                                  days[week * 7 + d],
                                                  cellHeight,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                24,
                                16,
                                12,
                              ),
                              child: Text(
                                '${_selected.year}년 ${calendarDateLabel(_selected)}',
                                key: const ValueKey('selected-date'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                            ),
                            if (selectedEntries.isEmpty)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
                                child: Text(
                                  '등록된 일정이 없어요.',
                                  style: TextStyle(color: _muted, fontSize: 14),
                                ),
                              )
                            else
                              for (final entry in selectedEntries)
                                _agendaTile(entry),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              key: const ValueKey('add-calendar-event'),
                              onPressed: () => _edit(),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFF4F4F6),
                                foregroundColor: _ink,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 24),
                              label: const Text(
                                '새로운 이벤트',
                                style: TextStyle(fontSize: 17),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: '월간 일정 목록',
                            onPressed: _showMonthAgenda,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF4F4F6),
                              foregroundColor: _ink,
                              padding: const EdgeInsets.all(18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.article_outlined, size: 23),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
    child: Row(
      children: [
        SizedBox(
          width: 32,
          child: IconButton(
            tooltip: '홈으로 돌아가기',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 44),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        Expanded(
          child: Semantics(
            label: '${_month.month}월, 날짜 이동',
            button: true,
            child: InkWell(
              onTap: _jumpToDate,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${_month.month}',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 76,
          child: OutlinedButton(
            onPressed: () => _select(_today),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              side: const BorderSide(color: _ink),
              shape: const StadiumBorder(),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: const FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.undo, size: 15),
                  SizedBox(width: 3),
                  Text(
                    'TODAY',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: '일정 검색',
            onPressed: _search,
            icon: const Icon(Icons.search, color: _ink),
            visualDensity: VisualDensity.compact,
          ),
        ),
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: '날짜 이동',
            onPressed: _jumpToDate,
            icon: const Icon(Icons.calendar_month_outlined, color: _ink),
            visualDensity: VisualDensity.compact,
          ),
        ),
        SizedBox(
          width: 40,
          child: PopupMenuButton<String>(
            tooltip: '달력 설정',
            icon: const Icon(Icons.settings_outlined, color: _ink),
            onSelected: (value) => setState(() {
              if (value == 'monday') _mondayFirst = !_mondayFirst;
              if (value == 'weekend') _colorWeekends = !_colorWeekends;
            }),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'monday',
                checked: _mondayFirst,
                child: const Text('월요일부터 시작'),
              ),
              CheckedPopupMenuItem(
                value: 'weekend',
                checked: _colorWeekends,
                child: const Text('주말 색상 표시'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _dayCell(DateTime day, double height) {
    final entries = widget.controller.entriesOn(day);
    final selected = day == _selected;
    final currentMonth = day.month == _month.month && day.year == _month.year;
    final slots = ((height - 30) / 15).floor().clamp(1, 3);
    final visibleCount = entries.length > slots ? slots - 1 : entries.length;
    final weekend = day.weekday == 7
        ? const Color(0xFFC87878)
        : const Color(0xFF7092BF);
    return Semantics(
      button: true,
      selected: selected,
      label: '${day.year}년 ${calendarDateLabel(day)}, 일정 ${entries.length}개',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
        child: Material(
          color: selected
              ? const Color(0xFF333334)
              : day == _today
              ? const Color(0xFFEFEFF2)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('calendar-day-${day.year}-${day.month}-${day.day}'),
            onTap: () => _select(day),
            onLongPress: () {
              _select(day);
              _edit();
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : !currentMonth
                          ? const Color(0xFFBBBBBE)
                          : _colorWeekends && day.weekday >= 6
                          ? weekend
                          : _ink,
                    ),
                  ),
                ),
                for (var i = 0; i < visibleCount; i++)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.only(left: 2),
                    decoration: BoxDecoration(
                      color: Color(
                        entries[i].event.category.colorValue,
                      ).withValues(alpha: selected ? .3 : .13),
                      border: Border(
                        left: BorderSide(
                          color: Color(entries[i].event.category.colorValue),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      entries[i].event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.25,
                        color: selected ? Colors.white : _ink,
                      ),
                    ),
                  ),
                if (entries.length > visibleCount)
                  Text(
                    '+${entries.length - visibleCount}개',
                    style: TextStyle(
                      fontSize: 9,
                      color: selected ? Colors.white70 : _muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _agendaTile(CalendarEntry entry) {
    final event = entry.event;
    final color = Color(event.category.colorValue);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          key: ValueKey('agenda-${event.id}-${entry.start.toIso8601String()}'),
          onTap: () => _edit(event),
          leading: Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          minLeadingWidth: 4,
          title: Text(
            event.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${_entryTimeLabel(entry)} · ${event.category.label}${event.location.isEmpty ? '' : ' · ${event.location}'}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Icon(
            event.roomId == null
                ? Icons.chevron_right
                : Icons.meeting_room_outlined,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }

  String _entryTimeLabel(CalendarEntry entry) {
    if (entry.event.allDay) return '하루종일';
    if (entry.event.roomId != null) return calendarTimeLabel(entry.start);
    if (calendarDay(entry.start) == calendarDay(entry.end)) {
      return '${calendarTimeLabel(entry.start)} – ${calendarTimeLabel(entry.end)}';
    }
    return '${entry.start.month}/${entry.start.day} ${calendarTimeLabel(entry.start)} – '
        '${entry.end.month}/${entry.end.day} ${calendarTimeLabel(entry.end)}';
  }
}

class _EventSearch extends SearchDelegate<CalendarEvent?> {
  _EventSearch(this.controller) : super(searchFieldLabel: '일정 검색');
  final CalendarController controller;

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      tooltip: '검색어 지우기',
      onPressed: () => query = '',
      icon: const Icon(Icons.clear),
    ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: '검색 닫기',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final search = query.trim().toLowerCase();
      final events =
          controller.events
              .where(
                (event) => '${event.title} ${event.location} ${event.notes}'
                    .toLowerCase()
                    .contains(search),
              )
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));
      if (events.isEmpty) return const Center(child: Text('검색된 일정이 없어요.'));
      return ListView.builder(
        itemCount: events.length,
        itemBuilder: (_, index) {
          final event = events[index];
          return ListTile(
            leading: Icon(
              Icons.circle,
              size: 10,
              color: Color(event.category.colorValue),
            ),
            title: Text(event.title),
            subtitle: Text(
              '${event.start.year}년 ${calendarDateLabel(event.start)} · ${event.category.label}',
            ),
            onTap: () => close(context, event),
          );
        },
      );
    },
  );
}
