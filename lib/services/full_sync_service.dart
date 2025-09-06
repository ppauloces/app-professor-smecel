import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';

class FullSyncService {
  static const String _baseUrl = 'https://smecel.com.br/api/professor';
  final DatabaseHelper _db = DatabaseHelper();

  Future<bool> _isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Sincronização completa no login - baixa todos os dados do professor
  Future<Map<String, dynamic>> syncAllData(String professorCodigo) async {
    print('🚀🚀🚀 syncAllData CHAMADO - StackTrace: ${StackTrace.current}');
    final startTime = DateTime.now();
    
    if (!await _isConnected()) {
      return {
        'success': false, 
        'message': 'Sem conexão com a internet para sincronização inicial'
      };
    }

    try {
      final professorId = int.tryParse(professorCodigo) ?? 0;
      print('🚀 Iniciando sincronização completa para professor $professorCodigo');
      
      // 1. Baixar todas as escolas
      print('🏫 Sincronizando escolas...');
      final escolas = await _syncEscolas(professorCodigo, professorId);
      print('✅ Encontradas ${escolas.length} escolas');
      
      int totalTurmas = 0;
      int totalHorarios = 0;
      
      // 2. Para cada escola, baixar turmas e horários
      for (final escola in escolas) {
        // Converter escolaId para int de forma segura
        final escolaIdRaw = escola['escola_id'];
        final escolaId = escolaIdRaw is int ? escolaIdRaw : int.tryParse(escolaIdRaw.toString()) ?? 0;
        
        print('🎓 Sincronizando turmas da escola: ${escola['escola_nome']} (ID: $escolaId)');
        
        try {
          final turmas = await _syncTurmas(professorCodigo, escolaId.toString(), escolaId, professorId);
          totalTurmas += turmas.length;
          print('✅ Encontradas ${turmas.length} turmas na escola ${escola['escola_nome']}');
          
          // 3. Para cada turma, baixar grade completa de horários e alunos
          for (final turma in turmas) {
            // Converter turmaId para int de forma segura
            final turmaIdRaw = turma['turma_id'];
            final turmaId = turmaIdRaw is int ? turmaIdRaw : int.tryParse(turmaIdRaw.toString()) ?? 0;
            
            print('📅 Sincronizando horários da turma: ${turma['turma_nome']} (ID: $turmaId)');
            
            try {
              final horarios = await _syncHorarios(professorId, escolaId, turmaId);
              totalHorarios += horarios.length;
              print('✅ Encontrados ${horarios.length} horários para turma ${turma['turma_nome']}');
              
              // 4. Para cada disciplina da turma, baixar alunos
              final disciplinasUnicas = <int>{};
              for (final horario in horarios) {
                // Converter disciplinaId para int de forma segura
                final disciplinaIdRaw = horario['ch_lotacao_disciplina_id'];
                final disciplinaId = disciplinaIdRaw is int ? disciplinaIdRaw : int.tryParse(disciplinaIdRaw.toString()) ?? 0;
                if (disciplinaId > 0) {
                  disciplinasUnicas.add(disciplinaId);
                }
              }
              
              for (final disciplinaId in disciplinasUnicas) {
                try {
                  print('🎓 Sincronizando alunos da turma ${turma['turma_nome']} - disciplina $disciplinaId');
                  final alunos = await _syncAlunos(professorId, turmaId, disciplinaId);
                  if (alunos.isNotEmpty) {
                    print('✅ Encontrados ${alunos.length} alunos para disciplina $disciplinaId');
                    
                    // Verificar se foi possível salvar ao menos um aluno
                    final alunosCached = await _db.getAlunosCached(turmaId, disciplinaId, DateTime.now(), 1);
                    if (alunosCached.isNotEmpty) {
                      print('💾 Alunos salvos com sucesso no banco local');
                      break; // Se conseguiu salvar alunos, não precisa tentar outras disciplinas
                    } else {
                      print('⚠️ Nenhum aluno foi salvo, tentando próxima disciplina...');
                    }
                  }
                } catch (e) {
                  print('❌ Erro ao sincronizar alunos da disciplina $disciplinaId: $e');
                  // Continua para próxima disciplina
                }
              }
              
            } catch (e) {
              print('❌ Erro ao sincronizar horários da turma ${turma['turma_nome']}: $e');
              // Continua para próxima turma
            }
          }
        } catch (e) {
          print('❌ Erro ao sincronizar turmas da escola ${escola['escola_nome']}: $e');
          // Continua para próxima escola
        }
      }
      
      final duration = DateTime.now().difference(startTime);
      print('✅ Sincronização completa finalizada em ${duration.inSeconds}s');
      print('📊 Total sincronizado: ${escolas.length} escolas, $totalTurmas turmas, $totalHorarios horários');
      
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
    final response = await http.post(
      Uri.parse('$_baseUrl/get_escolas.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'codigo': professorCodigo}),
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
    // Aceita tanto List quanto Map (ex.: {"0": {...}, "1": {...}})
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
    final response = await http.post(
      Uri.parse('$_baseUrl/get_turmas.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'codigo': professorCodigo,
        'escola': escolaId,
      }),
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
        // Usar uma data fictícia para cada dia da semana para usar o endpoint existente
        DateTime dataFicticia = _getDateForWeekday(diaSemana);
        final dataFormatada = '${dataFicticia.year}-${dataFicticia.month.toString().padLeft(2, '0')}-${dataFicticia.day.toString().padLeft(2, '0')}';
        
        final response = await http.post(
          Uri.parse('$_baseUrl/get_horarios.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'professorId': professorId,
            'escolaId': escolaId,
            'turmaId': turmaId,
            'data': dataFormatada,
          }),
        );

        final responseData = jsonDecode(response.body);
        
        if (responseData['status'] == 'success') {
          final horariosRaw = responseData['horarios'] as List;
          final horariosData = horariosRaw
              .map((h) => Map<String, dynamic>.from(h as Map))
              .toList();
          todosHorarios.addAll(horariosData);
          print('📅 Dia $diaSemana: encontrados ${horariosData.length} horários');
        } else {
          print('📅 Dia $diaSemana: ${responseData['message'] ?? 'nenhum horário encontrado'}');
        }
        // Se não encontrar horários para um dia, continua para o próximo
      } catch (e) {
        // Se houver erro em um dia específico, continua para os outros
        print('Erro ao buscar horários do dia $diaSemana: $e');
      }
    }
    
    // Salvar todos os horários de uma vez
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
      print('📚 Tentando buscar alunos: Professor $professorId, Turma $turmaId, Disciplina $disciplinaId');
      
      // Usar data de hoje para buscar alunos
      final hoje = DateTime.now();
      final dataFormatada = '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';
      
      final response = await http.post(
        Uri.parse('$_baseUrl/get_alunos.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'professorId': professorId,
          'turma': turmaId,
          'disciplina': disciplinaId,
          'data': dataFormatada,
          'aulaNumero': 1, // Usar primeira aula como padrão
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('❌ HTTP erro ${response.statusCode}: ${response.reasonPhrase}');
        return [];
      }

      final responseData = jsonDecode(response.body);
      print('📄 Resposta do servidor: ${responseData['status']}');
      
      if (responseData['status'] == 'success') {
        final alunosData = responseData['alunos'] as List;
        final alunos = alunosData.map((a) => Map<String, dynamic>.from(a as Map)).toList();
        
        print('✅ Encontrados ${alunos.length} alunos para sincronizar');
        
        // Log dos primeiros alunos para debug
        if (alunos.isNotEmpty) {
          print('📝 Amostra dos dados recebidos:');
          for (int i = 0; i < alunos.length && i < 3; i++) {
            final aluno = alunos[i];
            print('   Aluno $i: aluno_id=${aluno['aluno_id']}, vinculo_aluno_id=${aluno['vinculo_aluno_id']}, aluno_nome="${aluno['aluno_nome']}", falta=${aluno['falta']}');
          }
        }
        
        // Salvar alunos no banco local
        await _db.saveAlunos(alunos, turmaId, professorId);
        
        return alunos;
      } else {
        print('❌ Servidor retornou erro: ${responseData['message'] ?? 'Erro desconhecido'}');
        return [];
      }
    } catch (e) {
      print('❌ Erro ao sincronizar alunos da turma $turmaId, disciplina $disciplinaId: $e');
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
      print('🔄 FullSyncService.syncIncremental: INICIANDO para professor $professorCodigo');
      
      // 1. Enviar dados pendentes
      final uploadResult = await _uploadPendingData();
      
      // 2. TODO: Verificar se há atualizações no servidor (opcional)
      // Por enquanto, apenas enviar dados pendentes
      
      print('✅ Sincronização incremental concluída');
      
      return {
        'success': true,
        'message': 'Sincronização incremental realizada',
        'details': uploadResult,
      };
      
    } catch (e) {
      print('❌ Erro na sincronização incremental: $e');
      return {
        'success': false,
        'message': 'Erro na sincronização incremental: $e'
      };
    }
  }

