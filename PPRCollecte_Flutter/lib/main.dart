import 'dart:async';
import 'dart:ui';

import 'package:executor_lib/executor_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dargon2_flutter/dargon2_flutter.dart';
import 'screens/auth/login_page.dart';
import 'screens/home/home_page.dart';
import 'data/local/database_helper.dart';
import 'data/remote/api_service.dart';
import 'services/attribut_config_mobile_service.dart';
import 'services/formulaire_config_mobile_service.dart';
import 'services/offline_basemap_service.dart';
import 'services/srm_field_option_service.dart';

bool _isIgnorableAppError(Object error) {
  return error is CancellationException || error.toString() == 'Cancelled';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? bootstrapError;
  StackTrace? bootstrapStack;

  try {
    // Fail-fast visible : un build release doit pointer vers un backend HTTPS
    // de prod ou un host HTTP explicitement autorise. En cas de mauvaise
    // configuration, on affiche une page d'erreur au lieu d'un ecran noir.
    ApiService.validateBaseUrl();
    DArgon2Flutter.init();
  } catch (error, stack) {
    bootstrapError = error;
    bootstrapStack = stack;
  }

  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isIgnorableAppError(details.exception)) {
      return;
    }
    previousFlutterError?.call(details);
  };

  final previousPlatformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (_isIgnorableAppError(error)) {
      return true;
    }
    if (previousPlatformError != null) {
      return previousPlatformError(error, stack);
    }
    return false;
  };

  if (bootstrapError != null) {
    debugPrint('SRM bootstrap failed: $bootstrapError\n$bootstrapStack');
    runApp(BootstrapErrorApp(error: bootstrapError.toString()));
    return;
  }

  runApp(const MyApp());
}

class BootstrapErrorApp extends StatelessWidget {
  final String error;

  const BootstrapErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Configuration release invalide',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17202A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'L’application ne peut pas démarrer car le backend du build '
                      'n’est pas configuré correctement.',
                      style: TextStyle(fontSize: 16, color: Color(0xFF34495E)),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        error,
                        style: const TextStyle(
                          color: Color(0xFFB71C1C),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Rebuilder avec tools/build_mobile_release.ps1 et fournir '
                      'API_BASE_URL.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B4F72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SRM Collecte',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF1B4F72),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B4F72),
          primary: const Color(0xFF1B4F72),
          secondary: const Color(0xFF2E86C1),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B4F72),
          foregroundColor: Colors.white,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          closeIconColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<Widget> _target = _resolveTarget();

  Future<Widget> _resolveTarget() async {
    final db = DatabaseHelper();
    final user = await db.getActiveSessionUser();
    if (user == null) {
      ApiService.resetSession();
      return const LoginPage();
    }

    _restoreApiServiceFromUser(user);

    // Restaure le JWT depuis le Keystore (sinon les appels API post-restart
    // partiraient sans Bearer -> 401). Si l'access token est expire mais le
    // refresh encore valide, _authedGet declenchera un refresh au 1er 401.
    final tokenRestored = await ApiService.restoreTokensFromStore();
    if (tokenRestored) {
      // Tentative de refresh proactif silencieux : si online et access
      // expire, on obtient un access frais des le demarrage. Si offline,
      // l'echec est ignore (le mode offline n'a pas besoin du serveur).
      unawaited(ApiService.refreshAccessToken());
    }

    // Session restaurée (jusqu'à 7 jours sans re-login) : on rafraîchit
    // silencieusement la config des formulaires depuis le serveur en
    // background. Si offline, l'erreur est ignorée et la SQLite existante
    // continue d'alimenter les formulaires.
    unawaited(_refreshMobileFormConfigSilently());

    final activeBasemap = await OfflineBasemapService().getActiveBasemap();
    final offlineBasemapPath = activeBasemap?['local_path']?.toString().trim();
    final offlineBasemapFormat = activeBasemap?['format']?.toString().trim();
    final agentName = ApiService.nomPrenom ?? 'Agent SRM';

    return HomePage(
      agentName: agentName,
      isOnline: false,
      initialOfflineBasemapPath: offlineBasemapPath,
      initialOfflineBasemapFormat: offlineBasemapFormat,
      initialBasemapNotice:
          offlineBasemapPath == null || offlineBasemapPath.isEmpty
              ? "Aucune carte offline active n'a encore été téléchargée."
              : null,
      onLogout: _logoutRestoredSession,
    );
  }

  Future<void> _refreshMobileFormConfigSilently() async {
    try {
      await Future.wait<dynamic>([
        FormulaireConfigMobileService().refreshConfig(),
        AttributConfigMobileService().refreshConfig(),
        SrmFieldOptionService().refreshOptions(),
      ]);
    } catch (e) {
      debugPrint('[MOBILE-FORM-CONFIG] Refresh ignore au resume session: $e');
    }
  }

  void _restoreApiServiceFromUser(Map<String, dynamic> user) {
    final rawUserId = user['id_user'];
    ApiService.userId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');
    ApiService.userLogin = user['login']?.toString();
    ApiService.userNom = user['nom']?.toString();
    ApiService.userPrenom = user['prenom']?.toString();
    ApiService.userRole = user['role']?.toString();
    ApiService.nomPrenom = DatabaseHelper.fullNameFromUserRow(user);
  }

  Future<void> _logoutRestoredSession() async {
    await DatabaseHelper().clearSrmSession();
    ApiService.resetSession();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _target,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return snapshot.data!;
        }
        return const Scaffold(
          backgroundColor: Color(0xFFF8FAFC),
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
