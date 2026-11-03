import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}
