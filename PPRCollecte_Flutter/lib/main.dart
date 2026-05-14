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
  DArgon2Flutter.init();

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

  runApp(const MyApp());
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
