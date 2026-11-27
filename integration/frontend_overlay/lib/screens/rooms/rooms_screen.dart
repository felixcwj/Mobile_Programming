import 'package:flutter/material.dart';
import '../../l10n/planit_l10n.dart';

import '../../models/plan_room.dart';
import '../../services/rooms_controller.dart';
import '../../widgets/planit_mascot.dart';
import '../profile/profile_widgets.dart';
import 'room_detail_screen.dart';
import 'room_widgets.dart';

const _muted = Color(0xFF6C879A);

enum _RoomFilter {
  all('전체 약속'),
  inProgress('취향 진행 중'),
  confirmed('확정된 약속');

  const _RoomFilter(this.label);
  final String label;

  bool includes(PlanRoom room) => switch (this) {
    all => true,
    inProgress => room.status != RoomStatus.confirmed,
    confirmed => room.status == RoomStatus.confirmed,
  };
}

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    super.key,
    required this.controller,
    this.onCreatePlan,
    this.onConfirmed,
  });
  final RoomsController controller;
  final VoidCallback? onCreatePlan;
  final ValueChanged<PlanRoom>? onConfirmed;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  _RoomFilter _selectedFilter = _RoomFilter.all;

  @override
  Widget build(BuildContext context) => Theme(
    data: profileTheme(context),
    child: Scaffold(
      backgroundColor: const Color(0xFFF0F5F9),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: profileSurface,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFFB9E4F8), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1629ACF0),
                  blurRadius: 32,
                  spreadRadius: 3,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final rooms = widget.controller.rooms;
                final filtered = rooms.where(_selectedFilter.includes).toList()
                  ..sort((a, b) {
                    final aDate = a.date;
                    final bDate = b.date;
                    if (aDate == null) return bDate == null ? 0 : 1;
                    if (bDate == null) return -1;
                    return aDate.compareTo(bDate);
                  });
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                      child: Row(
                        children: [
                          BackButton(
                            onPressed: Navigator.of(context).canPop()
                                ? () => Navigator.pop(context)
                                : null,
                            color: profileInk,
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PlanitMascot(size: 28),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    l10n(context).myRooms,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: profileInk,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.onCreatePlan != null)
                            IconButton(
                              tooltip: l10n(context).makeAPlan,
                              onPressed: widget.onCreatePlan,
                              style: IconButton.styleFrom(
                                backgroundColor: profileButton,
                                foregroundColor: profileBlue,
                              ),
                              icon: const Icon(Icons.add_rounded, size: 24),
                            )
                          else
                            const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n(context).totalPlans,
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text.rich(
                                    key: const ValueKey('room-total'),
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${rooms.length}',
                                          style: const TextStyle(
                                            fontFamily: 'Fredoka',
                                            color: profileBlue,
                                            fontSize: 38,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        TextSpan(
                                          text: l10n(context).planCountSuffix(rooms.length),
                                          style: TextStyle(
                                            color: profileInk,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final filter in _RoomFilter.values)
                                        _filterChip(filter),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (filtered.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _emptyState(rooms.isEmpty),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              sliver: SliverList.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) =>
                                    _roomCard(filtered[index]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _filterChip(_RoomFilter filter) {
    final selected = _selectedFilter == filter;
    return ChoiceChip(
      key: ValueKey('room-filter-${filter.name}'),
      label: Text(displayLabel(context, filter.label)),
      selected: selected,
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: profileButton,
      surfaceTintColor: Colors.transparent,
      labelStyle: TextStyle(
        color: selected ? profileBlue : _muted,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF9CD6F4) : const Color(0xFFDDEAF2),
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      onSelected: (_) => setState(() => _selectedFilter = filter),
    );
  }

  Widget _emptyState(bool noRooms) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.calendar_month_outlined, size: 40, color: profileBlue),
        const SizedBox(height: 16),
        Text(
          noRooms
              ? l10n(context).noPlansYet2
              : _selectedFilter == _RoomFilter.confirmed
              ? l10n(context).noConfirmedPlans
              : l10n(context).noPlansCollectingPreferences,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 14),
        ),
        if (noRooms && widget.onCreatePlan != null) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: profileButton,
              foregroundColor: profileBlue,
              minimumSize: const Size(0, 48),
            ),
            onPressed: widget.onCreatePlan,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(l10n(context).makeAPlan),
          ),
        ],
      ],
    ),
  );

  Widget _roomCard(PlanRoom room) {
    final statusLabel = switch (room.status) {
      RoomStatus.collecting =>
        room.allSubmitted
            ? l10n(context).preferencesCollected
            : l10n(context).collectingPreferences2,
      RoomStatus.recommended => l10n(context).reviewItinerary,
      RoomStatus.confirmed => l10n(context).confirmed,
    };
    return Material(
      key: ValueKey('room-card-${room.id}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFDDEAF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RoomDetailScreen(
              roomId: room.id,
              controller: widget.controller,
              onConfirmed: widget.onConfirmed,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      room.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: profileInk,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _muted,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _metadata(
                Icons.calendar_month_outlined,
                roomDate(room.date, context: context),
              ),
              if (room.region.isNotEmpty && room.region != '지역 미정') ...[
                const SizedBox(height: 6),
                _metadata(Icons.place_outlined, room.region),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: profileButton,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: const TextStyle(
                        color: profileBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    room.status == RoomStatus.collecting
                        ? l10n(context).preferenceCount(
                            room.submittedCount,
                            room.members.length,
                          )
                        : l10n(context).memberCount(room.members.length),
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metadata(IconData icon, String label) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: _muted),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      ),
    ],
  );
}
