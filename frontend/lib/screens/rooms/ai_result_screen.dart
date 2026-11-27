import 'package:flutter/material.dart';
import '../../l10n/planit_l10n.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/plan_room.dart';
import '../../services/rooms_controller.dart';
import '../../services/planit_api.dart';
import 'room_widgets.dart';

class AiResultScreen extends StatelessWidget {
  const AiResultScreen({
    super.key,
    required this.roomId,
    required this.controller,
    this.onConfirmed,
  });
  final String roomId;
  final RoomsController controller;
  final ValueChanged<PlanRoom>? onConfirmed;

  Future<void> _openVerifiedPlace(BuildContext context, String placeId) async {
    if (placeId.isEmpty ||
        placeId.startsWith('-') ||
        int.tryParse(placeId) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n(context).theMapLinkForThisPlaceIs)),
      );
      return;
    }
    final link = Uri.parse('https://map.kakao.com/link/map/' + placeId);
    try {
      if (!await launchUrl(link, mode: LaunchMode.externalApplication)) {
        throw const FormatException('No map handler');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n(context).couldNotOpenTheMapCheckYour)),
        );
      }
    }
  }

  Future<void> _confirm(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n(context).confirmThisItinerary),
        content: Text(l10n(context).roomMembersWillSeeTheConfirmedPlan),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n(context).keepReviewing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n(context).confirmPlan),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      final confirmed = controller.online
          ? await controller.confirmRemote(roomId)
          : controller.confirm(roomId);
      if (confirmed && context.mounted) {
        onConfirmed?.call(controller.room(roomId));
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n(context).planSavedToTheServer)),
          );
      }
    } on PlanitApiException catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(displayError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final room = controller.room(roomId);
      final confirmed = room.status == RoomStatus.confirmed;
      return Scaffold(
        backgroundColor: roomBackground,
        appBar: AppBar(
          title: Text(
            confirmed
                ? l10n(context).confirmedItinerary
                : room.recommendationSource == 'kakao_verified_rule_based'
                ? l10n(context).automaticSuggestionsFromVerifiedPlaces
                : l10n(context).aiRecommendations,
          ),
          backgroundColor: roomBackground,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: roomBlue,
                    size: 36,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    confirmed
                        ? l10n(context).yourDayTogetherIsPlanned
                        : l10n(context).aDayToEnjoyTogether,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: roomInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${room.title}\n${roomDate(room.date, context: context)} · ${room.region}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: roomMuted, height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  if (!controller.online)
                    RoomPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n(context).sampleItinerary,
                            style: TextStyle(
                              color: roomBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            l10n(context).thisSampleItineraryIncludesAMealA,
                            style: TextStyle(color: roomMuted, height: 1.7),
                          ),
                        ],
                      ),
                    ),
                  if (room.recommendationSource == 'kakao_verified_rule_based')
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: RoomPanel(
                        child: Text(
                          l10n(context).thisPracticeItineraryUsesKakaoMapSearch,
                          style: TextStyle(color: roomMuted, height: 1.6),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  RoomPanel(
                    child: Column(
                      children: [
                        for (var i = 0; i < room.course.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(height: 1),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: roomTint,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: roomBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      room.course[i].time,
                                      style: const TextStyle(
                                        color: roomBlue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      room.course[i].title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      room.course[i].description,
                                      style: const TextStyle(
                                        color: roomMuted,
                                        height: 1.5,
                                      ),
                                    ),
                                    if (room.course[i].placeId != null)
                                      TextButton.icon(
                                        onPressed: () => _openVerifiedPlace(
                                          context,
                                          room.course[i].placeId!,
                                        ),
                                        icon: const Icon(
                                          Icons.map_outlined,
                                          size: 17,
                                        ),
                                        label: Text(
                                          l10n(context).viewOnKakaoMap,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  RoomAction(
                    label: confirmed
                        ? l10n(context).planConfirmed
                        : !controller.canConfirm(roomId)
                        ? l10n(context).theRoomOwnerCanConfirmThePlan
                        : controller.isConfirming(roomId)
                        ? l10n(context).confirming
                        : l10n(context).confirmThisItinerary2,
                    icon: Icons.check,
                    onPressed:
                        !confirmed &&
                            controller.canConfirm(roomId) &&
                            !controller.isConfirming(roomId) &&
                            room.allSubmitted &&
                            room.course.isNotEmpty
                        ? () => _confirm(context)
                        : null,
                  ),
                  if (!controller.online) const RoomDemoNotice(),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
