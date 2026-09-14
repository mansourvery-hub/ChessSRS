import 'package:chess_srs/l10n/l10n.dart';
import 'package:chess_srs/src/model/clock/clock_tool_controller.dart';

extension ClockTimeControlTypeL10n on ClockTimeControlType {
  String label(AppLocalizations l10n) {
    return switch (this) {
      ClockTimeControlType.increment => l10n.increment,
      ClockTimeControlType.simpleDelay => 'Simple delay',
      ClockTimeControlType.bronsteinDelay => 'Bronstein delay',
    };
  }

  String valueInSecondsLabel(AppLocalizations l10n) {
    return switch (this) {
      ClockTimeControlType.increment => l10n.incrementInSeconds,
      ClockTimeControlType.simpleDelay ||
      ClockTimeControlType.bronsteinDelay => l10n.incrementInSeconds,
    };
  }
}
