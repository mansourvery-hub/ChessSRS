import 'package:chess_srs/src/model/auth/auth_controller.dart';
import 'package:chess_srs/src/model/common/id.dart';
import 'package:chess_srs/src/model/user/user.dart';

const fakeAuthUser = AuthUser(
  token: 'testToken',
  user: LightUser(id: UserId('testuser'), name: 'testUser'),
);
