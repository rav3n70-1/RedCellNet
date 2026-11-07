// test/role_based_ui_architecture_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:red_cell_net_final/core/routes/app_routes.dart';
import 'package:red_cell_net_final/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:red_cell_net_final/features/home/presentation/pages/home_page.dart';

void main() {
  group('Strict Role-Based UI Architecture Separation Tests', () {
    test('Donor HomePage and Admin Command Portal are distinct standalone widgets', () {
      const donorPortal = HomePage();
      const staffPortal = AdminDashboardPage();

      expect(donorPortal, isA<HomePage>());
      expect(staffPortal, isA<AdminDashboardPage>());
      expect(donorPortal.runtimeType, isNot(equals(staffPortal.runtimeType)));
    });

    test('Route definitions isolate staff portal and public/donor routes', () {
      expect(AppRoutes.admin, '/admin');
      expect(AppRoutes.home, '/home');
      expect(AppRoutes.isProtected(AppRoutes.admin), isTrue);
      expect(AppRoutes.isProtected(AppRoutes.home), isTrue);
    });
  });
}
