import 'package:uuid/uuid.dart';

/// Representa un registro de consumo de datos de una operación HTTP
class DataUsageRecord {
  final String id;
  final DateTime timestamp;
  final String operationType; // 'sync', 'post', 'get', 'upload', etc.
  final String endpoint;
  final int bytesSent;
  final int bytesReceived;
  final int totalBytes;
  final int? statusCode;
  final String? userId;
  final String? errorMessage;

  DataUsageRecord({
    String? id,
    required this.timestamp,
    required this.operationType,
    required this.endpoint,
    required this.bytesSent,
    required this.bytesReceived,
    required this.totalBytes,
    this.statusCode,
    this.userId,
    this.errorMessage,
  }) : id = id ?? const Uuid().v4();

  // Constructor desde Map (SQLite)
  factory DataUsageRecord.fromMap(Map<String, dynamic> map) {
    return DataUsageRecord(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      operationType: map['operation_type'] as String,
      endpoint: map['endpoint'] as String,
      bytesSent: map['bytes_sent'] as int,
      bytesReceived: map['bytes_received'] as int,
      totalBytes: map['total_bytes'] as int,
      statusCode: map['status_code'] as int?,
      userId: map['user_id'] as String?,
      errorMessage: map['error_message'] as String?,
    );
  }

  // Convertir a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'operation_type': operationType,
      'endpoint': endpoint,
      'bytes_sent': bytesSent,
      'bytes_received': bytesReceived,
      'total_bytes': totalBytes,
      'status_code': statusCode,
      'user_id': userId,
      'error_message': errorMessage,
    };
  }

  // Helper para obtener descripción amigable del tipo de operación
  String get operationTypeLabel {
    switch (operationType.toLowerCase()) {
      case 'sync':
        return 'Sincronización';
      case 'post':
        return 'Envío de datos';
      case 'get':
        return 'Descarga de datos';
      case 'upload':
        return 'Subida de archivos';
      default:
        return operationType;
    }
  }

  // Helper para formatear bytes
  String get formattedTotalBytes {
    return _formatBytes(totalBytes);
  }

  String get formattedBytesSent {
    return _formatBytes(bytesSent);
  }

  String get formattedBytesReceived {
    return _formatBytes(bytesReceived);
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  // CopyWith para inmutabilidad
  DataUsageRecord copyWith({
    String? id,
    DateTime? timestamp,
    String? operationType,
    String? endpoint,
    int? bytesSent,
    int? bytesReceived,
    int? totalBytes,
    int? statusCode,
    String? userId,
    String? errorMessage,
  }) {
    return DataUsageRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      operationType: operationType ?? this.operationType,
      endpoint: endpoint ?? this.endpoint,
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      totalBytes: totalBytes ?? this.totalBytes,
      statusCode: statusCode ?? this.statusCode,
      userId: userId ?? this.userId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'DataUsageRecord(id: $id, type: $operationType, endpoint: $endpoint, total: ${formattedTotalBytes})';
  }
}
