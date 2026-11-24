import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../l10n/planit_l10n.dart';

import '../screens/profile/profile_widgets.dart';

String scrollTimeLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

DateTime scrollTimeOnDate(DateTime date, int minutes) =>
    DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);

/// Minutes from the selected day's midnight. 1440 means 24:00 (next midnight).
Future<int?> showScrollTimePicker(
  BuildContext context, {
  required int initialMinutes,
  required String title,
}) => showModalBottomSheet<int>(
  context: context,
  backgroundColor: Colors.transparent,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => Theme(
    data: profileTheme(context),
    child: ScrollTimePicker(initialMinutes: initialMinutes, title: title),
  ),
);

class ScrollTimePicker extends StatefulWidget {
  const ScrollTimePicker({
    super.key,
    required this.initialMinutes,
    required this.title,
  }) : assert(initialMinutes >= 0 && initialMinutes <= 1440);

  final int initialMinutes;
  final String title;

  @override
  State<ScrollTimePicker> createState() => _ScrollTimePickerState();
}

class _ScrollTimePickerState extends State<ScrollTimePicker> {
  late int _hour = widget.initialMinutes ~/ 60;
  late int _minute = widget.initialMinutes % 60;
  late final _hours = FixedExtentScrollController(initialItem: _hour);
  late final _minutes = FixedExtentScrollController(initialItem: _minute);

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: profileSurface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFBFD8E8),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(
                color: profileInk,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              scrollTimeLabel(_hour * 60 + _minute),
              key: const ValueKey('selected-scroll-time'),
              style: const TextStyle(
                color: profileBlue,
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      key: const ValueKey('time-hour-wheel'),
                      scrollController: _hours,
                      itemExtent: 40,
                      onSelectedItemChanged: (hour) {
                        if (hour == 24) _minutes.jumpToItem(0);
                        setState(() {
                          _hour = hour;
                          if (hour == 24) _minute = 0;
                        });
                      },
                      children: [
                        for (var hour = 0; hour <= 24; hour++)
                          Center(
                            child: Text(
                              hour.toString().padLeft(2, '0'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: profileInk, fontSize: 24),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(l10n(context).hr, style: TextStyle(color: profileInk)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoPicker(
                      key: const ValueKey('time-minute-wheel'),
                      scrollController: _minutes,
                      itemExtent: 40,
                      onSelectedItemChanged: (minute) =>
                          setState(() => _minute = _hour == 24 ? 0 : minute),
                      children: [
                        for (
                          var minute = 0;
                          minute < (_hour == 24 ? 1 : 60);
                          minute++
                        )
                          Center(
                            child: Text(
                              minute.toString().padLeft(2, '0'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: profileInk, fontSize: 24),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(l10n(context).min, style: TextStyle(color: profileInk)),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n(context).isMidnightAtTheEndOfThe,
              style: TextStyle(color: Color(0xFF6C879A), fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n(context).cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _hour * 60 + _minute),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l10n(context).select),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
