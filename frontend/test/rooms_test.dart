import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/models/plan_room.dart';
import 'package:meetsync/screens/rooms/rooms_screen.dart';
import 'package:meetsync/services/rooms_controller.dart';

void main() {
  test('Only a ready room can be confirmed, once', () {
    final controller = RoomsController.demo();
    addTearDown(controller.dispose);
    expect(controller.confirm('weekend'), isFalse);
    expect(controller.confirm('unknown'), isFalse);
    expect(controller.confirm('after-work'), isTrue);
    expect(controller.room('after-work').status, RoomStatus.confirmed);
    expect(controller.confirm('after-work'), isFalse);
  });

  testWidgets('Filter, detail, course and confirmation update the room list', (
    tester,
  ) async {
    final controller = RoomsController.demo();
    addTearDown(controller.dispose);
    var confirmedCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RoomsScreen(
          controller: controller,
          onConfirmed: (_) => confirmedCount++,
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '코스 확인하기'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('퇴근 후, 리프레시'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('퇴근 후, 리프레시'));
    await tester.pumpAndSettle();
    expect(find.text('친구들의 취향  2/2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('추천 코스 확인하기'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('추천 코스 확인하기'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('이 코스로 약속 확정'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('이 코스로 약속 확정')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 코스로 약속 확정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('더 살펴볼게요'));
    await tester.pumpAndSettle();
    expect(controller.room('after-work').status, RoomStatus.recommended);
    expect(confirmedCount, 0);
    await Scrollable.ensureVisible(
      tester.element(find.text('이 코스로 약속 확정')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 코스로 약속 확정'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '약속 확정'));
    await tester.pumpAndSettle();
    expect(confirmedCount, 1);
    expect(controller.room('after-work').status, RoomStatus.confirmed);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('이 상태의 약속은 아직 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Empty state offers the supplied create action on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = RoomsController(rooms: []);
      addTearDown(controller.dispose);
      var createCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RoomsScreen(
            controller: controller,
            onCreatePlan: () => createCount++,
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('아직 참여 중인 방이 없어요'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, '약속 만들기'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(FilledButton, '약속 만들기'));
      expect(createCount, 1);
    },
  );
}
