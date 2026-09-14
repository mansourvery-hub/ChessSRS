import 'package:chess_srs/src/model/user/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';
part 'auth_user.g.dart';

@Freezed(fromJson: true, toJson: true)
sealed class AuthUser with _$AuthUser {
  const factory AuthUser({required LightUser user, required String token}) = _AuthUser;

  factory AuthUser.fromJson(Map<String, dynamic> json) => _$AuthUserFromJson(json);
}
