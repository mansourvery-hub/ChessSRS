import 'package:app_settings/app_settings.dart';
import 'package:chess_srs/l10n/l10n.dart';
import 'package:chess_srs/src/db/database.dart';
import 'package:chess_srs/src/model/auth/auth_controller.dart';
import 'package:chess_srs/src/model/common/preloaded_data.dart';
import 'package:chess_srs/src/model/settings/general_preferences.dart';
import 'package:chess_srs/src/model/study/study_preferences.dart';
import 'package:chess_srs/src/network/connectivity.dart';
import 'package:chess_srs/src/styles/styles.dart';
import 'package:chess_srs/src/utils/l10n.dart';
import 'package:chess_srs/src/utils/l10n_context.dart';
import 'package:chess_srs/src/utils/navigation.dart';
import 'package:chess_srs/src/view/settings/account_preferences_screen.dart';
import 'package:chess_srs/src/view/settings/app_log_settings_screen.dart';
import 'package:chess_srs/src/view/settings/board_settings_screen.dart';
import 'package:chess_srs/src/view/settings/engine_settings_screen.dart';
import 'package:chess_srs/src/view/settings/http_log_screen.dart';
import 'package:chess_srs/src/view/settings/sound_settings_screen.dart';
import 'package:chess_srs/src/widgets/adaptive_action_sheet.dart';
import 'package:chess_srs/src/widgets/adaptive_choice_picker.dart';
import 'package:chess_srs/src/widgets/feedback.dart';
import 'package:chess_srs/src/widgets/list.dart';
import 'package:chess_srs/src/widgets/misc.dart';
import 'package:chess_srs/src/widgets/platform.dart';
import 'package:chess_srs/src/widgets/settings.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Route<dynamic> buildRoute() {
    return buildScreenRoute(screen: const SettingsScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isDeviceOnlineProvider);
    final generalPrefs = ref.watch(generalPreferencesProvider);
    final packageInfo = ref.read(preloadedDataProvider).requireValue.packageInfo;
    final authUser = ref.watch(authControllerProvider);
    final signOutState = ref.watch(signOutMutation);
    final dbSize = ref.watch(getDbSizeInBytesProvider);

    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text(context.l10n.settingsSettings)),
      body: ListView(
        children: [
          if (authUser != null)
            ListSection(
              hasLeading: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  trailing: Theme.of(context).platform == TargetPlatform.iOS
                      ? const CupertinoListTileChevron()
                      : null,
                  title: Text(context.l10n.mobileAccountPreferences),
                  enabled: isOnline,
                  onTap: () {
                    Navigator.of(context).push(AccountPreferencesScreen.buildRoute());
                  },
                ),
              ],
            ),
          ListSection(
            hasLeading: true,
            children: [
              SettingsListTile(
                icon: const Icon(Icons.music_note_outlined),
                settingsLabel: Text(context.l10n.sound),
                settingsValue:
                    '${soundThemeL10n(context, generalPrefs.soundTheme)} (${volumeLabel(generalPrefs.masterVolume)})',
                onTap: () {
                  Navigator.of(context).push(SoundSettingsScreen.buildRoute());
                },
              ),
              SettingsListTile(
                enabled: !generalPrefs.isForcedDarkMode,
                icon: const Icon(Icons.brightness_medium_outlined),
                settingsLabel: Text(context.l10n.background),
                settingsValue: generalPrefs.isForcedDarkMode
                    ? BackgroundThemeMode.dark.title(context.l10n)
                    : generalPrefs.themeMode.title(context.l10n),
                onTap: () {
                  showChoicePicker(
                    context,
                    choices: BackgroundThemeMode.values,
                    selectedItem: generalPrefs.themeMode,
                    labelBuilder: (t) => Text(t.title(context.l10n)),
                    onSelectedItemChanged: (BackgroundThemeMode? value) => ref
                        .read(generalPreferencesProvider.notifier)
                        .setBackgroundThemeMode(value ?? BackgroundThemeMode.system),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(context.l10n.mobileTheme),
                trailing: Theme.of(context).platform == TargetPlatform.iOS
                    ? const CupertinoListTileChevron()
                    : null,
                onTap: () {
                  Navigator.of(context).push(SoundSettingsScreen.buildRoute());
                },
              ),
              ListTile(
                leading: const Icon(Symbols.chess_pawn),
                title: Text(context.l10n.mobileBoardSettings, overflow: TextOverflow.ellipsis),
                trailing: Theme.of(context).platform == TargetPlatform.iOS
                    ? const CupertinoListTileChevron()
                    : null,
                onTap: () {
                  Navigator.of(context).push(BoardSettingsScreen.buildRoute());
                },
              ),
              SwitchListTile(
                secondary: const Icon(Symbols.comment_rounded),
                title: const Text('Show move notes & comments'),
                subtitle: const Text('Display study explanations after guessing moves'),
                value: ref.watch(studyPreferencesProvider.select((p) => p.showPgnComments)),
                onChanged: (_) => ref.read(studyPreferencesProvider.notifier).togglePgnComments(),
              ),
              SwitchListTile(
                secondary: const Icon(Symbols.draw_rounded),
                title: const Text('Show board arrows & shapes'),
                subtitle: const Text(
                  'Display visual arrows and circle highlights from study notes',
                ),
                value: ref.watch(studyPreferencesProvider.select((p) => p.showAnnotations)),
                onChanged: (_) => ref.read(studyPreferencesProvider.notifier).toggleAnnotations(),
              ),
              SwitchListTile(
                secondary: const Icon(Symbols.smart_toy_rounded),
                title: const Text('Animate opponent moves'),
                subtitle: const Text('Play opponent’s previous move when starting a new line'),
                value: ref.watch(studyPreferencesProvider.select((p) => p.animateOpponentPreMove)),
                onChanged: (_) =>
                    ref.read(studyPreferencesProvider.notifier).toggleAnimateOpponentPreMove(),
              ),
              SettingsListTile(
                icon: const Icon(Symbols.schedule_rounded),
                settingsLabel: const Text('SRS scheduling algorithm'),
                settingsValue: ref.watch(
                  studyPreferencesProvider.select((p) => p.schedulerType.label),
                ),
                onTap: () {
                  final currentType = ref.read(studyPreferencesProvider).schedulerType;
                  showChoicePicker<SchedulerType>(
                    context,
                    choices: SchedulerType.values,
                    selectedItem: currentType,
                    labelBuilder: (t) => Text(t.label),
                    onSelectedItemChanged: (SchedulerType? value) {
                      if (value != null) {
                        ref.read(studyPreferencesProvider.notifier).setSchedulerType(value);
                      }
                    },
                  );
                },
              ),
              if (ref.watch(
                studyPreferencesProvider.select((p) => p.schedulerType == SchedulerType.fsrs),
              )) ...[
                SettingsListTile(
                  icon: const Icon(Symbols.target),
                  settingsLabel: const Text('Target recall retention'),
                  settingsValue:
                      '${(ref.watch(studyPreferencesProvider.select((p) => p.targetRetention)) * 100).round()}%',
                  onTap: () {
                    final current = ref.read(studyPreferencesProvider).targetRetention;
                    showChoicePicker<double>(
                      context,
                      choices: const [0.80, 0.85, 0.88, 0.90, 0.95],
                      selectedItem: current,
                      labelBuilder: (v) => Text(
                        '${(v * 100).round()}% ${v >= 0.95
                            ? "(Tournament mode)"
                            : v == 0.88
                            ? "(Default)"
                            : ""}',
                      ),
                      onSelectedItemChanged: (double? value) {
                        if (value != null) {
                          ref.read(studyPreferencesProvider.notifier).setTargetRetention(value);
                        }
                      },
                    );
                  },
                ),
              ],
              if (ref.watch(
                studyPreferencesProvider.select(
                  (p) => p.schedulerType == SchedulerType.easeScaling,
                ),
              )) ...[
                SettingsListTile(
                  icon: const Icon(Symbols.tune_rounded),
                  settingsLabel: const Text('Initial ease factor'),
                  settingsValue:
                      '${ref.watch(studyPreferencesProvider.select((p) => p.schedulerEase))}x',
                  onTap: () {
                    final current = ref.read(studyPreferencesProvider).schedulerEase;
                    showChoicePicker<double>(
                      context,
                      choices: const [1.5, 2.0, 2.5, 3.0, 3.5],
                      selectedItem: current,
                      labelBuilder: (v) => Text('${v}x (interval after first success)'),
                      onSelectedItemChanged: (double? value) {
                        if (value != null) {
                          ref.read(studyPreferencesProvider.notifier).setSchedulerEase(value);
                        }
                      },
                    );
                  },
                ),
                SettingsListTile(
                  icon: const Icon(Symbols.trending_up_rounded),
                  settingsLabel: const Text('Growth rate scaling'),
                  settingsValue:
                      '${ref.watch(studyPreferencesProvider.select((p) => p.schedulerScaling))}x',
                  onTap: () {
                    final current = ref.read(studyPreferencesProvider).schedulerScaling;
                    showChoicePicker<double>(
                      context,
                      choices: const [1.2, 1.3, 1.5, 1.8, 2.0],
                      selectedItem: current,
                      labelBuilder: (v) => Text('${v}x (multiplier on subsequent reviews)'),
                      onSelectedItemChanged: (double? value) {
                        if (value != null) {
                          ref.read(studyPreferencesProvider.notifier).setSchedulerScaling(value);
                        }
                      },
                    );
                  },
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Symbols.timeline_rounded, size: 20),
                  title: const Text(
                    'Interval progression preview',
                    style: TextStyle(fontSize: 12.0),
                  ),
                  subtitle: Builder(
                    builder: (context) {
                      final prefs = ref.watch(studyPreferencesProvider);
                      final ease = prefs.schedulerEase;
                      final scaling = prefs.schedulerScaling;
                      const r1 = 1.0;
                      final r2 = r1 * ease;
                      final r3 = r2 * scaling;
                      final r4 = r3 * scaling;
                      final r5 = r4 * scaling;
                      String fmt(double d) =>
                          d == d.roundToDouble() ? '${d.toInt()}d' : '${d.toStringAsFixed(1)}d';
                      return Text(
                        '${fmt(r1)} → ${fmt(r2)} → ${fmt(r3)} → ${fmt(r4)} → ${fmt(r5)}',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.memory_outlined),
                title: const Text('Chess engine'),
                trailing: Theme.of(context).platform == TargetPlatform.iOS
                    ? const CupertinoListTileChevron()
                    : null,
                onTap: () {
                  Navigator.of(context).push(EngineSettingsScreen.buildRoute());
                },
              ),
              SettingsListTile(
                icon: const Icon(Icons.language_outlined),
                settingsLabel: Text(context.l10n.language),
                settingsValue: localeToLocalizedName(
                  generalPrefs.locale ?? Localizations.localeOf(context),
                ),
                onTap: () {
                  if (Theme.of(context).platform == TargetPlatform.android) {
                    showChoicePicker<Locale>(
                      context,
                      choices: localesSortedByLocalizedName(AppLocalizations.supportedLocales),
                      selectedItem: generalPrefs.locale ?? Localizations.localeOf(context),
                      labelBuilder: (t) => Text(localeToLocalizedName(t)),
                      onSelectedItemChanged: (Locale? locale) =>
                          ref.read(generalPreferencesProvider.notifier).setLocale(locale),
                    );
                  } else {
                    AppSettings.openAppSettings(type: AppSettingsType.appLocale);
                  }
                },
              ),
            ],
          ),
          ListSection(
            hasLeading: true,
            children: [
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Local database size'),
                trailing: dbSize.hasValue ? Text(_getSizeString(dbSize.value)) : null,
              ),
              ListTile(
                leading: const Icon(Icons.http),
                title: const Text('HTTP logs'),
                onTap: () => Navigator.push(context, HttpLogScreen.buildRoute()),
                trailing: Theme.of(context).platform == TargetPlatform.iOS
                    ? const CupertinoListTileChevron()
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('App Logs'),
                trailing: Theme.of(context).platform == TargetPlatform.iOS
                    ? const CupertinoListTileChevron()
                    : null,
                onTap: () {
                  Navigator.of(context).push(AppLogSettingsScreen.buildRoute());
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Rate this app'),
                onTap: () async {
                  final isAndroid = Theme.of(context).platform == TargetPlatform.android;
                  final launched = await launchUrl(
                    isAndroid
                        ? Uri.parse('market://details?id=org.lichess.mobileV2')
                        : Uri.parse('https://apps.apple.com/us/app/lichess/id1662361230'),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched && isAndroid) {
                    launchUrl(
                      Uri.parse(
                        'https://play.google.com/store/apps/details?id=org.lichess.mobileV2',
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                trailing: const OpenInNewIcon(),
              ),
            ],
          ),
          if (authUser != null)
            ListSection(
              hasLeading: true,
              children: [
                switch (signOutState) {
                  MutationPending() => const ListTile(
                    leading: Icon(Icons.logout_outlined),
                    enabled: false,
                    title: Center(child: ButtonLoadingIndicator()),
                  ),
                  _ => ListTile(
                    leading: const Icon(Icons.logout_outlined),
                    title: Text(context.l10n.logOut),
                    enabled: isOnline,
                    onTap: () => _showSignOutConfirmDialog(context, ref),
                  ),
                },
              ],
            ),
          Padding(
            padding: Styles.bodySectionPadding,
            child: Text('v${packageInfo.version}', style: TextTheme.of(context).bodySmall),
          ),
        ],
      ),
    );
  }

  Future<void> _showSignOutConfirmDialog(BuildContext context, WidgetRef ref) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return showCupertinoActionSheet(
        context: context,
        actions: [
          BottomSheetAction(
            makeLabel: (context) => Text(context.l10n.logOut),
            isDestructiveAction: true,
            onPressed: () async {
              await signOutMutation.run(ref, (tsx) async {
                await tsx.get(authControllerProvider.notifier).signOut();
              });
            },
          ),
        ],
      );
    }
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.logOut),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await signOutMutation.run(ref, (tsx) async {
                  await tsx.get(authControllerProvider.notifier).signOut();
                });
              },
              child: Text(context.l10n.mobileOkButton),
            ),
          ],
        );
      },
    );
  }

  String _getSizeString(int? bytes) => '${_bytesToMB(bytes ?? 0).toStringAsFixed(2)}MB';

  double _bytesToMB(int bytes) => bytes * 0.000001;
}
