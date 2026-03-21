import 'package:ada_app/utils/parsing_helpers.dart';

enum NotificationLevel {
  info,
  important,
  blocking;

  static NotificationLevel fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'important':
        return NotificationLevel.important;
      case 'blocking':
        return NotificationLevel.blocking;
      case 'info':
      default:
        return NotificationLevel.info;
    }
  }
}

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final NotificationLevel type;
  final int timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: ParsingHelpers.parseInt(json['id']),
      title: ParsingHelpers.parseString(json['title']) ?? '',
      message: ParsingHelpers.parseString(json['message']) ?? '',
      type: NotificationLevel.fromString(
        ParsingHelpers.parseString(json['type']),
      ),
      timestamp: ParsingHelpers.parseInt(json['timestamp']),
      isRead: json['isRead'] == 1 || json['isRead'] == true,
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
    };
  }
}
