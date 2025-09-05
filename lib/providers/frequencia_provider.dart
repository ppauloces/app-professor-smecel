import 'package:flutter/foundation.dart';
import '../models/turma.dart';
import '../models/aluno.dart';
import '../models/aula.dart';
import '../services/frequencia_service.dart';

class FrequenciaProvider with ChangeNotifier {
  final FrequenciaService _frequenciaService = FrequenciaService();

  List<Turma> _turmas = [];
  List<Aluno> _alunos = [];
  Aula? _aulaAtual;
  Map<int, bool> _frequencias = {};
  bool _isLoading = false;
  String? _errorMessage;

  List<Turma> get turmas => _turmas;
  List<Aluno> get alunos => _alunos;
  Aula? get aulaAtual => _aulaAtual;
  Map<int, bool> get frequencias => _frequencias;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> carregarTurmas(int professorId) async {
    _setLoading(true);
    try {
      _turmas = await _frequenciaService.getTurmasProfessor(professorId);
      _clearError();
    } catch (e) {
      _setError('Erro ao carregar turmas: $e');
    }
    _setLoading(false);
  }

  Future<void> carregarAlunos(int turmaId) async {
    _setLoading(true);
    try {
      _alunos = await _frequenciaService.getAlunosTurma(turmaId);
      _frequencias.clear();
      _clearError();
    } catch (e) {
      _setError('Erro ao carregar alunos: $e');
    }
    _setLoading(false);
  }

  Future<void> iniciarAula({
    required int turmaId,
    required String titulo,
    String? observacoes,
  }) async {
    _setLoading(true);
    try {
      _aulaAtual = await _frequenciaService.criarAula(
        data: DateTime.now(),
        titulo: titulo,
        observacoes: observacoes,
        turmaId: turmaId,
      );

      if (_aulaAtual != null) {
        final frequenciasExistentes = await _frequenciaService
            .getFrequenciasAula(_aulaAtual!.id!);
        _frequencias = frequenciasExistentes;
      }
      
      _clearError();
    } catch (e) {
      _setError('Erro ao iniciar aula: $e');
    }
    _setLoading(false);
  }

  Future<void> registrarFrequencia({
    required int alunoId,
    required bool presente,
    String? observacoes,
  }) async {
    if (_aulaAtual == null) {
      _setError('Nenhuma aula iniciada');
      return;
    }

    try {
      await _frequenciaService.registrarFrequencia(
        alunoId: alunoId,
        aulaId: _aulaAtual!.id!,
        presente: presente,
        observacoes: observacoes,
      );

      _frequencias[alunoId] = presente;
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Erro ao registrar frequência: $e');
    }
  }

  bool isPresente(int alunoId) {
    return _frequencias[alunoId] ?? false;
  }

  bool hasFrequencia(int alunoId) {
    return _frequencias.containsKey(alunoId);
  }

  void toggleFrequencia(int alunoId) {
    final isPresente = _frequencias[alunoId] ?? false;
    registrarFrequencia(alunoId: alunoId, presente: !isPresente);
  }

  void finalizarAula() {
    _aulaAtual = null;
    _frequencias.clear();
    _alunos.clear();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
}