import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cms_core/core.dart';
import '../config/app_environment.dart';

class AuthSessionState {
  const AuthSessionState({
    required this.uid,
    required this.tenantId,
    required this.displayName,
    required this.role,
    required this.token,
    this.isOfflineSession = false,
  });

  final String uid;
  final String tenantId;
  final String displayName;
  final ClinicRole role;
  final String token;
  final bool isOfflineSession;

  bool can(ClinicPermission permission) {
    return RbacPolicyEngine.hasPermission(role: role, permission: permission);
  }
}

/// Abstracts Local Clinic Server LAN API vs Cloud Functions Gateway.
class ClinicTransportGateway {
  ClinicTransportGateway({
    required this.env,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final AppEnvironment env;
  final http.Client _client;
  String? _bearerToken;

  void setToken(String? token) {
    _bearerToken = token;
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final uri = Uri.parse('${env.localServerBaseUrl}$path');
    final res = await _client.get(uri, headers: _headers()).timeout(const Duration(seconds: 10));
    return _decodeResponse(res);
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${env.localServerBaseUrl}$path');
    final res = await _client
        .post(uri, headers: _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    return _decodeResponse(res);
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json; charset=utf-8',
        if (_bearerToken != null) 'Authorization': 'Bearer $_bearerToken',
      };

  Map<String, dynamic> _decodeResponse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    throw Exception(body['error'] ?? 'HTTP_${res.statusCode}');
  }
}
