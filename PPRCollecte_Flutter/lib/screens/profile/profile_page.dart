// lib/screens/profile/profile_page.dart
// Sprint 6 — Page Profil + Dashboard SRM
import 'package:flutter/material.dart';
import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';

class ProfilePage extends StatefulWidget {
  final String agentName;
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.agentName,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseHelper _db = DatabaseHelper();

  bool _isLoading = true;

  // Infos utilisateur
  String _nomPrenom = '';
  String _login = '';
  String _role = '';

  // Infos projet/mission
  String _projetNom = '';
  String _projetCode = '';
  String _projetRegion = '';

  // Compteurs par métier
  int _totalEP = 0;
  int _totalASS = 0;
  int _totalELEC = 0;
  int _totalSynced = 0;
  int _totalUnsynced = 0;

  // Compteurs par type de géométrie
  int _totalPoints = 0;
  int _totalLignes = 0;
  int _totalPolygones = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // ── Infos utilisateur ──
      _nomPrenom = ApiService.nomPrenom ?? widget.agentName;
      _login = ApiService.userLogin ?? '';
      _role = ApiService.userRole ?? '';

      // ── Infos projet ──
      _projetNom = ApiService.currentProjetNom ?? '';
      _projetCode = ApiService.currentProjetCode ?? '';
      _projetRegion = ApiService.currentProjetRegion ?? '';

      // ── Compteurs entités ──
      int epCount = 0, assCount = 0, elecCount = 0;
      int synced = 0, unsynced = 0;
      int points = 0, lignes = 0, polygones = 0;

      for (final metier in SrmConfig.getMetiers()) {
        for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
          final tableName = SrmConfig.getTableName(metier, entity);
          if (tableName == null || tableName.isEmpty) continue;

          try {
            final rows = await _db.getEntitiesSrm(tableName);
            final count = rows.length;

            // Par métier
            if (metier == 'Eau Potable') epCount += count;
            if (metier == 'Assainissement') assCount += count;
            if (metier == 'Électricité') elecCount += count;

            // Synced / Unsynced
            for (final row in rows) {
              final s = (row['synced']?.toString() == '1');
              if (s) synced++; else unsynced++;
            }

            // Par géométrie
            final config = SrmConfig.getEntityConfig(metier, entity);
            if (config != null) {
              final geo = config['geometryType'] as String? ?? 'Point';
              if (geo == 'Point') points += count;
              if (geo == 'LineString') lignes += count;
              if (geo == 'Polygon') polygones += count;
            }
          } catch (_) {
            // table pas encore créée → 0
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalEP = epCount;
          _totalASS = assCount;
          _totalELEC = elecCount;
          _totalSynced = synced;
          _totalUnsynced = unsynced;
          _totalPoints = points;
          _totalLignes = lignes;
          _totalPolygones = polygones;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: const Text(
          'Profil & Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF1B4F72),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  _buildProjetCard(),
                  const SizedBox(height: 16),
                  _buildDashboardMetier(),
                  const SizedBox(height: 16),
                  _buildDashboardGeometrie(),
                  const SizedBox(height: 16),
                  _buildDashboardSync(),
                  const SizedBox(height: 24),
                  _buildLogoutButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  // ── Carte Profil ──────────────────────────────────────────────────
  Widget _buildProfileCard() {
    final initials = _nomPrenom.isNotEmpty
        ? _nomPrenom
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : '?';

    final roleColor = _role == 'admin'
        ? const Color(0xFF1B4F72)
        : _role == 'editeur_terrain'
            ? const Color(0xFF27AE60)
            : const Color(0xFF8E44AD);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1B4F72),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B4F72).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nomPrenom.isNotEmpty ? _nomPrenom : widget.agentName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B4F72),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$_login',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: roleColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _role.isNotEmpty ? _role : 'agent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: roleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Carte Projet ──────────────────────────────────────────────────
  Widget _buildProjetCard() {
    return _buildSection(
      title: '📋 Projet',
      color: const Color(0xFF1976D2),
      children: [
        _buildInfoRow(Icons.work_outline, 'Projet', _projetNom),
        _buildInfoRow(Icons.tag, 'Code affaire', _projetCode),
        _buildInfoRow(Icons.map_outlined, 'Région', _projetRegion),
      ],
    );
  }

  // ── Dashboard par Métier ──────────────────────────────────────────
  Widget _buildDashboardMetier() {
    final total = _totalEP + _totalASS + _totalELEC;
    return _buildSection(
      title: '📊 Objets collectés par métier',
      color: const Color(0xFF1B4F72),
      children: [
        _buildMetierBar('Eau Potable', _totalEP, total, const Color(0xFF1976D2)),
        const SizedBox(height: 8),
        _buildMetierBar('Assainissement', _totalASS, total, const Color(0xFF27AE60)),
        const SizedBox(height: 8),
        _buildMetierBar('Électricité', _totalELEC, total, const Color(0xFFF39C12)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B4F72).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.layers, size: 20, color: Color(0xFF1B4F72)),
              const SizedBox(width: 8),
              Text(
                'Total : $total objet${total > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4F72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetierBar(
      String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            Text('$count',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ── Dashboard par Géométrie ───────────────────────────────────────
  Widget _buildDashboardGeometrie() {
    return _buildSection(
      title: '📐 Par type de géométrie',
      color: const Color(0xFF8E44AD),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGeoCard(
                  '📍', 'Points', _totalPoints, const Color(0xFF1976D2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildGeoCard(
                  '〰️', 'Lignes', _totalLignes, const Color(0xFF27AE60)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildGeoCard(
                  '⬡', 'Polygones', _totalPolygones, const Color(0xFFF39C12)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGeoCard(String emoji, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }

  // ── Dashboard Synchronisation ─────────────────────────────────────
  Widget _buildDashboardSync() {
    final total = _totalSynced + _totalUnsynced;
    final pct = total > 0 ? _totalSynced / total : 0.0;

    return _buildSection(
      title: '🔄 État de synchronisation',
      color: const Color(0xFF2196F3),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSyncCard('En attente', _totalUnsynced,
                  const Color(0xFFF39C12), Icons.schedule),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSyncCard('Synchronisés', _totalSynced,
                  const Color(0xFF27AE60), Icons.cloud_done),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progression sync',
                    style: TextStyle(fontSize: 13)),
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: const Color(0xFF27AE60).withOpacity(0.15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF27AE60)),
                minHeight: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncCard(
      String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF666666))),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bouton Déconnexion ────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Déconnexion'),
              content: const Text('Voulez-vous vous déconnecter ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    widget.onLogout();
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Déconnecter',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text('Se déconnecter',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(color: color.withOpacity(0.2))),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1976D2)),
          const SizedBox(width: 10),
          Text('$label : ',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF666666))),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
