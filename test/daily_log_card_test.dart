import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setu/models/daily_log.dart';
import 'package:setu/models/user_model.dart';
import 'package:setu/presentation/widgets/daily_log_card.dart';

void main() {
  group('Step 6 Requirements', () {
    testWidgets('1 & 2. Grey renders as "Missed" with icon and color', (WidgetTester tester) async {
      final greyLog = DailyLog(
        date: '2026-08-22',
        status: 'grey',
        transcript: '',
        summary: 'No check-in received.',
        medicationTaken: null,
        flaggedConcerns: [],
        respondedAt: null,
        audioUrl: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyLogCard(log: greyLog),
          ),
        ),
      );

      // Verify "Missed" text is displayed
      expect(find.text('Missed'), findsOneWidget);
      
      // Verify the unchecked radio button icon is displayed
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

      // Verify text color is Colors.grey
      final textWidget = tester.widget<Text>(find.text('Missed'));
      expect(textWidget.style?.color, Colors.grey);
    });

    test('3. UserModel parses fcmTokens correctly', () {
      final json = {
        'userId': 'user123',
        'name': 'Caregiver 1',
        'phoneNumber': '+1234567890',
        'circleIds': ['circle_1'],
        'fcmTokens': ['tokenA', 'tokenB'],
      };

      final user = UserModel.fromJson(json);
      expect(user.fcmTokens, isNotNull);
      expect(user.fcmTokens.length, 2);
      expect(user.fcmTokens.contains('tokenA'), isTrue);
      
      final outJson = user.toJson();
      expect((outJson['fcmTokens'] as List).contains('tokenA'), isTrue);
    });
  });
}
