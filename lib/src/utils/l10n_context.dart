import 'package:chess_srs/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

extension LocalizedBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
