import 'dart:async';

import 'package:chess_srs/src/binding.dart';
import 'package:chess_srs/src/model/account/account_repository.dart';
import 'package:chess_srs/src/model/account/home_preferences.dart';
import 'package:chess_srs/src/model/account/home_widgets.dart';
import 'package:chess_srs/src/model/auth/auth_controller.dart';
import 'package:chess_srs/src/model/engine/evaluation_preferences.dart';
import 'package:chess_srs/src/model/engine/weights_service.dart';
import 'package:chess_srs/src/model/game/game_history.dart';
import 'package:chess_srs/src/network/connectivity.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/tab_navigation.dart';
import 'package:chess_srs/src/utils/focus_detector.dart';
import 'package:chess_srs/src/utils/l10n.dart';
import 'package:chess_srs/src/utils/l10n_context.dart';
import 'package:chess_srs/src/utils/navigation.dart';
import 'package:chess_srs/src/utils/screen.dart';
import 'package:chess_srs/src/view/account/account_menu.dart';
import 'package:chess_srs/src/view/account/profile_screen.dart';
import 'package:chess_srs/src/view/auth/sign_in_error.dart';
import 'package:chess_srs/src/view/auth/sign_in_options.dart';
import 'package:chess_srs/src/view/settings/engine_settings_screen.dart';
import 'package:chess_srs/src/view/user/recent_games.dart';
import 'package:chess_srs/src/widgets/feedback.dart';
import 'package:chess_srs/src/widgets/haptic_refresh_indicator.dart';
import 'package:chess_srs/src/widgets/misc.dart';
import 'package:chess_srs/src/widgets/platform.dart';
import 'package:chess_srs/src/widgets/server_outage_display.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Number of cold app starts before hiding the home customization tip.
const kColdAppStartsHideCustomizationTipThreshold = 5;

class HomeTabScreen extends ConsumerStatefulWidget {
  const HomeTabScreen({super.key, this.editModeEnabled = false});

  final bool editModeEnabled;

  static Route<dynamic> buildRoute({bool editModeEnabled = false}) {
    return buildScreenRoute(screen: HomeTabScreen(editModeEnabled: editModeEnabled));
  }

  @override
  ConsumerState<HomeTabScreen> createState() => _HomeScreenState();
}

class _IsEditingHome extends InheritedWidget {
  const _IsEditingHome({required super.child, required this.isEditingWidgets});

  final bool isEditingWidgets;

  @override
  bool updateShouldNotify(_IsEditingHome oldWidget) {
    return isEditingWidgets != oldWidget.isEditingWidgets;
  }

  static _IsEditingHome? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_IsEditingHome>();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('isEditingWidgets', isEditingWidgets));
  }
}

const String kWelcomeMessageShownKey = 'app_welcome_message_shown';
const String kHideHomeWidgetCustomizationTip = 'app_hide_home_widget_customization_tip';

class _HomeScreenState extends ConsumerState<HomeTabScreen> {
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  DateTime? _focusLostAt;

  bool wasOnline = true;
  bool hasRefreshed = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(connectivityChangesProvider, (_, connectivity) {
      // Refresh the data only once if it was offline and is now online
      if (!connectivity.isRefreshing && connectivity.hasValue) {
        final isNowOnline = connectivity.value!.isOnline;

        if (!hasRefreshed && !wasOnline && isNowOnline) {
          hasRefreshed = true;
          _refreshData(isOnline: isNowOnline);
        }

        wasOnline = isNowOnline;
      }
    });

