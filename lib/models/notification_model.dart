import 'dart:convert';
import 'package:ada_app/utils/parsing_helpers.dart';

enum NotificationLevel {
  info,
  important,
  blocking,
  unblocking;

  static NotificationLevel fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'important':
        return NotificationLevel.important;
      case 'blocking':
        return NotificationLevel.blocking;
      case 'unblocking':
        return NotificationLevel.unblocking;
      case 'info':
      default:
        return NotificationLevel.info;
    }
  }
}

class TargetConfig {
  final String? type;
  final String username;
  final String? imei;
  final String? appVersion;
  final bool envioUsuario;
  final bool envioEmployee;
  final bool envioImei;

  TargetConfig({
    this.type,
    required this.username,
    this.imei,
    this.appVersion,
    required this.envioUsuario,
    required this.envioEmployee,
    required this.envioImei,
  });

  factory TargetConfig.fromJson(Map<String, dynamic> json) {
    return TargetConfig(
      type: json['type'],
      username: json['username'] ?? json['imei'] ?? json['appVersion'] ?? '',
      imei: json['imei'],
      appVersion: json['appVersion'],
      envioUsuario: json['envioUsuario'] == true,
      envioEmployee: json['envioEmployee'] == true,
      envioImei: json['envioImei'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (type != null) 'type': type,
      'username': username,
      if (imei != null) 'imei': imei,
      if (appVersion != null) 'appVersion': appVersion,
      'envioUsuario': envioUsuario,
      'envioEmployee': envioEmployee,
      'envioImei': envioImei,
    };
  }
}

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final NotificationLevel type;
  final int timestamp;
  final bool isRead;
  final dynamic target;
  final List<TargetConfig>? targetConfig;

  final String? blockingUrl;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.target,
    this.targetConfig,
    this.blockingUrl,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Deserializar target si viene como string JSON (desde SQLite)
    dynamic targetData = json['target'];
    if (targetData is String && (targetData.startsWith('[') || targetData.startsWith('{'))) {
      try {
        targetData = jsonDecode(targetData);
      } catch (_) {}
    }

    // Deserializar targetConfig si viene como string JSON
    dynamic configData = json['targetConfig'];
    if (configData is String) {
      try {
        configData = jsonDecode(configData);
      } catch (_) {}
    }

    return NotificationModel(
      id: ParsingHelpers.parseInt(json['id']),
      title: ParsingHelpers.parseString(json['title']) ?? '',
      message: ParsingHelpers.parseString(json['message']) ?? '',
      type: NotificationLevel.fromString(
        ParsingHelpers.parseString(json['type']),
      ),
      timestamp: ParsingHelpers.parseInt(json['timestamp']),
      isRead: json['isRead'] == 1 || json['isRead'] == true,
      target: targetData,
      targetConfig: configData != null
          ? (configData as List)
              .map((i) => TargetConfig.fromJson(i))
              .toList()
          : null,
      blockingUrl: ParsingHelpers.parseString(json['blockingUrl']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'timestamp': timestamp,
      'isRead': isRead ? 1 : 0,
      'target': target,
      'targetConfig': targetConfig?.map((i) => i.toJson()).toList(),
      'blockingUrl': blockingUrl,
    };
  }
}

