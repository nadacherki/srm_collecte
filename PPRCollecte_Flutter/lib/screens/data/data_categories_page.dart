import 'package:flutter/material.dart';

import 'anomaly_treatment_page.dart';
import 'srm_data_status_page.dart';

class DataCategoriesPage extends StatelessWidget {
  final bool isOnline;
  final String agentName;

  const DataCategoriesPage({
    super.key,
    required this.isOnline,
    required this.agentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F7FB),
      appBar: AppBar(
        toolbarHeight: 58,
        title: const Text(
          'Données',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF1976D2),
                Color(0xFF42A5F5),
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              children: [
                const Text(
                  'Choisissez un statut de données',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),
                _buildCategoryCard(
                  context,
                  title: 'Données Enregistrées',
                  description:
                      'Données créées localement, pas encore synchronisées',
                  icon: Icons.save_alt,
                  color: const Color(0xFF7C3AED),
                  accentColor: const Color(0xFFEDE9FE),
                  dataFilter: 'unsynced',
                ),
                const SizedBox(height: 16),
                _buildCategoryCard(
                  context,
                  title: 'Données Synchronisées',
                  description: 'Données locales déjà envoyées au serveur',
                  icon: Icons.cloud_done,
                  color: const Color(0xFF0284C7),
                  accentColor: const Color(0xFFE0F2FE),
                  dataFilter: 'synced',
                ),
                const SizedBox(height: 16),
                _buildCategoryCard(
                  context,
                  title: 'Données Téléchargées',
                  description: 'Données récupérées depuis le serveur',
                  icon: Icons.cloud_download,
                  color: const Color(0xFF059669),
                  accentColor: const Color(0xFFD1FAE5),
                  dataFilter: 'saved',
                ),
                const SizedBox(height: 16),
                _buildCategoryCard(
                  context,
                  title: 'Traitement des anomalies',
                  description: 'Suivi exploitant et retours terrain à compléter',
                  icon: Icons.build,
                  color: const Color(0xFFD97706),
                  accentColor: const Color(0xFFFEF3C7),
                  dataFilter: 'all',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnomalyTreatmentPage(
                          isOnline: isOnline,
                          agentName: agentName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required Color accentColor,
    required String dataFilter,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SrmDataStatusPage(
                    title: title,
                    dataFilter: dataFilter,
                    isOnline: isOnline,
                    agentName: agentName,
                  ),
                ),
              );
            },
        child: Container(
          constraints: const BoxConstraints(minHeight: 118),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 23, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.28,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 15,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
