import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class S {
  final String lang;
  S(this.lang);

  static S of(BuildContext context) => S(context.watch<AppState>().langCode);

  String t(String key) {
    final map = (lang == 'tr') ? _tr : _en;
    return map[key] ?? _en[key] ?? key;
  }

  static const Map<String, String> _en = {
    'appName': 'DateSync',
    'tagline': 'Tiny games. Big chemistry.',
    'continue': 'Continue',
    'start': 'Start',
    'next': 'Next',
    'back': 'Back',
    'done': 'Done',
    'settings': 'Settings',
    'language': 'Language',
    'english': 'English',
    'turkish': 'Turkish',
    'partners': 'Partners',
    'yourName': 'Your name',
    'partnerName': 'Partner name',
    'save': 'Save',
    'resetNames': 'Reset partner names',
    'home': 'Home',
    'modes': 'Modes',

    'mode_sync': 'SYNC REVEAL',
    'mode_sync_sub': 'Pick secretly → reveal together → chaos 😈',
    'mode_tod': 'Truth or Dare',
    'mode_tod_sub': 'Classic pass & play. Flirty. Funny.',
    'mode_spark': 'Spark',
    'mode_spark_sub': 'Romantic micro prompts for instant connection.',

    'sync_ready': 'READY',
    'sync_pick_in': 'Pick in',
    'sync_reveal': 'REVEAL',
    'sync_match': '💥 SYNC! Bonus round unlocked',
    'sync_mismatch': 'Mismatch! Explain in 5 words.',
    'sync_bonus_title': 'Bonus Round',
    'sync_explain_title': 'Explain in 5 words',
    'sync_talk': 'Say it out loud. No typing needed 😉',

    'tod_pick': 'Pick a card',
    'truth': 'TRUTH',
    'dare': 'DARE',
    'for_player': 'For',
  };

  static const Map<String, String> _tr = {
    'appName': 'DateSync',
    'tagline': 'Mini oyunlar. Büyük kimya.',
    'continue': 'Devam',
    'start': 'Başla',
    'next': 'Sonraki',
    'back': 'Geri',
    'done': 'Bitti',
    'settings': 'Ayarlar',
    'language': 'Dil',
    'english': 'İngilizce',
    'turkish': 'Türkçe',
    'partners': 'Partnerler',
    'yourName': 'Senin ismin',
    'partnerName': 'Partner ismi',
    'save': 'Kaydet',
    'resetNames': 'Partner isimlerini sıfırla',
    'home': 'Ana Sayfa',
    'modes': 'Modlar',

    'mode_sync': 'SYNC REVEAL',
    'mode_sync_sub': 'Gizli seç → birlikte aç → kahkaha 💥',
    'mode_tod': 'Truth or Dare',
    'mode_tod_sub': 'Klasik sırayla oynanır. Flört/komik.',
    'mode_spark': 'Spark',
    'mode_spark_sub': 'Anında romantik bağ kurduran mini sorular.',

    'sync_ready': 'HAZIR',
    'sync_pick_in': 'Seçim için',
    'sync_reveal': 'AÇ',
    'sync_match': '💥 SYNC! Bonus tur açıldı',
    'sync_mismatch': 'Uyumsuz! 5 kelimeyle açıkla.',
    'sync_bonus_title': 'Bonus Tur',
    'sync_explain_title': '5 kelimeyle açıkla',
    'sync_talk': 'Yüksek sesle söyle. Yazmak yok 😉',

    'tod_pick': 'Kart seç',
    'truth': 'TRUTH',
    'dare': 'DARE',
    'for_player': 'Sıra',
  };
}