    // Watched directly rather than through [isDeviceOnlineProvider], because
    // this screen shows a spinner until the connectivity status is known.
    return ref
        .watch(connectivityChangesProvider)
        .when(
          skipLoadingOnReload: true,
          data: (connectivity) {
            final isOnline = connectivity.isOnline;
            final authUser = ref.watch(authControllerProvider);
            final recentGames = ref.watch(myRecentGamesProvider);
            final nbOfGames = ref.watch(userNumberOfGamesProvider(null)).value ?? 0;
            final isTablet = isTabletOrLarger(context);

            // Everything the lichess server provides is unavailable both when the
            // device is offline and when the server itself is down. Widgets backed
            // by local data (recent games) keep
            // working in either case, so only the server-backed ones are hidden,
            // and a [ServerOutageDisplay] is shown in their place during an outage.
            final isServerUnavailable = ref
                .watch(lichessConnectionStatusProvider)
                .isServerUnavailable;
            final hasServerContent = isOnline && !isServerUnavailable;
            final showOutage = isServerUnavailable && !widget.editModeEnabled;

            // Show the welcome screen if not logged in and there are no recent games and no stored games
            // (i.e. first installation, or the user has never played a game)
            final shouldShowWelcomeScreen =
                authUser == null &&
                recentGames.maybeWhen(data: (data) => data.isEmpty, orElse: () => false);

            List<Widget> widgets;

            if (shouldShowWelcomeScreen) {
              final welcomeWidgets = [
                const _EditableWidget(
                  widget: HomeEditableWidget.hello,
                  shouldShow: true,
                  child: _GreetingWidget(),
                ),
                if (showOutage) const ServerOutageDisplay(),
                if (!widget.editModeEnabled) ...[
                  if (authUser == null) ...[
                    const Center(child: _SignInWidget()),
                    const SizedBox(height: 16.0),
                  ],
                  const _HomeCustomizationTip(),
                ],
              ];

              widgets = [
                if (isTablet)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [...welcomeWidgets],
                        ),
                      ),
                    ],
                  )
                else
                  ...welcomeWidgets,
              ];
            } else if (isTablet) {
              widgets = [
                const _EditableWidget(
                  widget: HomeEditableWidget.hello,
                  shouldShow: true,
                  child: _GreetingWidget(),
                ),
                if (!widget.editModeEnabled) ...[
                  const _HomeCustomizationTip(),
                  const _NNUEFilesOutdatedTip(),
                ],
                if (showOutage) const ServerOutageDisplay(),
                if (hasServerContent)
                  _EditableWidget(
                    widget: HomeEditableWidget.perfCards,
                    shouldShow: authUser != null,
                    child: const AccountPerfCards(padding: Styles.bodySectionPadding),
                  ),
                _EditableWidget(
                  widget: HomeEditableWidget.recentGames,
                  shouldShow: true,
                  child: RecentGamesWidget(
                    recentGames: recentGames,
                    nbOfGames: nbOfGames,
                    user: null,
                  ),
                ),
              ];
            } else {
              widgets = [
                const _EditableWidget(
                  widget: HomeEditableWidget.hello,
                  shouldShow: true,
                  child: _GreetingWidget(),
                ),
                if (!widget.editModeEnabled) ...[
                  const _HomeCustomizationTip(),
                  const _NNUEFilesOutdatedTip(),
                ],
                if (showOutage) const ServerOutageDisplay(),
                _EditableWidget(
                  widget: HomeEditableWidget.perfCards,
                  shouldShow: authUser != null && hasServerContent,
                  child: AccountPerfCards(
                    padding: Styles.horizontalBodyPadding.add(Styles.sectionBottomPadding),
                  ),
                ),
                _EditableWidget(
                  widget: HomeEditableWidget.recentGames,
                  shouldShow: true,
                  child: RecentGamesWidget(
                    recentGames: recentGames,
                    nbOfGames: nbOfGames,
                    user: null,
                  ),
                ),
              ];
            }

            final content = ListView(controller: homeScrollController, children: widgets);

            return FocusDetector(
              onFocusLost: () {
                _focusLostAt = DateTime.now();
              },
              onFocusRegained: () {
                if (context.mounted && _focusLostAt != null) {
                  final duration = DateTime.now().difference(_focusLostAt!);
                  if (duration.inSeconds < 10) {
                    return;
                  }
                  _refreshData(isOnline: isOnline);
                }
              },
              child: _IsEditingHome(
                isEditingWidgets: widget.editModeEnabled,
                child: PlatformScaffold(
                  appBar: widget.editModeEnabled
                      ? PlatformAppBar(
                          title: Text(context.l10n.mobileSettingsHomeWidgets),
                          leading: const BackButton(),
                          automaticallyImplyLeading: false,
                        )
                      : PlatformAppBar(
                          title: Theme.of(context).platform == TargetPlatform.iOS
                              ? AppBarLichessTitle(
                                  iconSize:
                                      Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24,
                                )
                              : const AppBarLichessTitle(),
                          centerTitle: false,
                          titleTextStyle: Theme.of(context).platform == TargetPlatform.iOS
                              ? Theme.of(context).textTheme.headlineSmall
                              : null,
                          actions: const [AccountMenuButton()],
                        ),
                  body: widget.editModeEnabled
                      ? content
                      : HapticRefreshIndicator(
                          edgeOffset: Theme.of(context).platform == TargetPlatform.iOS
                              ? MediaQuery.paddingOf(context).top + kToolbarHeight
                              : 0.0,
                          key: _refreshKey,
                          onRefresh: () => _refreshData(isOnline: isOnline),
                          child: content,
                        ),
                  bottomNavigationBar: widget.editModeEnabled
                      ? BottomAppBar(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text(context.l10n.ok),
                              ),
                            ],
                          ),
                        )
                      : null,
                  bottomSheet: widget.editModeEnabled ? null : const OfflineBanner(),
                ),
              ),
            );
          },
          error: (_, _) => const CenterLoadingIndicator(),
          loading: () => const CenterLoadingIndicator(),
        );
  }

  Future<void> _refreshData({required bool isOnline}) async {
    try {
      await Future.wait([
        ref.refresh(myRecentGamesProvider.future),
        if (isOnline) ref.refresh(accountProvider.future),
      ]);
    } catch (_) {
      // Refreshing while the server is unavailable is expected to fail. Each
      // provider surfaces its own error, and the failed responses are what keep
      // the server status up to date, so there is nothing to do here.
    }
  }
}

