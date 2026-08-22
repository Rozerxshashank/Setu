import '../models/user_model.dart';

abstract class UserRepository {
  Future<UserModel?> getUser(String userId);
  Stream<UserModel?> watchUser(String userId);
  Future<void> createUser(UserModel user);
  Future<void> updateUser(UserModel user);
}

class MockUserRepository implements UserRepository {
  final Map<String, UserModel> _users = {};

  @override
  Future<UserModel?> getUser(String userId) async {
    await Future.delayed(const Duration(seconds: 1));
    return _users[userId];
  }

  @override
  Stream<UserModel?> watchUser(String userId) async* {
    yield _users[userId];
  }

  @override
  Future<void> createUser(UserModel user) async {
    await Future.delayed(const Duration(seconds: 1));
    _users[user.userId] = user;
  }

  @override
  Future<void> updateUser(UserModel user) async {
    await Future.delayed(const Duration(seconds: 1));
    _users[user.userId] = user;
  }
}
