enum AppFlavor { development, staging, production }

enum TransportMode { localLanServer, firebaseCloud }

class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.localServerBaseUrl,
    required this.localWsUrl,
    required this.cloudFunctionsBaseUrl,
    required this.defaultLocaleCode,
  });

  final AppFlavor flavor;
  final String localServerBaseUrl;
  final String localWsUrl;
  final String cloudFunctionsBaseUrl;
  final String defaultLocaleCode;

  static AppEnvironment fromDartDefine() {
    const envName = String.fromEnvironment('CMS_ENV', defaultValue: 'development');
    const localUrl = String.fromEnvironment('CMS_LOCAL_URL', defaultValue: 'http://127.0.0.1:8085');
    const wsUrl = String.fromEnvironment('CMS_LOCAL_WS', defaultValue: 'ws://127.0.0.1:8085/ws/lan');
    const cloudUrl = String.fromEnvironment('CMS_CLOUD_URL', defaultValue: 'https://europe-west1-cms-clinic.cloudfunctions.net');

    final flavor = switch (envName) {
      'production' => AppFlavor.production,
      'staging' => AppFlavor.staging,
      _ => AppFlavor.development,
    };

    return AppEnvironment(
      flavor: flavor,
      localServerBaseUrl: localUrl,
      localWsUrl: wsUrl,
      cloudFunctionsBaseUrl: cloudUrl,
      defaultLocaleCode: 'ar',
    );
  }
}
