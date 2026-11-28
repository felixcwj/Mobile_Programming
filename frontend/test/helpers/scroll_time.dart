import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/widgets/scroll_time_picker.dart';

Future<void> selectScrollTime(WidgetTester tester, int hour, int minute) async {
  assert(minute % ScrollTimePicker.minuteInterval == 0);
  final hours = tester.widget<CupertinoPicker>(
    find.byKey(const ValueKey('time-hour-wheel')),
  );
  hours.scrollController!.jumpToItem(hour);
  await tester.pumpAndSettle();
  final minutes = tester.widget<CupertinoPicker>(
    find.byKey(const ValueKey('time-minute-wheel')),
  );
  minutes.scrollController!.jumpToItem(
    minute ~/ ScrollTimePicker.minuteInterval,
  );
  await tester.pumpAndSettle();
}
