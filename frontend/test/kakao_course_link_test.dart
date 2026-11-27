import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meetsync/models/plan_room.dart';
import 'package:meetsync/screens/rooms/ai_result_screen.dart';
import 'package:meetsync/services/rooms_controller.dart';

void main() {
  testWidgets('verified Kakao place is linked to a map in recommended course',
      (tester) async {
    final controller = RoomsController(rooms: [
      PlanRoom(
        id: 'map-test',
        title: '지도 시험',
        date: DateTime(2026, 12, 1, 13),
        region: '서울',
        inviteCode: 'AB2#C@!',
        members: const [RoomMember(name: '나', submitted: true)],
        status: RoomStatus.recommended,
        recommendationSource: 'kakao_verified_rule_based',
        course: const [
          CourseStop(
            time: '13:00',
            title: '실제 카카오맵 장소',
            description: '카페 · 서울',
            placeId: '18577297',
          ),
        ],
      ),
    ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: AiResultScreen(roomId: 'map-test', controller: controller),
    ));
    await tester.pumpAndSettle();
    expect(find.text('실제 장소 기반 자동 추천'), findsOneWidget);
    expect(find.text('카카오맵에서 위치 확인'), findsOneWidget);
    expect(find.textContaining('유료 AI를 사용하지 않은'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
