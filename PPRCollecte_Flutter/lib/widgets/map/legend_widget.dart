// Légende SRM dynamique basée sur SrmConfig.

import 'package:flutter/material.dart';
import '../../core/config/srm_config.dart';
import '../common/custom_marker_icons.dart';

class LegendWidget extends StatefulWidget {
  final Map<String, bool> initialVisibility;
  final Function(Map<String, bool>) onVisibilityChanged;

  /// Compteur d'objets par table (fourni par home_page)
  final Map<String, int> pointCountsByTable;

  /// Compteur d'anomalies par table (fourni par home_page)
  final Map<String, int> anomalieCountsByTable;

  /// Compteur d'objets incomplets par table (fourni par home_page)
  final Map<String, int> incompletCountsByTable;

  // Paramètres conservés pour préserver la signature existante dans home_page.
  final List<dynamic> allPolylines;
  final List<dynamic> allMarkers;
  final int polygonCount;

  /// Callback notifiant home_page quand la légende s'ouvre ou se ferme.
  final ValueChanged<bool>? onExpandedChanged;

  const LegendWidget({
    super.key,
    required this.initialVisibility,
    required this.onVisibilityChanged,
    this.pointCountsByTable = const {},
    this.anomalieCountsByTable = const {},
    this.incompletCountsByTable = const {},
    this.allPolylines = const [],
    this.allMarkers = const [],
    this.polygonCount = 0,
    this.onExpandedChanged,
  });

  @override
  State<LegendWidget> createState() => _LegendWidgetState();
}

class _LegendWidgetState extends State<LegendWidget> {
  static const String _readOnlyRegardMiroirTable = 'regard_miroir';
  late Map<String, bool> _visibility;
  bool _isExpanded = false;
  bool _anomalieFilterActive = false;
  bool _incompletFilterActive = false;

  final Map<String, bool> _metierExpanded = {};

  static const Map<String, Color> _metierColor = {
    'Eau Potable':    Color(0xFF1565C0),
    'Assainissement': Color(0xFF2E7D32),
    'Électricité':    Color(0xFFE65100),
  };

  static const Map<String, IconData> _metierIcon = {
    'Eau Potable':    Icons.water_drop,
    'Assainissement': Icons.waves,
    'Électricité':    Icons.bolt,
  };

  static String _vk(String tableName) => 'srm_$tableName';
  static String _mk(String metier) => 'srm_metier_$metier';

  Iterable<String> _readOnlyTablesForMetier(String metier) sync* {
    if (metier == 'Eau Potable') {
      yield _readOnlyRegardMiroirTable;
    }
  }

  @override
  void initState() {
    super.initState();
    _visibility = Map<String, bool>.from(widget.initialVisibility);
    for (final m in SrmConfig.getMetiers()) {
      _metierExpanded[m] = false;
      if (!_visibility.containsKey(_mk(m))) _visibility[_mk(m)] = true;
      for (final entity in SrmConfig.getEntitiesForMetier(m)) {
        final t = SrmConfig.getTableName(m, entity);
        if (t != null && !_visibility.containsKey(_vk(t))) {
          _visibility[_vk(t)] = true;
        }
      }
    }
    _anomalieFilterActive = _visibility['srm_anomalie'] == true;
    _incompletFilterActive = _visibility['srm_incomplet'] == true;
    _visibility.putIfAbsent(_vk(_readOnlyRegardMiroirTable), () => true);
  }

  void _toggle(String key, bool value) {
    setState(() {
      _visibility[key] = value;
      widget.onVisibilityChanged(Map.from(_visibility));
    });
  }

