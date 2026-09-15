import 'package:chess_srs/src/model/common/chess.dart';
import 'package:chess_srs/src/model/game/game_board_params.dart';
import 'package:chess_srs/src/utils/l10n_context.dart';
import 'package:chess_srs/src/view/game/game_body.dart';
import 'package:chess_srs/src/widgets/bottom_bar.dart';
import 'package:chess_srs/src/widgets/game_layout.dart';
import 'package:chess_srs/src/widgets/shimmer.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dartchess/dartchess.dart';
import 'package:material_ui/material_ui.dart';

class StandaloneGameLoadingContent extends StatelessWidget {
  const StandaloneGameLoadingContent({this.loadingParam, this.userActionsBar, super.key});

  final LoadingParam? loadingParam;
  final Widget? userActionsBar;

  @override
  Widget build(BuildContext context) {
    final loadingFen = loadingParam?.fen;
    final variant = loadingParam?.variant ?? Variant.standard;
    Position? loadingPosition;
    if (loadingFen != null) {
      try {
        loadingPosition = Position.setupPosition(
          variant.rule,
          Setup.parseFen(loadingFen),
          ignoreImpossibleCheck: true,
        );
      } catch (_) {
        loadingPosition = null;
      }
    }
    final lastMove = loadingParam?.lastMove;
    return Shimmer(
      child: SafeArea(
        child: GameLayout(
          orientation: loadingParam?.orientation ?? Side.white,
          boardParams: loadingPosition == null
              ? GameBoardParams.emptyBoard
              : GameBoardParams.readonly(
                  variant: variant,
                  position: loadingPosition,
                  lastMove: switch (lastMove) {
                    NormalMove(:final from, :final to) when from == to => DropMove(
                      to: to,
                      role: Role.pawn,
                    ),
                    _ => lastMove,
                  },
                ),
          topTable: const LoadingPlayerWidget(),
          bottomTable: const LoadingPlayerWidget(),
          moves: const [],
          userActionsBar: userActionsBar,
        ),
      ),
    );
  }
}

/// A widget that shows a loading indicator for a player.
///
/// Must be wrapped in a [Shimmer] widget.
class LoadingPlayerWidget extends StatelessWidget {
  const LoadingPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isLoading: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            flex: 6,
            child: SizedBox(
              height: 24.0,
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ),
          const Spacer(),
          Flexible(
            flex: 2,
            child: SizedBox(
              height: 38.0,
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadGameError extends StatelessWidget {
  const LoadGameError(this.errorMessage, {this.showBottomBar = true});

  final String errorMessage;
  final bool showBottomBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            child: GameLayout(
              orientation: Side.white,
              boardParams: GameBoardParams.emptyBoard,
              moves: const [],
              errorMessage: errorMessage,
            ),
          ),
        ),
        BottomBar(
          children: [
            if (showBottomBar)
              BottomBarButton(
                onTap: () => Navigator.of(context).pop(),
                label: context.l10n.cancel,
                icon: CupertinoIcons.xmark,
                showLabel: true,
              ),
          ],
        ),
      ],
    );
  }
}
