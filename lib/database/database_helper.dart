import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/professor.dart';
import '../models/turma.dart';
import '../models/aluno.dart';
import '../models/aula.dart';
import '../models/frequencia.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'frequencia_escolar.db');
    return await openDatabase(
      path,
      version: 3, // Incrementei a versão para adicionar frequencias_pendentes
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE professores(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        senha TEXT NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        criado_em TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE escolas(
        id INTEGER PRIMARY KEY,
        nome TEXT NOT NULL,
        professor_id INTEGER NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        criado_em TEXT,
        FOREIGN KEY (professor_id) REFERENCES professores (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE turmas(
        id INTEGER PRIMARY KEY,
        nome TEXT NOT NULL,
        turno TEXT NOT NULL,
        ano_letivo INTEGER NOT NULL,
        escola_id INTEGER NOT NULL,
        professor_id INTEGER NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        criado_em TEXT,
        FOREIGN KEY (escola_id) REFERENCES escolas (id),
        FOREIGN KEY (professor_id) REFERENCES professores (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE horarios(
        id INTEGER PRIMARY KEY,
        disciplina_id INTEGER NOT NULL,
        numero_aula INTEGER NOT NULL,
        dia_semana INTEGER NOT NULL,
        disciplina_nome TEXT NOT NULL,
        turma_id INTEGER NOT NULL,
        escola_id INTEGER NOT NULL,
        professor_id INTEGER NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        criado_em TEXT,
        FOREIGN KEY (turma_id) REFERENCES turmas (id),
        FOREIGN KEY (escola_id) REFERENCES escolas (id),
        FOREIGN KEY (professor_id) REFERENCES professores (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE alunos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        matricula TEXT NOT NULL,
        turma_id INTEGER NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        criado_em TEXT,
        FOREIGN KEY (turma_id) REFERENCES turmas (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE aulas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        titulo TEXT NOT NULL,
        observacoes TEXT,
        turma_id INTEGER NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        criado_em TEXT,
        FOREIGN KEY (turma_id) REFERENCES turmas (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE frequencias(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        aluno_id INTEGER NOT NULL,
        aula_id INTEGER NOT NULL,
        presente INTEGER NOT NULL,
        observacoes TEXT,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        criado_em TEXT,
        FOREIGN KEY (aluno_id) REFERENCES alunos (id),
        FOREIGN KEY (aula_id) REFERENCES aulas (id),
        UNIQUE(aluno_id, aula_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE frequencias_pendentes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        professor_id INTEGER NOT NULL,
        turma_id INTEGER NOT NULL,
        disciplina_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        aula_numero INTEGER NOT NULL,
        presencas TEXT NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        criado_em TEXT
      )
    ''');

    // Removido: não inserir dados mockados; app faz sync real após login
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Dropar tabelas antigas e recriar com nova estrutura
      await db.execute('DROP TABLE IF EXISTS frequencias');
      await db.execute('DROP TABLE IF EXISTS frequencias_pendentes');
      await db.execute('DROP TABLE IF EXISTS aulas');
      await db.execute('DROP TABLE IF EXISTS alunos');
      await db.execute('DROP TABLE IF EXISTS horarios');
      await db.execute('DROP TABLE IF EXISTS turmas');
      await db.execute('DROP TABLE IF EXISTS escolas');
      await db.execute('DROP TABLE IF EXISTS professores');
      
      // Recriar todas as tabelas
      await _onCreate(db, newVersion);
    }
  }

  Future<void> _insertSampleData(Database db) async {}

  Future<int> insertProfessor(Professor professor) async {
    final db = await database;
    return await db.insert('professores', professor.toMap());
  }

  Future<Professor?> getProfessorByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'professores',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return Professor.fromMap(maps.first);
    }
    return null;
  }

  // ===== ESCOLAS =====
  Future<void> saveEscolas(List<Map<String, dynamic>> escolas, int professorId) async {
    final db = await database;
    await db.delete('escolas', where: 'professor_id = ?', whereArgs: [professorId]);
    
    for (final escola in escolas) {
      await db.insert('escolas', {
        'id': escola['escola_id'],
        'nome': escola['escola_nome'],
        'professor_id': professorId,
        'sincronizado': 1,
        'criado_em': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<Map<String, dynamic>>> getEscolasCached(int professorId) async {
    final db = await database;
    final maps = await db.query(
      'escolas',
      where: 'professor_id = ?',
      whereArgs: [professorId],
      orderBy: 'nome',
    );
    return maps.map((map) => {
      'escola_id': map['id'],
      'escola_nome': map['nome'],
    }).toList();
  }

  // ===== TURMAS =====
  Future<void> saveTurmas(List<Map<String, dynamic>> turmas, int escolaId, int professorId) async {
    final db = await database;
    await db.delete('turmas', where: 'escola_id = ? AND professor_id = ?', whereArgs: [escolaId, professorId]);
    
    for (final turma in turmas) {
      await db.insert('turmas', {
        'id': turma['turma_id'],
        'nome': turma['turma_nome'],
        'turno': turma['turma_turno'] ?? '',
        'ano_letivo': turma['turma_ano_letivo'] ?? DateTime.now().year,
        'escola_id': escolaId,
        'professor_id': professorId,
        'sincronizado': 1,
        'criado_em': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<Map<String, dynamic>>> getTurmasCached(int escolaId, int professorId) async {
    final db = await database;
    final maps = await db.query(
      'turmas',
      where: 'escola_id = ? AND professor_id = ?',
      whereArgs: [escolaId, professorId],
      orderBy: 'nome',
    );
    return maps.map((map) => {
      'turma_id': map['id'],
      'turma_nome': map['nome'],
      'turma_turno': map['turno'],
      'turma_ano_letivo': map['ano_letivo'],
    }).toList();
  }

  Future<List<Turma>> getTurmasByProfessor(int professorId) async {
    final db = await database;
    final maps = await db.query(
      'turmas',
      where: 'professor_id = ?',
      whereArgs: [professorId],
      orderBy: 'nome',
    );

    return List.generate(maps.length, (i) => Turma.fromMap(maps[i]));
  }

  // ===== ALUNOS =====
  Future<void> saveAlunos(List<Map<String, dynamic>> alunos, int turmaId, int professorId) async {
    final db = await database;
    // Limpar alunos existentes da turma
    await db.delete('alunos', where: 'turma_id = ?', whereArgs: [turmaId]);
    
    int alunosValidos = 0;
    int alunosInvalidos = 0;
    
    for (final aluno in alunos) {
      // Validar dados obrigatórios - tratar diferentes formatos de campos
      final nome = (aluno['nome'] ?? aluno['aluno_nome'])?.toString().trim();
      final alunoId = aluno['aluno_id'] ?? aluno['vinculo_aluno_id'] ?? aluno['id'];
      
      // Tratar tanto null quanto string "null" como inválidos
      if (nome == null || nome.isEmpty || nome.toLowerCase() == 'null' || alunoId == null) {
        print('⚠️ Aluno com dados inválidos ignorado: nome="$nome", id="$alunoId"');
        alunosInvalidos++;
        continue;
      }
      
      try {
        await db.insert('alunos', {
          'id': alunoId,
          'nome': nome,
          'matricula': (aluno['matricula'] ?? aluno['vinculo_aluno_id'])?.toString() ?? '',
          'turma_id': turmaId,
          'sincronizado': 1,
          'criado_em': DateTime.now().toIso8601String(),
        });
        alunosValidos++;
      } catch (e) {
        print('❌ Erro ao inserir aluno "$nome": $e');
        alunosInvalidos++;
      }
    }
    
    print('💾 Alunos salvos: $alunosValidos válidos, $alunosInvalidos inválidos');
  }

  Future<List<Map<String, dynamic>>> getAlunosCached(int turmaId, int disciplinaId, DateTime data, int aulaNumero) async {
    final db = await database;
    // Buscar alunos da turma com informações de frequência se existir
    final maps = await db.rawQuery('''
      SELECT 
        a.id as aluno_id,
        a.nome,
        a.matricula,
        a.turma_id,
        a.id as vinculo_aluno_id,
        COALESCE(f.presente, 1) as presente
      FROM alunos a
      LEFT JOIN frequencias f ON f.aluno_id = a.id 
      WHERE a.turma_id = ?
      ORDER BY a.nome
    ''', [turmaId]);
    
    return maps.map((map) => {
      'aluno_id': map['aluno_id'],
      'aluno_nome': map['nome'], // Mapear para o formato esperado
      'nome': map['nome'],
      'matricula': map['matricula'],
      'turma_id': map['turma_id'],
      'vinculo_aluno_id': map['vinculo_aluno_id'],
      'presente': map['presente'],
      'tem_falta': map['presente'] == 0,
      'falta': map['presente'] == 0 ? 1 : 0,
    }).toList();
  }

  // ===== HORÁRIOS =====
  Future<void> saveHorarios(List<Map<String, dynamic>> horarios, int turmaId, int escolaId, int professorId) async {
    final db = await database;
    await db.delete('horarios', where: 'turma_id = ? AND escola_id = ? AND professor_id = ?', whereArgs: [turmaId, escolaId, professorId]);
    
    for (final horario in horarios) {
      await db.insert('horarios', {
        'id': horario['ch_lotacao_id'],
        'disciplina_id': horario['ch_lotacao_disciplina_id'],
        'numero_aula': horario['ch_lotacao_aula'],
        'dia_semana': horario['ch_lotacao_dia'],
        'disciplina_nome': horario['disciplina_nome'],
        'turma_id': turmaId,
        'escola_id': escolaId,
        'professor_id': professorId,
        'sincronizado': 1,
        'criado_em': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<Map<String, dynamic>>> getHorariosCached(int turmaId, int escolaId, int professorId, int diaSemana) async {
    final db = await database;
    final maps = await db.query(
      'horarios',
      where: 'turma_id = ? AND escola_id = ? AND professor_id = ? AND dia_semana = ?',
      whereArgs: [turmaId, escolaId, professorId, diaSemana],
      orderBy: 'numero_aula',
    );
    return maps.map((map) => {
      'ch_lotacao_id': map['id'],
      'ch_lotacao_disciplina_id': map['disciplina_id'],
      'ch_lotacao_aula': map['numero_aula'],
      'ch_lotacao_dia': map['dia_semana'],
      'disciplina_nome': map['disciplina_nome'],
    }).toList();
  }

  Future<List<Aluno>> getAlunosByTurma(int turmaId) async {
    final db = await database;
    final maps = await db.query(
      'alunos',
      where: 'turma_id = ?',
      whereArgs: [turmaId],
      orderBy: 'nome',
    );

    return List.generate(maps.length, (i) => Aluno.fromMap(maps[i]));
  }

  Future<int> insertAula(Aula aula) async {
    final db = await database;
    return await db.insert('aulas', aula.toMap());
  }

  Future<int> insertFrequencia(Frequencia frequencia) async {
    final db = await database;
    return await db.insert(
      'frequencias',
      frequencia.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateFrequencia(Frequencia frequencia) async {
    final db = await database;
    await db.update(
      'frequencias',
      frequencia.toMap(),
      where: 'id = ?',
      whereArgs: [frequencia.id],
    );
  }

  Future<List<Frequencia>> getFrequenciasByAula(int aulaId) async {
    final db = await database;
    final maps = await db.query(
      'frequencias',
      where: 'aula_id = ?',
      whereArgs: [aulaId],
    );

    return List.generate(maps.length, (i) => Frequencia.fromMap(maps[i]));
  }

  Future<Frequencia?> getFrequencia(int alunoId, int aulaId) async {
    final db = await database;
    final maps = await db.query(
      'frequencias',
      where: 'aluno_id = ? AND aula_id = ?',
      whereArgs: [alunoId, aulaId],
    );

    if (maps.isNotEmpty) {
      return Frequencia.fromMap(maps.first);
    }
    return null;
  }

  // ===== FREQUÊNCIAS PENDENTES (OFFLINE) =====
  Future<int> insertFrequenciaPendente({
    required int professorId,
    required int turmaId,
    required int disciplinaId,
    required String data,
    required int aulaNumero,
    required List<Map<String, dynamic>> presencas,
  }) async {
    final db = await database;
    return await db.insert('frequencias_pendentes', {
      'professor_id': professorId,
      'turma_id': turmaId,
      'disciplina_id': disciplinaId,
      'data': data,
      'aula_numero': aulaNumero,
      'presencas': jsonEncode(presencas),
      'sincronizado': 0,
      'criado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getFrequenciasPendentes() async {
    final db = await database;
    return await db.query(
      'frequencias_pendentes',
      where: 'sincronizado = 0',
      orderBy: 'criado_em ASC',
    );
  }

  Future<void> marcarFrequenciaPendenteComoSincronizada(int id) async {
    final db = await database;
    await db.update(
      'frequencias_pendentes',
      {'sincronizado': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> removerFrequenciaPendente(int id) async {
    final db = await database;
    await db.delete(
      'frequencias_pendentes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getRegistrosPendentes() async {
    final db = await database;
    
    List<Map<String, dynamic>> pendentes = [];
    
    final turmas = await db.query('turmas', where: 'sincronizado = 0');
    pendentes.addAll(turmas.map((t) => {'tipo': 'turma', 'dados': t}));
    
    final alunos = await db.query('alunos', where: 'sincronizado = 0');
    pendentes.addAll(alunos.map((a) => {'tipo': 'aluno', 'dados': a}));
    
    final aulas = await db.query('aulas', where: 'sincronizado = 0');
    pendentes.addAll(aulas.map((a) => {'tipo': 'aula', 'dados': a}));
    
    final frequencias = await db.query('frequencias', where: 'sincronizado = 0');
    pendentes.addAll(frequencias.map((f) => {'tipo': 'frequencia', 'dados': f}));
    
    return pendentes;
  }

  Future<void> marcarComoSincronizado(String tabela, int id) async {
    final db = await database;
    await db.update(
      tabela,
      {'sincronizado': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Método para limpar completamente o banco (debug/reset)
  Future<void> resetDatabase() async {
    final db = await database;
    await db.execute('DROP TABLE IF EXISTS frequencias');
    await db.execute('DROP TABLE IF EXISTS aulas');
    await db.execute('DROP TABLE IF EXISTS alunos');
    await db.execute('DROP TABLE IF EXISTS horarios');
    await db.execute('DROP TABLE IF EXISTS turmas');
    await db.execute('DROP TABLE IF EXISTS escolas');
    await db.execute('DROP TABLE IF EXISTS professores');
    
    await _onCreate(db, 2);
  }
}