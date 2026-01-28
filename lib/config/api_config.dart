class ApiConfig {
  static const String baseUrl = 'https://smecel.com.br/api/professor';
  static const Duration defaultTimeout = Duration(seconds: 15);
  static const Duration longTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
}
