import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/study/study_controller.dart';
import 'package:chess_srs/src/model/user/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

export 'chat_message.dart';

part 'chat.freezed.dart';

@immutable
sealed class ChatOptions {
  const ChatOptions();

  StringId get id;
  LightUser? get opponent;
  bool get isPublic;
  bool get writeable;

  @override
  String toString() =>
      'ChatOptions(id: $id, opponent: $opponent, isPublic: $isPublic, writeable: $writeable)';
}

@freezed
abstract class StudyChatOptions extends ChatOptions with _$StudyChatOptions {
  const StudyChatOptions._();
  const factory StudyChatOptions({required StudyOptions options, required bool writeable}) =
      _StudyChatOptions;

  @override
  LightUser? get opponent => null;

  @override
  bool get isPublic => true;

  @override
  StringId get id => options.id;
}
