import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/auth_provider.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityProvider, AuthProvider>(
      builder: (context, connectivity, auth, child) {
        if (auth.syncFailed) {
          return MaterialBanner(
            content: const Text(
              'Falha ao sincronizar dados. Algumas informações podem estar indisponíveis.',
            ),
            backgroundColor: Colors.red.shade50,
            leading: Icon(Icons.error_outline, color: Colors.red.shade700),
            actions: [
              TextButton(
                onPressed: connectivity.isConnected
                    ? () => auth.forceFullSync()
                    : null,
                child: const Text('Tentar novamente'),
              ),
            ],
          );
        }

        if (!connectivity.isConnected) {
          return Container(
            width: double.infinity,
            color: Colors.orange.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.wifi_off, size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Text(
                  'Modo offline — usando dados salvos',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
