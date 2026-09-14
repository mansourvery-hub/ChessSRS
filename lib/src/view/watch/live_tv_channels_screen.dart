import 'package:chess_srs/src/model/tv/live_tv_channels.dart';
import 'package:chess_srs/src/model/tv/tv_channel.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/utils/focus_detector.dart';
import 'package:chess_srs/src/utils/l10n_context.dart';
import 'package:chess_srs/src/utils/navigation.dart';
import 'package:chess_srs/src/view/watch/tv_screen.dart';
import 'package:chess_srs/src/widgets/board_preview.dart';
import 'package:chess_srs/src/widgets/platform.dart';
import 'package:chess_srs/src/widgets/user.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class LiveTvChannelsScreen extends ConsumerWidget {
  const LiveTvChannelsScreen({super.key});

  static Route<dynamic> buildRoute() {
    return buildScreenRoute(screen: const LiveTvChannelsScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FocusDetector(
      onFocusRegained: () {
        ref.read(liveTvChannelsProvider.notifier).startWatching();
      },
      onFocusLost: () {
        if (context.mounted) {
          ref.read(liveTvChannelsProvider.notifier).stopWatching();
        }
      },
      child: PlatformScaffold(
        appBar: PlatformAppBar(title: const Text('Lichess TV')),
        body: const _Body(),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(liveTvChannelsProvider);
    return gamesAsync.when(
      data: (games) {
        final list = [
          for (final channel in TvChannel.values)
            if (games[channel] != null) games[channel]!,
        ];
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final game = list[index];
            return SmallBoardPreview(
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  TvScreen.buildRoute(
                    channel: game.channel,
                    gameId: game.id,
                    orientation: game.orientation,
                  ),
                );
              },
              orientation: game.orientation,
              fen: game.fen ?? kEmptyFEN,
              lastMove: game.lastMove,
              description: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(game.channel.label(context.l10n), style: Styles.boardPreviewTitle),
                  Icon(game.channel.icon, size: 32),
                  UserFullNameWidget.player(
                    user: game.player.asPlayer.user,
                    aiLevel: game.player.asPlayer.aiLevel,
                    rating: game.player.rating,
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
    );
  }
}
