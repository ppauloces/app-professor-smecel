import 'package:flutter/foundation.dart';
import '../services/sync_service.dart';

class SyncProvider with ChangeNotifier {
  final SyncService _syncService = SyncService();

  bool _isConnected = false;
  bool _isSyncing = false;
  String? _lastSyncMessage;
  DateTime? _lastSyncTime;
  Map<String, dynamic>? _lastSyncResult;

  bool get isConnected => _isConnected;
  bool get isSyncing => _isSyncing;
  String? get lastSyncMessage => _lastSyncMessage;
  DateTime? get lastSyncTime => _lastSyncTime;
  Map<String, dynamic>? get lastSyncResult => _lastSyncResult;

  Future<void> initSync() async {
    await _checkConnection();
    _syncService.startAutoSync();
  }

  Future<void> _checkConnection() async {
    try {
      _isConnected = await _syncService.isConnected();
    } catch (e) {
      _isConnected = false;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> syncNow() async {
    _isSyncing = true;
    notifyListeners();

    try {
      await _checkConnection();
      
      final result = await _syncService.syncPendingData();
      
      _lastSyncResult = result;
      _lastSyncMessage = result['message'];
      _lastSyncTime = DateTime.now();
      
      return result;
    } catch (e) {
      _lastSyncMessage = 'Erro durante sincronização: $e';
      return {'success': false, 'message': _lastSyncMessage};
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  String getLastSyncTimeFormatted() {
    if (_lastSyncTime == null) return 'Nunca';
    
    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);
    
    if (difference.inMinutes < 1) {
      return 'Agora há pouco';
    } else if (difference.inHours < 1) {
      return 'Há ${difference.inMinutes} minuto(s)';
    } else if (difference.inDays < 1) {
      return 'Há ${difference.inHours} hora(s)';
    } else {
      return 'Há ${difference.inDays} dia(s)';
    }
  }

  String getSyncStatusText() {
    if (_isSyncing) {
      return 'Sincronizando...';
    } else if (!_isConnected) {
      return 'Offline';
    } else {
      return 'Online';
    }
  }

  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}