class _SignInWidget extends ConsumerWidget {
  const _SignInWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signInState = ref.watch(signInMutation);

    ref.listen(signInMutation, (_, next) => showSignInErrorSnackBar(context, next));

    return FilledButton(
      onPressed: switch (signInState) {
        MutationPending() => null,
        _ => () => showSignInOptions(context, ref),
      },
      child: Text(context.l10n.signIn),
    );
  }
}

/// A widget that can be enabled or disabled by the user.
///
/// This widget is used to show or hide certain sections of the home screen.
///
/// The [homePreferencesProvider] provides a list of enabled widgets.
///
/// * The [widget] parameter is the widget that can be enabled or disabled.
///
/// * The [shouldShow] parameter is useful when the widget should be shown only
///   when certain conditions are met. For example, we only want to show the quick
///   pairing matrix when the user is online.
///   This parameter is only active when the user is not in edit mode, as we
///   always want to display the widget in edit mode.
class _EditableWidget extends ConsumerWidget {
  const _EditableWidget({required this.child, required this.widget, required this.shouldShow});

  final Widget child;
  final HomeEditableWidget widget;
  final bool shouldShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disabledWidgets = ref.watch(homePreferencesProvider).disabledWidgets;
    final isEditing = _IsEditingHome.maybeOf(context)?.isEditingWidgets ?? false;
    final isEnabled = !disabledWidgets.contains(widget);

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    return isEditing
        ? Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox.adaptive(
                      value: isEnabled,
                      onChanged: widget.alwaysEnabled
                          ? null
                          : (_) {
                              ref.read(homePreferencesProvider.notifier).toggleWidget(widget);
                            },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IgnorePointer(ignoring: isEditing, child: child),
              ),
            ],
          )
        : widget.alwaysEnabled || isEnabled
        ? child
        : const SizedBox.shrink();
  }
}

class _IsDayTimeNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      ref.invalidateSelf();
    });

    ref.onDispose(() {
      _timer?.cancel();
    });

    final hour = DateTime.now().hour;
    return hour >= 6 && hour < 18; // Daytime is between 6 AM and 6 PM
  }
}

final _isDayTimeProvider = NotifierProvider.autoDispose<_IsDayTimeNotifier, bool>(
  _IsDayTimeNotifier.new,
  name: '_isDayTimeProvider',
);

