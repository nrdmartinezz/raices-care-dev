import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/app/app.dart';

void main() {
  testWidgets('home screen renders the garden sections', (tester) async {
    // No Firebase here: the home screen still renders template content, and
    // nothing it builds watches a Firebase-backed provider.
    await tester.pumpWidget(const ProviderScope(child: RaicesApp()));

    expect(find.text("Today's Ritual"), findsOneWidget);
    expect(find.text('Growing Now'), findsOneWidget);
    expect(find.text('Queen Monstera'), findsOneWidget);
    expect(find.text('2 of 4 tasks done'), findsOneWidget);
  });
}
