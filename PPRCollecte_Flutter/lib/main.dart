import 'package:flutter/material.dart';
import 'screens/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
