// lib/screens/project/project_selection_page.dart
// â”€â”€ SPRINT 3 : SÃ©lection du projet et de la mission aprÃ¨s login â”€â”€
//
// Flux : Login â†’ projet_actif dÃ©jÃ  chargÃ© dans ApiService â†’ on affiche
// le projet actif + les missions de ce projet â†’ l'agent choisit/crÃ©e
// une mission â†’ accÃ¨s Ã  la carte (HomePage).
//
// Tables PostgreSQL :
//   public.projet  (id_projet, code_affaire, nom, srm, region, metier, statut)
//   public.mission (id_mission, id_agent, id_projet, etat_mission,
//                   date_debut, date_fin, nb_objets_collectesâ€¦)

import 'package:flutter/material.dart';
import '../../data/remote/api_service.dart';
import '../../data/local/database_helper.dart';
import '../home/home_page.dart';

class ProjectSelectionPage extends StatefulWidget {
  final String agentName;
  final bool isOnline;
  final VoidCallback onLogout;

  const ProjectSelectionPage({
    super.key,
    required this.agentName,
    required this.isOnline,
    required this.onLogout,
  });

  @override
  State<ProjectSelectionPage> createState() => _ProjectSelectionPageState();
}

class _ProjectSelectionPageState extends State<ProjectSelectionPage> {
  bool _loading = true;
  String? _error;

  // Projet actif (rempli par login)
  Map<String, dynamic>? _projetActif;

  // Missions disponibles
  List<Map<String, dynamic>> _missions = [];
  Map<String, dynamic>? _selectedMission;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // â”€â”€ Le projet actif est dÃ©jÃ  dans ApiService (renvoyÃ© par /api/login/) â”€â”€
    if (ApiService.currentProjetId != null) {
      _projetActif = {
        'id_projet': ApiService.currentProjetId,
        'code_affaire': ApiService.currentProjetCode,
        'nom': ApiService.currentProjetNom,
        'srm': ApiService.currentProjetSrm,
        'region': ApiService.currentProjetRegion,
        'metier': ApiService.currentProjetMetier,
        'statut': ApiService.currentProjetStatut,
      };
    }

