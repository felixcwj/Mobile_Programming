import 'calendar_event.dart';

enum RoomStatus {
  collecting('취향 모으는 중'),
  recommended('코스 확인하기'),
  confirmed('약속 확정');

  const RoomStatus(this.label);
  final String label;
}

class RoomMember {
  const RoomMember({
    required this.name,
    required this.submitted,
    this.summary = '',
  });
  final String name;
  final bool submitted;
  final String summary;

  RoomMember copyWith({bool? submitted, String? summary}) => RoomMember(
    name: name,
    submitted: submitted ?? this.submitted,
    summary: summary ?? this.summary,
  );
}

class CourseStop {
  const CourseStop({
    required this.time,
    required this.title,
    required this.description,
    this.placeId,
  });
  final String time;
  final String title;
  final String description;
  final String? placeId;
}

class PlanRoom {
  PlanRoom({
    required this.id,
    required this.title,
    this.date,
    this.end,
    this.recommendationSource,
    required this.region,
    required this.inviteCode,
    required List<RoomMember> members,
    this.status = RoomStatus.collecting,
    this.capacity = 8,
    this.category = EventCategory.personal,
    List<CourseStop> course = const [],
  }) : members = List.unmodifiable(members),
       course = List.unmodifiable(course);

  final String id;
  final String title;
  final DateTime? date;
  final DateTime? end;
  final String? recommendationSource;
  final String region;
  final String inviteCode;
  final List<RoomMember> members;
  final RoomStatus status;
  final int capacity;
  final EventCategory category;
  final List<CourseStop> course;

  int get submittedCount => members.where((member) => member.submitted).length;
  bool get allSubmitted =>
      members.isNotEmpty && submittedCount == members.length;

  PlanRoom copyWith({
    List<RoomMember>? members,
    RoomStatus? status,
    List<CourseStop>? course,
    DateTime? date,
    DateTime? end,
    bool clearDate = false,
    EventCategory? category,
  }) => PlanRoom(
    id: id,
    title: title,
    date: clearDate ? null : date ?? this.date,
    end: clearDate ? null : end ?? this.end,
    recommendationSource: recommendationSource,
    region: region;
    inviteCode: inviteCode,
    members: members ?? this.members,
    status: status ?? this.status,
    capacity: capacity,
    category: category ?? this.category,
    course: course ?? this.course,
  );
}
