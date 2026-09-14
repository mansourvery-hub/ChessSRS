import 'package:chess_srs/src/model/common/local_game_clock.dart';
import 'package:chess_srs/src/model/common/time_increment.dart';
import 'package:chess_srs/src/model/offline_computer/offline_computer_game_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final offlineComputerClockProvider =
    NotifierProvider.autoDispose<OfflineComputerClock, LocalGameClockState>(
      OfflineComputerClock.new,
      name: 'OfflineComputerClockProvider',
    );

class OfflineComputerClock extends LocalGameClock {
  @override
  TimeIncrement get defaultTimeIncrement => OfflineComputerGamePrefs.defaults.timeIncrement;
}
