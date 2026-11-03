import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naqashi/main.dart';

void main() {
  testWidgets('home screen renders in Persian', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NaqashiApp());
    await tester.pumpAndSettle();
    expect(find.text('ساخت اتاق خصوصی'), findsOneWidget);
    expect(find.text('آدرس سرور'), findsOneWidget);
  });
}
