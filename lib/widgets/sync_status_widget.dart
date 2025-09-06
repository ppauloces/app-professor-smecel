import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/auth_provider.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityProvider, AuthProvider>(
      builder: (context, connectivity, auth, child) {
        return PopupMenuButton<String>(
          icon: _buildStatusIcon(connectivity),
          onSelected: (value) {
            if (value == 'sync_now') {
              _performManualSync(context, connectivity, auth);
            } else if (value == 'force_sync') {
              _performForceSync(context, auth);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'status',
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        connectivity.isConnected ? Icons.wifi : Icons.wifi_off,
                        size: 16,
                        color: connectivity.isConnected ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        connectivity.connectionStatus,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: connectivity.isConnected ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Último sync: ${connectivity.lastSyncTimeFormatted}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (connectivity.lastSyncMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      connectivity.lastSyncMessage!,
                      style: const TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ],
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'sync_now',
              enabled: connectivity.isConnected && !connectivity.isSyncing,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    connectivity.isSyncing ? Icons.sync : Icons.sync,
                    size: 16,
                    color: connectivity.isSyncing ? Colors.orange : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    connectivity.isSyncing ? 'Sincronizando...' : 'Sincronizar agora',
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'force_sync',
              enabled: connectivity.isConnected && !connectivity.isSyncing && !auth.isSyncing,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Sincronização completa'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusIcon(ConnectivityProvider connectivity) {
    if (connectivity.isSyncing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (connectivity.isConnected) {
      return const Icon(Icons.cloud_done, color: Colors.white);
    } else {
      return const Icon(Icons.cloud_off, color: Colors.orange);
    }
  }

  void _performManualSync(BuildContext context, ConnectivityProvider connectivity, AuthProvider auth) async {
    final professorCodigo = auth.professor?.codigo;
    
    if (professorCodigo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Professor não identificado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await connectivity.syncNow(professorCodigo);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Sincronização realizada'),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _performForceSync(BuildContext context, AuthProvider auth) async {
    final professorCodigo = auth.professor?.codigo;
    
    if (professorCodigo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Professor não identificado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar diálogo de confirmação
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sincronização Completa'),
        content: const Text(
          'Isso irá baixar todos os dados novamente e pode demorar alguns minutos. Continuar?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await auth.forceFullSync();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronização completa realizada'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}