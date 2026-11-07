import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the app remembers between launches: identity, preferences,
/// progression. Loaded once in main(); widgets listen for changes.
class Settings extends ChangeNotifier {
  Settings._(this._p);
  final SharedPreferences _p;

  static late Settings I;

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    return I = Settings._(p);
  }

  /* ---------------- identity ---------------- */
  String get name => _p.getString('name') ?? '';
  set name(String v) => _set('name', v.trim());

  String get avatar => _p.getString('avatar') ?? '🦊';
  set avatar(String v) => _set('avatar', v);

  bool get onboarded => _p.getBool('onboarded') ?? false;
  set onboarded(bool v) => _set('onboarded', v);

  /* ---------------- preferences ---------------- */
  bool get sound => _p.getBool('sound') ?? true;
  set sound(bool v) => _set('sound', v);

  bool get haptics => _p.getBool('haptics') ?? true;
  set haptics(bool v) => _set('haptics', v);

  /// Game server, `host:port`. Empty until the player sets one.
  String get host => _p.getString('host') ?? '';
  set host(String v) => _set('host', v.trim());

  /* ---------------- offline party mode ---------------- */
  List<String> get recentWords => _p.getStringList('recentWords') ?? const [];
  void rememberWords(Iterable<String> words) {
    final list = [...recentWords, ...words];
    _p.setStringList('recentWords', list.length > 220 ? list.sublist(list.length - 220) : list);
  }

  List<String> get partyTeams => _p.getStringList('partyTeams') ?? const ['تیم آبی', 'تیم قرمز'];
  set partyTeams(List<String> v) => _set('partyTeams', v);

  /* ---------------- progression ---------------- */
  int get xp => _p.getInt('xp') ?? 0;
  int stat(String key) => _p.getInt('stat.$key') ?? 0;
  void addStat(String key, [int by = 1]) => _p.setInt('stat.$key', stat(key) + by);
  void setBest(String key, int v) {
    if (v > stat(key)) _p.setInt('stat.$key', v);
  }

  void addXp(int v) => _set('xp', xp + v);

  void _set(String k, Object v) {
    switch (v) {
      case final String s:
        _p.setString(k, s);
      case final bool b:
        _p.setBool(k, b);
      case final int i:
        _p.setInt(k, i);
      case final List<String> l:
        _p.setStringList(k, l);
    }
    notifyListeners();
  }
}
