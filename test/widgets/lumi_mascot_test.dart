import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_addiction_controller/features/home/presentation/widgets/lumi_mascot.dart';

void main() {
  group('LumiMascot Widget Tests', () {
    testWidgets('renders successfully for all 7 emotional moods', (tester) async {
      for (final mood in LumiMood.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: LumiMascot(
                  mood: mood,
                  size: LumiSize.md,
                ),
              ),
            ),
          ),
        );
        expect(find.byType(LumiMascot), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('displays speech bubble with primary text and subtext', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LumiMascot(
                mood: LumiMood.idleHappy,
                showSpeechBubble: true,
                speechText: 'Hello from Lumi!',
                subtext: 'Mindful pocket companion',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hello from Lumi!'), findsOneWidget);
      expect(find.text('Mindful pocket companion'), findsOneWidget);
    });

    testWidgets('petting Lumi triggers onPet callback and love animation', (tester) async {
      bool petted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LumiMascot(
                mood: LumiMood.idleHappy,
                onPet: () => petted = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(LumiMascot));
      await tester.pump();
      expect(petted, isTrue);
      expect(find.text('+Love'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('+Love'), findsNothing);
    });
  });
}
