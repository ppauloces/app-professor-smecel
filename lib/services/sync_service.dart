import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';

class SyncService {
  final DatabaseHelper _db = DatabaseHelper();
  static const String _baseUrl = 'https://api.escola.com'; // URL simulada

  Timer? _syncTimer;
  bool _isSyncing = false;

  void startAutoSync() {
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) => syncPendingData(),
    );
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<Map<String, dynamic>> syncPendingData() async {
    if (_isSyncing) {
      return {'success': false, 'message': 'Sincronização já em andamento'};
    }

    if (!await isConnected()) {
      return {'success': false, 'message': 'Sem conexão com a internet'};
    }

    _isSyncing = true;

    try {
      final registrosPendentes = await _db.getRegistrosPendentes();

      if (registrosPendentes.isEmpty) {
        return {'success': true, 'message': 'Nenhum registro pendente'};
      }

      int sincronizados = 0;
      List<String> erros = [];

      for (final registro in registrosPendentes) {
        try {
          await _syncRegistro(registro);
          sincronizados++;
        } catch (e) {
          erros.add('Erro ao sincronizar ${registro['tipo']}: $e');
        }
      }

      return {
        'success': erros.isEmpty,
        'message': erros.isEmpty
            ? 'Sincronizados $sincronizados registros'
            : 'Sincronizados $sincronizados registros com ${erros.length} erros',
        'detalhes': {
          'sincronizados': sincronizados,
          'erros': erros,
          'total': registrosPendentes.length,
        }
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro durante sincronização: $e'};
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncRegistro(Map<String, dynamic> registro) async {
    final tipo = registro['tipo'];
    final dados = registro['dados'];

    await Future.delayed(const Duration(milliseconds: 500));

    switch (tipo) {
      case 'turma':
        await _syncTurma(dados);
        break;
      case 'aluno':
        await _syncAluno(dados);
        break;
      case 'aula':
        await _syncAula(dados);
        break;
      case 'frequencia':
        await _syncFrequencia(dados);
        break;
    }
  }

  Future<void> _syncTurma(Map<String, dynamic> turma) async {
    await _simulateApiCall('POST', '/turmas', turma);
    await _db.marcarComoSincronizado('turmas', turma['id']);
  }

  Future<void> _syncAluno(Map<String, dynamic> aluno) async {
    await _simulateApiCall('POST', '/alunos', aluno);
    await _db.marcarComoSincronizado('alunos', aluno['id']);
  }

  Future<void> _syncAula(Map<String, dynamic> aula) async {
    await _simulateApiCall('POST', '/aulas', aula);
    await _db.marcarComoSincronizado('aulas', aula['id']);
  }

  Future<void> _syncFrequencia(Map<String, dynamic> frequencia) async {
    await _simulateApiCall('POST', '/frequencias', frequencia);
    await _db.marcarComoSincronizado('frequencias', frequencia['id']);
  }

  Future<http.Response> _simulateApiCall(
      String method, String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl$endpoint');

    await Future.delayed(Duration(milliseconds: 200 + (data.length * 10)));

    return http.Response(
      jsonEncode({'success': true, 'id': data['id']}),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  void dispose() {
    stopAutoSync();
  }
}
