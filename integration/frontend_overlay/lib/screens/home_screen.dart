import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/plan_room.dart';
import '../models/calendar_event.dart';
import '../models/user_profile.dart';
import '../services/profile_repository.dart';
import '../services/firebase_accounts.dart';
import '../services/rooms_controller.dart';
import '../services/calendar_controller.dart';
import '../services/planit_api.dart';
import 'calendar/calendar_screen.dart';
import 'calendar/event_editor_sheet.dart';
import 'create_room_screen.dart';
import 'login_screen.dart';
import 'home_widgets.dart';
import 'home_dashboard.dart';
import 'profile/profile_screen.dart';
import 'profile/profile_widgets.dart';
import 'rooms/room_detail_screen.dart';
import 'rooms/ai_result_screen.dart';
import 'rooms/rooms_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.loginId,
    this.profileRepository,
    this.accounts,
  });

  final String loginId;
  final ProfileRepository? profileRepository;
  final FirebaseAccounts? accounts;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Color primaryBlue = profileBlue;

  late final RoomsController _roomsController;
  bool _creatingRoom = false;
  late final CalendarController _calendarController;
  late final ProfileRepository _profileRepository;
  late final Timer _clock;

  List<PlanRoom> get _rooms => _roomsController.rooms;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomsController = RoomsController(rooms: [], api: PlanitApi());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRemote());
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _calendarController = CalendarController(roomsController: _roomsController);
    _profileRepository =
        widget.profileRepository ??
        MemoryProfileRepository(
          initialProfile: UserProfile(
            userId: widget.loginId,
            nickname: '플래너',
            email: '',
            loginId: widget.loginId,
          ),
        );
  }

  @override
  void dispose() {
    _clock.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _calendarController.dispose();
    _roomsController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRemote();
      setState(() {});
    }
  }

  Future<void> _loadRemote() async {
    try {
      await _roomsController.refresh();
      await _calendarController.refreshRemote();
    } on PlanitApiException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) _showMessage('서버 데이터를 불러오지 못했습니다. 다시 시도해 주세요.');
    }
  }

  Future<void> _logout() async {
    try {
      await widget.accounts?.signOut();
    } catch (_) {
      if (mounted) _showMessage('로그아웃하지 못했어요. 다시 시도해 주세요.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute(builder: (_) => LoginScreen(accounts: widget.accounts)),
      (_) => false,
    );
  }

  void _openProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ProfileScreen(repository: _profileRepository, onLogout: _logout),
      ),
    );
  }

  void _openRooms() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RoomsScreen(
          controller: _roomsController,
          onCreatePlan: _showCreateRoomDialog,
        ),
      ),
    );
  }

  void _openCalendar({DateTime? initialDate}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CalendarScreen(
          controller: _calendarController,
          initialDate: initialDate,
          onOpenRoom: (id) => _openRoom(_roomsController.room(id)),
        ),
      ),
    );
  }

  void _openEntry(CalendarEntry entry) {
    if (entry.event.roomId != null) {
      _openRoom(_roomsController.room(entry.event.roomId!));
    } else {
      _openCalendar(initialDate: entry.start);
    }
  }

  void _chooseDday() => showHomeDdayPicker(
    context,
    controller: _calendarController,
    onAddEvent: () => showEventEditor(
      context,
      controller: _calendarController,
      date: DateTime.now(),
    ),
  );

  void _openTask(HomePlanTask task) {
    if (task.reviewCourse) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AiResultScreen(
            roomId: task.room.id,
            controller: _roomsController,
          ),
        ),
      );
    } else {
      _openRoom(task.room);
    }
  }

  void _showAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: profileInk.withValues(alpha: .24),
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: 440),
      builder: (sheetContext) => HomeAddMenu(
        onCreate: () {
          Navigator.pop(sheetContext);
          _showCreateRoomDialog();
        },
        onJoin: () {
          Navigator.pop(sheetContext);
          _showJoinRoomDialog();
        },
      ),
    );
  }

  Future<void> _showCreateRoomDialog() async {
    final result = await Navigator.push<CreatedRoom>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRoomScreen(onJoin: _showJoinRoomDialog),
      ),
    );

    if (!mounted || result == null) return;

    if (_creatingRoom) return;
    setState(() => _creatingRoom = true);
    try {
      final room = await _roomsController.createRemote(
        title: result.name,
        capacity: result.capacity,
        date: result.date,
      );
      if (!mounted) return;
      _showRoomCreatedDialog(room);
      await _calendarController.refreshRemote();
    } on PlanitApiException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _creatingRoom = false);
    }
  }

  void _showRoomCreatedDialog(PlanRoom room) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('방이 만들어졌어요! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                room.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              const Text('초대 코드'),
              const SizedBox(height: 8),
              SelectableText(
                room.inviteCode,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              const Text('친구에게 이 코드를 공유해 보세요.', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: room.inviteCode));
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('코드 복사'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showJoinRoomDialog() async {
    final inputCode = await showDialog<String>(
      context: context,
      builder: (_) => const JoinRoomDialog(),
    );

    if (!mounted || inputCode == null) return;

    if (!RegExp(r'^(?:[A-Za-z0-9#@!]{7}|[A-Za-z0-9]{8})
      return;
    }

    try {
      await _roomsController.joinRemote(inputCode);
      await _calendarController.refreshRemote();
      if (mounted) _showMessage('약속방에 참여했습니다.');
    } on PlanitApiException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openRoom(PlanRoom room) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            RoomDetailScreen(roomId: room.id, controller: _roomsController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: profileTheme(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F5F9),
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [profileSurface, Color(0xFFF4FAFE)],
                ),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: const Color(0xFFB9E4F8), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2229ACF0),
                    blurRadius: 32,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: Color(0x08073365),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: HomeWordmark()),
                        _HomeIconButton(
                          tooltip: '프로필',
                          icon: Icons.person_outline_rounded,
                          onPressed: _openProfile,
                          size: 52,
                          iconSize: 28,
                        ),
                      ],
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: MediaQuery.sizeOf(context).height < 700
                              ? 12
                              : 20,
                        ),
                        child: HomeDashboard(
                          controller: _calendarController,
                          now: DateTime.now(),
                          onOpenEntry: _openEntry,
                          onOpenTask: _openTask,
                          onCreatePlan: _showCreateRoomDialog,
                          onChooseDday: _chooseDday,
                        ),
                      ),
                    ),
                    ListenableBuilder(
                      listenable: _roomsController,
                      builder: (context, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _HomeIconButton(
                            tooltip: '캘린더',
                            icon: Icons.calendar_month_outlined,
                            onPressed: _openCalendar,
                          ),
                          if (_rooms.isNotEmpty)
                            FilledButton(
                              key: const ValueKey('home-rooms'),
                              onPressed: _openRooms,
                              style: FilledButton.styleFrom(
                                backgroundColor: profileButton,
                                foregroundColor: profileInk,
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('내 약속방'),
                            ),
                          _HomeIconButton(
                            tooltip: '약속방 추가',
                            icon: Icons.add_rounded,
                            onPressed: _showAddMenu,
                            iconSize: 36,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeIconButton extends StatelessWidget {
  const _HomeIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 60,
    this.iconSize = 28,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x10073365),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: profileInk,
          fixedSize: Size.square(size),
          side: const BorderSide(color: Color(0xFFE5F3FC), width: 1.5),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, size: iconSize),
      ),
    );
  }
}
).hasMatch(inputCode)) {
      _showMessage('초대 코드는 7자리(기존 방은 8자리)입니다.');
      return;
    }

    try {
      await _roomsController.joinRemote(inputCode);
      await _calendarController.refreshRemote();
      if (mounted) _showMessage('약속방에 참여했습니다.');
    } on PlanitApiException catch (e) {
      if (mounted) _showMessage(e.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openRoom(PlanRoom room) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            RoomDetailScreen(roomId: room.id, controller: _roomsController),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: profileTheme(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F5F9),
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [profileSurface, Color(0xFFF4FAFE)],
                ),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: const Color(0xFFB9E4F8), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2229ACF0),
                    blurRadius: 32,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: Color(0x08073365),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: HomeWordmark()),
                        _HomeIconButton(
                          tooltip: '프로필',
                          icon: Icons.person_outline_rounded,
                          onPressed: _openProfile,
                          size: 52,
                          iconSize: 28,
                        ),
                      ],
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: MediaQuery.sizeOf(context).height < 700
                              ? 12
                              : 20,
                        ),
                        child: HomeDashboard(
                          controller: _calendarController,
                          now: DateTime.now(),
                          onOpenEntry: _openEntry,
                          onOpenTask: _openTask,
                          onCreatePlan: _showCreateRoomDialog,
                          onChooseDday: _chooseDday,
                        ),
                      ),
                    ),
                    ListenableBuilder(
                      listenable: _roomsController,
                      builder: (context, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _HomeIconButton(
                            tooltip: '캘린더',
                            icon: Icons.calendar_month_outlined,
                            onPressed: _openCalendar,
                          ),
                          if (_rooms.isNotEmpty)
                            FilledButton(
                              key: const ValueKey('home-rooms'),
                              onPressed: _openRooms,
                              style: FilledButton.styleFrom(
                                backgroundColor: profileButton,
                                foregroundColor: profileInk,
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('내 약속방'),
                            ),
                          _HomeIconButton(
                            tooltip: '약속방 추가',
                            icon: Icons.add_rounded,
                            onPressed: _showAddMenu,
                            iconSize: 36,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeIconButton extends StatelessWidget {
  const _HomeIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 60,
    this.iconSize = 28,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x10073365),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: profileInk,
          fixedSize: Size.square(size),
          side: const BorderSide(color: Color(0xFFE5F3FC), width: 1.5),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, size: iconSize),
      ),
    );
  }
}
