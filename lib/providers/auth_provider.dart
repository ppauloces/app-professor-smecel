import 'package:flutter/foundation.dart';
import '../models/professor.dart';
import '../services/auth_service.dart';
import '../services/full_sync_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FullSyncService _fullSyncService = FullSyncService();
  final NotificationService _notificationService = NotificationService();

  Professor? _professor;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSyncing = false;
  String? _syncMessage;
  bool _syncFailed = false;

  Professor? get professor => _professor;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSyncing => _isSyncing;
  String? get syncMessage => _syncMessage;
  bool get isAuthenticated => _professor != null;

  /// Indica se a última tentativa de sync falhou (para exibir aviso na UI)
  bool get syncFailed => _syncFailed;

  Future<void> checkAuthStatus() async {
    _setLoading(true);
    try {
      _professor = await _authService.getProfessorLogado();
      _clearError();

      // Se ja estava logado, iniciar lembretes
      if (_professor != null) {
        _notificationService.iniciarLembretes(_professor!.codigo);
      }
    } catch (e) {
      _setError('Erro ao verificar autenticação: $e');
    }
    _setLoading(false);
  }

  Future<bool> login(String codigo, String email, String senha) async {
    _setLoading(true);
    _clearError();
    _syncFailed = false;

    try {
      final professor = await _authService.login(codigo, email, senha);
      if (professor != null) {
        _professor = professor;
        _setLoading(false);

        // Sync roda em background apos login (UI ja navega para EscolasScreen)
        _performFullSync(codigo);

        // Iniciar lembretes de sincronizacao
        _notificationService.iniciarLembretes(codigo);

        return true;
      } else {
        _setError('Código, email ou senha incorretos');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Erro durante o login: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Realiza sincronização completa dos dados do professor com retry
  /// Realiza sincroniza??o completa dos dados do professor com retry
  Future<void> _performFullSync(String professorCodigo) async {
    _setSyncing(true, 'Verificando dados locais...');

    try {
      final professorId = int.tryParse(professorCodigo) ?? 0;

      final hasLocal = await _fullSyncService.hasLocalData(professorId);

      if (!hasLocal) {
        _setSyncing(true, 'Baixando escolas, turmas e horários...');

        // Tentar at? 2 vezes
        Map<String, dynamic>? result;
        for (int attempt = 1; attempt <= 2; attempt++) {
          result = await _fullSyncService.syncAllData(
            professorCodigo,
            syncAlunos: false,
          );

          if (result['success'] == true) {
            break;
          }

          if (attempt < 2) {
            _setSyncing(true, 'Tentando novamente...');
            await Future.delayed(const Duration(seconds: 2));
          }
        }

        if (result != null && result['success'] == true) {
          final details = result['details'] as Map<String, dynamic>;
          _setSyncing(true, 'Dados sincronizados: ${details['escolas']} escolas, ${details['turmas']} turmas');
          _syncFailed = false;
          await Future.delayed(const Duration(seconds: 2));
        } else {
          _syncFailed = true;
          _setSyncing(true, 'Falha ao baixar dados. Verifique sua conexão.');
          await Future.delayed(const Duration(seconds: 2));
        }
      } else {
        _setSyncing(true, 'Dados offline disponíveis');
        _syncFailed = false;
        await Future.delayed(const Duration(seconds: 1));
      }

      // Garantir alunos offline (prefetch por turma, se faltar)
      _setSyncing(true, 'Baixando alunos para uso offline...');
      final prefetchResult = await _fullSyncService.prefetchAlunos(professorCodigo);

      if (prefetchResult['success'] == true) {
        _syncFailed = false;
        await Future.delayed(const Duration(seconds: 1));
      } else {
        final message = prefetchResult['message']?.toString() ?? '';
        if (!message.contains('Sem conex')) {
          _syncFailed = true;
          _setSyncing(true, 'Falha ao baixar alunos offline');
          await Future.delayed(const Duration(seconds: 2));
        }
      }

    } catch (e) {
      debugPrint('Erro na sincronização: $e');
      _syncFailed = true;
    }

    _setSyncing(false, null);
  }


  Future<void> logout() async {
    _setLoading(true);
    try {
      _notificationService.pararLembretes();
      await _authService.logout();
      _professor = null;
      _syncFailed = false;
      _clearError();
    } catch (e) {
      _setError('Erro durante logout: $e');
    }
    _setLoading(false);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSyncing(bool syncing, String? message) {
    _isSyncing = syncing;
    _syncMessage = message;
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

  /// Força re-sincronização completa (limpa cache e baixa tudo novamente)
  Future<void> forceFullSync() async {
    if (_professor == null) return;

    _setSyncing(true, 'Limpando cache local...');

    try {
      final professorId = int.tryParse(_professor!.codigo) ?? 0;
      await _fullSyncService.clearCache(professorId);

      _setSyncing(true, 'Re-sincronizando dados...');
      final result = await _fullSyncService.syncAllData(
        _professor!.codigo,
        syncAlunos: true,
      );

      if (result['success']) {
        final details = result['details'] as Map<String, dynamic>;
        _syncFailed = false;
        _setSyncing(true, 'Sincronização completa: ${details['escolas']} escolas, ${details['turmas']} turmas, ${details['horarios']} horários');
        await Future.delayed(const Duration(seconds: 2));
      } else {
        _syncFailed = true;
        _setError('Erro na re-sincronização: ${result['message']}');
      }
    } catch (e) {
      _syncFailed = true;
      _setError('Erro na re-sincronização: $e');
    }

    _setSyncing(false, null);
  }

  /// Método chamado quando a conectividade é restaurada
  Future<void> onConnectivityRestored() async {
    if (_professor != null && !_isSyncing) {
      debugPrint('[AuthProvider] Conectividade restaurada, iniciando sync incremental...');

      // Verificar se ha pendencias e notificar o professor
      _notificationService.verificarAoReconectar();

      _setSyncing(true, 'Enviando dados offline...');

      try {
        final result = await _fullSyncService.syncIncremental(_professor!.codigo);

        if (result['success']) {
          final details = result['details'] as Map<String, dynamic>?;
          final uploaded = details?['uploaded'] ?? 0;

          if (uploaded > 0) {
            _setSyncing(false, 'Enviados $uploaded registros offline');
          } else {
            _setSyncing(false, 'Dados sincronizados');
          }

          // Se sync tinha falhado antes, tentar full sync agora
          if (_syncFailed) {
            _setSyncing(true, 'Baixando dados pendentes...');
            await _performFullSync(_professor!.codigo);
          }
        } else {
          _setSyncing(false, 'Erro na sincronização');
        }

        // Limpar mensagem após 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (_syncMessage?.contains('Enviados') == true ||
              _syncMessage == 'Dados sincronizados' ||
              _syncMessage == 'Erro na sincronização') {
            _syncMessage = null;
            notifyListeners();
          }
        });

      } catch (e) {
        _setSyncing(false, 'Erro na sincronização automática');
        debugPrint('Erro na sincronização automática: $e');
      }
    }
  }
}
