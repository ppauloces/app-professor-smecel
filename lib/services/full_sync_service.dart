import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import '../utils/http_helper.dart';
import '../database/database_helper.dart';

class FullSyncService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<bool> _isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[FullSync] $message');
    }
  }

  /// Sincronização completa no login - baixa dados do professor.
  /// Quando [syncAlunos] = true, também baixa os alunos de cada turma.
  Future<Map<String, dynamic>> syncAllData(
    String professorCodigo, {
    bool syncAlunos = false,
  }) async {
    final startTime = DateTime.now();

    if (!await _isConnected()) {
      return {
        'success': false,
        'message': 'Sem conexão com a internet para sincronização inicial'
      };
    }

    try {
      final professorId = int.tryParse(professorCodigo) ?? 0;
      _log('Iniciando sincronização completa para professor $professorCodigo');

      // 1. Baixar todas as escolas
      _log('Sincronizando escolas...');
      final escolas = await _syncEscolas(professorCodigo, professorId);
      _log('Encontradas ${escolas.length} escolas');

      int totalTurmas = 0;
      int totalHorarios = 0;

      // 2. Para cada escola, baixar turmas e horários
      for (final escola in escolas) {
        final escolaIdRaw = escola['escola_id'];
        final escolaId = escolaIdRaw is int ? escolaIdRaw : int.tryParse(escolaIdRaw.toString()) ?? 0;

        _log('Sincronizando turmas da escola: ${escola['escola_nome']} (ID: $escolaId)');

        try {
          final turmas = await _syncTurmas(professorCodigo, escolaId.toString(), escolaId, professorId);
          totalTurmas += turmas.length;
          _log('Encontradas ${turmas.length} turmas na escola ${escola['escola_nome']}');

          // 3. Para cada turma, baixar grade completa de horários
          for (final turma in turmas) {
            final turmaIdRaw = turma['turma_id'];
            final turmaId = turmaIdRaw is int ? turmaIdRaw : int.tryParse(turmaIdRaw.toString()) ?? 0;

            _log('Sincronizando horários da turma: ${turma['turma_nome']} (ID: $turmaId)');

            try {
              final horarios = await _syncHorarios(professorId, escolaId, turmaId);
              totalHorarios += horarios.length;
              _log('Encontrados ${horarios.length} horários para turma ${turma['turma_nome']}');

              if (syncAlunos) {
                // 4. Para cada disciplina da turma, baixar alunos
                final disciplinasUnicas = <int>{};
                for (final horario in horarios) {
                  final disciplinaIdRaw = horario['ch_lotacao_disciplina_id'];
                  final disciplinaId = disciplinaIdRaw is int ? disciplinaIdRaw : int.tryParse(disciplinaIdRaw.toString()) ?? 0;
                  if (disciplinaId > 0) {
                    disciplinasUnicas.add(disciplinaId);
                  }
                }

                for (final disciplinaId in disciplinasUnicas) {
                  try {
                    _log('Sincronizando alunos da turma ${turma['turma_nome']} - disciplina $disciplinaId');
                    final alunos = await _syncAlunos(professorId, turmaId, disciplinaId);
                    if (alunos.isNotEmpty) {
                      _log('Encontrados ${alunos.length} alunos para disciplina $disciplinaId');

                      final alunosCached = await _db.getAlunosCached(turmaId, disciplinaId, DateTime.now(), 1);
                      if (alunosCached.isNotEmpty) {
                        _log('Alunos salvos com sucesso no banco local');
                        break;
                      } else {
                        _log('Nenhum aluno foi salvo, tentando próxima disciplina...');
                      }
                    }
                  } catch (e) {
                    _log('Erro ao sincronizar alunos da disciplina $disciplinaId: $e');
                  }
                }
              }

            } catch (e) {
              _log('Erro ao sincronizar horários da turma ${turma['turma_nome']}: $e');
            }
          }
        } catch (e) {
          _log('Erro ao sincronizar turmas da escola ${escola['escola_nome']}: $e');
        }
      }

      final duration = DateTime.now().difference(startTime);
      _log('Sincronização completa finalizada em ${duration.inSeconds}s');
      _log('Total sincronizado: ${escolas.length} escolas, $totalTurmas turmas, $totalHorarios horários');

      return {
        'success': true,
        'message': 'Sincronização completa realizada',
        'details': {
          'escolas': escolas.length,
          'turmas': totalTurmas,
          'horarios': totalHorarios,
          'duration': duration.inSeconds,
        }
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Erro na sincronização: $e'
      };
    }
  }

  /// Baixa e salva todas as escolas do professor
  Future<List<Map<String, dynamic>>> _syncEscolas(String professorCodigo, int professorId) async {
    final response = await HttpHelper.post(
      '/get_escolas.php',
      {'codigo': professorCodigo},
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Resposta inesperada do servidor.');
    }

    if (decoded['status'] != 'success') {
      throw Exception(decoded['message'] ?? 'Erro ao carregar escolas');
    }

    final raw = decoded['escolas'];
    final List<dynamic> list = raw is List
        ? raw
        : raw is Map
            ? (raw as Map).values.toList()
            : <dynamic>[];

    final escolas = list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    await _db.saveEscolas(escolas, professorId);

    return escolas;
  }

  /// Baixa e salva todas as turmas de uma escola
  Future<List<Map<String, dynamic>>> _syncTurmas(String professorCodigo, String escolaId, int escolaIdInt, int professorId) async {
    final response = await HttpHelper.post(
      '/get_turmas.php',
      {
        'codigo': professorCodigo,
        'escola': escolaId,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Resposta inesperada do servidor.');
    }

    if (decoded['status'] != 'success') {
      throw Exception(decoded['message'] ?? 'Erro ao carregar turmas da escola $escolaId');
    }

    final raw = decoded['turmas'];
    final List<dynamic> list = raw is List
        ? raw
        : raw is Map
            ? (raw as Map).values.toList()
            : <dynamic>[];

    final turmas = list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    await _db.saveTurmas(turmas, escolaIdInt, professorId);

    return turmas;
  }

  /// Baixa e salva TODOS os horários de uma turma (grade completa da semana)
  Future<List<Map<String, dynamic>>> _syncHorarios(int professorId, int escolaId, int turmaId) async {
    List<Map<String, dynamic>> todosHorarios = [];

    // Baixar horários para cada dia da semana (1=Segunda, 2=Terça, ..., 6=Sábado)
    for (int diaSemana = 1; diaSemana <= 6; diaSemana++) {
      try {
        DateTime dataFicticia = _getDateForWeekday(diaSemana);
        final dataFormatada = '${dataFicticia.year}-${dataFicticia.month.toString().padLeft(2, '0')}-${dataFicticia.day.toString().padLeft(2, '0')}';

        final response = await HttpHelper.post(
          '/get_horarios.php',
          {
            'professorId': professorId,
            'escolaId': escolaId,
            'turmaId': turmaId,
            'data': dataFormatada,
          },
        );

        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          final horariosRaw = responseData['horarios'] as List;
          final horariosData = horariosRaw
              .map((h) => Map<String, dynamic>.from(h as Map))
              .toList();
          todosHorarios.addAll(horariosData);
          _log('Dia $diaSemana: encontrados ${horariosData.length} horários');
        } else {
          _log('Dia $diaSemana: ${responseData['message'] ?? 'nenhum horário encontrado'}');
        }
      } catch (e) {
        _log('Erro ao buscar horários do dia $diaSemana: $e');
      }
    }

    if (todosHorarios.isNotEmpty) {
      await _db.saveHorarios(todosHorarios, turmaId, escolaId, professorId);
    }

    return todosHorarios;
  }

  /// Gera uma data fictícia para um dia da semana específico
  DateTime _getDateForWeekday(int weekday) {
    DateTime now = DateTime.now();
    int daysUntilWeekday = weekday - now.weekday;
    if (daysUntilWeekday <= 0) daysUntilWeekday += 7;
    return now.add(Duration(days: daysUntilWeekday));
  }

  /// Baixa e salva todos os alunos de uma turma
  Future<List<Map<String, dynamic>>> _syncAlunos(int professorId, int turmaId, int disciplinaId) async {
    try {
      _log('Buscando alunos: Professor $professorId, Turma $turmaId, Disciplina $disciplinaId');

      final hoje = DateTime.now();
      final dataFormatada = '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

      final response = await HttpHelper.post(
        '/get_alunos.php',
        {
          'professorId': professorId,
          'turma': turmaId,
          'disciplina': disciplinaId,
          'data': dataFormatada,
          'aulaNumero': 1,
        },
        timeout: ApiConfig.defaultTimeout,
      );

      if (response.statusCode != 200) {
        _log('HTTP erro ${response.statusCode}: ${response.reasonPhrase}');
        return [];
      }

      final responseData = jsonDecode(response.body);
      _log('Resposta do servidor: ${responseData['status']}');

      if (responseData['status'] == 'success') {
        final alunosData = responseData['alunos'] as List;
        final alunos = alunosData.map((a) => Map<String, dynamic>.from(a as Map)).toList();

        _log('Encontrados ${alunos.length} alunos para sincronizar');

        if (kDebugMode && alunos.isNotEmpty) {
          _log('Amostra dos dados recebidos:');
          for (int i = 0; i < alunos.length && i < 3; i++) {
            final aluno = alunos[i];
            _log('  Aluno $i: aluno_id=${aluno['aluno_id']}, nome="${aluno['aluno_nome']}", falta=${aluno['falta']}');
          }
        }

        await _db.saveAlunos(alunos, turmaId, professorId);

        return alunos;
      } else {
        _log('Servidor retornou erro: ${responseData['message'] ?? 'Erro desconhecido'}');
        return [];
      }
    } catch (e) {
      _log('Erro ao sincronizar alunos da turma $turmaId, disciplina $disciplinaId: $e');
      return [];
    }
  }

  /// Verifica se o professor tem dados salvos localmente
  Future<bool> hasLocalData(int professorId) async {
    try {
      final escolas = await _db.getEscolasCached(professorId);
      return escolas.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Sincronização incremental - apenas upload de pendências e download de mudanças
  Future<Map<String, dynamic>> syncIncremental(String professorCodigo) async {
    if (!await _isConnected()) {
      return {
        'success': false,
        'message': 'Sem conexão para sincronização incremental'
      };
    }

    try {
      _log('syncIncremental: INICIANDO para professor $professorCodigo');

      final uploadResult = await _uploadPendingData();

      _log('Sincronização incremental concluída');

      return {
        'success': true,
        'message': 'Sincronização incremental realizada',
        'details': uploadResult,
      };

    } catch (e) {
      _log('Erro na sincronização incremental: $e');
      return {
        'success': false,
        'message': 'Erro na sincronização incremental: $e'
      };
    }
  }

  /// Upload de dados pendentes (frequências offline)
  Future<Map<String, dynamic>> _uploadPendingData() async {
    try {
      _log('Upload de dados pendentes iniciado');
      int uploaded = 0;
      int errors = 0;
      List<String> errorMessages = [];

      final frequenciasPendentes = await _db.getFrequenciasPendentes();
      _log('Encontradas ${frequenciasPendentes.length} frequências pendentes para envio');

      for (final freq in frequenciasPendentes) {
        try {
          final success = await _uploadFrequencia(freq);
          if (success) {
            await _db.removerFrequenciaPendente(freq['id']);
            uploaded++;
            _log('Frequência ${freq['id']} enviada e removida da fila');
          } else {
            errors++;
            errorMessages.add('Falha no upload da frequência ${freq['id']}');
          }
        } catch (e) {
          errors++;
          final errorMsg = 'Erro ao enviar frequência ${freq['id']}: $e';
          errorMessages.add(errorMsg);
          _log(errorMsg);
        }
      }

      final registrosPendentes = await _db.getRegistrosPendentes();
      _log('Enviando ${registrosPendentes.length} outros registros pendentes...');

      for (final registro in registrosPendentes) {
        try {
          await _uploadRecord(registro);
          uploaded++;
          _log('Registro ${registro['tipo']} enviado');
        } catch (e) {
          errors++;
          final errorMsg = 'Erro ao enviar ${registro['tipo']}: $e';
          errorMessages.add(errorMsg);
          _log(errorMsg);
        }
      }

      _log('Upload concluído: $uploaded enviados, $errors erros');

      return {
        'uploaded': uploaded,
        'errors': errors,
        'errorMessages': errorMessages,
        'frequencias': frequenciasPendentes.length,
      };

    } catch (e) {
      _log('Erro no upload de pendências: $e');
      return {
        'uploaded': 0,
        'errors': 1,
        'errorMessages': ['Erro geral no upload: $e'],
      };
    }
  }

  /// Upload de um registro específico
  Future<void> _uploadRecord(Map<String, dynamic> record) async {
    final tipo = record['tipo'];
    final dados = record['dados'];

    switch (tipo) {
      case 'frequencia':
        final success = await _uploadFrequencia(dados);
        if (!success) {
          throw Exception('Falha no upload de frequência');
        }
        break;
      case 'aula':
        await _uploadAula(dados);
        break;
      default:
        _log('Tipo de registro não suportado: $tipo');
    }
  }

  /// Upload específico de aula
  Future<void> _uploadAula(Map<String, dynamic> aula) async {
    // TODO: Implementar endpoint para upload de aula
    await Future.delayed(Duration(milliseconds: 100));
    await _db.marcarComoSincronizado('aulas', aula['id']);
  }

  /// Upload de frequência pendente para o servidor
  Future<bool> _uploadFrequencia(Map<String, dynamic> freq) async {
    try {
      final presencas = jsonDecode(freq['presencas']) as List;

      _log('Enviando frequência: Turma ${freq['turma_id']}, Data ${freq['data']}');

      final response = await HttpHelper.post(
        '/salvar_frequencia.php',
        {
          'professorId': freq['professor_id'],
          'turmaId': freq['turma_id'],
          'disciplinaId': freq['disciplina_id'],
          'aulaNumero': freq['aula_numero'],
          'data': freq['data'],
          'presencas': presencas,
        },
        timeout: ApiConfig.longTimeout,
      );

      final responseData = jsonDecode(response.body);

      if (responseData['status'] == 'success') {
        _log('Frequência enviada com sucesso');
        return true;
      } else {
        _log('Servidor rejeitou frequência: ${responseData['message']}');
        return false;
      }
    } catch (e) {
      _log('Erro no upload de frequência: $e');
      return false;
    }
  }

  /// Limpa cache do professor (para re-sincronização)
  Future<void> clearCache(int professorId) async {
    _log('Limpando cache do professor $professorId');
    final db = await _db.database;
    await db.delete('horarios', where: 'professor_id = ?', whereArgs: [professorId]);
    await db.delete('turmas', where: 'professor_id = ?', whereArgs: [professorId]);
    await db.delete('escolas', where: 'professor_id = ?', whereArgs: [professorId]);
    _log('Cache limpo');
  }
}
