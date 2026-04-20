import 'dart:ui';

import 'package:executor_lib/executor_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dargon2_flutter/dargon2_flutter.dart';
import 'screens/auth/login_page.dart';

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
      home: const LoginPage(),
    );
  }
}
