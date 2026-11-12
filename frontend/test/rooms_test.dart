import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/models/plan_room.dart';
import 'package:meetsync/screens/rooms/rooms_screen.dart';
import 'package:meetsync/screens/rooms/ai_result_screen.dart';
import 'package:meetsync/services/rooms_controller.dart';
import 'package:meetsync/services/planit_api.dart';

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

  testWidgets('Confirming a recommended course requires backend approval',
      (tester) async {
    final api = PlanitApi.instance;
    api.clearSession();
    final calls = <String>[];
    api.replaceHttpClientForTesting(MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode({'access_token': 'room-token'}), 200);
      }
      expect(request.headers['authorization'], 'Bearer room-token');
      if (request.url.path == '/rooms/after-work') {
        return http.Response(jsonEncode({'members': [
          {'uid': 'one', 'submitted': true},
          {'uid': 'two', 'submitted': true}
        ]}), 200);
      }
      if (request.url.path == '/rooms/after-work/recommendation') {
        return http.Response(jsonEncode({
          'is_stale': false,
          'source_revision': 'revision-1',
          'plan': {'stops': [
            {'start_time': '18:00', 'name': 'Dinner', 'address': 'Yeonnam'}
          ]}
        }), 200);
      }
      if (request.url.path == '/rooms/after-work/appointment/confirm') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['recommendation_revision'], 'revision-1');
        return http.Response(jsonEncode({'appointment': {
          'starts_at': '2026-11-19T18:00:00Z', 'version': 1
        }}), 200);
      }
      return http.Response(jsonEncode({'detail': 'not found'}), 404);
    }));
    await api.login('planner', 'password123');
    final controller = RoomsController.demo();
    addTearDown(controller.dispose);
    addTearDown(api.clearSession);
    var confirmedCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: AiResultScreen(roomId: 'after-work',
        controller: controller,
        onConfirmed: (_) => confirmedCount++),
    ));
    final confirm = find.text('이 코스로 약속 확정');
    await tester.scrollUntilVisible(confirm, 180,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(find.text('더 살펴볼게요'));
    await tester.pumpAndSettle();
    expect(confirmedCount, 0);
    expect(controller.room('after-work').status, RoomStatus.recommended);
    expect(calls, isNot(contains('POST /rooms/after-work/appointment/confirm')));
    await tester.scrollUntilVisible(confirm, 180,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '약속 확정'));
    await tester.pumpAndSettle();
    expect(confirmedCount, 1);
    expect(controller.room('after-work').status, RoomStatus.confirmed);
    expect(calls, contains('POST /rooms/after-work/appointment/confirm'));
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
