import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> selectScrollTime(WidgetTester tester, int hour, int minute) async {
  final hours = tester.widget<CupertinoPicker>(
    find.byKey(const ValueKey('time-hour-wheel')),
  );
  hours.scrollController!.jumpToItem(hour);
  await tester.pumpAndSettle();
  final minutes = tester.widget<CupertinoPicker>(
    find.byKey(const ValueKey('time-minute-wheel')),
  );
  minutes.scrollController!.jumpToItem(minute);
  await tester.pumpAndSettle();
}
