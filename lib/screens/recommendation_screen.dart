import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/meeting.dart';
import '../widgets/ui.dart';
import 'revision_screen.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key, required this.meeting});
  final Meeting meeting;
  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _PlanStop {
  const _PlanStop({required this.time, required this.activity, required this.title, required this.detail, required this.icon});
  final String time;
  final String activity;
  final String title;
  final String detail;
  final IconData icon;
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  String get startTime {
    // 수정 버튼은 실제 자연어 분석이 아닌 고정 예시를 시연합니다.
    if (widget.meeting.revised) return '19:00';
    return widget.meeting.time;
  }

  String offsetTime(String time, int minutes) {
    final parts = time.split(':');
    final total = int.parse(parts[0]) * 60 + int.parse(parts[1]) + minutes;
    final hour = (total ~/ 60) % 24;
    final minute = total % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  List<_PlanStop> makeStops() {
    final activities = widget.meeting.activities.isEmpty
        ? <String>['카페', '맛집', '산책']
        : widget.meeting.activities.take(3).toList();
    final templates = <String, (String, String, IconData)>{
      '카페': ('카페에서 만나기', '가볍게 대화하며 하루를 시작해요.', Icons.local_cafe_outlined),
      '맛집': ('맛있는 저녁 식사', '함께 식사하는 시간을 가져요.', Icons.restaurant_outlined),
      '보드게임': ('보드게임 즐기기', '서로 친해지는 즐거운 시간이에요.', Icons.casino_outlined),
      '영화': ('영화 관람', '취향에 맞는 영화를 골라요.', Icons.movie_outlined),
      '전시': ('전시 관람', '새로운 이야깃거리를 발견해요.', Icons.museum_outlined),
      '산책': ('동네 산책', '걷고 이야기하며 마무리해요.', Icons.directions_walk_outlined),
    };
    return List.generate(activities.length, (i) {
      final activity = activities[i];
      final data = templates[activity]!;
      return _PlanStop(
        time: offsetTime(startTime, i * 90),
        activity: activity,
        title: data.$1,
        detail: data.$2,
        icon: data.$3,
      );
    });
  }

  Future<void> revise() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => RevisionScreen(meeting: widget.meeting),
    ));
    if (changed == true && mounted) setState(() => widget.meeting.revised = true);
  }

  @override
  Widget build(BuildContext context) {
    final stops = makeStops();
    return Scaffold(
      appBar: AppBar(title: const Text('추천 일정')),
      body: Column(children: [
        Expanded(child: PageWidth(child: ListView(padding: const EdgeInsets.fromLTRB(22, 12, 22, 32), children: [
          const PageHeader(eyebrow: 'STEP 03 / YOUR PLAN', title: '우리의 하루 계획', subtitle: '선택한 활동으로 구성한 일정 예시를 확인해 보세요.'),
          const SizedBox(height: 23),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 13),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('추천 일정이 준비됐어요', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 4),
                Text('현재는 조건을 반영한 시연용 코스입니다.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ])),
              const TinyLabel('DEMO'),
            ]),
          ),
          const SizedBox(height: 17),
          Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.meeting.region}에서 보내는 하루', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.dark)),
            const SizedBox(height: 11),
            Wrap(spacing: 13, runSpacing: 7, children: [
              _SummaryMeta(Icons.calendar_today_outlined, widget.meeting.dateLabel),
              _SummaryMeta(Icons.schedule_outlined, '$startTime 시작'),
              _SummaryMeta(Icons.group_outlined, '${widget.meeting.people}명'),
            ]),
            const Divider(height: 27),
            const Text('1인 예산', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 4),
            Text(widget.meeting.budget, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ])),
          const SizedBox(height: 29),
          SectionTitle('추천 타임라인', trailing: TinyLabel('${stops.length}개 활동')),
          const SizedBox(height: 18),
          ...List.generate(stops.length, (i) {
            final stop = stops[i];
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 54, child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(stop.time, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900)),
              )),
              SizedBox(width: 20, child: Column(children: [
                Container(margin: const EdgeInsets.only(top: 24), width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                if (i < stops.length - 1) Container(margin: const EdgeInsets.only(top: 4), width: 2, height: 103, color: AppColors.border),
              ])),
              const SizedBox(width: 9),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Surface(padding: const EdgeInsets.all(15), child: Row(children: [
                  IconTile(stop.icon, size: 43),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(stop.activity, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(stop.title, style: const TextStyle(fontSize: 15, color: AppColors.dark, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(stop.detail, style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
                  ])),
                ])),
              )),
            ]);
          }),
          const SizedBox(height: 8),
          const DemoNotice('실제 장소 검색, 이동 시간 계산 및 LLM API 호출은 구현되지 않았습니다. 표시된 시간은 시연용 간격입니다.'),
          const SizedBox(height: 22),
          Center(child: TextButton.icon(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home_outlined),
            label: const Text('홈으로 돌아가기'),
          )),
        ]))),
        BottomAction(label: '일정 수정 요청하기', icon: Icons.edit_note_rounded, onPressed: revise),
      ]),
    );
  }
}

class _SummaryMeta extends StatelessWidget {
  const _SummaryMeta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 15, color: AppColors.muted),
    const SizedBox(width: 5),
    Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
  ]);
}
