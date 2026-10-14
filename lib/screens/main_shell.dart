import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/meeting.dart';
import '../widgets/ui.dart';
import 'create_meeting_screen.dart';
import 'room_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selectedTab = 0;
  final List<Meeting> meetings = [
    Meeting(name: '금요일 친구 모임', date: DateTime.now().add(const Duration(days: 2)), people: 4),
  ];

  Future<void> createMeeting() async {
    final result = await Navigator.of(context).push<Meeting>(
      MaterialPageRoute(builder: (_) => const CreateMeetingScreen()),
    );
    if (!mounted || result == null) return;
    setState(() => meetings.insert(0, result));
    await openRoom(result);
  }

  Future<void> openRoom(Meeting meeting) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => RoomScreen(meeting: meeting)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: selectedTab,
          children: [
            HomeTab(meetings: meetings, onCreate: createMeeting, onOpen: openRoom, onCalendar: () => setState(() => selectedTab = 1)),
            CalendarTab(meetings: meetings, onOpen: openRoom),
            ProfileTab(meetingCount: meetings.length),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primarySoft,
          selectedIndex: selectedTab,
          height: 72,
          onDestinationSelected: (value) => setState(() => selectedTab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary), label: '홈'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded, color: AppColors.primary), label: '달력'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary), label: '마이페이지'),
          ],
        ),
      );
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.meetings, required this.onCreate, required this.onOpen, required this.onCalendar});
  final List<Meeting> meetings;
  final VoidCallback onCreate;
  final ValueChanged<Meeting> onOpen;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: PageWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
            children: [
              Row(children: [
                const Icon(Icons.blur_circular_rounded, size: 30, color: AppColors.primary),
                const SizedBox(width: 9),
                const Text('모여봄', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.dark)),
                const Spacer(),
                IconButton.filledTonal(onPressed: onCalendar, icon: const Icon(Icons.calendar_today_outlined, size: 20), tooltip: '달력 보기'),
              ]),
              const SizedBox(height: 29),
              const Text('우리의 약속을\n조금 더 쉽게.', style: TextStyle(fontSize: 28, height: 1.32, fontWeight: FontWeight.w900, color: AppColors.dark)),
              const SizedBox(height: 10),
              const Text('시간과 취향을 모아 딱 맞는 하루를 계획해요.', style: TextStyle(fontSize: 14, color: AppColors.muted)),
              const SizedBox(height: 27),
              _NewMeetingHero(onCreate: onCreate),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(child: _MiniStat(label: '내 약속방', value: '${meetings.length}', icon: Icons.groups_2_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _MiniStat(label: '예정된 약속', value: '${meetings.where((m) => !m.date.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))).length}', icon: Icons.event_available_outlined)),
              ]),
              const SizedBox(height: 29),
              SectionTitle('내 약속', trailing: TinyLabel('${meetings.length}개')),
              const SizedBox(height: 14),
              if (meetings.isEmpty)
                Surface(child: Column(children: [
                  const Icon(Icons.event_note_outlined, size: 42, color: AppColors.muted),
                  const SizedBox(height: 12),
                  const Text('아직 약속이 없어요', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  const Text('첫 약속을 만들어 보세요.', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onCreate, child: const Text('새 약속 만들기')),
                ]))
              else
                ...meetings.map((meeting) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _MeetingCard(meeting: meeting, onTap: () => onOpen(meeting)),
                )),
              const SizedBox(height: 12),
              const DemoNotice('현재는 UI 시연 버전입니다. 약속 정보는 앱을 실행하는 동안에만 유지됩니다.'),
            ],
          ),
        ),
      );
}

