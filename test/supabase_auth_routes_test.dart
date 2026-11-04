import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:red_cell_net_final/core/routes/app_routes.dart';
import 'package:red_cell_net_final/features/auth/presentation/pages/login_page.dart';

void main() {
  group('Supabase Auth & Protected Routes Tests', () {
    test('Verify public and protected routes classification', () {
      // Public routes
      expect(AppRoutes.isProtected(AppRoutes.root), isFalse);
      expect(AppRoutes.isProtected(AppRoutes.authGate), isFalse);
      expect(AppRoutes.isProtected(AppRoutes.login), isFalse);
      expect(AppRoutes.isProtected(AppRoutes.register), isFalse);

      // Protected routes
      expect(AppRoutes.isProtected(AppRoutes.home), isTrue);
      expect(AppRoutes.isProtected(AppRoutes.profile), isTrue);
      expect(AppRoutes.isProtected(AppRoutes.editProfile), isTrue);
      expect(AppRoutes.isProtected(AppRoutes.requests), isTrue);
      expect(AppRoutes.isProtected(AppRoutes.createRequest), isTrue);
      expect(AppRoutes.isProtected(AppRoutes.requestDetails), isTrue);
      expect(AppRoutes.isProtected(AppRoutes.map), isTrue);
      expect(AppRoutes.isProtected(AppRoutes.notifications), isTrue);
      expect(AppRoutes.isProtected(AppRoutes.admin), isTrue);
    });

    testWidgets(
        'Unauthenticated user navigating to protected route is redirected to LoginPage',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          onGenerateRoute: AppRoutes.onGenerateRoute,
          initialRoute: AppRoutes.home,
        ),
      );
      await tester.pumpAndSettle();

      // Protected route intercept redirects unauthenticated user to LoginPage
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}
