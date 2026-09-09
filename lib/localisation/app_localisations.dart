import 'package:flutter/material.dart';

/// Real EN/SW localisation, deliberately built as a plain Dart lookup table
/// + LocalizationsDelegate instead of the ARB/gen-l10n pipeline — that
/// tooling adds a codegen build step which is more moving parts than a
/// two-language MVP needs, and this is just as real: it swaps strings at
/// runtime based on device/app locale, same contract flutter_localizations
/// gives you.
///
/// Usage in a widget: `context.t('feed_empty_title')`.
/// Add new keys to both maps below and they're immediately available.
class AppLocalisations {
  final Locale locale;
  AppLocalisations(this.locale);

  static const supportedLocales = [Locale('en'), Locale('sw')];

  static AppLocalisations of(BuildContext context) {
    final loc = Localizations.of<AppLocalisations>(context, AppLocalisations);
    assert(loc != null, 'AppLocalisations not found — is AppLocalisations.delegate registered in MaterialApp?');
    return loc!;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'nav_feed': 'Feed',
      'nav_discover': 'Discover',
      'nav_scouts': 'Scouts',
      'nav_profile': 'Profile',
      'feed_empty_title': 'No players yet',
      'feed_empty_description': 'Approved player submissions will appear here.\nTap + below to submit the first one.',
      'discover_title': 'DISCOVER',
      'discover_subtitle': 'Browse talent by region',
      'scouts_title': 'SCOUTS',
      'scouts_subtitle': 'Verified scouts and agents',
      'profile_sign_in': 'Sign in',
      'profile_sign_up': 'Sign up',
      'profile_sign_out': 'Sign out',
      'profile_email': 'Email',
      'profile_password': 'Password',
      'submit_review_note': 'All submissions reviewed before appearing publicly',
    },
    'sw': {
      'nav_feed': 'Mlisho',
      'nav_discover': 'Gundua',
      'nav_scouts': 'Wachunguzi',
      'nav_profile': 'Wasifu',
      'feed_empty_title': 'Hakuna wachezaji bado',
      'feed_empty_description': 'Wachezaji walioidhinishwa wataonekana hapa.\nGusa + chini kuwasilisha wa kwanza.',
      'discover_title': 'GUNDUA',
      'discover_subtitle': 'Vinjari vipaji kwa eneo',
      'scouts_title': 'WACHUNGUZI',
      'scouts_subtitle': 'Wachunguzi na mawakala walioidhinishwa',
      'profile_sign_in': 'Ingia',
      'profile_sign_up': 'Jisajili',
      'profile_sign_out': 'Toka',
      'profile_email': 'Barua pepe',
      'profile_password': 'Nenosiri',
      'submit_review_note': 'Mawasilisho yote yanakaguliwa kabla ya kuonekana hadharani',
    },
  };

  String t(String key) {
    final lang = locale.languageCode;
    return _strings[lang]?[key] ?? _strings['en']?[key] ?? key;
  }

  static const LocalizationsDelegate<AppLocalisations> delegate = _AppLocalisationsDelegate();
}

class _AppLocalisationsDelegate extends LocalizationsDelegate<AppLocalisations> {
  const _AppLocalisationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalisations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalisations> load(Locale locale) async => AppLocalisations(locale);

  @override
  bool shouldReload(_AppLocalisationsDelegate old) => false;
}

/// Shorthand so screens can write `context.t('key')` instead of the more
/// verbose `AppLocalisations.of(context).t('key')`.
extension AppLocalisationsX on BuildContext {
  String t(String key) => AppLocalisations.of(this).t(key);
}
