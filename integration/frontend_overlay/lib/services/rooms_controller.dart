import 'package:flutter/foundation.dart';

import '../models/plan_room.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'planit_api.dart';

/// Local preview state. No network, LLM, authentication or calendar persistence.
/// Create once in the parent and dispose when that parent is disposed.
class RoomsController extends ChangeNotifier {
  RoomsController({required List<PlanRoom> rooms, this.api}) : _rooms = List.of(rooms);
  final PlanitApi? api;
  bool get online => api != null;
  final Map<String, String> _revisions = {};
  final Map<String, String> _roomOwners = {};
  final Map<String, List<Map<String, dynamic>>> _pendingDecisions = {};
  final Map<String, List<Map<String, dynamic>>> _pendingDateRequests = {};
  final Set<String> _voting = {};
  List<Map<String, dynamic>> pendingDecisions(String id) => List.unmodifiable(_pendingDecisions[id] ?? []);
  List<Map<String, dynamic>> pendingDateRequests(String id) => List.unmodifiable(_pendingDateRequests[id] ?? []);
  bool isVoting(String id) => _voting.contains(id);
  bool canVote(Map<String, dynamic> request) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final votes = request['votes'];
    return uid != null && request['status'] == 'pending' &&
        (votes is! Map || !votes.containsKey(uid));
  }
  final Set<String> _confirming = {};
  final Set<String> _recommending = {};
  bool isRecommending(String id) => _recommending.contains(id);
  bool canConfirm(String id) => !online || _roomOwners[id] == FirebaseAuth.instance.currentUser?.uid;
  bool isConfirming(String id) => _confirming.contains(id);
  int _refreshGeneration = 0;
  bool _disposed = false;


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

  void saveMyPreference(String id, String text) {
    final summary = text.trim();
    if (summary.isEmpty) throw ArgumentError('A preference is required.');
    final index = _rooms.indexWhere((room) => room.id == id);
    if (index < 0) throw ArgumentError('Unknown room.');
    final current = _rooms[index];
    if (current.status == RoomStatus.confirmed) {
      throw StateError('Preferences are read-only after confirmation.');
    }
    // The local login session currently identifies its own member as "나".
    final memberIndex = current.members.indexWhere(
      (member) => member.name == '나',
    );
    if (memberIndex < 0) {
      throw StateError('The current member is not in this room.');
    }
    final member = current.members[memberIndex];
    if (member.submitted && member.summary == summary) return;
    final members = List<RoomMember>.of(current.members);
    members[memberIndex] = member.copyWith(submitted: true, summary: summary);
    _rooms[index] = current.copyWith(
      members: members,
      status: RoomStatus.collecting,
      // Any previous course was based on the old preferences.
      course: const [],
    );
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
  /// Recover authoritative shared rooms and appointments after every login.
  Future<void> refresh() async {
    final service = api;
    if (service == null || _disposed) return;
    final generation = ++_refreshGeneration;
    final revisions = <String, String>{};
    final owners = <String, String>{};
    final decisionsByRoom = <String, List<Map<String, dynamic>>>{};
    final dateRequestsByRoom = <String, List<Map<String, dynamic>>>{};
    final list = await service.listRooms();
    final appointments = await service.request('GET', '/calendar/room-appointments');
    final dates = <String, DateTime>{};
    final ends = <String, DateTime>{};
    final locations = <String, String>{};
    final statusByRoom = <String, String>{};
    for (final raw in appointments['events'] as List? ?? []) {
      if (raw is! Map) continue;
      final id = raw['room_id']?.toString();
      final dt = DateTime.tryParse(raw['starts_at']?.toString() ?? '')?.toLocal();
      if (id != null && dt != null) {
        dates[id] = dt;
        final end = DateTime.tryParse(raw['ends_at']?.toString() ?? '')?.toLocal();
        if (end != null && end.isAfter(dt)) ends[id] = end;
        locations[id] = (raw['location'] ?? '').toString();
        statusByRoom[id] = raw['status']?.toString() ?? 'scheduled';
      }
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final restored = <PlanRoom>[];
    for (final item in list) {
      final id = item['room_id']?.toString() ?? '';
      if (id.isEmpty) continue;
      try {
        final detail = await service.getRoom(id);
        owners[id] = (detail['owner_uid'] ?? '').toString();
        final decisions = await service.request('GET',
            '/rooms/${Uri.encodeComponent(id)}/decisions');
        decisionsByRoom[id] = (decisions['decisions'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .where((item) => item['status'] == 'pending').toList();
        if (statusByRoom[id] == 'confirmed') {
          final dateRequests = await service.request('GET',
              '/rooms/${Uri.encodeComponent(id)}/appointment/date-requests');
          dateRequestsByRoom[id] = (dateRequests['requests'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .where((item) => item['status'] == 'pending').toList();
        }
        final members = <RoomMember>[];
        for (final raw in detail['members'] as List? ?? []) {
          if (raw is! Map) continue;
          final memberId = raw['uid']?.toString() ?? '';
          members.add(RoomMember(
            name: memberId == uid ? '나' : '참여자 ${members.length + 1}',
            submitted: raw['submitted'] == true,
          ));
        }
        if (!members.any((m) => m.name == '나')) {
          members.add(const RoomMember(name: '나', submitted: false));
        }
        final my = await service.myRoomPreferences(id);
        final myPrefs = my['preferences'];
        if (myPrefs is Map && my['submitted'] == true) {
          final index = members.indexWhere((m) => m.name == '나');
          members[index] = members[index].copyWith(
            submitted: true, summary: (myPrefs['additional_notes'] ?? '').toString());
        }
        final stops = <CourseStop>[];
        String? recommendationSource;
        var roomStatus = statusByRoom[id] == 'confirmed'
            ? RoomStatus.confirmed : RoomStatus.collecting;
        try {
          final recommendation = await service.request(
              'GET', '/rooms/${Uri.encodeComponent(id)}/recommendation');
          if (recommendation['is_stale'] != true) {
            final plan = recommendation['plan'];
            if (plan is Map && plan['recommendation_source'] == 'kakao_verified_rule_based') {
              recommendationSource = 'kakao_verified_rule_based';
            }
            if (plan is Map && plan['stops'] is List) {
              for (final stop in plan['stops'] as List) {
                if (stop is! Map) continue;
                stops.add(CourseStop(
                  time: (stop['start_time'] ?? '').toString(),
                  title: (stop['name'] ?? stop['activity'] ?? '').toString(),
                  description: '${stop['activity'] ?? ''} · ${stop['address'] ?? ''}',
                  placeId: stop['place_id']?.toString(),
                ));
              }
              final revision = recommendation['source_revision'];
              if (revision is String) revisions[id] = revision;
              if (stops.isNotEmpty && roomStatus != RoomStatus.confirmed) {
                roomStatus = RoomStatus.recommended;
              }
            }
          }
        } on PlanitApiException catch (e) {
          if (e.statusCode != 404 && e.statusCode != 409) rethrow;
        }
        restored.add(PlanRoom(
          id: id,
          title: (detail['title'] ?? '새 약속방').toString(),
          date: dates[id],
          end: ends[id],
          region: statusByRoom[id] == 'confirmed' && (locations[id]?.isNotEmpty ?? false)
              ? locations[id]!
              : (myPrefs is Map ? myPrefs['region'] : null)?.toString() ?? '지역 미정',
          inviteCode: (detail['invite_code'] ?? '').toString(),
          members: members,
          capacity: (detail['max_members'] as num?)?.toInt() ?? 8,
          status: roomStatus,
          course: stops,
          recommendationSource: recommendationSource,
        ));
      } on PlanitApiException {
        rethrow;
      }
    }
    if (_disposed || generation != _refreshGeneration) return;
    _revisions..clear()..addAll(revisions);
    _roomOwners..clear()..addAll(owners);
    _pendingDecisions..clear()..addAll(decisionsByRoom);
    _pendingDateRequests..clear()..addAll(dateRequestsByRoom);
    _rooms..clear()..addAll(restored);
    notifyListeners();
  }

  Future<PlanRoom> createRemote({
    required String title,
    required int capacity,
    required DateTime date,
  }) async {
    final service = api;
    if (service == null) throw StateError('API not configured.');
    final created = await service.createRoom(title, capacity);
    final id = created['room_id']?.toString() ?? '';
    if (id.isEmpty) throw const PlanitApiException('방 ID를 받지 못했습니다.');
    await service.request('PUT', '/rooms/${Uri.encodeComponent(id)}/schedule',
        body: {'starts_at': date.toUtc().toIso8601String(), 'version': 0});
    await refresh();
    return room(id);
  }

  Future<void> joinRemote(String code) async {
    final service = api;
    if (service == null) throw StateError('API not configured.');
    await service.joinRoom(code);
    await refresh();
  }

  Future<void> setDateRemote(String id, DateTime? value) async {
    final service = api;
    if (service == null) throw StateError('API not configured.');
    final current = await service.request(
        'GET', '/rooms/${Uri.encodeComponent(id)}/schedule');
    final saved = current['schedule'];
    final version = saved is Map ? (saved['version'] as num?)?.toInt() ?? 0 : 0;
    await service.request('PUT', '/rooms/${Uri.encodeComponent(id)}/schedule', body: {
      'starts_at': value?.toUtc().toIso8601String(), 'version': version,
    });
    await refresh();
  }

  Future<bool> saveConditionsRemote(String roomId, {
    required String region,
    required DateTime date,
    required String start,
    required String end,
    required int budget,
    required List<String> activities,
    String notes = '',
  }) async {
    final service = api;
    if (service == null) throw StateError('API not configured.');
    final valid = await service.validateRegion(region.trim());
    if (valid['valid'] != true) {
      throw const PlanitApiException('지도에서 확인할 수 없는 국내 지역입니다.');
    }
    final dateText = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final result = await service.request('POST',
        '/rooms/${Uri.encodeComponent(roomId)}/preferences', body: {
      'region': valid['resolved_region'] ?? region.trim(),
      'available_date': dateText,
      'start_time': start,
      'end_time': end,
      'budget': budget,
      'activities': activities,
      'additional_notes': notes,
    });
    await refresh();
    return result['proposal_created'] == true;
  }

  Future<void> recommendRemote(String roomId) async {
    final service = api;
    if (service == null) throw StateError('API not configured.');
    if (_recommending.contains(roomId)) return;
    _recommending.add(roomId);
    if (!_disposed) notifyListeners();
    try {
      await service.request('POST',
          '/rooms/${Uri.encodeComponent(roomId)}/recommend',
          timeout: const Duration(seconds: 180));
      await refresh();
    } finally {
      _recommending.remove(roomId);
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> changeConfirmedDateRemote(String roomId, DateTime date) async {
    final service = api;
    if (service == null) throw StateError('API not configured.');
    final latest = await service.request('GET',
        '/rooms/${Uri.encodeComponent(roomId)}/appointment');
    final appointment = latest['appointment'];
    final version = appointment is Map ? (appointment['version'] as num?)?.toInt() : null;
    if (version == null) {
      throw const PlanitApiException('확정된 약속 정보를 확인할 수 없습니다.');
    }
    final day = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final result = await service.request('PATCH',
        '/rooms/${Uri.encodeComponent(roomId)}/appointment/date',
        body: {'date': day, 'version': version},
        timeout: const Duration(seconds: 180));
    await refresh();
    return result['proposal_created'] == true;
  }

  Future<void> leaveRemote(String roomId) async {
    final service = api;
    if (service == null) throw StateError('API not configured.');
    await service.request('DELETE',
        '/rooms/${Uri.encodeComponent(roomId)}/members/me');
    await refresh();
  }
  Future<void> voteRemote(String roomId, String decisionId, bool approve,
      {required bool dateRequest}) async {
    final service = api;
    if (service == null) throw StateError('API not configured.');
    final key = '${roomId}:${decisionId}';
    if (_voting.contains(key)) return;
    _voting.add(key);
    if (!_disposed) notifyListeners();
    try {
      final suffix = dateRequest
          ? '/appointment/date-requests/${Uri.encodeComponent(decisionId)}/vote'
          : '/decisions/${Uri.encodeComponent(decisionId)}/vote';
      await service.request('POST',
          '/rooms/${Uri.encodeComponent(roomId)}$suffix',
          body: {'approve': approve},
          timeout: const Duration(seconds: 180));
      await refresh();
    } finally {
      _voting.remove(key);
      if (!_disposed) notifyListeners();
    }
  }
  Future<bool> confirmRemote(String roomId) async {
    final service = api;
    if (service == null) throw StateError('API not configured.');
    if (_confirming.contains(roomId)) return false;
    if (!canConfirm(roomId)) {
      throw const PlanitApiException('약속 확정은 방장만 할 수 있습니다.');
    }
    final revision = _revisions[roomId];
    if (revision == null || revision.isEmpty) {
      throw const PlanitApiException('최신 AI 추천을 먼저 불러와 주세요.');
    }
    _confirming.add(roomId);
    if (!_disposed) notifyListeners();
    try {
      await service.request('POST',
          '/rooms/${Uri.encodeComponent(roomId)}/appointment/confirm',
          body: {'recommendation_revision': revision});
      await refresh();
      return true;
    } finally {
      _confirming.remove(roomId);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshGeneration++;
    super.dispose();
  }
}
