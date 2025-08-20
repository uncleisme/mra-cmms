class ActivityNotification {
  final String id;
  final String? userId;
  final String? title;
  final String? message; // prefer this for display when present (notifications.message)
  final String? module; // e.g., 'Work Orders', 'Leave', 'contact'
  final String? action; // e.g., 'created', 'approved', 'deleted'
  final String? entityId; // coerced to String for flexibility
  final List<String>? recipients;
  final DateTime createdAt;
  final bool isRead;

  ActivityNotification({
    required this.id,
    this.userId,
    this.title,
    this.message,
    this.module,
    this.action,
    this.entityId,
    this.recipients,
    required this.createdAt,
    this.isRead = false,
  });

  factory ActivityNotification.fromMap(Map<String, dynamic> map) {
    List<String>? parseRecipients(dynamic raw) {
      if (raw == null) return null;
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      if (raw is String) {
        // comma-separated fallback
        return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return null;
    }

    bool parseIsRead(dynamic raw) {
      if (raw is bool) return raw;
      if (raw is String) {
        final v = raw.trim().toLowerCase();
        if (v == 'true') return true;
        if (v == 'false') return false;
        if (v == '1') return true;
        if (v == '0') return false;
      }
      if (raw is num) return raw != 0;
      return false;
    }

    return ActivityNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      title: map['title'] as String?,
      message: map['message'] as String?,
      module: map['module'] as String?,
      action: map['action'] as String?,
      entityId: map['entity_id']?.toString(),
      recipients: parseRecipients(map['recipients']),
      createdAt: DateTime.parse(map['created_at'] as String),
      isRead: parseIsRead(map['is_read']),
    );
  }
}