  /// Upload de dados pendentes (frequências offline)
  Future<Map<String, dynamic>> _uploadPendingData() async {
    try {
      print('📤 FullSyncService._uploadPendingData: INICIANDO upload de dados pendentes');
      int uploaded = 0;
      int errors = 0;
      List<String> errorMessages = [];
      
      // 1. Upload frequências pendentes primeiro (prioridade alta)
      final frequenciasPendentes = await _db.getFrequenciasPendentes();
      print('📤 Encontradas ${frequenciasPendentes.length} frequências pendentes para envio');
      
      for (final freq in frequenciasPendentes) {
        try {
          final success = await _uploadFrequencia(freq);
          if (success) {
            await _db.removerFrequenciaPendente(freq['id']);
            uploaded++;
            print('✅ Frequência ${freq['id']} enviada e removida da fila');
          } else {
            errors++;
            errorMessages.add('Falha no upload da frequência ${freq['id']}');
          }
        } catch (e) {
          errors++;
          final errorMsg = 'Erro ao enviar frequência ${freq['id']}: $e';
          errorMessages.add(errorMsg);
          print('❌ $errorMsg');
        }
      }
      
      // 2. Upload outros registros pendentes
      final registrosPendentes = await _db.getRegistrosPendentes();
      print('📤 Enviando ${registrosPendentes.length} outros registros pendentes...');
      
      for (final registro in registrosPendentes) {
        try {
          await _uploadRecord(registro);
          uploaded++;
          print('✅ Registro ${registro['tipo']} enviado');
        } catch (e) {
          errors++;
          final errorMsg = 'Erro ao enviar ${registro['tipo']}: $e';
          errorMessages.add(errorMsg);
          print('❌ $errorMsg');
        }
      }
      
      print('📊 Upload concluído: $uploaded enviados, $errors erros');
      
      return {
        'uploaded': uploaded,
        'errors': errors,
        'errorMessages': errorMessages,
        'frequencias': frequenciasPendentes.length,
      };
      
    } catch (e) {
      print('❌ Erro no upload de pendências: $e');
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
        // Usar a função específica para frequências pendentes
        final success = await _uploadFrequencia(dados);
        if (!success) {
          throw Exception('Falha no upload de frequência');
        }
        break;
      case 'aula':
        await _uploadAula(dados);
        break;
      // TODO: Adicionar outros tipos conforme necessário
      default:
        print('⚠️ Tipo de registro não suportado: $tipo');
    }
  }

