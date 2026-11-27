import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/planit_l10n.dart';
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
    this.api,
  });

  final String loginId;
  final ProfileRepository? profileRepository;
  final FirebaseAccounts? accounts;
  final PlanitApi? api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Color primaryBlue = profileBlue;

  late final RoomsController _roomsController;
  bool _creatingRoom = false;
  bool _loadingRemote = false;
  late final CalendarController _calendarController;
  late final ProfileRepository _profileRepository;
  late final Timer _clock;

  List<PlanRoom> get _rooms => _roomsController.rooms;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomsController = RoomsController(
      rooms: [],
      api: widget.api ?? (widget.accounts == null ? null : PlanitApi()),
    );
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
    if (!mounted || _loadingRemote || !_roomsController.online) return;
    _loadingRemote = true;
    try {
      await _roomsController.refresh();
      if (!mounted) return;
      await _calendarController.refreshRemote();
    } on PlanitApiException catch (e) {
      if (mounted) _showMessage(displayError(context, e));
    } catch (_) {
      if (mounted) _showMessage(l10n(context).couldNotLoadServerDataPleaseTry);
    } finally {
      _loadingRemote = false;
    }
  }

  Future<void> _logout() async {
    try {
      await widget.accounts?.signOut();
    } catch (_) {
      if (mounted) _showMessage(l10n(context).couldNotSignOutPleaseTryAgain);
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
    if (_creatingRoom) return;
    _creatingRoom = true;
    RoomCreationResult? remote;
    final route = MaterialPageRoute<CreatedRoom>(
      builder: (_) => CreateRoomScreen(
        onJoin: _showJoinRoomDialog,
        onCreate: !_roomsController.online
            ? null
            : (draft) async {
                try {
                  remote = await _roomsController.createRemote(
                    title: draft.name,
                    capacity: draft.capacity,
                    date: draft.date,
                    category: draft.category,
                  );
                } on RoomCreationUncertain {
                  unawaited(_loadRemote());
                  rethrow;
                }
              },
      ),
    );
    try {
      logRoomCreation('creation form opened');
      final result = await Navigator.of(context).push(route);
      await route.completed;
      logRoomCreation('creation form closed submitted=${result != null}');
      if (!mounted || result == null) return;

      final saved = remote;
      if (saved != null) {
        _showRoomCreatedDialog(saved.room, scheduleSaved: saved.scheduleSaved);
        if (!saved.scheduleSaved) unawaited(_loadRemote());
        return;
      }
      final room = PlanRoom(
        id: result.code,
        title: result.name,
        date: result.date,
        inviteCode: result.code,
        region: '지역 미정',
        capacity: result.capacity,
        category: result.category,
        members: const [RoomMember(name: '나', isSelf: true, submitted: false)],
      );
      _roomsController.addRoom(room);
      _showRoomCreatedDialog(room);
    } finally {
      _creatingRoom = false;
    }
  }

  void _showRoomCreatedDialog(PlanRoom room, {bool scheduleSaved = true}) {
    logRoomCreation('showing invite confirmation');
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text(l10n(dialogContext).roomCreated),
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
              Text(l10n(dialogContext).inviteCode),
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
              Text(
                l10n(dialogContext).shareThisCodeWithYourFriends,
                textAlign: TextAlign.center,
              ),
              if (!scheduleSaved) ...[
                const SizedBox(height: 12),
                Text(
                  l10n(dialogContext).roomScheduleNotConfirmed,
                  textAlign: TextAlign.center,
                ),
              ],
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
              label: Text(l10n(dialogContext).copyCode),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n(dialogContext).ok),
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

    if (!RegExp(
      r'^(?:[A-Za-z0-9#@!]{7}|[A-Za-z0-9]{8})$',
    ).hasMatch(inputCode)) {
      _showMessage(l10n(context).inviteCodesHaveCharactersForOlderRooms);
      return;
    }

    if (!_roomsController.online) {
      final matches = _rooms.where((r) => r.inviteCode == inputCode);
      _showMessage(
        matches.isNotEmpty
            ? l10n(context).thisRoomIsAlreadyInYourList
            : l10n(context).connectToTheServerToJoinRooms,
      );
      return;
    }
    try {
      await _roomsController.joinRemote(inputCode);
      await _calendarController.refreshRemote();
      if (mounted) _showMessage(l10n(context).youJoinedTheRoom);
    } on PlanitApiException catch (e) {
      if (mounted) _showMessage(displayError(context, e));
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
                          tooltip: l10n(context).profile,
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
                            tooltip: l10n(context).calendar,
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
                              child: Text(l10n(context).myRooms),
                            ),
                          _HomeIconButton(
                            tooltip: l10n(context).addARoom,
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
