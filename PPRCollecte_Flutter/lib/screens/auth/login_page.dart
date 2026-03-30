// lib/screens/auth/login_page.dart
// ── SPRINT 3 : Login SRM (login + mot_de_passe en clair) ──
// L'API retourne { success, user: { id_user, login, nom_prenom, role,
//   id_projet_actif }, projet_actif: { id_projet, nom, statut, metier… } }

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../../screens/project/project_selection_page.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  static const Duration _probeTimeout = Duration(milliseconds: 900);
  static const Duration _loginTimeout = Duration(seconds: 5);
  bool rememberMe = false;
  bool _obscurePwd = true;
  bool _isLoading = false;

  // ── Tester si le serveur est joignable ──
  Future<bool> _isApiReachable() async {
    try {
      final uri = Uri.parse(ApiService.baseUrl);
      final host = uri.host;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final socket = await Socket.connect(host, port, timeout: _probeTimeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }

  Future<void> _loadRememberedUser() async {
    final db = DatabaseHelper();
    final login = await db.getCurrentUserLogin();
    if (login != null && login.isNotEmpty) {
      final user = await db.getCurrentUserSrm();
      if (user != null) {
        setState(() {
          loginController.text = user['login'] ?? '';
          passwordController.text = user['mot_de_passe'] ?? '';
          rememberMe = true;
        });
      }
    } else {
      setState(() {
        rememberMe = false;
        loginController.clear();
        passwordController.clear();
      });
    }
  }

  // ── Login hors-ligne (SQLite) ──
  Future<void> _loginOffline(String login, String password) async {
    final isValidLocal = await DatabaseHelper().validateUser(login, password);
    if (isValidLocal) {
      await DatabaseHelper().setCurrentUserLogin(login, remember: rememberMe);

      // Restaurer ApiService depuis SQLite
      final user = await DatabaseHelper().getCurrentUserSrm();
      if (user != null) {
        ApiService.userId = user['api_id'] as int?;
        ApiService.userLogin = user['login'] as String?;
        ApiService.nomPrenom = user['nom_prenom'] as String?;
        ApiService.userRole = user['role'] as String?;

        // Restaurer le projet actif depuis SQLite
        final projetId = user['id_projet_actif'];
        if (projetId != null) {
          ApiService.currentProjetId = projetId is int
              ? projetId
              : int.tryParse(projetId.toString());
          final projet = await DatabaseHelper()
              .getProjetLocal(ApiService.currentProjetId!);
          if (projet != null) {
            ApiService.currentProjetNom = projet['nom'] as String?;
            ApiService.currentProjetStatut = projet['statut'] as String?;
            ApiService.currentProjetMetier = projet['metier'] as String?;
          }
        }
        print('🔄 ApiService restauré (offline): '
            'userId=${ApiService.userId} projet=${ApiService.currentProjetId}');
      }

      final fullName = ApiService.nomPrenom ?? 'Utilisateur Local';

      if (!mounted) return;
      _navigateToProjectSelection(fullName, isOnline: false);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Mode hors-ligne : identifiants introuvables localement."),
        ),
      );
    }
  }

  // ── Login principal ──
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final login = loginController.text.trim();
    final password = passwordController.text;

    setState(() => _isLoading = true);

    try {
      // (A) Serveur disponible ?
      final apiUp = await _isApiReachable();
      if (!apiUp) {
        await _loginOffline(login, password);
        return;
      }

      // (B) POST /api/login/ avec login + mot_de_passe (en clair)
      final userData =
          await ApiService.login(login, password).timeout(_loginTimeout);

      // (C) Session "Se souvenir"
      await DatabaseHelper().setCurrentUserLogin(login, remember: rememberMe);

      // (D) Sauvegarder l'utilisateur localement (pour le mode offline)
      await DatabaseHelper().upsertUserSrm(
        login: login,
        motDePasse: password, // en clair, comme dans la base PostgreSQL
        nomPrenom: userData['nom_prenom'],
        role: userData['role'],
        apiId: userData['id_user'],
        idProjetActif: userData['id_projet_actif'],
      );

      // (E) Sauvegarder le projet actif localement
      if (userData['projet_id'] != null) {
        await DatabaseHelper().upsertProjetLocal(
          idProjet: userData['projet_id'],
          nom: userData['projet_nom'],
          codeAffaire: userData['projet_code'],
          srm: userData['projet_srm'],
          region: userData['projet_region'],
          metier: userData['projet_metier'],
          statut: userData['projet_statut'],
        );
      }

      final fullName = userData['nom_prenom'] ?? 'Agent SRM';

      if (!mounted) return;
      _navigateToProjectSelection(fullName, isOnline: true);
    } on TimeoutException catch (_) {
      await _loginOffline(login, password);
    } on SocketException catch (_) {
      await _loginOffline(login, password);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToProjectSelection(String agentName,
      {required bool isOnline}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectSelectionPage(
          agentName: agentName,
          isOnline: isOnline,
          onLogout: () {
            ApiService.resetSession();
            DatabaseHelper().clearSrmSession();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
        ),
      ),
    );
  }

  // ===== Dialog "Mot de passe oublié" =====
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_reset_rounded,
                  color: Color(0xFF0284C7), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text("Mot de passe oublié ?",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A))),
            ),
          ],
        ),
        content: const Text(
          "Contactez votre administrateur SRM pour réinitialiser votre mot de passe.",
          style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Compris"),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        margin: const EdgeInsets.symmetric(vertical: 24),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          autovalidateMode:
                              AutovalidateMode.onUserInteraction,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ── Logo SRM ──
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFE0F2FE),
                                      Color(0xFFCCFBF1)
                                    ],
                                  ),
                                ),
                                child: const SrmLoginEmblem(),
                              ),
                              const SizedBox(height: 10),
                              const Text("SRM Collecte",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A))),
                              const SizedBox(height: 14),
                              const Text(
                                "Connexion à SRM Collecte",
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 20),

                              // ── Champ Login ──
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text("Login",
                                    style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: loginController,
                                keyboardType: TextInputType.text,
                                decoration: _inputDeco(
                                    hint: "Votre identifiant SRM",
                                    icon: Icons.person_rounded),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return "Entrez votre login";
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              // ── Mot de passe ──
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text("Mot de passe",
                                    style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: passwordController,
                                obscureText: _obscurePwd,
                                decoration: _inputDeco(
                                  hint: "••••••••",
                                  icon: Icons.lock_rounded,
                                  suffix: IconButton(
                                    icon: Icon(_obscurePwd
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(
                                        () => _obscurePwd = !_obscurePwd),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return "Entrez votre mot de passe";
                                  }
                                  if (v.length < 4) {
                                    return "Mot de passe trop court";
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 10),

                              // Se souvenir + Mot de passe oublié
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: rememberMe,
                                      onChanged: (val) {
                                        setState(() {
                                          rememberMe = val ?? false;
                                          if (!rememberMe) {
                                            loginController.clear();
                                            passwordController.clear();
                                          }
                                        });
                                      },
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("Se souvenir",
                                      style: TextStyle(
                                          color: Color(0xFF334155))),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    child:
                                        const Text("Mot de passe oublié ?"),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Bouton connexion
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF38BDF8),
                                    foregroundColor: const Color(0xFF0F172A),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text("Se connecter",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo SRM (fallback vers icône si asset manquant)
class SrmLoginEmblem extends StatelessWidget {
  const SrmLoginEmblem({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        "assets/srm_collecte_logo.png",
        width: 104,
        height: 104,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.water_drop,
          size: 48,
          color: Color(0xFF2196F3),
        ),
      ),
    );
  }
}
