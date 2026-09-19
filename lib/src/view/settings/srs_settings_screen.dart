// Copyright (C) 2024 ChessSRS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:chess_srs/src/domain/chess_fsrs_scheduler.dart';
import 'package:chess_srs/src/model/study/study_preferences.dart';
import 'package:chess_srs/src/utils/navigation.dart';
import 'package:chess_srs/src/widgets/adaptive_choice_picker.dart';
import 'package:chess_srs/src/widgets/list.dart';
import 'package:chess_srs/src/widgets/platform.dart';
import 'package:chess_srs/src/widgets/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

class SrsSettingsScreen extends ConsumerWidget {
  const SrsSettingsScreen({super.key});

  static Route<dynamic> buildRoute() {
    return buildScreenRoute(screen: const SrsSettingsScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(studyPreferencesProvider);

    return PlatformScaffold(
      appBar: PlatformAppBar(title: const Text('Spaced Repetition (SRS)')),
      body: ListView(
        children: [
          ListSection(
            header: const SettingsSectionTitle('Algorithm & Intervals'),
            hasLeading: true,
            children: [
              SettingsListTile(
                icon: const Icon(Symbols.calendar_today_rounded),
                settingsLabel: const Text('Daily review limit'),
                settingsValue: prefs.maxDailyReviews == 0
                    ? 'Unlimited'
                    : '${prefs.maxDailyReviews} positions / day',
                onTap: () {
                  showChoicePicker<int>(
                    context,
                    choices: const [25, 50, 100, 150, 200, 0],
                    selectedItem: prefs.maxDailyReviews,
                    labelBuilder: (v) => Text(
                      v == 0
                          ? 'Unlimited'
                          : v == 100
                          ? '$v positions / day (Default)'
                          : '$v positions / day',
                    ),
                    onSelectedItemChanged: (int? value) {
                      if (value != null) {
                        ref.read(studyPreferencesProvider.notifier).setMaxDailyReviews(value);
                      }
                    },
                  );
                },
              ),
              SettingsListTile(
                icon: const Icon(Symbols.schedule_rounded),
                settingsLabel: const Text('SRS scheduling algorithm'),
                settingsValue: prefs.schedulerType.label,
                onTap: () {
                  showChoicePicker<SchedulerType>(
                    context,
                    choices: SchedulerType.values,
                    selectedItem: prefs.schedulerType,
                    labelBuilder: (t) => Text(t.label),
                    onSelectedItemChanged: (SchedulerType? value) {
                      if (value != null) {
                        ref.read(studyPreferencesProvider.notifier).setSchedulerType(value);
                      }
                    },
                  );
                },
              ),
              if (prefs.schedulerType == SchedulerType.fsrs) ...[
                SettingsListTile(
                  icon: const Icon(Symbols.target),
                  settingsLabel: const Text('Target recall retention'),
                  settingsValue: '${(prefs.targetRetention * 100).round()}%',
                  onTap: () {
                    showChoicePicker<double>(
                      context,
                      choices: const [0.80, 0.85, 0.88, 0.90, 0.95],
                      selectedItem: prefs.targetRetention,
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
                ListTile(
                  dense: true,
                  leading: const Icon(Symbols.timeline_rounded, size: 20),
                  title: const Text(
                    'FSRS interval progression preview',
                    style: TextStyle(fontSize: 12.0),
                  ),
                  subtitle: Builder(
                    builder: (context) {
                      final intervals = fsrsIntervalProgressionPreview(
                        targetRetention: prefs.targetRetention,
                      );
                      String fmt(double d) =>
                          d >= 10 ? '${d.round()}d' : '${d.toStringAsFixed(1)}d';
                      return Text(
                        intervals.map(fmt).join(' → '),
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
              if (prefs.schedulerType == SchedulerType.simple) ...[
                const ListTile(
                  dense: true,
                  leading: Icon(Symbols.timeline_rounded, size: 20),
                  title: Text('Simple doubling interval preview', style: TextStyle(fontSize: 12.0)),
                  subtitle: Text(
                    '1d → 2d → 4d → 8d → 16d',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
              if (prefs.schedulerType == SchedulerType.easeScaling) ...[
                SettingsListTile(
                  icon: const Icon(Symbols.tune_rounded),
                  settingsLabel: const Text('Initial ease factor'),
                  settingsValue: '${prefs.schedulerEase}x',
                  onTap: () {
                    showChoicePicker<double>(
                      context,
                      choices: const [1.5, 2.0, 2.5, 3.0, 3.5],
                      selectedItem: prefs.schedulerEase,
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
                  settingsValue: '${prefs.schedulerScaling}x',
                  onTap: () {
                    showChoicePicker<double>(
                      context,
                      choices: const [1.2, 1.3, 1.5, 1.8, 2.0],
                      selectedItem: prefs.schedulerScaling,
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
            ],
          ),
          ListSection(
            header: const SettingsSectionTitle('Review Experience'),
            hasLeading: true,
            children: [
              SwitchListTile.adaptive(
                secondary: const Icon(Symbols.smart_toy_rounded),
                title: const Text('Animate opponent moves'),
                subtitle: const Text('Play opponent’s previous move when starting a new line'),
                value: prefs.animateOpponentPreMove,
                onChanged: (_) =>
                    ref.read(studyPreferencesProvider.notifier).toggleAnimateOpponentPreMove(),
              ),
              SwitchListTile.adaptive(
                secondary: const Icon(Symbols.comment_rounded),
                title: const Text('Show move notes & comments'),
                subtitle: const Text('Display study explanations after guessing moves'),
                value: prefs.showPgnComments,
                onChanged: (_) => ref.read(studyPreferencesProvider.notifier).togglePgnComments(),
              ),
              SwitchListTile.adaptive(
                secondary: const Icon(Symbols.draw_rounded),
                title: const Text('Show board arrows & shapes'),
                subtitle: const Text(
                  'Display visual arrows and circle highlights from study notes',
                ),
                value: prefs.showAnnotations,
                onChanged: (_) => ref.read(studyPreferencesProvider.notifier).toggleAnnotations(),
              ),
            ],
          ),
          ListSection(
            header: const SettingsSectionTitle('Diagnostics'),
            hasLeading: true,
            children: [
              SwitchListTile.adaptive(
                secondary: const Icon(Symbols.bug_report_rounded),
                title: const Text('Developer / SRS diagnostics'),
                subtitle: const Text(
                  'Show mathematical memory metrics (DSR) and graph effects during review',
                ),
                value: prefs.srsDiagnostics,
                onChanged: (_) =>
                    ref.read(studyPreferencesProvider.notifier).toggleSrsDiagnostics(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
