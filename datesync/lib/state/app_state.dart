import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  static const _kNameA = 'partner_name_a';
  static const _kNameB = 'partner_name_b';
  static const _kLang = 'lang_code';

  String _partnerA = '';
  String _partnerB = '';
  String _langCode = 'en'; // 'en' | 'tr'

  String get partnerA => _partnerA;
  String get partnerB => _partnerB;
  String get langCode => _langCode;

  bool get hasPartners => _partnerA.trim().isNotEmpty && _partnerB.trim().isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _partnerA = prefs.getString(_kNameA) ?? '';
    _partnerB = prefs.getString(_kNameB) ?? '';
    _langCode = prefs.getString(_kLang) ?? 'en';
    notifyListeners();
  }

  Future<void> setPartners({required String a, required String b}) async {
    _partnerA = a.trim();
    _partnerB = b.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNameA, _partnerA);
    await prefs.setString(_kNameB, _partnerB);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (code != 'en' && code != 'tr') return;
    _langCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, _langCode);
    notifyListeners();
  }

  Future<void> resetPartners() async {
    _partnerA = '';
    _partnerB = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kNameA);
    await prefs.remove(_kNameB);
    notifyListeners();
  }
}
