import 'package:ada_app/services/data/data_usage_service.dart';
import 'package:ada_app/models/data_usage_record.dart';
import 'package:flutter/material.dart';
import 'package:ada_app/ui/theme/colors.dart'; // Correct path

class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({Key? key}) : super(key: key);

  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen> {
  final DataUsageService _dataUsageService = DataUsageService();

  Map<String, dynamic> _statistics = {};
  List<DataUsageRecord> _recentRecords = [];
  Map<String, int> _dailyUsage = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final stats = await _dataUsageService.getStatistics();
      final recent = await _dataUsageService.getRecentRecords(limit: 200);
      final daily = await _dataUsageService.getDailyUsage(7);

      setState(() {
        _statistics = stats;
        _recentRecords = recent;
        _dailyUsage = daily;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando datos: $e')));
      }
    }
  }

  String _formatBytes(int bytes) {
    return DataUsageRecord(
      timestamp: DateTime.now(),
      operationType: '',
      endpoint: '',
      bytesSent: 0,
      bytesReceived: bytes,
      totalBytes: bytes,
    ).formattedTotalBytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consumo de Datos'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar',
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
                  // Cards de resumen
                  _buildSummaryCards(),
                  const SizedBox(height: 24),

                  // Desglose por categoría
                  _buildCategoryBreakdown(),
                  const SizedBox(height: 24),

                  // Gráfico de consumo diario
                  _buildDailyChart(),
                  const SizedBox(height: 24),

                  // Actividad reciente
                  _buildRecentActivity(),
                ],
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
        Text(
          'Resumen de Consumo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Hoy',
                value: _formatBytes(today),
                icon: Icons.today,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: '7 días',
                value: _formatBytes(week),
                icon: Icons.date_range,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSummaryCard(
          title: '30 días',
          value: _formatBytes(month),
          icon: Icons.calendar_month,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categories = _statistics['categories'] as Map<String, int>? ?? {};
    if (categories.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No hay datos de categorías disponibles',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final total = categories.values.fold(0, (sum, value) => sum + value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Desglose por Tipo (30 días)',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: categories.entries.map((entry) {
                final percentage = total > 0
                    ? (entry.value / total * 100)
                    : 0.0;
                return _buildCategoryItem(
                  label: _getCategoryLabel(entry.key),
                  bytes: entry.value,
                  percentage: percentage,
                  color: _getCategoryColor(entry.key),
                );
              }).toList(),
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                _formatBytes(bytes),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChart() {
    if (_dailyUsage.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = _dailyUsage.values.fold(
      0,
      (max, value) => value > max ? value : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consumo Diario (últimos 7 días)',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _dailyUsage.entries.map((entry) {
                  final height = maxValue > 0
                      ? (entry.value / maxValue * 160)
                      : 0.0;
                  final date = DateTime.parse(entry.key);
                  final dayLabel = '${date.day}/${date.month}';

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Tooltip(
                            message: '${_formatBytes(entry.value)}\n$dayLabel',
                            child: Container(
                              height: height,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withOpacity(0.6),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dayLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    if (_recentRecords.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No hay actividad reciente',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // Agrupar registros por (operationType + endpoint)
    final groupedRecords = <String, List<DataUsageRecord>>{};

    for (final record in _recentRecords) {
      final endpointLabel = _extractEndpointLabel(record.endpoint);
      final key = '${record.operationType}_$endpointLabel';

      if (!groupedRecords.containsKey(key)) {
        groupedRecords[key] = [];
      }
      groupedRecords[key]!.add(record);
    }

    // Convertir a lista de resumen para mostrar
    final summaryList = groupedRecords.entries.map((entry) {
      final records = entry.value;
      final first = records.first;

      // Sumar bytes
      final totalBytes = records.fold(0, (sum, r) => sum + r.totalBytes);
      final count = records.length;
      final latestTimestamp = records
          .map((r) => r.timestamp)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      // Chequear errores (si alguno falló)
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

    // Ordenar por fecha más reciente
    summaryList.sort((a, b) => b.latestTimestamp.compareTo(a.latestTimestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actividad Reciente Agrupada',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summaryList.length,
            separatorBuilder: (_, __) =>
                Divider(color: Colors.grey[200], height: 1),
            itemBuilder: (context, index) {
              final item = summaryList[index];
              final hasErrors = item.errorCount > 0;

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(
                      item.operationType,
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(item.operationType),
                    color: _getCategoryColor(item.operationType),
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.endpointLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.count > 1)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item.count} reqs',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.operationTypeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (hasErrors)
                      Text(
                        '${item.errorCount} errores: ${item.lastErrorMessage ?? "Desconocido"}',
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatBytes(item.totalBytes),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _getCategoryColor(item.operationType),
                      ),
                    ),
                    Text(
                      _formatTime(item.latestTimestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getCategoryLabel(String type) {
    switch (type.toLowerCase()) {
      case 'sync':
        return 'Sincronización';
      case 'post':
        return 'Envío de datos';
      case 'get':
        return 'Descarga';
      default:
        return type;
    }
  }

  Color _getCategoryColor(String type) {
    switch (type.toLowerCase()) {
      case 'sync':
        return AppColors.info;
      case 'post':
        return AppColors.secondary;
      case 'get':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'sync':
        return Icons.sync;
      case 'post':
        return Icons.upload;
      case 'get':
        return Icons.download;
      default:
        return Icons.data_usage;
    }
  }

  String _extractEndpointLabel(String endpoint) {
    final uri = Uri.tryParse(endpoint);
    if (uri != null) {
      return uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : uri.path.isNotEmpty
          ? uri.path
          : endpoint;
    }
    return endpoint;
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Ahora';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
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
