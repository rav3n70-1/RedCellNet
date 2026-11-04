// Basic Flutter widget smoke test for RedCellNet
import 'package:flutter_test/flutter_test.dart';
import 'package:red_cell_net_final/app/app.dart';

void main() {
  testWidgets('App widget instantiation test', (WidgetTester tester) async {
    // Verify MyApp can be created as a Widget
    const app = MyApp();
    expect(app, isNotNull);
  });
}
