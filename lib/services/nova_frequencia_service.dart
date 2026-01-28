import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import '../utils/http_helper.dart';
import '../models/aluno.dart';
import '../database/database_helper.dart';

class NovaFrequenciaService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[NovaFrequencia] $message');
    }
  }

  Future<List<Aluno>> getAlunosPorAula({
    required String professorId,
    required String turmaId,
    required String disciplinaId,
    required DateTime data,
    required int aulaNumero,
  }) async {
    _log('Buscando alunos para turma $turmaId, disciplina $disciplinaId');

    final conectividade = await Connectivity().checkConnectivity();
    final isConnected = conectividade != ConnectivityResult.none;

    _log('Status da conexão: ${isConnected ? 'ONLINE' : 'OFFLINE'}');

    try {
      if (isConnected) {
        _log('Buscando dados ONLINE...');
        final dataFormatada = '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

        final response = await HttpHelper.post(
          '/get_alunos.php',
          {
            'professorId': int.parse(professorId),
            'turma': int.parse(turmaId),
            'disciplina': int.parse(disciplinaId),
            'data': dataFormatada,
            'aulaNumero': aulaNumero,
          },
        );

        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          final alunosData = responseData['alunos'] as List;

          if (kDebugMode) {
            _log('Recebidos ${alunosData.length} alunos do servidor');
          }

          // Salvar dados para uso offline
          await _databaseHelper.saveAlunos(
            alunosData.map((a) => Map<String, dynamic>.from(a)).toList(),
            int.parse(turmaId),
            int.parse(professorId),
          );

          _log('Salvos ${alunosData.length} alunos para uso offline');
          return alunosData.map((alunoJson) => Aluno.fromMap(alunoJson)).toList();
        } else {
          throw Exception(responseData['message'] ?? 'Erro ao carregar alunos');
        }
      } else {
        // OFFLINE: Buscar dados offline
        _log('Buscando dados OFFLINE...');
        final alunosOffline = await _databaseHelper.getAlunosCached(
          int.parse(turmaId),
          int.parse(disciplinaId),
          data,
          aulaNumero,
        );

        if (alunosOffline.isNotEmpty) {
          _log('Encontrados ${alunosOffline.length} alunos offline');
          return alunosOffline.map((alunoJson) => Aluno.fromMap(alunoJson)).toList();
        } else {
          throw Exception('Sem dados offline disponíveis para esta aula');
        }
      }
    } catch (e) {
      // FALLBACK: Se online falhar, tentar offline
      if (isConnected) {
        _log('Erro online, tentando dados offline como fallback...');
        try {
          final alunosOffline = await _databaseHelper.getAlunosCached(
            int.parse(turmaId),
            int.parse(disciplinaId),
            data,
            aulaNumero,
          );

          if (alunosOffline.isNotEmpty) {
            _log('Usando dados offline como fallback (${alunosOffline.length} alunos)');
            return alunosOffline.map((alunoJson) => Aluno.fromMap(alunoJson)).toList();
          }
        } catch (offlineError) {
          _log('Erro ao buscar dados offline: $offlineError');
        }
      }

      throw Exception('Erro ao buscar alunos: $e');
    }
  }

  Future<bool> salvarFrequencia({
    required String professorId,
    required String turmaId,
    required String disciplinaId,
    required DateTime data,
    required int aulaNumero,
    required List<Map<String, dynamic>> presencas,
  }) async {
    _log('Salvando frequência - Professor: $professorId, Turma: $turmaId');

    final conectividade = await Connectivity().checkConnectivity();
    final isConnected = conectividade != ConnectivityResult.none;

    final dataFormatada = '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

    if (isConnected) {
      try {
        _log('Tentando salvar online...');
        final requestBody = {
          'professorId': int.parse(professorId),
          'turmaId': int.parse(turmaId),
          'disciplinaId': int.parse(disciplinaId),
          'aulaNumero': aulaNumero,
          'data': dataFormatada,
          'presencas': presencas,
        };

        final response = await HttpHelper.post(
          '/salvar_frequencia.php',
          requestBody,
          timeout: ApiConfig.defaultTimeout,
        );

        final body = response.body.trim();
        if (body.isEmpty) {
          _log('Resposta vazia do servidor ao salvar frequencia');
          throw Exception('Resposta vazia do servidor');
        }

        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(body) as Map<String, dynamic>;
        } catch (e) {
          _log('Resposta invalida ao salvar frequencia: $body');
          throw Exception('Resposta invalida do servidor');
        }

        if (responseData['status'] == 'success') {
          _log('Frequência salva online com sucesso');
          return true;
        } else {
          _log('Servidor retornou erro: ${responseData['message']}');
          throw Exception(responseData['message'] ?? 'Erro ao salvar frequência');
        }
      } catch (e) {
        _log('Erro ao salvar online: $e - salvando offline...');
        // Se falhar online, salvar offline
      }
    } else {
      _log('Sem conexão - salvando offline...');
    }

    // MODO OFFLINE - Salvar localmente
    try {
      await _databaseHelper.insertFrequenciaPendente(
        professorId: int.parse(professorId),
        turmaId: int.parse(turmaId),
        disciplinaId: int.parse(disciplinaId),
        data: dataFormatada,
        aulaNumero: aulaNumero,
        presencas: presencas,
      );
      // Atualiza também o espelho de faltas locais para refletir na UI offline
      final ausentes = presencas
          .where((p) => !(p['presente'] == true || (p['presente'] is String && (p['presente'].toString().toLowerCase() == 'true' || p['presente'].toString() == '1'))))
          .map<int>((p) => (p['aluno_id'] as int))
          .toList();

      await _databaseHelper.clearFaltasLocal(int.parse(disciplinaId), aulaNumero, dataFormatada);
      await _databaseHelper.saveFaltasLocal(
        matriculasAusentes: ausentes,
        disciplinaId: int.parse(disciplinaId),
        aulaNumero: aulaNumero,
        data: dataFormatada,
      );

      _log('Frequência salva offline - será enviada quando conectar');
      return true;
    } catch (e) {
      _log('Erro ao salvar offline: $e');
      throw Exception('Erro ao salvar frequência offline: $e');
    }
  }
}
