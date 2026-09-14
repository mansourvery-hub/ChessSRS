import 'package:chess_srs/src/model/auth/auth_controller.dart';
import 'package:chess_srs/src/model/user/user.dart';
import 'package:chess_srs/src/utils/navigation.dart';
import 'package:chess_srs/src/view/account/profile_screen.dart';
import 'package:chess_srs/src/view/user/user_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class UserOrProfileScreen extends ConsumerWidget {
  const UserOrProfileScreen({required this.user, super.key});
  final LightUser user;

  static Route<dynamic> buildRoute(LightUser user) {
    return buildScreenRoute(screen: UserOrProfileScreen(user: user));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authControllerProvider);
    return authUser != null && authUser.user.id == user.id
        ? const ProfileScreen()
        : UserScreen(user: user);
  }
}