class _NewMeetingHero extends StatelessWidget {
  const _NewMeetingHero({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4C51D7), Color(0xFF868CF7)]),
            ),
            padding: const EdgeInsets.all(23),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 27),
              const SizedBox(height: 19),
              const Text('이번 약속도 모여봄과 함께', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              const Text('새 약속을 만들고 친구들의 조건을 모아보세요.', style: TextStyle(color: Color(0xFFE9EAFF), fontSize: 12.5)),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('새 약속 만들기'),
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, minimumSize: const Size(0, 44)),
              ),
            ]),
          ),
          Positioned(right: -41, top: -45, child: IgnorePointer(child: Container(width: 145, height: 145, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withAlpha(34), width: 27))))),
        ]),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Surface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        child: Row(children: [
          Icon(icon, size: 21, color: AppColors.primary),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.dark, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11))),
        ]),
      );
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.onTap});
  final Meeting meeting;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.border)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const IconTile(Icons.groups_2_rounded),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(meeting.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.dark))),
                  const SizedBox(width: 7),
                  const TinyLabel('조율 중'),
                ]),
                const SizedBox(height: 6),
                Text('${meeting.dateLabel}  ·  ${meeting.people}명  ·  ${meeting.region}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 22),
            ]),
          ),
        ),
      );
}

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.meetings, required this.onOpen});
  final List<Meeting> meetings;
  final ValueChanged<Meeting> onOpen;
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime selected = DateTime.now();
  late DateTime displayedMonth;

  @override
  void initState() {
    super.initState();
    displayedMonth = DateTime(selected.year, selected.month);
  }

  void changeMonth(int offset) => setState(() {
        displayedMonth = DateTime(displayedMonth.year, displayedMonth.month + offset);
        selected = DateTime(displayedMonth.year, displayedMonth.month, 1);
      });

  bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(displayedMonth.year, displayedMonth.month, 1).weekday - 1;
    final days = DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final rows = ((firstWeekday + days + 6) / 7).floor();
    final chosenMeetings = widget.meetings.where((m) => sameDay(m.date, selected)).toList();
    return SafeArea(child: PageWidth(child: ListView(padding: const EdgeInsets.fromLTRB(22, 27, 22, 25), children: [
      const PageHeader(eyebrow: 'CALENDAR', title: '약속 캘린더', subtitle: '약속 날짜를 한눈에 확인하세요.'),
      const SizedBox(height: 27),
      Surface(child: Column(children: [
        Row(children: [
          Expanded(child: Text('${displayedMonth.year}년 ${displayedMonth.month}월', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.dark))),
          IconButton(tooltip: '이전 달', onPressed: () => changeMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
          IconButton(tooltip: '다음 달', onPressed: () => changeMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        const SizedBox(height: 15),
        Row(children: [
          for (final day in ['월', '화', '수', '목', '금', '토', '일'])
            Expanded(child: Center(child: Text(day, style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)))),
        ]),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows * 7,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.98),
          itemBuilder: (context, index) {
            final day = index - firstWeekday + 1;
            if (day < 1 || day > days) return const SizedBox.shrink();
            final date = DateTime(displayedMonth.year, displayedMonth.month, day);
            final isSelected = sameDay(date, selected);
            final isToday = sameDay(date, DateTime.now());
            final hasMeeting = widget.meetings.any((m) => sameDay(m.date, date));
            return InkWell(
              onTap: () => setState(() => selected = date),
              borderRadius: BorderRadius.circular(14),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 29, height: 29,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: isToday && !isSelected ? Border.all(color: AppColors.primary) : null,
                  ),
                  child: Text('$day', style: TextStyle(color: isSelected ? Colors.white : AppColors.dark, fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500, fontSize: 13)),
                ),
                const SizedBox(height: 1),
                Container(width: 4, height: 4, decoration: BoxDecoration(color: hasMeeting ? AppColors.primary : Colors.transparent, shape: BoxShape.circle)),
              ]),
            );
          },
        ),
      ])),
      const SizedBox(height: 27),
      SectionTitle('${selected.month}월 ${selected.day}일 약속'),
      const SizedBox(height: 13),
      if (chosenMeetings.isEmpty)
        const Surface(child: Row(children: [Icon(Icons.event_busy_outlined, color: AppColors.muted), SizedBox(width: 11), Text('이 날에는 등록된 약속이 없어요.', style: TextStyle(color: AppColors.muted))]))
      else
        ...chosenMeetings.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(side: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.event_available_rounded, color: AppColors.primary),
            title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${m.time} · ${m.people}명 · ${m.region}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onOpen(m),
          ),
        )),
    ])));
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.meetingCount});
  final int meetingCount;
  @override
  Widget build(BuildContext context) => SafeArea(child: PageWidth(child: ListView(padding: const EdgeInsets.fromLTRB(22, 27, 22, 24), children: [
    const PageHeader(eyebrow: 'MY PAGE', title: '마이페이지', subtitle: '약속을 준비하는 나의 공간'),
    const SizedBox(height: 26),
    Surface(child: Row(children: [
      Container(width: 58, height: 58, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(19)), child: const Icon(Icons.person_rounded, size: 30, color: AppColors.primary)),
      const SizedBox(width: 15),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('게스트 사용자', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.dark)),
        SizedBox(height: 5),
        Text('로그인 연동 전 · UI 시연 모드', style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ])),
      const TinyLabel('DEMO'),
    ])),
    const SizedBox(height: 20),
    Surface(child: Row(children: [
      const IconTile(Icons.calendar_today_rounded),
      const SizedBox(width: 14),
      const Expanded(child: Text('내가 만든 약속', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.dark))),
      Text('$meetingCount개', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
    ])),
    const SizedBox(height: 30),
    const SectionTitle('계정 및 설정'),
    const SizedBox(height: 13),
    const Surface(child: Column(children: [
      _ProfileRow(icon: Icons.edit_outlined, text: '닉네임 변경'),
      Divider(height: 23),
      _ProfileRow(icon: Icons.lock_outline_rounded, text: '비밀번호 변경'),
      Divider(height: 23),
      _ProfileRow(icon: Icons.settings_outlined, text: '계정 설정'),
    ])),
    const SizedBox(height: 14),
    const DemoNotice('회원가입, 로그인 및 계정 설정은 백엔드 연동 단계에서 구현할 예정입니다. 현재 버튼은 동작하지 않습니다.'),
  ])));
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 20, color: AppColors.muted),
    const SizedBox(width: 13),
    Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.dark, fontWeight: FontWeight.w600))),
    const Text('준비 중', style: TextStyle(color: AppColors.muted, fontSize: 11)),
  ]);
}
