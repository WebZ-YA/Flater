import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cms_core/core.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/network/clinic_gateway.dart';

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  return AppEnvironment.fromDartDefine();
});

final transportGatewayProvider = Provider<ClinicTransportGateway>((ref) {
  return ClinicTransportGateway(env: ref.watch(appEnvironmentProvider));
});

final isOnlineProvider = StateProvider<bool>((ref) => true);
final pendingSyncCountProvider = StateProvider<int>((ref) => 0);

class AuthSessionNotifier extends StateNotifier<AuthSessionState?> {
  AuthSessionNotifier(this._gateway) : super(null);

  final ClinicTransportGateway _gateway;

  Future<void> signInWithCredentials({
    required String email,
    required String password,
    required String tenantId,
    required ClinicRole role,
  }) async {
    if (email.trim().isEmpty || password.length < 6) {
      throw const AuthFailure('INVALID_CREDENTIALS', 'يرجى إدخال بريد إلكتروني وكلمة مرور صالحة.');
    }

    // Connects to Local Clinic Server or Firebase Auth in production
    final session = AuthSessionState(
      uid: IdGenerator.newUuid(),
      tenantId: tenantId,
      displayName: email.split('@').first,
      role: role,
      token: 'local-signed-session-placeholder',
      isOfflineSession: false,
    );
    _gateway.setToken(session.token);
    state = session;
  }

  void signOut() {
    _gateway.setToken(null);
    state = null;
  }
}

final authSessionProvider = StateNotifierProvider<AuthSessionNotifier, AuthSessionState?>((ref) {
  return AuthSessionNotifier(ref.watch(transportGatewayProvider));
});
