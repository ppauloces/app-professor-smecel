import 'dart:io';
import 'utils/http_overrides.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/escolas_screen.dart';
import 'widgets/lottie_loading.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    HttpOverrides.global = DevHttpOverrides();
  }
  await NotificationService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'SMECEL - Frequência Escolar',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
        ],
        locale: const Locale('pt', 'BR'),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Inicializar conectividade
      Provider.of<ConnectivityProvider>(context, listen: false).initialize();
      // Verificar autenticação
      Provider.of<AuthProvider>(context, listen: false).checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ConnectivityProvider>(
      builder: (context, authProvider, connectivityProvider, child) {
        // Listener para reconexão automática
        if (connectivityProvider.isConnected &&
            authProvider.isAuthenticated &&
            !authProvider.isSyncing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (connectivityProvider.wasOffline) {
              authProvider.onConnectivityRestored();
              connectivityProvider.clearWasOffline();
            }
          });
        }
        
        if (authProvider.isLoading) {
          return const Scaffold(
            body: LottieLoading(),
          );
        }

        if (authProvider.isAuthenticated) {
          return const EscolasScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}