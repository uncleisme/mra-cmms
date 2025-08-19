class LeaveRequest {
  final String id;
  final String userId;
  final String typeKey;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // approved, rejected, pending
  final String? reason;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LeaveRequest({
    required this.id,
    required this.userId,
    required this.typeKey,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.reason,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory LeaveRequest.fromMap(Map<String, dynamic> map) => LeaveRequest(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        typeKey: map['type_key'] as String,
        startDate: DateTime.parse(map['start_date'].toString()),
        endDate: DateTime.parse(map['end_date'].toString()),
        status: map['status'] as String,
        reason: map['reason'] as String?,
        approvedBy: map['approved_by'] as String?,
        approvedAt: map['approved_at'] != null ? DateTime.tryParse(map['approved_at'].toString()) : null,
        createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
        updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'type_key': typeKey,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'status': status,
        'reason': reason,
        'approved_by': approvedBy,
        'approved_at': approvedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
