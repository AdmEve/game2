import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/settings.dart';
import 'core/sfx.dart';
import 'theme.dart';
import 'ui/home_screen.dart';
import 'ui/sheets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.lajvardDeep,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await Settings.load();
  unawaited(Sfx.init()); // sounds load in the background; the first screen doesn't wait
  runApp(const NaqashiApp());
}

class NaqashiApp extends StatelessWidget {
  const NaqashiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نقاشی بکش',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // The whole app is Persian: force RTL regardless of device locale.
      locale: const Locale('fa', 'IR'),
      builder: (context, child) {
        // Honour the system text size, within what the layouts can take.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: .9, maxScaleFactor: 1.15)),
          child: Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink()),
        );
      },
      home: const _Start(),
    );
  }
}

/// First launch asks for a name and avatar; after that, straight home.
class _Start extends StatefulWidget {
  const _Start();
  @override
  State<_Start> createState() => _StartState();
}

class _StartState extends State<_Start> {
  bool _onboarded = Settings.I.onboarded;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _onboarded
            ? const HomeScreen()
            : OnboardingScreen(onDone: () => setState(() => _onboarded = true)),
      );
}
