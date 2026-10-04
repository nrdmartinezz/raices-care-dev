import 'package:flutter_test/flutter_test.dart';
import 'package:raices/app/app.dart';

void main() {
  testWidgets('home screen renders the garden sections', (tester) async {
    await tester.pumpWidget(const RaicesApp());

    expect(find.text("Today's Ritual"), findsOneWidget);
    expect(find.text('Growing Now'), findsOneWidget);
    expect(find.text('Queen Monstera'), findsOneWidget);
    expect(find.text('2 of 4 tasks done'), findsOneWidget);
  });
}
