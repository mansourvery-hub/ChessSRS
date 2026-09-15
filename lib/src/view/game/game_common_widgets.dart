import 'package:chess_srs/src/model/analysis/analysis_controller.dart';
import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/game/exported_game.dart';
import 'package:chess_srs/src/model/game/game_share_service.dart';
import 'package:chess_srs/src/network/http.dart';
import 'package:chess_srs/src/utils/l10n_context.dart';
import 'package:chess_srs/src/utils/share.dart';
import 'package:chess_srs/src/view/analysis/analysis_screen.dart';
import 'package:chess_srs/src/view/game/gif_export_dialog.dart';
import 'package:chess_srs/src/widgets/adaptive_action_sheet.dart';
import 'package:chess_srs/src/widgets/feedback.dart';
import 'package:chess_srs/src/widgets/platform_context_menu_button.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

/// Opens a game screen for the given [LightExportedGame].
///
/// Will open [GameScreen] if the game Id is a [GameFullId], otherwise [AnalysisScreen].
///
/// If the game is not read supported, a snackbar is shown.
void openGameScreen(
  BuildContext context, {
  required LightExportedGame game,
  required Side orientation,
  String? loadingFen,
  Move? loadingLastMove,
  DateTime? lastMoveAt,
}) {
  if (game.variant.isReadSupported) {
    Navigator.of(context, rootNavigator: true).push(
      AnalysisScreen.buildRoute(
        AnalysisOptions.archivedGame(
          orientation: orientation,
          gameId: game.id,
          initialMoveCursor: 0,
        ),
      ),
    );
  } else {
    showSnackBar(context, 'This variant is not supported yet.', type: SnackBarType.info);
  }
}

class GameBookmarkContextMenuAction extends StatefulWidget {
  const GameBookmarkContextMenuAction({
    required this.id,
    required this.bookmarked,
    required this.onToggleBookmark,
    super.key,
  });

  final GameId id;
  final bool bookmarked;
  final Future<void> Function() onToggleBookmark;

  @override
  State<GameBookmarkContextMenuAction> createState() => _GameBookmarkContextMenuActionState();
}

class _GameBookmarkContextMenuActionState extends State<GameBookmarkContextMenuAction> {
  Future<void>? _pendingBookmarkAction;
  late bool _bookmarked;

  @override
  void initState() {
    _bookmarked = widget.bookmarked;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _pendingBookmarkAction,
      builder: (context, snapshot) {
        return ContextMenuAction(
          icon: _bookmarked ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined,
          label: _bookmarked ? context.l10n.mobileRemoveBookmark : context.l10n.bookmarkThisGame,
          onPressed: snapshot.connectionState == ConnectionState.waiting
              ? null
              : () async {
                  try {
                    final future = widget.onToggleBookmark();
                    setState(() {
                      _pendingBookmarkAction = future;
                    });
                    await future;
                    if (context.mounted) {
                      setState(() {
                        _bookmarked = !_bookmarked;
                      });
                    }
                  } catch (_) {
                    if (context.mounted) {
                      showSnackBar(context, 'Bookmark action failed', type: SnackBarType.error);
                    }
                  }
                },
        );
      },
    );
  }
}

/// Makes a list of [BottomSheetAction] for game sharing options, meant to be
/// used in a "Share & export" bottom sheet.
///
/// The game URL can always be shared; the GIF and PGN exports are only available
/// once the game is [finished].
List<BottomSheetAction> makeFinishedGameShareBottomSheetActions(
  BuildContext context,
  WidgetRef ref, {
  required GameId gameId,
  required Side orientation,
  required bool finished,
}) {
  return [
    BottomSheetAction(
      makeLabel: (context) => Text(context.l10n.mobileShareGameURL),
      onPressed: () {
        launchShareDialog(context, ShareParams(uri: lichessUri('/$gameId/${orientation.name}')));
      },
    ),
    if (finished) ...[
      BottomSheetAction(
        makeLabel: (context) => Text(context.l10n.gameAsGIF),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => GifExport(gameId: gameId, orientation: orientation),
        ),
      ),
      BottomSheetAction(
        makeLabel: (context) => Text(context.l10n.downloadAnnotated),
        onPressed: () async {
          try {
            final pgn = await ref.read(gameShareServiceProvider).annotatedPgn(gameId);
            if (context.mounted) {
              launchShareDialog(context, ShareParams(text: pgn));
            }
          } catch (e) {
            if (context.mounted) {
              showSnackBar(context, 'Failed to get PGN', type: SnackBarType.error);
            }
          }
        },
      ),
      BottomSheetAction(
        makeLabel: (context) => Text(context.l10n.downloadRaw),
        onPressed: () async {
          try {
            final pgn = await ref.read(gameShareServiceProvider).rawPgn(gameId);
            if (context.mounted) {
              launchShareDialog(context, ShareParams(text: pgn));
            }
          } catch (e) {
            if (context.mounted) {
              showSnackBar(context, 'Failed to get PGN', type: SnackBarType.error);
            }
          }
        },
      ),
    ],
  ];
}
