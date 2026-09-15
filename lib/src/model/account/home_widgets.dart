import 'package:chess_srs/l10n/l10n.dart';

/// Enum representing the editable widgets on the home screen.
enum HomeEditableWidget {
  hello(false),
  perfCards(false),
  friends(false),
  recentGames(false);

  String label(AppLocalizations l10n) => switch (this) {
    HomeEditableWidget.hello => 'Hello',
    HomeEditableWidget.perfCards => 'Performance Cards',
    HomeEditableWidget.friends => l10n.friends,
    HomeEditableWidget.recentGames => l10n.recentGames,
  };

  const HomeEditableWidget(this.alwaysEnabled);

  /// True if the widget should always be enabled and cannot be disabled.
  final bool alwaysEnabled;
}
