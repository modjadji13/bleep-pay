import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthState {
  final String? token;
  final String? userId;

  const AuthState({this.token, this.userId});

  AuthState copyWith({String? token, String? userId}) {
    return AuthState(
      token: token ?? this.token,
      userId: userId ?? this.userId,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _storage = const FlutterSecureStorage();

  AuthNotifier() : super(const AuthState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final token = await _storage.read(key: 'token');
    final userId = await _storage.read(key: 'user_id');
    if (token != null && userId != null) {
      state = AuthState(token: token, userId: userId);
    }
  }

  Future<void> login(String token, String userId) async {
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'user_id', value: userId);
    state = AuthState(token: token, userId: userId);
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
