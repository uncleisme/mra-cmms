class WorkOrder {
  final String id;
  final String? workOrderId;
  final String? workType;
  final String? assetId;
  final String? locationId;
  final String? status;
  final String? priority;
  final String? title;
  final String? description;
  final DateTime? createdDate;
  final DateTime? appointmentDate;
  final String? appointmentTime;
  final String? requestedBy;
  final String? assignedTo;
  final String? recurrenceRule;
  final DateTime? recurrenceStartDate;
  final DateTime? recurrenceEndDate;
  final DateTime? nextScheduledDate;
  final String? jobType;
  final String? serviceProviderId;
  final String? contactPerson;
  final String? contactNumber;
  final String? contactEmail;
  final String? referenceText;
  final String? unitNumber;
  final String? repairContactPerson;
  final String? repairContactNumber;
  final String? repairContactEmail;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WorkOrder({
    required this.id,
    this.workOrderId,
    this.workType,
    this.assetId,
    this.locationId,
    this.status,
    this.priority,
    this.title,
    this.description,
    this.createdDate,
    this.appointmentDate,
    this.appointmentTime,
    this.requestedBy,
    this.assignedTo,
    this.recurrenceRule,
    this.recurrenceStartDate,
    this.recurrenceEndDate,
    this.nextScheduledDate,
    this.jobType,
    this.serviceProviderId,
    this.contactPerson,
    this.contactNumber,
    this.contactEmail,
    this.referenceText,
    this.unitNumber,
    this.repairContactPerson,
    this.repairContactNumber,
    this.repairContactEmail,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkOrder.fromMap(Map<String, dynamic> map) => WorkOrder(
    id: map['id'] as String,
    workOrderId: map['work_order_id'] as String?,
    workType: map['work_type'] as String?,
    assetId: map['asset_id'] as String?,
    locationId: map['location_id'] as String?,
    status: map['status'] as String?,
    priority: map['priority'] as String?,
    title: map['title'] as String?,
    description: map['description'] as String?,
    createdDate: map['created_date'] != null
        ? DateTime.tryParse(map['created_date'].toString())
        : null,
    appointmentDate: map['appointment_date'] != null
        ? DateTime.tryParse(map['appointment_date'].toString())
        : null,
    appointmentTime: map['appointment_time'] as String?,
    requestedBy: map['requested_by'] as String?,
    assignedTo: map['assigned_to'] as String?,
    recurrenceRule: map['recurrence_rule'] as String?,
    recurrenceStartDate: map['recurrence_start_date'] != null
        ? DateTime.tryParse(map['recurrence_start_date'].toString())
        : null,
    recurrenceEndDate: map['recurrence_end_date'] != null
        ? DateTime.tryParse(map['recurrence_end_date'].toString())
        : null,
    nextScheduledDate: map['next_scheduled_date'] != null
        ? DateTime.tryParse(map['next_scheduled_date'].toString())
        : null,
    jobType: map['job_type'] as String?,
    serviceProviderId: map['service_provider_id'] as String?,
    contactPerson: map['contact_person'] as String?,
    contactNumber: map['contact_number'] as String?,
    contactEmail: map['contact_email'] as String?,
    referenceText: map['reference_text'] as String?,
    unitNumber: map['unit_number'] as String?,
    repairContactPerson: map['repair_contact_person'] as String?,
    repairContactNumber: map['repair_contact_number'] as String?,
    repairContactEmail: map['repair_contact_email'] as String?,
    createdAt: map['created_at'] != null
        ? DateTime.tryParse(map['created_at'].toString())
        : null,
    updatedAt: map['updated_at'] != null
        ? DateTime.tryParse(map['updated_at'].toString())
        : null,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'work_order_id': workOrderId,
    'work_type': workType,
    'asset_id': assetId,
    'location_id': locationId,
    'status': status,
    'priority': priority,
    'title': title,
    'description': description,
    'created_date': createdDate?.toIso8601String(),
    'appointment_date': appointmentDate?.toIso8601String(),
    'appointment_time': appointmentTime,
    'requested_by': requestedBy,
    'assigned_to': assignedTo,
    'recurrence_rule': recurrenceRule,
    'recurrence_start_date': recurrenceStartDate?.toIso8601String(),
    'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
    'next_scheduled_date': nextScheduledDate?.toIso8601String(),
    'job_type': jobType,
    'service_provider_id': serviceProviderId,
    'contact_person': contactPerson,
    'contact_number': contactNumber,
    'contact_email': contactEmail,
    'reference_text': referenceText,
    'unit_number': unitNumber,
    'repair_contact_person': repairContactPerson,
    'repair_contact_number': repairContactNumber,
    'repair_contact_email': repairContactEmail,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