  /// Upload específico de aula
  Future<void> _uploadAula(Map<String, dynamic> aula) async {
    // TODO: Implementar endpoint para upload de aula
    // Por enquanto, simular upload
    await Future.delayed(Duration(milliseconds: 100));
    
    // Marcar como sincronizado
    await _db.marcarComoSincronizado('aulas', aula['id']);
  }

  /// Upload de frequência pendente para o servidor
  Future<bool> _uploadFrequencia(Map<String, dynamic> freq) async {
    try {
      final presencas = jsonDecode(freq['presencas']) as List;
      
      print('📤 Enviando frequência: Turma ${freq['turma_id']}, Data ${freq['data']}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/salvar_frequencia.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'professorId': freq['professor_id'],
          'turmaId': freq['turma_id'],
          'disciplinaId': freq['disciplina_id'],
          'aulaNumero': freq['aula_numero'],
          'data': freq['data'],
          'presencas': presencas,
        }),
      ).timeout(Duration(seconds: 15));

      final responseData = jsonDecode(response.body);
      
      if (responseData['status'] == 'success') {
        print('✅ Frequência enviada com sucesso');
        return true;
      } else {
        print('❌ Servidor rejeitou frequência: ${responseData['message']}');
        return false;
      }
    } catch (e) {
      print('❌ Erro no upload de frequência: $e');
      return false;
    }
  }

  /// Limpa cache do professor (para re-sincronização)
  Future<void> clearCache(int professorId) async {
    print('🗑️ Limpando cache do professor $professorId');
    final db = await _db.database;
    await db.delete('horarios', where: 'professor_id = ?', whereArgs: [professorId]);
    await db.delete('turmas', where: 'professor_id = ?', whereArgs: [professorId]);
    await db.delete('escolas', where: 'professor_id = ?', whereArgs: [professorId]);
    print('✅ Cache limpo');
  }
}