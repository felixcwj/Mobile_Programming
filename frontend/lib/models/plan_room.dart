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
}

class CourseStop {
  const CourseStop({
    required this.time,
    required this.title,
    required this.description,
  });
  final String time;
  final String title;
  final String description;
}

class PlanRoom {
  PlanRoom({
    required this.id,
    required this.title,
    this.date,
    required this.region,
    required this.inviteCode,
    required List<RoomMember> members,
    this.status = RoomStatus.collecting,
    this.capacity = 8,
    List<CourseStop> course = const [],
  }) : members = List.unmodifiable(members),
       course = List.unmodifiable(course);

  final String id;
  final String title;
  final DateTime? date;
  final String region;
  final String inviteCode;
  final List<RoomMember> members;
  final RoomStatus status;
  final int capacity;
  final List<CourseStop> course;

  int get submittedCount => members.where((member) => member.submitted).length;
  bool get allSubmitted =>
      members.isNotEmpty && submittedCount == members.length;

  PlanRoom copyWith({
    RoomStatus? status,
    List<CourseStop>? course,
    DateTime? date,
    bool clearDate = false,
  }) => PlanRoom(
    id: id,
    title: title,
    date: clearDate ? null : date ?? this.date,
    region: region,
    inviteCode: inviteCode,
    members: members,
    status: status ?? this.status,
    capacity: capacity,
    course: course ?? this.course,
  );
}
