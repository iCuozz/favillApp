import 'package:flutter_test/flutter_test.dart';
import 'package:favilla_app/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // The app should render without crashing
    expect(find.byType(MyApp), findsOneWidget);
  });
}
