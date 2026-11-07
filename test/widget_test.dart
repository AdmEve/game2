import 'package:flutter_test/flutter_test.dart';
import 'package:naqashi/core/settings.dart';
import 'package:naqashi/core/sfx.dart';
import 'package:flutter/material.dart';
import 'package:naqashi/main.dart';
import 'package:naqashi/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => Sfx.enabled = false);

  testWidgets('first launch asks for a name and avatar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Settings.load();
    await tester.pumpWidget(const NaqashiApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('اسمت چیه؟'), findsOneWidget);
    expect(find.text('بزن بریم!'), findsOneWidget);
  });

  testWidgets('home shows both modes after onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true, 'name': 'پویا'});
    await Settings.load();
    await tester.pumpWidget(const NaqashiApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('دورهمی'), findsOneWidget);
    expect(find.text('بازی با دوستان'), findsOneWidget);
    expect(find.text('پویا'), findsOneWidget);
  });

  testWidgets('the guess box sends several guesses in a row and keeps focus', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Settings.load();
    final sent = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: GuessBar(enabled: true, hint: 'حدس', onSend: sent.add)),
      ),
    ));
    await tester.tap(find.byType(TextField));
    for (final w in ['سیب', 'موز', 'انار']) {
      await tester.enterText(find.byType(TextField), w);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue, reason: 'keyboard stays up');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty, reason: 'cleared after send');
    }
    expect(sent, ['سیب', 'موز', 'انار']);
  });
}
