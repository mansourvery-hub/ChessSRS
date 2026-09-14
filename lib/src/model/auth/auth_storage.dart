import 'dart:convert';

import 'package:chess_srs/src/constants.dart';
import 'package:chess_srs/src/db/secure_storage.dart';
import 'package:chess_srs/src/model/auth/auth_user.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const kAuthStorageKey = '$kLichessHost.userSession';

/// A provider for [AuthStorage].
final authStorageProvider = Provider<AuthStorage>((Ref ref) {
  return const AuthStorage();
}, name: 'AuthStorageProvider');

class AuthStorage {
  const AuthStorage();

  /// Whether secure storage is usable on this platform.
  ///
  /// Can be false on Linux desktop sessions without a keyring service
  /// (libsecret), in which case auth persistence is simply unavailable and
  /// read returns null instead of throwing.
  static bool get isAvailable => _isAvailable;
  static bool _isAvailable = true;

  Future<AuthUser?> read() async {
    try {
      final string = await SecureStorage.instance.read(key: kAuthStorageKey);
      if (string != null) {
        return AuthUser.fromJson(jsonDecode(string) as Map<String, dynamic>);
      }
      return null;
    } on PlatformException catch (_) {
      _isAvailable = false;
      return null;
    }
  }

  Future<void> write(AuthUser authUser) async {
    try {
      await SecureStorage.instance.write(
        key: kAuthStorageKey,
        value: jsonEncode(authUser.toJson()),
      );
    } on PlatformException catch (_) {
      _isAvailable = false;
    }
  }

  Future<void> delete() async {
    try {
      await SecureStorage.instance.delete(key: kAuthStorageKey);
    } on PlatformException catch (_) {
      _isAvailable = false;
    }
  }
}
