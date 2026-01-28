import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class HttpHelper {
  /// Faz POST com timeout e retry automático com backoff exponencial.
  ///
  /// [endpoint] caminho relativo ao baseUrl (ex: '/get_escolas.php')
  /// [body] corpo da requisição (será convertido para JSON)
  /// [timeout] timeout da requisição (padrão: ApiConfig.defaultTimeout)
  /// [retries] número de tentativas (padrão: ApiConfig.maxRetries)
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    Duration? timeout,
    int? retries,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final maxAttempts = retries ?? ApiConfig.maxRetries;
    final requestTimeout = timeout ?? ApiConfig.defaultTimeout;

    Exception? lastException;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(requestTimeout);

        if (response.statusCode >= 500 && attempt < maxAttempts) {
          // Erro de servidor: retry com backoff
          _log('Erro ${response.statusCode} no servidor (tentativa $attempt/$maxAttempts), retentando...');
          await _backoff(attempt);
          continue;
        }

        return response;
      } on TimeoutException {
        lastException = TimeoutException(
          'Timeout ao acessar $endpoint (tentativa $attempt/$maxAttempts)',
        );
        _log('Timeout em $endpoint (tentativa $attempt/$maxAttempts)');
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        _log('Erro em $endpoint (tentativa $attempt/$maxAttempts): $e');
      }

      if (attempt < maxAttempts) {
        await _backoff(attempt);
      }
    }

    throw lastException ?? Exception('Falha após $maxAttempts tentativas em $endpoint');
  }

  /// Backoff exponencial: 1s, 2s, 4s...
  static Future<void> _backoff(int attempt) async {
    final delay = Duration(seconds: 1 << (attempt - 1)); // 1, 2, 4...
    await Future.delayed(delay);
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[HttpHelper] $message');
    }
  }
}
