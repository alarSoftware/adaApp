import 'package:ada_app/services/data/data_usage_service.dart';
import 'package:ada_app/models/data_usage_record.dart';
import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart';

class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({Key? key}) : super(key: key);

  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen>
    with SingleTickerProviderStateMixin {
  final DataUsageService _dataUsageService = DataUsageService();

  Map<String, dynamic> _statistics = {};
  List<DataUsageRecord> _recentRecords = [];
  bool _isLoading = true;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _animationController.reset();

    try {
      final stats = await _dataUsageService.getStatistics();
      final recent = await _dataUsageService.getRecentRecords(limit: 500);

      setState(() {
        _statistics = stats;
        _recentRecords = recent;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando datos: $e')));
      }
    }
  }

  String _formatBytes(num bytes) {
    if (bytes < 1024) return '${bytes.toInt()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50] ?? Colors.white,
      appBar: AppBar(
        title: const Text(
          'Monitor de Datos',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: FadeTransition(
                opacity: _animationController,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 28),
                    _buildCategoryBreakdown(),
                    const SizedBox(height: 32),
                    _buildRecentActivity(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    final today = _statistics['today'] as int? ?? 0;
    final week = _statistics['week'] as int? ?? 0;
    final month = _statistics['month'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Resumen Global',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Icon(Icons.analytics_rounded, color: AppColors.primary, size: 28),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildGradientCard(
                title: 'Hoy',
                value: _formatBytes(today),
                icon: Icons.today_rounded,
                colors: [Color(0xFF4776E6), Color(0xFF8E54E9)],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildGradientCard(
                title: 'Últimos 7 días',
                value: _formatBytes(week),
                icon: Icons.date_range_rounded,
                colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGradientCard(
          title: 'Últimos 30 días',
          value: _formatBytes(month),
          icon: Icons.data_usage_rounded,
          // Verde más oscuro, menos fuerte a la vista
          colors: [Color(0xFF0B6623), Color(0xFF2E8B57)],
          isLarge: true,
        ),
      ],
    );
  }

  Widget _buildGradientCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> colors,
    bool isLarge = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isLarge ? 24 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isLarge ? 16 : 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isLarge ? 20 : 16),
          Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 32 : 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categories = _statistics['categories'] as Map<String, int>? ?? {};
    if (categories.isEmpty) return const SizedBox.shrink();

    final total = categories.values.fold(0, (sum, value) => sum + value);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Desglose por Tráfico',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: categories.entries.map((entry) {
              final percentage = (entry.value / total * 100);
              return _buildCategoryItem(
                label: _getCategoryLabel(entry.key),
                bytes: entry.value,
                percentage: percentage,
                color: _getCategoryColor(entry.key),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem({
    required String label,
    required int bytes,
    required double percentage,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.circle, color: color, size: 10),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                _formatBytes(bytes),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                height: 8,
                width: MediaQuery.of(context).size.width * (percentage / 100),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Daily chart removed as requested

  Widget _buildRecentActivity() {
    if (_recentRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'Sin actividad reciente',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 1. Agrupar registros
    final groupedRecords = <String, List<DataUsageRecord>>{};
    num totalRecentBytes = 0;
    int totalPeticiones = 0;

    for (final record in _recentRecords) {
      final endpointLabel = _extractEndpointLabel(record.endpoint);
      final key = '${record.operationType}_$endpointLabel';

      if (!groupedRecords.containsKey(key)) {
        groupedRecords[key] = [];
      }
      groupedRecords[key]!.add(record);
      totalRecentBytes += record.totalBytes;
      totalPeticiones++;
    }

    // 2. Crear resúmenes
    final summaryList = groupedRecords.entries.map((entry) {
      final records = entry.value;
      final first = records.first;
      final totalBytes = records.fold(0, (sum, r) => sum + r.totalBytes);
      final count = records.length;
      final latestTimestamp = records
          .map((r) => r.timestamp)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      final errorCount = records
          .where((r) => r.statusCode != null && r.statusCode! >= 400)
          .length;
      final lastError = records
          .firstWhere(
            (r) => r.statusCode != null && r.statusCode! >= 400,
            orElse: () => first,
          )
          .errorMessage;

      return _GroupedUsageItem(
        operationType: first.operationType,
        operationTypeLabel: first.operationTypeLabel,
        endpointLabel: _extractEndpointLabel(first.endpoint),
        totalBytes: totalBytes,
        count: count,
        latestTimestamp: latestTimestamp,
        errorCount: errorCount,
        lastErrorMessage: lastError,
      );
    }).toList();

    summaryList.sort(
      (a, b) => b.totalBytes.compareTo(a.totalBytes),
    ); // Sort by heaviest consumptions

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Top Consumos Recientes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '$totalPeticiones pets.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...summaryList.map((item) {
          final percentage = totalRecentBytes > 0
              ? (item.totalBytes / totalRecentBytes * 100)
              : 0.0;
          return _buildAggregatedActivityCard(item, percentage);
        }).toList(),
      ],
    );
  }

  Widget _buildAggregatedActivityCard(
    _GroupedUsageItem item,
    double percentage,
  ) {
    final color = _getCategoryColor(item.operationType);
    final hasErrors = item.errorCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(item.operationType),
                color: color,
                size: 24,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.endpointLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'x${item.count}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.operationTypeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatBytes(item.totalBytes),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    top: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      'Última actividad:',
                      _formatTime(item.latestTimestamp),
                    ),
                    _buildDetailRow(
                      'Promedio por petición:',
                      _formatBytes(item.totalBytes / item.count),
                    ),
                    if (hasErrors) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.errorCount} errores detectados.\nÚltimo: ${item.lastErrorMessage ?? "Error desconocido"}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(String type) {
    switch (type.toLowerCase()) {
      case 'sync':
        return 'Sincronización Múltiple';
      case 'post':
        return 'Subida de Datos';
      case 'get':
        return 'Descarga de Datos';
      default:
        return type.toUpperCase();
    }
  }

  Color _getCategoryColor(String type) {
    switch (type.toLowerCase()) {
      case 'sync':
        return const Color(0xFF00B4DB);
      case 'post':
        return const Color(0xFF8E54E9);
      case 'get':
        return const Color(0xFF2E8B57);
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'sync':
        return Icons.sync_rounded;
      case 'post':
        return Icons.cloud_upload_rounded;
      case 'get':
        return Icons.cloud_download_rounded;
      default:
        return Icons.data_usage_rounded;
    }
  }

  String _extractEndpointLabel(String endpoint) {
    String label = endpoint;
    final uri = Uri.tryParse(endpoint);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      var segment = uri.pathSegments.last;
      if (int.tryParse(segment) != null && uri.pathSegments.length > 1) {
        segment = uri.pathSegments[uri.pathSegments.length - 2];
      }
      label = segment;
    }
    return _formatFriendlyName(label);
  }

  String _formatFriendlyName(String text) {
    if (text.isEmpty) return text;
    String formatted = text.replaceAll(RegExp(r'[_-]'), ' ');
    formatted = formatted.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (m) => ' ',
    );
    return formatted
        .split(' ')
        .map((word) {
          if (word.trim().isEmpty) return '';
          if (word.length == 1) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ')
        .trim();
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Hace instantes';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
    return '${timestamp.day}/${timestamp.month} a las ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class _GroupedUsageItem {
  final String operationType;
  final String operationTypeLabel;
  final String endpointLabel;
  final int totalBytes;
  final int count;
  final DateTime latestTimestamp;
  final int errorCount;
  final String? lastErrorMessage;

  _GroupedUsageItem({
    required this.operationType,
    required this.operationTypeLabel,
    required this.endpointLabel,
    required this.totalBytes,
    required this.count,
    required this.latestTimestamp,
    this.errorCount = 0,
    this.lastErrorMessage,
  });
}
