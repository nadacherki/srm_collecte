

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
      hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Icon(icon, color: const Color(0xFF90A4AE), size: 20),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE8EDF2), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2),
      ),
      errorStyle: const TextStyle(color: Color(0xFFEF5350), fontSize: 11),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // ── Fond haut bleu ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.42,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Stack(
                  children: [
                    // Cercle décoratif haut-droite
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                    ),
                    // Cercle décoratif bas-gauche
                    Positioned(
                      bottom: -20,
                      left: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Contenu scrollable ──
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 32),

                          // ── Logo grand ──
                          _buildLogo(),

                          const SizedBox(height: 14),

                          // ── Titre ──
                          const Text(
                            'Bienvenue !',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Connectez-vous pour accéder\nà votre espace SRM Collecte',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Card formulaire ──
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 420),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1976D2).withOpacity(0.10),
                                    blurRadius: 32,
                                    offset: const Offset(0, 12),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
                              child: Form(
                                key: _formKey,
                                autovalidateMode: AutovalidateMode.onUserInteraction,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Titre card
                                    const Center(
                                      child: Text(
                                        'Connexion',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A2340),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // ── Champ Login ──
                                    TextFormField(
                                      controller: loginController,
                                      keyboardType: TextInputType.text,
                                      style: const TextStyle(
                                          color: Color(0xFF1A2340), fontSize: 14),
                                      decoration: _inputDeco(
                                        hint: 'Identifiant SRM',
                                        icon: Icons.person_outline_rounded,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Entrez votre login';
                                        }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 16),

                                    // ── Mot de passe ──
                                    TextFormField(
                                      controller: passwordController,
                                      obscureText: _obscurePwd,
                                      style: const TextStyle(
                                          color: Color(0xFF1A2340), fontSize: 14),
                                      decoration: _inputDeco(
                                        hint: 'Mot de passe',
                                        icon: Icons.lock_outline_rounded,
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscurePwd
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: const Color(0xFF90A4AE),
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                              () => _obscurePwd = !_obscurePwd),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Entrez votre mot de passe';
                                        }
                                        if (v.length < 4) {
                                          return 'Mot de passe trop court';
                                        }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 14),

                                    // ── Se souvenir + Mot de passe oublié ──
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: Checkbox(
                                            value: rememberMe,
                                            activeColor: const Color(0xFF2196F3),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            side: const BorderSide(
                                                color: Color(0xFFB0BEC5),
                                                width: 1.5),
                                            onChanged: (val) {
                                              setState(() {
                                                rememberMe = val ?? false;
                                                if (!rememberMe) {
                                                  loginController.clear();
                                                  passwordController.clear();
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Se souvenir',
                                          style: TextStyle(
                                              color: Color(0xFF607D8B),
                                              fontSize: 13),
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: _showForgotPasswordDialog,
                                          child: const Text(
                                            'Mot de passe oublié ?',
                                            style: TextStyle(
                                              color: Color(0xFF2196F3),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 24),

                                    // ── Bouton connexion ──
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1976D2),
                                          foregroundColor: Colors.white,
                                          elevation: 4,
                                          shadowColor: const Color(0xFF1976D2)
                                              .withOpacity(0.4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'Se connecter',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Pied de page ──
                          const Text(
                            'Collecter. Organiser. Exploiter vos données en toute simplicité.',
                            style: TextStyle(
                              color: Color(0xFF90A4AE),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'EP  •  ASS  •  ELEC',
                            style: TextStyle(
                              color: Color(0xFFB0BEC5),
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: const SrmLoginEmblem(),
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
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.water_drop,
          size: 52,
          color: Color(0xFF2196F3),
        ),
      ),
    );
  }
}