    // â”€â”€ Charger les missions du projet â”€â”€
    if (ApiService.currentProjetId != null) {
      await _loadMissions(ApiService.currentProjetId!);
    } else {
      setState(() {
        _loading = false;
        _error = 'Aucun projet actif. Contactez votre administrateur.';
      });
    }
  }

  Future<void> _loadMissions(int projetId) async {
    try {
      if (widget.isOnline) {
        final missions = await ApiService.fetchMissions(projetId);
        await DatabaseHelper().saveMissionsLocal(missions, projetId);
        setState(() {
          _missions = missions;
          _loading = false;
        });
      } else {
        final missions = await DatabaseHelper().getMissionsLocal(projetId);
        setState(() {
          _missions = missions;
          _loading = false;
        });
      }
    } catch (e) {
      // Fallback SQLite
      try {
        final missions = await DatabaseHelper().getMissionsLocal(projetId);
        setState(() {
          _missions = missions;
          _loading = false;
        });
      } catch (_) {
        setState(() {
          _error = 'Impossible de charger les missions : $e';
          _loading = false;
        });
      }
    }
  }

  // â”€â”€ CrÃ©er une nouvelle mission â”€â”€
  Future<void> _createNewMission() async {
    if (!widget.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Création de mission impossible en mode hors-ligne')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final result =
          await ApiService.createMission(ApiService.currentProjetId!);
      if (result != null) {
        // Recharger les missions
        await _loadMissions(ApiService.currentProjetId!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nouvelle mission créée !')),
        );
      } else {
        setState(() => _loading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la création')),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  // â”€â”€ Valider et aller Ã  la carte â”€â”€
  void _onValidate() {
    if (_selectedMission == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une mission')),
      );
      return;
    }

    // Stocker l'id_mission dans ApiService
    final missionId = _selectedMission!['id_mission'];
    final parsedMissionId =
        missionId is int ? missionId : int.tryParse(missionId.toString());
    ApiService.currentMissionId = parsedMissionId;

    print('[MISSION] Projet: ${ApiService.currentProjetNom} '
        '(id=${ApiService.currentProjetId})');
    print('[MISSION] Mission: id_mission=${ApiService.currentMissionId}');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          agentName: widget.agentName,
          isOnline: widget.isOnline,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('SRM Collecte'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initData,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ En-tÃªte agent â”€â”€
          _buildAgentHeader(),
          const SizedBox(height: 24),

          // â”€â”€ Projet actif (pas de choix â€” dÃ©jÃ  assignÃ© par l'admin) â”€â”€
          const Text('Projet actif',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          if (_projetActif != null) _buildProjetCard(_projetActif!),
          if (_projetActif == null)
            const Text('Aucun projet actif',
                style: TextStyle(color: Color(0xFF64748B))),

          const SizedBox(height: 24),

          // â”€â”€ Missions â”€â”€
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sélectionnez une mission',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A))),
              if (widget.isOnline)
                TextButton.icon(
                  onPressed: _createNewMission,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvelle'),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_missions.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFEA580C)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aucune mission. Créez-en une pour démarrer la collecte.',
                      style:
                          TextStyle(color: Color(0xFFEA580C), fontSize: 14),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._missions.map((m) => _buildMissionCard(m)),

          const SizedBox(height: 30),

          // â”€â”€ Bouton Valider â”€â”€
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedMission != null ? _onValidate : null,
              icon: const Icon(Icons.map_rounded),
              label: const Text('Accéder à la carte',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF1976D2),
            child: Text(
              widget.agentName.isNotEmpty
                  ? widget.agentName[0].toUpperCase()
                  : 'A',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.agentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      widget.isOnline ? Icons.wifi : Icons.wifi_off,
                      size: 14,
                      color: widget.isOnline ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.isOnline ? 'En ligne' : 'Hors-ligne',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            widget.isOnline ? Colors.green : Colors.red,
                      ),
                    ),
                    if (ApiService.userRole != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ApiService.userRole!,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjetCard(Map<String, dynamic> projet) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3B82F6), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_rounded,
                    color: Color(0xFF3B82F6), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  projet['nom'] ?? 'Projet #${projet['id_projet']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF1E40AF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (projet['code_affaire'] != null)
                _chip(projet['code_affaire'], Icons.numbers),
              if (projet['srm'] != null)
                _chip(projet['srm'], Icons.business),
              if (projet['region'] != null)
                _chip(projet['region'], Icons.map_outlined),
              if (projet['metier'] != null)
                _chip(projet['metier'], Icons.build),
              if (projet['statut'] != null)
                _chipStatut(projet['statut']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard(Map<String, dynamic> mission) {
    final missionId = mission['id_mission'];
    final isSelected = _selectedMission != null &&
        _selectedMission!['id_mission'] == missionId;
    final etat = mission['etat_mission'] ?? 'EN_COURS';
    final nbObjets = mission['nb_objets_collectes'] ?? 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMission = mission;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF22C55E)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF22C55E).withOpacity(0.15)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.assignment_rounded,
                  color: isSelected
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF64748B),
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mission #$missionId',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSelected
                          ? const Color(0xFF166534)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _chipStatut(etat),
                      const SizedBox(width: 8),
                      Text('$nbObjets objets',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  if (mission['date_debut'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Début : ${mission['date_debut']}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF22C55E), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _chipStatut(String statut) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statutColor(statut).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        statut,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _statutColor(statut),
        ),
      ),
    );
  }

  Color _statutColor(String? statut) {
    switch (statut?.toUpperCase()) {
      case 'EN_COURS':
        return const Color(0xFF2563EB);
      case 'CLOTURE':
        return const Color(0xFF6B7280);
      case 'PROVISOIRE':
        return const Color(0xFFEA580C);
      case 'EN_PREPARATION':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF64748B);
    }
  }
}

