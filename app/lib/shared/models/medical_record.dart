class MedicalRecord {
  final String id;
  final String petId;
  final String type;
  final String title;
  final DateTime recordDate;
  final DateTime? nextDueDate;
  final String? notes;
  final DateTime createdAt;

  const MedicalRecord({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    required this.recordDate,
    this.nextDueDate,
    this.notes,
    required this.createdAt,
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> json) => MedicalRecord(
    id: json['id'] as String,
    petId: json['pet_id'] as String,
    type: json['type'] as String,
    title: json['title'] as String,
    recordDate: DateTime.parse(json['record_date'] as String),
    nextDueDate: json['next_due_date'] != null
        ? DateTime.parse(json['next_due_date'] as String)
        : null,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'pet_id': petId,
    'type': type,
    'title': title,
    'record_date': recordDate.toIso8601String().substring(0, 10),
    if (nextDueDate != null)
      'next_due_date': nextDueDate!.toIso8601String().substring(0, 10),
    if (notes != null) 'notes': notes,
  };
}