class _GreetingWidget extends ConsumerWidget {
  const _GreetingWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authControllerProvider);
    final isDayTime = ref.watch(_isDayTimeProvider);
    final style = TextTheme.of(context).bodyLarge;

    const iconSize = 24.0;

    final user = authUser?.user;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: Styles.bodyPadding,
        child: GestureDetector(
          onTap: () {
            ref.invalidate(accountProvider);
            Navigator.of(context).push(ProfileScreen.buildRoute());
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isDayTime ? '☀️' : '🌙',
                style: const TextStyle(fontSize: iconSize, height: 1.0),
              ),
              const SizedBox(width: 5.0),
              if (user != null)
                Flexible(
                  child: l10nWithWidget(
                    isDayTime ? context.l10n.mobileGoodDay : context.l10n.mobileGoodEvening,
                    Text(user.name, style: style),
                    textStyle: style,
                  ),
                )
              else
                Flexible(
                  child: Text(
                    isDayTime
                        ? context.l10n.mobileGoodDayWithoutName
                        : context.l10n.mobileGoodEveningWithoutName,
                    style: style,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.content, required this.actions});

  final Widget content;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Styles.bodyPadding,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.bodyLarge,
                child: Padding(padding: const EdgeInsets.all(8.0), child: content),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _NNUEFilesOutdatedTip extends ConsumerStatefulWidget {
  const _NNUEFilesOutdatedTip();

  @override
  ConsumerState<_NNUEFilesOutdatedTip> createState() => _NNUEFilesOutdatedTipState();
}

class _NNUEFilesOutdatedTipState extends ConsumerState<_NNUEFilesOutdatedTip> {
  bool _openedSettings = false;
  late Future<bool> _checkNNUEFilesFuture;

  @override
  void initState() {
    super.initState();
    _checkNNUEFilesFuture = ref.read(stockfishNnueServiceProvider).hasOutdatedNNUEFiles();
  }

  @override
  Widget build(BuildContext context) {
    final chessEnginePref = ref.watch(engineEvaluationPreferencesProvider).enginePref;
    if (chessEnginePref != ChessEnginePref.sfLatest) {
      return const SizedBox.shrink();
    }

    final nnueService = ref.watch(stockfishNnueServiceProvider);
    if (nnueService.isDownloadingNNUEFile) {
      return const SizedBox.shrink();
    }

    return FocusDetector(
      // If we come back from the settings, trigger rebuild to hide the widget if the user has updated the NNUE files
      onFocusRegained: () {
        if (_openedSettings) {
          setState(() {
            _checkNNUEFilesFuture = nnueService.hasOutdatedNNUEFiles();
            _openedSettings = false;
          });
        }
      },
      child: FutureBuilder(
        future: _checkNNUEFilesFuture,
        builder: (context, snapshot) {
          final hasOutdatedNNUEFiles = snapshot.data ?? false;
          if (!hasOutdatedNNUEFiles) {
            return const SizedBox.shrink();
          }

          return _TipCard(
            content: Row(
              children: [
                Icon(Icons.warning, size: 25.0, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8.0),
                const Flexible(
                  child: Text(
                    // TODO l10n
                    'New Stockfish version available! Go to the settings to download the updated NNUE file.',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _openedSettings = true;
                  });
                  Navigator.of(
                    context,
                    rootNavigator: true,
                  ).push(EngineSettingsScreen.buildRoute());
                },
                // TODO l10n
                child: const Text('Open settings'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeCustomizationTip extends StatefulWidget {
  const _HomeCustomizationTip();

  @override
  State<_HomeCustomizationTip> createState() => _HomeCustomizationTipState();
}

class _HomeCustomizationTipState extends State<_HomeCustomizationTip> {
  bool _shouldDisplayHomeWidgetCustomizationTip() {
    final prefs = LichessBinding.instance.sharedPreferences;

    return prefs.getBool(kHideHomeWidgetCustomizationTip) != true &&
        LichessBinding.instance.numAppStarts <= kColdAppStartsHideCustomizationTipThreshold;
  }

  void _setHideHomeWidgetCustomizationTip() {
    LichessBinding.instance.sharedPreferences.setBool(kHideHomeWidgetCustomizationTip, true);

    // trigger rebuild to hide the tip
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldDisplayHomeWidgetCustomizationTip()) {
      return const SizedBox.shrink();
    }

    return _TipCard(
      content: Text(context.l10n.mobileCustomizeHomeTip),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
              rootNavigator: true,
            ).push(HomeTabScreen.buildRoute(editModeEnabled: true));

            _setHideHomeWidgetCustomizationTip();
          },
          child: Text(context.l10n.mobileCustomizeButton),
        ),
        const SizedBox(width: 8.0),
        TextButton(
          onPressed: () {
            _setHideHomeWidgetCustomizationTip();
          },
          child: Text(context.l10n.mobileCustomizeHomeTipDismiss),
        ),
      ],
    );
  }
}
