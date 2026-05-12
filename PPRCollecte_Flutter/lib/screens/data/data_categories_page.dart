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

  String _getDataFilterType(String categoryTitle) {
    switch (categoryTitle) {
      case 'Données Enregistrées':
        return 'unsynced';
      case 'Données Synchronisées':
        return 'synced';
      case 'Données Téléchargées':
        return 'saved';
      default:
        return 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: const Text(
          'Données',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choisissez un statut de données',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 1,
                mainAxisSpacing: 16,
                childAspectRatio: 3,
                children: [
                  _buildCategoryCard(
                    context,
                    title: 'Données Enregistrées',
                    description:
                        'Données créées localement, non encore synchronisées',
                    icon: Icons.save,
                    color: const Color.fromARGB(255, 167, 94, 196),
                  ),
                  _buildCategoryCard(
                    context,
                    title: 'Données Synchronisées',
                    description: 'Données locales déjà envoyées au serveur',
                    icon: Icons.cloud_upload,
                    color: const Color(0xFF2196F3),
                  ),
                  _buildCategoryCard(
                    context,
                    title: 'Données Téléchargées',
                    description: 'Données récupérées depuis le serveur',
                    icon: Icons.cloud_download,
                    color: const Color(0xFF4CAF50),
                  ),
                  _buildCategoryCard(
                    context,
                    title: 'Traitement des anomalies',
                    description:
                        'Suivi exploitant et retours terrain à compléter',
                    icon: Icons.construction,
                    color: const Color(0xFFFF9800),
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
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SrmDataStatusPage(
                  title: title,
                  dataFilter: _getDataFilterType(title),
                  isOnline: isOnline,
                  agentName: agentName,
                ),
              ),
            );
          },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 24,
                color: Color(0xFF999999),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
