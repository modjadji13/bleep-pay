import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_provider.dart';

// Change this to your backend URL
const String baseUrl = 'http://172.20.10.2:8080';

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authProvider);
  return ApiClient(token: auth.token);
});

class ApiClient {
  late final Dio _dio;

  ApiClient({String? token}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // Attach JWT to every request automatically
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  // -- Auth --

  Future<Map<String, dynamic>> register(String phone, String password) async {
    final res = await _dio.post('/auth/register', data: {
      'phone': phone,
      'password': password,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'phone': phone,
      'password': password,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  // -- Payments --

  Future<Map<String, dynamic>> requestPayment(String toUserId, int amountCents) async {
    final res = await _dio.post('/payments/request', data: {
      'to_user_id': toUserId,
      'amount_cents': amountCents,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> acceptPayment(String paymentId) async {
    await _dio.post('/payments/accept', data: {'payment_id': paymentId});
  }

  Future<void> declinePayment(String paymentId) async {
    await _dio.post('/payments/decline', data: {'payment_id': paymentId});
  }
}
