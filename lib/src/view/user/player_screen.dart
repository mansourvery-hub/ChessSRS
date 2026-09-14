import 'package:chess_srs/src/model/auth/auth_controller.dart';
import 'package:chess_srs/src/model/relation/online_friends.dart';
import 'package:chess_srs/src/model/user/user_repository_providers.dart';
import 'package:chess_srs/src/utils/focus_detector.dart';
import 'package:chess_srs/src/utils/l10n_context.dart';
import 'package:chess_srs/src/utils/navigation.dart';
import 'package:chess_srs/src/view/account/rating_pref_aware.dart';
import 'package:chess_srs/src/view/relation/friend_screen.dart';
import 'package:chess_srs/src/view/user/leaderboard_widget.dart';
import 'package:chess_srs/src/view/user/online_bots_screen.dart';
import 'package:chess_srs/src/view/user/search_screen.dart';
import 'package:chess_srs/src/view/user/user_or_profile_screen.dart';
import 'package:chess_srs/src/widgets/platform.dart';
import 'package:chess_srs/src/widgets/platform_search_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  static Route<dynamic> buildRoute() {
    return buildScreenRoute(screen: const PlayerScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FocusDetector(
      onFocusRegained: () {
        ref.read(onlineFriendsProvider.notifier).startWatchingFriends();
      },
      onFocusLost: () {
        if (context.mounted) {
          ref.read(onlineFriendsProvider.notifier).stopWatchingFriends();
        }
      },
      child: PlatformScaffold(
        appBar: PlatformAppBar(title: Text(context.l10n.players)),
        body: _Body(),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _focusNode = _AlwaysDisabledFocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authControllerProvider);
    final onlineFriends = ref.watch(onlineFriendsProvider);
    final onlineBots = ref.watch(onlineBotsProvider);
    final top1 = ref.watch(top1Provider);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: PlatformSearchBar(
            hintText: context.l10n.searchSearch,
            focusNode: _focusNode,
            onTap: () => Navigator.of(context).push(
              SearchScreen.buildRoute(
                onUserTap: (user) {
                  Navigator.of(context).push(UserOrProfileScreen.buildRoute(user));
                },
              ),
            ),
          ),
        ),
        if (authUser != null) OnlineFriendsWidget(onlineFriends: onlineFriends),
        OnlineBotsWidget(onlineBots: onlineBots),
        RatingPrefAware(child: LeaderboardWidget(top1: top1)),
      ],
    );
  }
}

class _AlwaysDisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}
