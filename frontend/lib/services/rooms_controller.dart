import 'package:flutter/foundation.dart';

import '../models/plan_room.dart';

/// Local preview state. No network, LLM, authentication or calendar persistence.
/// Create once in the parent and dispose when that parent is disposed.
class RoomsController extends ChangeNotifier {
  RoomsController({required List<PlanRoom> rooms}) : _rooms = List.of(rooms);

  factory RoomsController.demo() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day, 13);
    return RoomsController(
      rooms: [
        PlanRoom(
          id: 'weekend',
          title: '우리의 느긋한 주말',
          date: day.add(const Duration(days: 4)),
          region: '성수',
          inviteCode: 'PLAN24',
          members: const [
            RoomMember(
              name: '나',
              submitted: true,
              summary: '조용한 카페 · 전시 · 3만 원',
            ),
            RoomMember(name: '지민', submitted: true, summary: '맛집 · 사진 · 4만 원'),
            RoomMember(name: '서연', submitted: false),
            RoomMember(name: '도윤', submitted: false),
          ],
        ),
        PlanRoom(
          id: 'after-work',
          title: '퇴근 후, 리프레시',
          date: day.add(const Duration(days: 7, hours: 5)),
          region: '연남',
          inviteCode: 'PLAN75',
          status: RoomStatus.recommended,
          members: const [
            RoomMember(name: '나', submitted: true, summary: '맛집 · 산책 · 3만 원'),
            RoomMember(name: '민수', submitted: true, summary: '카페 · 산책 · 3만 원'),
          ],
          course: const [
            CourseStop(
              time: '18:00',
              title: '저녁 식사',
              description: '연남동에서 가볍게 즐기는 저녁',
            ),
            CourseStop(
              time: '19:30',
              title: '동네 산책',
              description: '근처 산책길에서 여유로운 시간',
            ),
            CourseStop(
              time: '20:00',
              title: '카페에서 마무리',
              description: '이야기 나누기 좋은 차분한 공간',
            ),
          ],
        ),
        PlanRoom(
          id: 'friends',
          title: '오랜만이야, 우리!',
          date: day.add(const Duration(days: 12)),
          region: '잠실',
          inviteCode: 'PLAN91',
          status: RoomStatus.confirmed,
          members: const [
            RoomMember(name: '나', submitted: true, summary: '맛집 · 카페'),
            RoomMember(name: '수빈', submitted: true, summary: '산책 · 카페'),
            RoomMember(name: '하준', submitted: true, summary: '맛집 · 산책'),
          ],
          course: const [
            CourseStop(
              time: '13:00',
              title: '함께 점심',
              description: '잠실에서 식사하며 근황 나누기',
            ),
            CourseStop(
              time: '14:30',
              title: '호수 산책',
              description: '식사 후 가까운 산책길 걷기',
            ),
            CourseStop(
              time: '15:30',
              title: '카페에서 쉬어가기',
              description: '편안한 대화로 하루 마무리',
            ),
          ],
        ),
      ],
    );
  }

  final List<PlanRoom> _rooms;
  List<PlanRoom> get rooms => List.unmodifiable(_rooms);
  PlanRoom room(String id) => _rooms.firstWhere((room) => room.id == id);

  void setDate(String id, DateTime? date) {
    final index = _rooms.indexWhere((room) => room.id == id);
    if (index < 0) return;
    _rooms[index] = _rooms[index].copyWith(date: date, clearDate: date == null);
    notifyListeners();
  }

  void addRoom(PlanRoom room) {
    if (_rooms.any(
      (existing) =>
          existing.id == room.id || existing.inviteCode == room.inviteCode,
    )) {
      throw ArgumentError('A room with this ID or invite code already exists.');
    }
    _rooms.add(room);
    notifyListeners();
  }

  /// Returns true only on the first transition, preventing duplicate callbacks.
  bool confirm(String id) {
    final index = _rooms.indexWhere((room) => room.id == id);
    if (index < 0) return false;
    final current = _rooms[index];
    if (current.status != RoomStatus.recommended ||
        current.course.isEmpty ||
        !current.allSubmitted) {
      return false;
    }
    _rooms[index] = current.copyWith(status: RoomStatus.confirmed);
    notifyListeners();
    return true;
  }
}
