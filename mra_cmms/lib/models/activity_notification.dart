class ActivityNotification {
  final String id;
  final String? title;
  final String? body;
  final DateTime createdAt;

  ActivityNotification({
    required this.id,
    this.title,
    this.body,
    required this.createdAt,
  });

  factory ActivityNotification.fromMap(Map<String, dynamic> map) {
    return ActivityNotification(
      id: map['id'] as String,
      title: map['title'] as String?,
      body: map['body'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
