import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/meeting.dart';
import '../widgets/ui.dart';
import 'recommendation_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.meeting});
  final Meeting meeting;
  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late String region;
  late String time;
  late String budget;
  late Set<String> selectedActivities;

  static const regions = ['홍대', '강남', '성수', '잠실', '건대'];
  static const times = ['15:00', '17:00', '18:00', '19:00', '20:00'];
  static const budgets = ['20,000원 이하', '20,000~30,000원', '30,000~50,000원', '50,000원 이상'];
  static const activityOptions = ['카페', '맛집', '보드게임', '영화', '전시', '산책'];

  @override
  void initState() {
    super.initState();
    region = widget.meeting.region;
    time = widget.meeting.time;
    budget = widget.meeting.budget;
    selectedActivities = widget.meeting.activities.toSet();
  }

  void save() {
    widget.meeting.region = region;
    widget.meeting.time = time;
    widget.meeting.budget = budget;
    widget.meeting.activities = selectedActivities.toList();
  }

  @override
  void dispose() {
    // 뒤로 가기를 눌렀을 때도 사용자가 변경한 조건을 유지합니다.
    save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('약속방')),
        body: Column(children: [
          Expanded(child: PageWidth(child: ListView(padding: const EdgeInsets.fromLTRB(22, 12, 22, 28), children: [
            const PageHeader(eyebrow: 'STEP 02 / MEETING ROOM', title: '약속 조건을 맞춰볼까요?', subtitle: '모두가 원하는 약속을 위해 조건을 골라주세요.'),
            const SizedBox(height: 24),
            Surface(child: Row(children: [
              const IconTile(Icons.groups_rounded),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.meeting.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.dark)),
                const SizedBox(height: 5),
                Text('${widget.meeting.dateLabel} · ${widget.meeting.people}명 참여', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ])),
              const TinyLabel('조율 중'),
            ])),
            const SizedBox(height: 29),
            const SectionTitle('나의 약속 조건'),
            const SizedBox(height: 17),
            const FieldTitle('선호 지역'),
            DropdownButtonFormField<String>(
              initialValue: region,
              isExpanded: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.place_outlined, color: AppColors.primary)),
              items: regions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) { if (v != null) setState(() => region = v); },
            ),
            const SizedBox(height: 19),
            const FieldTitle('가능한 시작 시간'),
            DropdownButtonFormField<String>(
              initialValue: time,
              isExpanded: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.schedule_outlined, color: AppColors.primary)),
              items: times.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) { if (v != null) setState(() => time = v); },
            ),
            const SizedBox(height: 19),
            const FieldTitle('1인 예산'),
            DropdownButtonFormField<String>(
              initialValue: budget,
              isExpanded: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary)),
              items: budgets.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) { if (v != null) setState(() => budget = v); },
            ),
            const SizedBox(height: 21),
            const FieldTitle('하고 싶은 활동 · 중복 선택'),
            Wrap(spacing: 8, runSpacing: 4, children: activityOptions.map((a) => FilterChip(
              label: Text(a),
              selected: selectedActivities.contains(a),
              onSelected: (selected) => setState(() {
                if (selected) { selectedActivities.add(a); } else { selectedActivities.remove(a); }
              }),
            )).toList()),
            const SizedBox(height: 28),
            const SectionTitle('함께하는 사람'),
            const SizedBox(height: 12),
            Surface(child: Column(children: [
              Row(children: [
                const CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(Icons.person, color: AppColors.primary)),
                const SizedBox(width: 12),
                const Expanded(child: Text('나', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.dark))),
                const TinyLabel('입력 완료', color: AppColors.success),
              ]),
              const Divider(height: 23),
              Row(children: [
                const Icon(Icons.people_outline_rounded, color: AppColors.muted),
                const SizedBox(width: 13),
                Expanded(child: Text('다른 참여자 ${widget.meeting.people - 1}명', style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600))),
                const Text('시연용 표시', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ]),
            ])),
            const SizedBox(height: 12),
            const DemoNotice('참여자 정보와 AI 추천은 현재 시연용입니다. 실제 사용자 초대 및 LLM 연결은 아직 구현되지 않았습니다.'),
          ]))),
          BottomAction(label: 'AI 추천 일정 보기 · 데모', icon: Icons.auto_awesome_rounded, onPressed: () {
            save();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecommendationScreen(meeting: widget.meeting)));
          }),
        ]),
      );
}
