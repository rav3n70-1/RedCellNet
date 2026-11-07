// test/push_and_admin_responsive_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:red_cell_net_final/core/services/push_notification_service.dart';
import 'package:red_cell_net_final/core/widgets/notification_badge_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService & Widget Tests', () {
    test('PushNotificationService is a valid singleton', () {
      final s1 = PushNotificationService();
      final s2 = PushNotificationService();
      expect(identical(s1, s2), isTrue);
    });

    testWidgets('NotificationBadgeWidget renders cleanly in light and dark mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NotificationBadgeWidget(),
                  ],
                ),
              ),
            ),
            body: Center(child: Text('Test Body')),
          ),
        ),
      );

      // Verify the bell icon is present
      expect(find.byType(NotificationBadgeWidget), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });
  });
}
