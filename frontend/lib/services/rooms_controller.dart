import 'package:flutter/foundation.dart';

import '../models/plan_room.dart';
import 'planit_api.dart';

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
  final Map<String, int> _scheduleVersions = {};
  final Map<String, String> _recommendationRevisions = {};
  int _localMutationEpoch = 0;
  int _latestLoadRequest = 0;

  /// Refreshes actual rooms and confirmed/pending dates from the backend.
  Future<void> loadRemote() async {
    // An older refresh must never erase a room created while its HTTP calls
    // were still in flight (e.g. the initial home refresh vs Create Room).
    final requestId = ++_latestLoadRequest;
    final initialMutationEpoch = _localMutationEpoch;
    final api = PlanitApi.instance;
    final response = await api.request('GET', '/rooms');
    final calendar = await api.request('GET', '/calendar/room-appointments');
    if (requestId != _latestLoadRequest ||
        initialMutationEpoch != _localMutationEpoch) {
      return;
    }
    final raw = response['rooms'] as List<dynamic>? ?? [];
    final items = calendar['events'] as List<dynamic>? ?? [];
    final byRoom = <String, Map<String, dynamic>>{};
    for (final value in items) {
      if (value is! Map<String, dynamic>) continue;
      final id = value['room_id']?.toString();
      if (id == null) continue;
      final current = byRoom[id];
      if (current == null ||
          DateTime.parse(value['starts_at'].toString())
              .isAfter(DateTime.parse(current['starts_at'].toString()))) {
        byRoom[id] = value;
      }
    }
    final loaded = <PlanRoom>[];
    _scheduleVersions.clear();
    for (final value in raw) {
      if (value is! Map<String, dynamic>) continue;
      final id = value['room_id']?.toString();
      if (id == null) continue;
      final event = byRoom[id];
      DateTime? when;
      if (event != null) {
        when = DateTime.parse(event['starts_at'].toString()).toLocal();
        _scheduleVersions[id] = (event['version'] as num?)?.toInt() ?? 0;
      }
      final submittedUids =
          (value['submitted_uids'] as List<dynamic>? ?? []).map((uid) => uid.toString()).toSet();
      final members = (value['member_uids'] as List<dynamic>? ?? [])
          .map((uid) => RoomMember(
              name: uid.toString(),
              submitted: submittedUids.contains(uid.toString())))
          .toList();
      loaded.add(PlanRoom(
        id: id,
        title: value['title']?.toString() ?? '새 약속방',
        date: when,
        region: '지역 미정',
        inviteCode: value['invite_code']?.toString() ?? '',
        members: members,
        capacity: (value['max_members'] as num?)?.toInt() ?? 8,
        status: event?['status'] == 'confirmed'
            ? RoomStatus.confirmed
            : RoomStatus.collecting,
      ));
    }
    _rooms
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  List<CourseStop> _courseFromResponse(Map<String, dynamic> response) {
    final plan = response['plan'];
    if (plan is! Map<String, dynamic>) return const [];
    final raw = plan['stops'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map((entry) => CourseStop(
      time: entry['start_time']?.toString() ?? '',
      title: entry['name']?.toString() ?? entry['activity']?.toString() ?? '장소',
      description: entry['address']?.toString() ?? '',
    )).toList();
  }

  Future<void> syncRoom(String id) async {
    final room = this.room(id);
    final api = PlanitApi.instance;
    final details = await api.request('GET', '/rooms/${Uri.encodeComponent(id)}');
    final members = (details['members'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((entry) => RoomMember(
            name: entry['uid']?.toString() ?? '사용자',
            submitted: entry['submitted'] == true))
        .toList();
    Map<String, dynamic>? recommendation;
    try {
      recommendation = await api.request(
        'GET', '/rooms/${Uri.encodeComponent(id)}/recommendation');
    } on PlanitApiException catch (error) {
      if (error.statusCode != 404) rethrow;
    }
    final fresh = recommendation != null && recommendation['is_stale'] != true;
    if (fresh) {
      final revision = recommendation['source_revision']?.toString();
      if (revision != null) _recommendationRevisions[id] = revision;
    }
    final course = fresh ? _courseFromResponse(recommendation) : <CourseStop>[];
    _replaceRoom(PlanRoom(
      id: room.id,
      title: room.title,
      date: room.date,
      region: room.region,
      inviteCode: room.inviteCode,
      members: members.isEmpty ? room.members : members,
      capacity: room.capacity,
      status: room.status == RoomStatus.confirmed
          ? RoomStatus.confirmed
          : course.isEmpty ? RoomStatus.collecting : RoomStatus.recommended,
      course: course,
    ));
  }

  Future<void> generateRecommendation(String id) async {
    final response = await PlanitApi.instance.request(
        'POST', '/rooms/${Uri.encodeComponent(id)}/recommend');
    final revision = response['source_revision']?.toString();
    if (revision != null) _recommendationRevisions[id] = revision;
    final previous = room(id);
    _replaceRoom(previous.copyWith(
      status: RoomStatus.recommended,
      course: _courseFromResponse(response),
    ));
  }

  Future<void> confirmRemote(String id) async {
    var revision = _recommendationRevisions[id];
    if (revision == null) {
      await syncRoom(id);
      revision = _recommendationRevisions[id];
    }
    if (revision == null) {
      throw const PlanitApiException('최신 AI 추천을 먼저 생성해야 합니다.');
    }
    final previous = room(id);
    final response = await PlanitApi.instance.request(
      'POST', '/rooms/${Uri.encodeComponent(id)}/appointment/confirm',
      body: {'recommendation_revision': revision},
    );
    final record = response['appointment'];
    DateTime? when = previous.date;
    if (record is Map<String, dynamic>) {
      when = DateTime.tryParse(record['starts_at']?.toString() ?? '')?.toLocal()
          ?? when;
      _scheduleVersions[id] = (record['version'] as num?)?.toInt() ?? 1;
    }
    _replaceRoom(previous.copyWith(status: RoomStatus.confirmed, date: when));
  }

  void _replaceRoom(PlanRoom updated) {
    final index = _rooms.indexWhere((room) => room.id == updated.id);
    if (index < 0) return;
    _rooms[index] = updated;
    _localMutationEpoch++;
    notifyListeners();
  }

  Future<PlanRoom> createRemoteRoom(String name, int capacity) async {
    final data = await PlanitApi.instance.request('POST', '/rooms', body: {
      'title': name,
      'max_members': capacity,
    });
    final id = data['room_id']?.toString();
    if (id == null) throw const PlanitApiException('생성된 방 ID가 없습니다.');
    final room = PlanRoom(
      id: id,
      title: name,
      region: '지역 미정',
      inviteCode: data['invite_code']?.toString() ?? '',
      capacity: capacity,
      members: const [RoomMember(name: '나', submitted: false)],
    );
    addRoom(room);
    return room;
  }

  Future<void> joinRemoteRoom(String inviteCode) async {
    await PlanitApi.instance.request('POST', '/rooms/join', body: {
      'invite_code': inviteCode,
    });
    await loadRemote();
  }

  Future<void> saveRemoteSchedule(String id, DateTime? when) async {
    final api = PlanitApi.instance;
    final room = this.room(id);
    if (room.status == RoomStatus.confirmed && when == null) {
      throw const PlanitApiException('확정된 약속은 날짜를 해제할 수 없습니다.');
    }
    final isConfirmed = room.status == RoomStatus.confirmed;
    final latest = await api.request('GET', isConfirmed
        ? '/rooms/$id/appointment'
        : '/rooms/$id/schedule');
    final current = latest[isConfirmed ? 'appointment' : 'schedule'];
    final version = current is Map<String, dynamic>
        ? (current['version'] as num?)?.toInt() ?? 0
        : 0;
    final response = isConfirmed
        ? await api.request('PATCH', '/rooms/$id/appointment/date', body: {
            'date': '${when?.year.toString().padLeft(4, '0')}-${when?.month.toString().padLeft(2, '0')}-${when?.day.toString().padLeft(2, '0')}',
            'version': version,
          })
        : await api.request('PUT', '/rooms/$id/schedule', body: {
            'starts_at': when?.toUtc().toIso8601String(),
            'version': version,
          });
    final snapshot = response['schedule'] ?? response['appointment'];
    if (snapshot is Map<String, dynamic>) {
      _scheduleVersions[id] = (snapshot['version'] as num?)?.toInt() ?? 0;
    }
    setDate(id, when);
  }

  List<PlanRoom> get rooms => List.unmodifiable(_rooms);
  PlanRoom room(String id) => _rooms.firstWhere((room) => room.id == id);

  void setDate(String id, DateTime? date) {
    final index = _rooms.indexWhere((room) => room.id == id);
    if (index < 0) return;
    _rooms[index] = _rooms[index].copyWith(date: date, clearDate: date == null);
    _localMutationEpoch++;
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
    _localMutationEpoch++;
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
