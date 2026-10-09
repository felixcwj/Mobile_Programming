import 'package:flutter/material.dart';

void main() => runApp(const MeetMateApp());

const ink = Color(0xFF17253D);
const brand = Color(0xFF5669F5);
const canvas = Color(0xFFF7F8FC);

class MeetMateApp extends StatelessWidget {
  const MeetMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '모여봄 | AI 약속 플래너',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: brand, primary: brand),
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: ink,
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4E8F1))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4E8F1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brand, width: 1.5)),
        ),
      ),
      home: const PlannerHome(),
    );
  }
}

class Appointment {
  Appointment({required this.name, required this.date, required this.people});
  String name;
  String date;
  int people;
  String region = '홍대';
  String time = '18:00';
  String budget = '30,000~50,000원';
  List<String> activities = ['카페', '맛집', '보드게임'];
  bool revised = false;
}

class PlannerHome extends StatefulWidget {
  const PlannerHome({super.key});
  @override
  State<PlannerHome> createState() => _PlannerHomeState();
}

class _PlannerHomeState extends State<PlannerHome> {
  final List<Appointment> meetings = [Appointment(name: '금요일 친구 모임', date: '10월 16일 (금)', people: 4)];

  Future<void> create() async {
    final meeting = await Navigator.push<Appointment>(context, MaterialPageRoute(builder: (_) => const CreateMeetingScreen()));
    if (meeting != null && mounted) {
      setState(() => meetings.insert(0, meeting));
      openMeeting(meeting);
    }
  }

  void openMeeting(Appointment meeting) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ConditionScreen(meeting: meeting))).then((_) { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(22), children: [
          const SizedBox(height: 14),
          const Row(children: [Icon(Icons.auto_awesome_rounded, color: brand, size: 30), SizedBox(width: 9), Text('모여봄', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ink))]),
          const SizedBox(height: 30),
          const Text('약속 잡기, 이제 AI에게 맡기세요', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 9),
          const Text('친구들의 조건을 모아 모두에게 맞는 하루를 추천해요.', style: TextStyle(color: Color(0xFF6E7890), fontSize: 14)),
          const SizedBox(height: 27),
          Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [brand, Color(0xFF8994FA)]), borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 34),
            const SizedBox(height: 17),
            const Text('새 약속을 만들어 볼까요?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('시간부터 코스까지 한 번에 조율해요.', style: TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: brand), onPressed: create, icon: const Icon(Icons.add), label: const Text('새 약속 만들기')),
          ])),
          const SizedBox(height: 32),
          Text('내 약속  ${meetings.length}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 13),
          ...meetings.map((m) => Padding(padding: const EdgeInsets.only(bottom: 12), child: SurfaceCard(child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () => openMeeting(m), child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEEF0FF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.groups_rounded, color: brand)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 5), Text('${m.date} · ${m.people}명', style: const TextStyle(fontSize: 13, color: Colors.blueGrey))])),
            const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey),
          ])))))),
        ]),
      ),
    );
  }
}

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});
  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final name = TextEditingController(text: '주말 친구 모임');
  DateTime date = DateTime(2026, 10, 17);
  int count = 4;

  @override
  void dispose() { name.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('새 약속 만들기')), body: SafeArea(child: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(22), children: [
        const StepLabel(step: '01', text: '약속 기본 정보'), const SizedBox(height: 22),
        const FieldLabel('약속 이름'), TextField(controller: name, decoration: const InputDecoration(hintText: '예: 금요일 친구 모임')),
        const SizedBox(height: 22), const FieldLabel('약속 날짜'),
        SurfaceCard(child: ListTile(leading: const Icon(Icons.event_rounded, color: brand), title: Text('${date.year}년 ${date.month}월 ${date.day}일'), trailing: const Icon(Icons.edit_calendar_rounded), onTap: () async {
          final result = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2026), lastDate: DateTime(2030));
          if (result != null) setState(() => date = result);
        })),
        const SizedBox(height: 22), const FieldLabel('참여 인원'),
        SurfaceCard(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7), child: Row(children: [const Icon(Icons.people_alt_outlined, color: brand), const SizedBox(width: 12), const Expanded(child: Text('총 참여 인원')), IconButton(onPressed: count > 2 ? () => setState(() => count--) : null, icon: const Icon(Icons.remove_circle_outline)), Text('$count명', style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(onPressed: count < 20 ? () => setState(() => count++) : null, icon: const Icon(Icons.add_circle_outline))]))),
        const SizedBox(height: 15), const Text('참여자는 추후 초대 링크로 연결할 예정입니다.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ])),
      BottomAction(label: '약속 만들고 조건 입력하기', onPressed: () {
        final title = name.text.trim();
        if (title.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('약속 이름을 입력해주세요.'))); return; }
        Navigator.pop(context, Appointment(name: title, date: '${date.month}월 ${date.day}일', people: count));
      }),
    ])));
  }
}

