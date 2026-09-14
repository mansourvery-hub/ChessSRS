import 'dart:convert';

import 'package:chess_srs/l10n/l10n.dart';
import 'package:chess_srs/src/binding.dart';
import 'package:chess_srs/src/model/settings/general_preferences.dart';
import 'package:chess_srs/src/model/settings/preferences_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

Locale getSystemLocale(WidgetsBinding widgetsBinding) {
  return AppLocalizations.delegate.isSupported(widgetsBinding.platformDispatcher.locale)
      ? widgetsBinding.platformDispatcher.locale
      : const Locale('en');
}

/// Setup [Intl.defaultLocale] and timeago locale and messages.
Locale setupIntl(WidgetsBinding widgetsBinding) {
  final systemLocale = getSystemLocale(widgetsBinding);

  // Get locale from shared preferences, if any
  final json = LichessBinding.instance.sharedPreferences.getString(PrefCategory.general.storageKey);
  final generalPref = json != null
      ? GeneralPrefs.fromJson(jsonDecode(json) as Map<String, dynamic>)
      : GeneralPrefs.defaults;
  final prefsLocale = generalPref.locale;
  final locale = prefsLocale ?? systemLocale;

  Intl.defaultLocale = locale.toLanguageTag();

  return locale;
}
