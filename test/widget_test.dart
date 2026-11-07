import 'package:flutter_test/flutter_test.dart';
import 'package:slh_hawk_parent/main.dart';

void main() {
  testWidgets('app starts in Arabic', (tester) async {
    await tester.pumpWidget(const SLHHawkApp(initialLanguage: 'ar'));
    await tester.pump();
    expect(find.text('SLH_HAWK'), findsOneWidget);
  });
}
