import 'package:flutter_test/flutter_test.dart';

import 'package:perfumes_app/main.dart';

void main() {
  testWidgets('La app inicia en dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const PerfumesApp());

    expect(find.text('Dashboard'), findsOneWidget);
  });
}
