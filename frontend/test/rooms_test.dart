import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/models/plan_room.dart';
import 'package:meetsync/screens/rooms/rooms_screen.dart';
import 'package:meetsync/screens/rooms/room_detail_screen.dart';
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

  test(
    'Preference edits preserve other members and invalidate an old course',
    () {
      final controller = RoomsController.demo();
      addTearDown(controller.dispose);
      final before = controller.room('after-work');
      controller.saveMyPreference('after-work', before.members.first.summary);
      expect(controller.room('after-work').status, RoomStatus.recommended);
      expect(controller.room('after-work').course, isNotEmpty);
      controller.saveMyPreference('after-work', '  전시를 보고 조용한 카페에 가고 싶어요.  ');
      final updated = controller.room('after-work');
      expect(updated.members.first.summary, '전시를 보고 조용한 카페에 가고 싶어요.');
      expect(updated.members.first.submitted, isTrue);
      expect(updated.members.last, same(before.members.last));
      expect(updated.date, before.date);
      expect(updated.inviteCode, before.inviteCode);
      expect(updated.course, isEmpty);
      expect(updated.status, RoomStatus.collecting);
      expect(updated.allSubmitted, isTrue);
      expect(controller.confirm('after-work'), isFalse);
      expect(
        () => controller.saveMyPreference('after-work', '  '),
        throwsArgumentError,
      );
      expect(
        () => controller.saveMyPreference('friends', '새 취향'),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'Preference text and participant statuses survive reopening at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = RoomsController(
        rooms: [
          PlanRoom(
            id: 'preferences',
            title: '주말 약속',
            date: DateTime(2026, 12, 25, 18, 30),
            region: '성수',
            inviteCode: 'ABC123!',
            members: const [
              RoomMember(name: '나', submitted: false),
              RoomMember(name: '지민', submitted: true, summary: '전시 관람'),
              RoomMember(name: '민수', submitted: false),
            ],
          ),
        ],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: RoomsScreen(controller: controller)),
      );
      await tester.tap(find.text('주말 약속'));
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('save-room-preference'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('하고 싶은 일을 적어 주세요.'), findsOneWidget);
      expect(controller.room('preferences').members.first.submitted, isFalse);
      await tester.enterText(
        find.byKey(const ValueKey('room-preference')),
        '맛있는 점심을 먹고 전시를 보고 싶어요.',
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        controller.room('preferences').members.first.summary,
        '맛있는 점심을 먹고 전시를 보고 싶어요.',
      );
      final friend = find.byKey(const ValueKey('room-member-지민'));
      final waiting = find.byKey(const ValueKey('room-member-민수'));
      await tester.ensureVisible(waiting);
      expect(
        find.descendant(of: friend, matching: find.text('입력 완료')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: waiting, matching: find.text('대기 중')),
        findsOneWidget,
      );
      expect(find.text('입력 완료 2/3'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('주말 약속'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('room-preference')));
      final input = tester.widget<TextFormField>(
        find.byKey(const ValueKey('room-preference')),
      );
      expect(input.controller!.text, '맛있는 점심을 먹고 전시를 보고 싶어요.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Completing the final preference updates the collection badge', (
    tester,
  ) async {
    final controller = RoomsController(
      rooms: [
        PlanRoom(
          id: 'last-member',
          title: '둘이서 약속',
          region: '지역 미정',
          inviteCode: 'TEST123',
          members: const [
            RoomMember(name: '나', submitted: false),
            RoomMember(name: '지민', submitted: true, summary: '산책'),
          ],
        ),
      ],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RoomDetailScreen(roomId: 'last-member', controller: controller),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('room-preference')),
      '함께 산책',
    );
    final save = find.byKey(const ValueKey('save-room-preference'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('취합 완료'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('취합 완료'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('입력 완료 2/2'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('입력 완료 2/2'), findsOneWidget);
    expect(controller.room('last-member').course, isEmpty);
    expect(tester.takeException(), isNull);
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
    await tester.tap(find.widgetWithText(ChoiceChip, '취향 진행 중'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('퇴근 후, 리프레시'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('퇴근 후, 리프레시'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('입력 완료 2/2'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('입력 완료 2/2'), findsOneWidget);
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
    expect(find.byKey(const ValueKey('room-card-after-work')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('room-filter-confirmed')),
    );
    await tester.tap(find.byKey(const ValueKey('room-filter-confirmed')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('퇴근 후, 리프레시'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('퇴근 후, 리프레시'), findsOneWidget);
    expect(find.text('3 개'), findsOneWidget);
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
        find.text('등록된 약속이 없어요'),
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

  testWidgets(
    'Three room filters keep totals and group unconfirmed plans at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = RoomsController.demo();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: RoomsScreen(controller: controller)),
      );
      expect(find.text('약속 총 개수'), findsOneWidget);
      expect(find.text('3 개'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      await tester.tap(find.byKey(const ValueKey('room-filter-inProgress')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-card-weekend')), findsOneWidget);
      expect(find.byKey(const ValueKey('room-card-friends')), findsNothing);
      await tester.scrollUntilVisible(
        find.text('퇴근 후, 리프레시'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('퇴근 후, 리프레시'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('room-filter-confirmed')),
      );
      await tester.tap(find.byKey(const ValueKey('room-filter-confirmed')));
      await tester.pumpAndSettle();
      expect(find.text('3 개'), findsOneWidget);
      expect(find.byKey(const ValueKey('room-card-friends')), findsOneWidget);
      expect(find.byKey(const ValueKey('room-card-weekend')), findsNothing);
      expect(find.byKey(const ValueKey('room-card-after-work')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('room-filter-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-card-weekend')), findsOneWidget);
      expect(find.text('3 개'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