class ConditionScreen extends StatefulWidget {
  const ConditionScreen({super.key, required this.meeting});
  final Appointment meeting;
  @override
  State<ConditionScreen> createState() => _ConditionScreenState();
}

class _ConditionScreenState extends State<ConditionScreen> {
  late String region;
  late String time;
  late String budget;
  late Set<String> activities;
  final regions = ['홍대', '강남', '성수', '잠실', '건대'];
  final times = ['15:00', '17:00', '18:00', '19:00', '20:00'];
  final budgets = ['20,000원 이하', '20,000~30,000원', '30,000~50,000원', '50,000원 이상'];
  final options = ['카페', '맛집', '보드게임', '영화', '전시', '산책'];

  @override
  void initState() { super.initState(); region = widget.meeting.region; time = widget.meeting.time; budget = widget.meeting.budget; activities = widget.meeting.activities.toSet(); }

  void save() { widget.meeting.region = region; widget.meeting.time = time; widget.meeting.budget = budget; widget.meeting.activities = activities.toList(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('내 조건 입력')), body: SafeArea(child: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(22), children: [
        const StepLabel(step: '02', text: '약속 조건 설정'), const SizedBox(height: 8), Text('${widget.meeting.name} · ${widget.meeting.date}', style: const TextStyle(color: Colors.blueGrey)),
        const SizedBox(height: 24), const FieldLabel('선호 지역'),
        DropdownButtonFormField<String>(initialValue: region, items: regions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => region = v!)),
        const SizedBox(height: 20), const FieldLabel('가능한 시작 시간'),
        DropdownButtonFormField<String>(initialValue: time, items: times.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => time = v!)),
        const SizedBox(height: 20), const FieldLabel('1인 예산'),
        DropdownButtonFormField<String>(initialValue: budget, items: budgets.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => budget = v!)),
        const SizedBox(height: 20), const FieldLabel('하고 싶은 활동 (복수 선택)'),
        Wrap(spacing: 8, runSpacing: 5, children: options.map((a) => FilterChip(label: Text(a), selected: activities.contains(a), selectedColor: const Color(0xFFE5E8FF), checkmarkColor: brand, onSelected: (selected) => setState(() { if (selected) { activities.add(a); } else { activities.remove(a); } }))).toList()),
        const SizedBox(height: 18), const Text('입력 조건은 이번 프로토타입에서 기기 메모리에만 저장됩니다.', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ])),
      BottomAction(label: '조건 저장 후 참여자 확인', onPressed: () { save(); Navigator.push(context, MaterialPageRoute(builder: (_) => MeetingDetailScreen(meeting: widget.meeting))); }),
    ])));
  }
}

class MeetingDetailScreen extends StatelessWidget {
  const MeetingDetailScreen({super.key, required this.meeting});
  final Appointment meeting;
  @override
  Widget build(BuildContext context) {
    final people = ['나', '김민수', '이지은', '박서준'];
    return Scaffold(appBar: AppBar(title: const Text('약속 상세')), body: SafeArea(child: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(22), children: [
        const StepLabel(step: '03', text: '참여자 조건 확인'), const SizedBox(height: 20),
        SurfaceCard(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(meeting.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 8), Text('${meeting.date} · ${meeting.people}명', style: const TextStyle(color: Colors.blueGrey)), const Divider(height: 30), Text('내 조건  ${meeting.region} · ${meeting.time} · ${meeting.budget}', style: const TextStyle(fontSize: 13))]))),
        const SizedBox(height: 27), const FieldLabel('참여자 입력 현황 (예시)'),
        ...List.generate(meeting.people, (i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: SurfaceCard(child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFEEF0FF), child: Text('${i + 1}', style: const TextStyle(color: brand))), title: Text(i < people.length ? people[i] : '참여자 ${i + 1}'), subtitle: Text(i == 0 ? '${meeting.region} · ${meeting.time} 가능' : i.isEven ? '강남 · 19:00 가능' : '홍대 · 18:00 가능'), trailing: const Icon(Icons.check_circle, color: Color(0xFF49AE8A)))))),
        const SizedBox(height: 12), const Text('참여자 목록 및 입력 현황은 시연용 예시입니다.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ])),
      BottomAction(label: 'AI 추천 일정 보기 (데모)', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecommendationScreen(meeting: meeting)))),
    ])));
  }
}

class RecommendationScreen extends StatelessWidget {
  const RecommendationScreen({super.key, required this.meeting});
  final Appointment meeting;

