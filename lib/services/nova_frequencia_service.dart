import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/aluno.dart';
import '../database/database_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NovaFrequenciaService {
  static const String _baseUrl = 'https://smecel.com.br/api/professor';
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<List<Aluno>> getAlunosPorAula({
    required String professorId,
    required String turmaId,
    required String disciplinaId,
    required DateTime data,
    required int aulaNumero,
  }) async {
    print('🎓 Buscando alunos para turma $turmaId, disciplina $disciplinaId');
    
    // Verificar conectividade primeiro
    final conectividade = await Connectivity().checkConnectivity();
    final isConnected = conectividade != ConnectivityResult.none;
    
    print('🌐 Status da conexão: ${isConnected ? 'ONLINE' : 'OFFLINE'}');
    
    try {
      if (isConnected) {
        print('🌐 Buscando dados ONLINE (dados atualizados)...');
        // ONLINE: Buscar dados atualizados do servidor
        final dataFormatada = '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
        
        final response = await http.post(
          Uri.parse('$_baseUrl/get_alunos.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'professorId': int.parse(professorId),
            'turma': int.parse(turmaId),
            'disciplina': int.parse(disciplinaId),
            'data': dataFormatada,
            'aulaNumero': aulaNumero,
          }),
        );

        final responseData = jsonDecode(response.body);
        
        if (responseData['status'] == 'success') {
          final alunosData = responseData['alunos'] as List;
          
          print('🔍 DADOS RECEBIDOS DO SERVIDOR:');
          for (int i = 0; i < alunosData.length; i++) {
            final aluno = alunosData[i];
            print('   Aluno $i: aluno_id=${aluno['aluno_id']}, nome="${aluno['aluno_nome']}", falta=${aluno['falta']}');
          }
          
          // Salvar dados para uso offline
          await _databaseHelper.saveAlunos(
            alunosData.map((a) => Map<String, dynamic>.from(a)).toList(),
            int.parse(turmaId),
            int.parse(professorId)
          );
          
          print('💾 Salvos ${alunosData.length} alunos para uso offline');
          final alunosObjetos = alunosData.map((alunoJson) => Aluno.fromMap(alunoJson)).toList();
          
          print('🔍 ALUNOS PROCESSADOS:');
          for (int i = 0; i < alunosObjetos.length; i++) {
            final aluno = alunosObjetos[i];
            print('   Aluno $i: id=${aluno.id}, nome="${aluno.nome}", temFalta=${aluno.temFalta}');
          }
          
          return alunosObjetos;
        } else {
          throw Exception(responseData['message'] ?? 'Erro ao carregar alunos');
        }
      } else {
        // OFFLINE: Buscar dados offline
        print('📱 Buscando dados OFFLINE...');
        final alunosOffline = await _databaseHelper.getAlunosCached(
          int.parse(turmaId), 
          int.parse(disciplinaId), 
          data, 
          aulaNumero
        );
        
        if (alunosOffline.isNotEmpty) {
          print('📱 Encontrados ${alunosOffline.length} alunos offline');
          return alunosOffline.map((alunoJson) => Aluno.fromMap(alunoJson)).toList();
        } else {
          throw Exception('Sem dados offline disponíveis para esta aula');
        }
      }
    } catch (e) {
      // FALLBACK: Se online falhar, tentar offline
      if (isConnected) {
        print('❌ Erro online, tentando dados offline como fallback...');
        try {
          final alunosOffline = await _databaseHelper.getAlunosCached(
            int.parse(turmaId), 
            int.parse(disciplinaId), 
            data, 
            aulaNumero
          );
          
          if (alunosOffline.isNotEmpty) {
            print('📱 Usando dados offline como fallback (${alunosOffline.length} alunos)');
            return alunosOffline.map((alunoJson) => Aluno.fromMap(alunoJson)).toList();
          }
        } catch (offlineError) {
          print('❌ Erro ao buscar dados offline: $offlineError');
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
    print('💾 Salvando frequência - Professor: $professorId, Turma: $turmaId');
    
    // Verificar conectividade primeiro
    final conectividade = await Connectivity().checkConnectivity();
    final isConnected = conectividade != ConnectivityResult.none;
    
    final dataFormatada = '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
    
    if (isConnected) {
      // MODO ONLINE - Tentar enviar para servidor
      try {
        print('🌐 Tentando salvar online...');
        final requestBody = {
          'professorId': int.parse(professorId),
          'turmaId': int.parse(turmaId),
          'disciplinaId': int.parse(disciplinaId),
          'aulaNumero': aulaNumero,
          'data': dataFormatada,
          'presencas': presencas,
        };
        
        print('📤 Request Body: ${jsonEncode(requestBody)}');
        print('📤 URL: $_baseUrl/salvar_frequencia.php');
        
        final response = await http.post(
          Uri.parse('$_baseUrl/salvar_frequencia.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        ).timeout(Duration(seconds: 10));

        print('📥 Response Status: ${response.statusCode}');
        print('📥 Response Body: ${response.body}');

        final responseData = jsonDecode(response.body);
        
        if (responseData['status'] == 'success') {
          print('✅ Frequência salva online com sucesso');
          return true;
        } else {
          print('❌ Servidor retornou erro: ${responseData['message']}');
          throw Exception(responseData['message'] ?? 'Erro ao salvar frequência');
        }
      } catch (e) {
        print('❌ Erro ao salvar online: $e');
        print('📱 Fallback: salvando offline...');
        // Se falhar online, salvar offline
      }
    } else {
      print('📱 Sem conexão - salvando offline...');
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

      // Limpa faltas anteriores desta aula e grava as novas
      await _databaseHelper.clearFaltasLocal(int.parse(disciplinaId), aulaNumero, dataFormatada);
      await _databaseHelper.saveFaltasLocal(
        matriculasAusentes: ausentes,
        disciplinaId: int.parse(disciplinaId),
        aulaNumero: aulaNumero,
        data: dataFormatada,
      );
      
      print('✅ Frequência salva offline - será enviada quando conectar (faltas_local atualizado)');
      return true;
    } catch (e) {
      print('❌ Erro ao salvar offline: $e');
      throw Exception('Erro ao salvar frequência offline: $e');
    }
  }
}