  void _toggleMetier(String metier, bool value) {
    setState(() {
      _visibility[_mk(metier)] = value;
      for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
        final t = SrmConfig.getTableName(metier, entity);
        if (t != null) _visibility[_vk(t)] = value;
      }
      for (final table in _readOnlyTablesForMetier(metier)) {
        _visibility[_vk(table)] = value;
      }
      widget.onVisibilityChanged(Map.from(_visibility));
    });
  }

  void _toggleAnomalieFilter(bool value) {
    setState(() {
      _anomalieFilterActive = value;
      _visibility['srm_anomalie'] = value;
      widget.onVisibilityChanged(Map.from(_visibility));
    });
  }

  void _toggleIncompletFilter(bool value) {
    setState(() {
      _incompletFilterActive = value;
      _visibility['srm_incomplet'] = value;
      widget.onVisibilityChanged(Map.from(_visibility));
    });
  }

  int _countForTable(String table) => widget.pointCountsByTable[table] ?? 0;
  int _anomaliesForTable(String table) => widget.anomalieCountsByTable[table] ?? 0;
  int _incompletForTable(String table) => widget.incompletCountsByTable[table] ?? 0;

  int _totalForMetier(String metier) {
    int t = 0;
    for (final e in SrmConfig.getEntitiesForMetier(metier)) {
      final tn = SrmConfig.getTableName(metier, e);
      if (tn != null) t += _countForTable(tn);
    }
    return t;
  }

  int _anomaliesForMetier(String metier) {
    int t = 0;
    for (final e in SrmConfig.getEntitiesForMetier(metier)) {
      final tn = SrmConfig.getTableName(metier, e);
      if (tn != null) t += _anomaliesForTable(tn);
    }
    return t;
  }

  int _incompletForMetier(String metier) {
    int t = 0;
    for (final e in SrmConfig.getEntitiesForMetier(metier)) {
      final tn = SrmConfig.getTableName(metier, e);
      if (tn != null) t += _incompletForTable(tn);
    }
    return t;
  }

  int get _totalObjects =>
      widget.pointCountsByTable.entries
          .where((entry) => entry.key != _readOnlyRegardMiroirTable)
          .fold(0, (sum, entry) => sum + entry.value);

  int get _totalAnomalies =>
      widget.anomalieCountsByTable.entries
          .where((entry) => entry.key != _readOnlyRegardMiroirTable)
          .fold(0, (sum, entry) => sum + entry.value);

  int get _totalIncompletes =>
      widget.incompletCountsByTable.entries
          .where((entry) => entry.key != _readOnlyRegardMiroirTable)
          .fold(0, (sum, entry) => sum + entry.value);

  bool _isMetierFullyChecked(String metier) {
    for (final e in SrmConfig.getEntitiesForMetier(metier)) {
      final t = SrmConfig.getTableName(metier, e);
      if (t != null && !(_visibility[_vk(t)] ?? true)) return false;
    }
    for (final t in _readOnlyTablesForMetier(metier)) {
      if (!(_visibility[_vk(t)] ?? true)) return false;
    }
    return true;
  }

  bool _isMetierPartiallyChecked(String metier) {
    bool anyOn = false, anyOff = false;
    for (final e in SrmConfig.getEntitiesForMetier(metier)) {
      final t = SrmConfig.getTableName(metier, e);
      if (t == null) continue;
      if (_visibility[_vk(t)] ?? true) {
        anyOn = true;
      } else {
        anyOff = true;
      }
    }
    for (final t in _readOnlyTablesForMetier(metier)) {
      if (_visibility[_vk(t)] ?? true) {
        anyOn = true;
      } else {
        anyOff = true;
      }
    }
    return anyOn && anyOff;
  }

  //  BUILD
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 105,
      right: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (_isExpanded) _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: () {
        setState(() => _isExpanded = !_isExpanded);
        widget.onExpandedChanged?.call(_isExpanded);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isExpanded
                  ? Icons.legend_toggle
                  : Icons.legend_toggle_outlined,
              size: 20,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 8),
            const Text('Légende',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (_totalObjects > 0) ...[
              const SizedBox(width: 6),
              _badge(_totalObjects, color: Colors.grey.shade600),
            ],
            // Badge anomalie toujours visible dans le header si des anomalies existent
            if (_totalIncompletes > 0) ...[              const SizedBox(width: 4),
              _badge(_totalIncompletes,
                  color: const Color(0xFFF57C00),
                  icon: Icons.edit_off),
            ],
            if (_totalAnomalies > 0) ...[
              const SizedBox(width: 4),
              _badge(_totalAnomalies,
                  color: const Color(0xFFD32F2F),
                  icon: Icons.warning_amber_rounded),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: Colors.grey.shade300),
        Container(
          constraints: const BoxConstraints(maxHeight: 520, maxWidth: 272),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnomalieFilter(),
                const SizedBox(height: 8),
                _buildIncompletFilter(),
                const SizedBox(height: 10),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 6),
                ...SrmConfig.getMetiers().map(_buildMetierSection),
              ],
            ),
          ),
        ),
      ],
    );
  }

  //  FILTRE ANOMALIE
  Widget _buildAnomalieFilter() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _anomalieFilterActive
            ? const Color(0xFFD32F2F).withOpacity(0.07)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _anomalieFilterActive
              ? const Color(0xFFD32F2F).withOpacity(0.45)
              : Colors.grey.shade200,
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          // Panneau triangle danger (mini version)
          SizedBox(
            width: 28,
            height: 28,
            child: CustomPaint(
              painter: _MiniWarningPainter(),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Isoler les anomalies',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _anomalieFilterActive
                        ? const Color(0xFFD32F2F)
                        : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _anomalieFilterActive
                      ? 'Uniquement les objets en anomalie'
                      : 'Anomalies toujours visibles en rouge',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (_totalAnomalies > 0) ...[
            _badge(_totalAnomalies,
                color: const Color(0xFFD32F2F),
                icon: Icons.warning_amber_rounded),
            const SizedBox(width: 4),
          ],
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: _anomalieFilterActive,
              onChanged: _toggleAnomalieFilter,
              activeThumbColor: const Color(0xFFD32F2F),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncompletFilter() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _incompletFilterActive
            ? const Color(0xFFF57C00).withOpacity(0.07)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _incompletFilterActive
              ? const Color(0xFFF57C00).withOpacity(0.45)
              : Colors.grey.shade200,
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          // Mini cercle orange avec ?
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF57C00),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Isoler les incomplets',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _incompletFilterActive
                        ? const Color(0xFFF57C00)
                        : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _incompletFilterActive
                      ? 'Uniquement les objets incomplets'
                      : 'Incomplets toujours visibles en orange',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (_totalIncompletes > 0) ...[
            _badge(_totalIncompletes,
                color: const Color(0xFFF57C00),
                icon: Icons.edit_off),
            const SizedBox(width: 4),
          ],
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: _incompletFilterActive,
              onChanged: _toggleIncompletFilter,
              activeThumbColor: const Color(0xFFF57C00),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetierSection(String metier) {
    final color = _metierColor[metier] ?? Colors.grey;
    final icon = _metierIcon[metier] ?? Icons.category;
    final isExpanded = _metierExpanded[metier] ?? false;
    final isFullyChecked = _isMetierFullyChecked(metier);
    final isPartial = _isMetierPartiallyChecked(metier);
    final total = _totalForMetier(metier);
    final anomalies = _anomaliesForMetier(metier);
    final incomplets = _incompletForMetier(metier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              setState(() => _metierExpanded[metier] = !isExpanded),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                // Checkbox tristate parent
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isPartial ? null : isFullyChecked,
                    tristate: true,
                    onChanged: (_) =>
                        _toggleMetier(metier, !isFullyChecked),
                    activeColor: color,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: (isFullyChecked || isPartial)
                        ? color
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(icon, color: Colors.white, size: 13),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    metier,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: (isFullyChecked || isPartial)
                          ? Colors.grey.shade800
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
                if (total > 0) _badge(total, color: color),
                if (incomplets > 0) ...[
                  const SizedBox(width: 3),
                  _badge(incomplets,
                      color: const Color(0xFFF57C00),
                      icon: Icons.edit_off),
                ],
                if (anomalies > 0) ...[
                  const SizedBox(width: 3),
                  _badge(anomalies,
                      color: const Color(0xFFD32F2F),
                      icon: Icons.warning_amber_rounded),
                ],
                const SizedBox(width: 3),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ),

        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2, bottom: 4),
            child: Column(
              children: [
                ...SrmConfig.getEntitiesForMetier(metier)
                    .map((e) => _buildEntityRow(metier, e, color)),
                if (metier == 'Eau Potable')
                  _buildReadOnlyPolygonRow(
                    label: 'Regard miroir',
                    tableName: _readOnlyRegardMiroirTable,
                    color: const Color(0xFF2E7D32),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildEntityRow(String metier, String entity, Color metierColor) {
    final tableName = SrmConfig.getTableName(metier, entity);
    if (tableName == null) return const SizedBox.shrink();

    final visKey = _vk(tableName);
    final isVisible = _visibility[visKey] ?? true;
    final count = _countForTable(tableName);
    final anomalies = _anomaliesForTable(tableName);
    final incomplets = _incompletForTable(tableName);

    final iconCfg = CustomMarkerIcons.iconConfig[tableName];
    final entityIcon = iconCfg?.icon ?? Icons.location_pin;
    final entityColor = isVisible
        ? (iconCfg?.color ?? metierColor)
        : Colors.grey.shade300;

    final isLine = SrmConfig.isLineEntity(metier, entity);
    final isPolygon = SrmConfig.isPolygonEntity(metier, entity);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: isVisible,
              onChanged: (v) => _toggle(visKey, v ?? false),
              activeColor: iconCfg?.color ?? metierColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 5),
          if (isLine)
            _lineSymbol(
              entityColor,
              hasAnomalie: anomalies > 0,
              hasIncomplet: incomplets > 0,
            )
          else if (isPolygon)
            _polygonSymbol(
              entityColor,
              hasAnomalie: anomalies > 0,
              hasIncomplet: incomplets > 0,
            )
          else
            _pointSymbol(entityIcon, entityColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entity,
              style: TextStyle(
                fontSize: 11,
                color: isVisible
                    ? Colors.grey.shade700
                    : Colors.grey.shade400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (incomplets > 0) ...[
            _badge(incomplets,
                color: const Color(0xFFF57C00),
                icon: Icons.edit_off,
                small: true),
            const SizedBox(width: 3),
          ],
          if (anomalies > 0) ...[
            _badge(anomalies,
                color: const Color(0xFFD32F2F),
                icon: Icons.warning_amber_rounded,
                small: true),
            const SizedBox(width: 3),
          ],
          if (count > 0)
            _badge(count,
                color: iconCfg?.color ?? metierColor, small: true),
        ],
      ),
    );
  }

  Widget _pointSymbol(IconData icon, Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(icon, color: Colors.white, size: 11),
    );
  }

  Widget _lineSymbol(
    Color color, {
    bool hasAnomalie = false,
    bool hasIncomplet = false,
  }) {
    final displayColor = hasAnomalie
        ? const Color(0xFFD32F2F)
        : hasIncomplet
            ? const Color(0xFFF57C00)
            : color;
    return SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 20,
              height: hasAnomalie || hasIncomplet ? 4 : 3,
              decoration: BoxDecoration(
                color: displayColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (hasAnomalie)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (_) => Container(
                    width: 3,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              )
            else if (hasIncomplet)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  4,
                  (_) => Container(
                    width: 2,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyPolygonRow({
    required String label,
    required String tableName,
    required Color color,
  }) {
    final visKey = _vk(tableName);
    final isVisible = _visibility[visKey] ?? true;
    final count = _countForTable(tableName);
    final anomalies = _anomaliesForTable(tableName);
    final incomplets = _incompletForTable(tableName);
    final displayColor = isVisible ? color : Colors.grey.shade300;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: isVisible,
              onChanged: (v) => _toggle(visKey, v ?? false),
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 5),
          _polygonSymbol(
            displayColor,
            hasAnomalie: anomalies > 0,
            hasIncomplet: incomplets > 0,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isVisible
                    ? Colors.grey.shade700
                    : Colors.grey.shade400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (incomplets > 0) ...[
            _badge(incomplets,
                color: const Color(0xFFF57C00),
                icon: Icons.edit_off,
                small: true),
            const SizedBox(width: 3),
          ],
          if (anomalies > 0) ...[
            _badge(anomalies,
                color: const Color(0xFFD32F2F),
                icon: Icons.warning_amber_rounded,
                small: true),
            const SizedBox(width: 3),
          ],
          if (count > 0)
            _badge(count, color: color, small: true),
        ],
      ),
    );
  }

  Widget _polygonSymbol(
    Color color, {
    bool hasAnomalie = false,
    bool hasIncomplet = false,
  }) {
    final displayColor = hasAnomalie
        ? const Color(0xFFD32F2F)
        : hasIncomplet
            ? const Color(0xFFF57C00)
            : color;
    return SizedBox(
      width: 22,
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 22,
            height: 16,
            decoration: BoxDecoration(
              color: displayColor.withOpacity(hasAnomalie || hasIncomplet ? 0.28 : 0.0),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: displayColor,
                width: hasAnomalie || hasIncomplet ? 2.2 : 1.8,
              ),
            ),
          ),
          if (hasAnomalie)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (_) => Container(
                  width: 2,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            )
          else if (hasIncomplet)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                4,
                (_) => Container(
                  width: 2,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(int count,
      {required Color color, IconData? icon, bool small = false}) {
    if (count <= 0) return const SizedBox.shrink();
    final double fs = small ? 9 : 10;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 4 : 6, vertical: small ? 1 : 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fs + 1, color: color),
            const SizedBox(width: 2),
          ],
          Text(count.toString(),
              style: TextStyle(
                  fontSize: fs,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MiniWarningPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.50, h * 0.04)
      ..lineTo(w * 0.97, h * 0.94)
      ..lineTo(w * 0.03, h * 0.94)
      ..close();

    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE53935)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.11
        ..strokeJoin = StrokeJoin.round,
    );

    final p = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(w * 0.50, h * 0.52),
            width: w * 0.12,
            height: h * 0.28),
        Radius.circular(w * 0.06),
      ),
      p,
    );
    canvas.drawCircle(Offset(w * 0.50, h * 0.80), w * 0.075, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

