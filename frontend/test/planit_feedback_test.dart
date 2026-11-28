import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetsync/main.dart';
import 'package:meetsync/screens/profile/profile_widgets.dart';
import 'package:meetsync/screens/rooms/ai_result_screen.dart';
import 'package:meetsync/screens/rooms/room_widgets.dart';
import 'package:meetsync/services/rooms_controller.dart';
import 'package:meetsync/widgets/planit_notice.dart';

void main() {
  testWidgets(
    'confirmation dialog uses the app palette and fits the phone frame',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final rooms = RoomsController.demo();
      addTearDown(rooms.dispose);
      for (final width in [320.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpWidget(
          MeetSyncApp(
            initialLocale: const Locale('ko'),
            home: AiResultScreen(roomId: 'after-work', controller: rooms),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(RoomAction),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.byType(RoomAction)),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(RoomAction));
        await tester.pumpAndSettle();
        final surface = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first;
        final rect = tester.getRect(surface);
        expect(rect.width, lessThanOrEqualTo(360));
        expect(rect.center.dx, closeTo(width / 2, .1));
        expect(tester.widget<Material>(surface).color, profileSurface);
        expect(
          Theme.of(
            tester.element(find.byType(AlertDialog)),
          ).colorScheme.primary,
          profileBlue,
        );
        await tester.tap(find.text('더 살펴볼게요'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('centered notices fit the app and do not intercept taps', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 1200.0]) {
      var taps = 0;
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MeetSyncApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    taps++;
                    showPlanitNotice(context, Text('Saved $taps'));
                  },
                  child: const Text('Save'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('planit-notice'));
      final rect = tester.getRect(card);
      expect(rect.width, lessThanOrEqualTo(344));
      expect(rect.center, Offset(width / 2, 422));
      expect(tester.widget<Material>(card).color, profileButton);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(taps, 2);
      expect(find.text('Saved 1'), findsNothing);
      expect(find.text('Saved 2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'save notice survives closing editor and cleans up with the app',
    (tester) async {
      await tester.pumpWidget(
        MeetSyncApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () {
                          showPlanitNotice(
                            context,
                            const Text('Changes saved'),
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('Finish'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('Finish'), findsNothing);
      expect(find.text('Changes saved'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