  @override
  Widget build(BuildContext context) {
    final start = meeting.time;
    final entries = meeting.revised
        ? [('19:00', '카페에서 만나기', '시간 변경을 반영했어요', Icons.local_cafe_outlined), ('20:00', '저녁 식사', '모두 함께 식사해요', Icons.restaurant_outlined), ('21:30', '보드게임', '마무리 활동', Icons.casino_outlined)]
        : [(start, '카페에서 만나기', '가볍게 대화를 시작해요', Icons.local_cafe_outlined), ('19:30', '저녁 식사', '취향을 반영한 맛집 코스', Icons.restaurant_outlined), ('21:00', '보드게임', '다 함께 즐길 수 있는 활동', Icons.casino_outlined)];
    return Scaffold(appBar: AppBar(title: const Text('AI 추천 일정')), body: SafeArea(child: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(22), children: [
        const StepLabel(step: '04', text: '추천 일정 확인'), const SizedBox(height: 19),
        Container(padding: const EdgeInsets.all(19), decoration: BoxDecoration(color: const Color(0xFFE9ECFF), borderRadius: BorderRadius.circular(17)), child: const Row(children: [Icon(Icons.auto_awesome, color: brand, size: 30), SizedBox(width: 12), Expanded(child: Text('친구들과 보내기 좋은 코스를 준비했어요!', style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800)))])),
        const SizedBox(height: 23),
        SurfaceCard(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${meeting.region}에서 만나는 하루', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 8), Text('${meeting.date}  ·  1인 예상 ${meeting.budget}', style: const TextStyle(fontSize: 13, color: Colors.blueGrey))]))),
        const SizedBox(height: 24),
        ...entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 13), child: SurfaceCard(child: Padding(padding: const EdgeInsets.all(17), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEEF0FF), borderRadius: BorderRadius.circular(13)), child: Icon(e.$4, color: brand)), const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.$1, style: const TextStyle(color: brand, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(e.$2, style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 16)), const SizedBox(height: 5), Text(e.$3, style: const TextStyle(color: Colors.blueGrey, fontSize: 12))])),
        ]))))),
        const SizedBox(height: 13), const Text('※ 실제 장소 검색, 이동시간 계산, LLM 호출 없이 출력하는 예시 일정입니다.', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ])),
      BottomAction(label: '조건을 변경해 일정 수정하기', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RevisionScreen(meeting: meeting))), secondaryLabel: '홈으로 돌아가기', onSecondaryPressed: () => Navigator.of(context).popUntil((route) => route.isFirst)),
    ])));
  }
}

class RevisionScreen extends StatefulWidget {
  const RevisionScreen({super.key, required this.meeting});
  final Appointment meeting;
  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  final request = TextEditingController(text: '친구 한 명이 7시부터 가능해요.');
  bool shown = false;
  @override
  void dispose() { request.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('일정 수정')), body: SafeArea(child: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(22), children: [
        const StepLabel(step: '05', text: '조건 변경 요청'), const SizedBox(height: 18),
        const Text('변경된 조건을 자유롭게 입력해 주세요.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), const SizedBox(height: 13),
        TextField(controller: request, maxLines: 4, decoration: const InputDecoration(hintText: '예: 친구 한 명이 7시부터 가능해요.')),
        const SizedBox(height: 13), const Text('이 화면은 AI 재조율 기능의 UI 데모입니다. 입력 내용은 실제 분석되지 않습니다.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        if (shown) ...[
          const SizedBox(height: 28),
          SurfaceCard(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.check_circle, color: Color(0xFF49AE8A)), SizedBox(width: 8), Text('수정된 일정 예시', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 14), const Text('19:00  카페 → 20:00  저녁 → 21:30  보드게임', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8), const Text('예시로 모든 참여자의 시작 시간을 19시로 맞췄습니다.', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
          ]))),
        ],
      ])),
      BottomAction(label: shown ? '수정된 일정 상세 보기' : '일정 다시 추천받기 (데모)', onPressed: () {
        if (request.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('변경 요청을 입력해주세요.'))); return; }
        if (!shown) { setState(() => shown = true); } else { widget.meeting.revised = true; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RecommendationScreen(meeting: widget.meeting))); }
      }),
    ])));
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(color: Colors.white, borderRadius: BorderRadius.circular(18), child: child);
}

class StepLabel extends StatelessWidget {
  const StepLabel({super.key, required this.step, required this.text});
  final String step;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFE9ECFF), borderRadius: BorderRadius.circular(9)), child: Text(step, style: const TextStyle(color: brand, fontWeight: FontWeight.w800))), const SizedBox(width: 10), Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink))]);
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ink)));
}

class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.label, required this.onPressed, this.secondaryLabel, this.onSecondaryPressed});
  final String label;
  final VoidCallback onPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 16), color: canvas, child: Column(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)))), if (secondaryLabel != null) TextButton(onPressed: onSecondaryPressed, child: Text(secondaryLabel!))]));
}
