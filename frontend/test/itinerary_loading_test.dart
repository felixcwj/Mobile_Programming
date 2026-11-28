import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/l10n/generated/app_localizations.dart';
import 'package:meetsync/models/plan_room.dart';
import 'package:meetsync/screens/rooms/ai_result_screen.dart';
import 'package:meetsync/screens/rooms/room_detail_screen.dart';
import 'package:meetsync/screens/rooms/room_widgets.dart';
import 'package:meetsync/services/planit_api.dart';
import 'package:meetsync/services/rooms_controller.dart';
import 'package:meetsync/widgets/planit_loading.dart';
import 'package:meetsync/widgets/planit_mascot.dart';

Widget app(Widget screen) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: screen,
);

class _DelayedRooms extends RoomsController {
  _DelayedRooms() : super(rooms: RoomsController.demo().rooms);
  final operation = Completer<void>();
  bool confirming = false;
  bool recommending = false;
  int confirmations = 0;

  @override
  bool get online => true;
  @override
  bool canConfirm(String id) => true;
  @override
  bool isConfirming(String id) => confirming;
  @override
  bool isRecommending(String id) => recommending;

  @override
  Future<bool> confirmRemote(String id) async {
    if (confirming) return false;
    confirmations++;
    confirming = true;
    notifyListeners();
    try {
      await operation.future;
      return confirm(id);
    } finally {
      confirming = false;
      notifyListeners();
    }
  }

  @override
  Future<void> recommendRemote(String id) async {
    recommending = true;
    notifyListeners();
    try {
      await operation.future;
    } finally {
      recommending = false;
      notifyListeners();
    }
  }
}

void main() {
  testWidgets('itinerary stays inside a phone frame on phone and desktop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rooms = RoomsController.demo();
    addTearDown(rooms.dispose);
    for (final width in [320.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        app(AiResultScreen(roomId: 'after-work', controller: rooms)),
      );
      await tester.pumpAndSettle();
      final frame = tester.getRect(
        find
            .descendant(
              of: find.byKey(const ValueKey('room-page-frame')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final content = tester.getRect(
        find.byKey(const ValueKey('itinerary-scroll')),
      );
      expect(frame.width, lessThanOrEqualTo(440));
      expect(frame.center.dx, closeTo(width / 2, .1));
      expect(content.left, greaterThanOrEqualTo(frame.left));
      expect(content.right, lessThanOrEqualTo(frame.right));
      await tester.scrollUntilVisible(find.byType(RoomAction), 180);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('confirmation shows bouncing mascot until server completion', (
    tester,
  ) async {
    final rooms = _DelayedRooms();
    addTearDown(rooms.dispose);
    await tester.pumpWidget(
      app(AiResultScreen(roomId: 'after-work', controller: rooms)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(RoomAction), 200);
    await tester.tap(find.byType(RoomAction));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm plan'));
    await tester.pump();
    expect(find.byType(PlanitLoading), findsOneWidget);
    expect(find.byType(PlanitMascot), findsOneWidget);
    expect(rooms.confirmations, 1);
    final dot = find.byKey(const ValueKey('planit-loading-dot-0'));
    final initial = tester.widget<Transform>(dot).transform.clone();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<Transform>(dot).transform, isNot(initial));
    rooms.operation.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PlanitLoading), findsNothing);
    expect(rooms.room('after-work').status, RoomStatus.confirmed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed recommendation closes loading and allows retry', (
    tester,
  ) async {
    final rooms = _DelayedRooms();
    addTearDown(rooms.dispose);
    await tester.pumpWidget(
      app(RoomDetailScreen(roomId: 'after-work', controller: rooms)),
    );
    await tester.pumpAndSettle();
    final generate = find.byKey(
      const ValueKey('generate-room-recommendations'),
    );
    await tester.scrollUntilVisible(
      generate,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(generate);
    await tester.pump();
    expect(find.byType(PlanitLoading), findsOneWidget);
    rooms.operation.completeError(const PlanitApiException('Request failed'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanitLoading), findsNothing);
    expect(tester.widget<OutlinedButton>(generate).onPressed, isNotNull);
    expect(find.text('Request failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps all three loading dots still', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: PlanitLoading(message: 'Saving…')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlanitMascot), findsOneWidget);
    final image = find.byType(Image);
    await tester.runAsync(
      () => precacheImage(
        tester.widget<Image>(image).image,
        tester.element(image),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.renderObject<RenderImage>(find.byType(RawImage)).image,
      isNotNull,
    );
    for (var index = 0; index < 3; index++) {
      final dot = find.byKey(ValueKey('planit-loading-dot-$index'));
      expect(tester.widget<Transform>(dot).transform.getTranslation().y, 0);
    }
    expect(tester.takeException(), isNull);
  });
}
