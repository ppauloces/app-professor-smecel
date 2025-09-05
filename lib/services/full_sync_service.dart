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
    if (!await _isConnected()) {
      return {
        'success': false, 
        'message': 'Sem conexão com a internet para sincronização inicial'
      };
    }

    try {
      final professorId = int.tryParse(professorCodigo) ?? 0;
      
      // 1. Baixar todas as escolas
      print('🏫 Sincronizando escolas...');
      final escolas = await _syncEscolas(professorCodigo, professorId);
      print('✅ Encontradas ${escolas.length} escolas');
      
      int totalTurmas = 0;
      int totalHorarios = 0;
      
      // 2. Para cada escola, baixar turmas e horários
      for (final escola in escolas) {
        final escolaId = escola['escola_id'];
        print('🎓 Sincronizando turmas da escola: ${escola['escola_nome']}');
        
        try {
          final turmas = await _syncTurmas(professorCodigo, escolaId.toString(), escolaId, professorId);
          totalTurmas += turmas.length;
          print('✅ Encontradas ${turmas.length} turmas na escola ${escola['escola_nome']}');
          
          // 3. Para cada turma, baixar grade completa de horários
          for (final turma in turmas) {
            final turmaId = turma['turma_id'];
            print('📅 Sincronizando horários da turma: ${turma['turma_nome']}');
            
            try {
              final horarios = await _syncHorarios(professorId, escolaId, turmaId);
              totalHorarios += horarios.length;
              print('✅ Encontrados ${horarios.length} horários para turma ${turma['turma_nome']}');
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
      
      return {
        'success': true,
        'message': 'Sincronização completa realizada',
        'details': {
          'escolas': escolas.length,
          'turmas': totalTurmas,
          'horarios': totalHorarios,
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
          final horariosData = responseData['horarios'] as List<Map<String, dynamic>>;
          todosHorarios.addAll(horariosData);
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

  /// Verifica se o professor tem dados salvos localmente
  Future<bool> hasLocalData(int professorId) async {
    try {
      final escolas = await _db.getEscolasCached(professorId);
      return escolas.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Limpa cache do professor (para re-sincronização)
  Future<void> clearCache(int professorId) async {
    final db = await _db.database;
    await db.delete('horarios', where: 'professor_id = ?', whereArgs: [professorId]);
    await db.delete('turmas', where: 'professor_id = ?', whereArgs: [professorId]);
    await db.delete('escolas', where: 'professor_id = ?', whereArgs: [professorId]);
  }
}