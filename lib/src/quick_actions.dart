import 'package:chess_srs/l10n/l10n.dart';
import 'package:chess_srs/src/localizations.dart';
import 'package:chess_srs/src/model/common/chess.dart';
import 'package:chess_srs/src/model/common/perf.dart';
import 'package:chess_srs/src/model/common/speed.dart';
import 'package:chess_srs/src/model/lobby/game_seek.dart';
import 'package:chess_srs/src/tab_navigation.dart';
import 'package:chess_srs/src/view/game/game_screen.dart';
import 'package:chess_srs/src/view/game/game_screen_providers.dart';
import 'package:chess_srs/src/view/offline_computer/offline_computer_game_screen.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quick_actions/quick_actions.dart';

/// Provider for the [QuickActionService].
final quickActionServiceProvider = Provider<QuickActionService>((Ref ref) {
  final service = QuickActionService(ref);
  ref.listen<RecentGameSeekPrefs>(recentGameSeekProvider, (previous, next) {
    if (previous?.seeks == next.seeks) return;
    service.setQuickActions(next.seeks);
  });
  return service;
});

class QuickActionService {
  QuickActionService(this.ref);

  final Ref ref;
  AppLocalizations get l10n => ref.read(localizationsProvider).strings;

  final QuickActions quickActions = const QuickActions();

  TargetPlatform get platform => defaultTargetPlatform;

  void start() {
    // Quick actions are only supported on Android and iOS; the plugin has no
    // implementation on desktop targets.
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      return;
    }

    final recentSeeks = ref.read(recentGameSeekProvider).seeks;
    quickActions.initialize((String shortcutType) {
      final context = ref.read(currentNavigatorKeyProvider).currentContext;
      if (context == null || !context.mounted) return;

      if (shortcutType.startsWith('recent_seek_')) {
        final index = int.tryParse(shortcutType.split('_').last);
        if (index != null) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).push(GameScreen.buildRoute(source: LobbySource(recentSeeks[index])));
        }
      } else if (shortcutType == 'play_computer') {
        Navigator.of(context, rootNavigator: true).push(OfflineComputerGameScreen.buildRoute());
      }
    });
    setQuickActions(recentSeeks);
  }

  void setQuickActions(IList<GameSeek> recentSeeks) {
    quickActions.setShortcutItems(<ShortcutItem>[
      ShortcutItem(
        type: 'play_computer',
        localizedTitle: l10n.playAgainstComputer,
        icon: platform == TargetPlatform.iOS ? 'ComputerIcon' : 'computer',
      ),

      ...recentSeeks.asMap().entries.map((entry) {
        final index = entry.key;
        final seek = entry.value;

        final time = seek.clock != null ? seek.clock!.$1.inMinutes.toString() : '-';
        final increment = seek.clock != null ? seek.clock!.$2.inSeconds.toString() : '0';
        final rated = seek.rated ? l10n.ratedTournament : l10n.casualTournament;

        final variant = (seek.variant == Variant.standard)
            ? ''
            : (seek.variant != null && seek.timeIncrement != null)
            ? ' • ${Perf.fromVariantAndSpeed(seek.variant!, Speed.fromTimeIncrement(seek.timeIncrement!)).shortLabel(l10n)}'
            : '';

        return ShortcutItem(
          type: 'recent_seek_$index',
          localizedTitle: '$time+$increment $rated$variant',
          localizedSubtitle: l10n.recentGames,
          icon: platform == TargetPlatform.iOS ? 'PlusIcon' : 'add_icon',
        );
      }),
    ]);
  }
}
