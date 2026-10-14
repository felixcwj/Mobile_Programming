class Meeting {
  Meeting({required this.name, required this.date, required this.people});

  String name;
  DateTime date;
  int people;
  String region = '홍대';
  String time = '18:00';
  String budget = '30,000~50,000원';
  List<String> activities = ['카페', '맛집', '보드게임'];
  bool revised = false;

  String get dateLabel {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}월 ${date.day}일 (${days[date.weekday - 1]})';
  }

  String get fullDateLabel => '${date.year}년 $dateLabel';
}
