class MedicalRecord {
  final String id;
  final String petId;
  final String type;
  final String title;
  final DateTime recordDate;
  final DateTime? nextDueDate;
  final String? notes;
  final String? brand;
  final String? dewormType;
  final String? clinic;
  final double? cost;
  final List<String> photoUrls;
  final DateTime createdAt;

  const MedicalRecord({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    required this.recordDate,
    this.nextDueDate,
    this.notes,
    this.brand,
    this.dewormType,
    this.clinic,
    this.cost,
    this.photoUrls = const [],
    required this.createdAt,
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> json) => MedicalRecord(
        id: json['id'] as String,
        petId: json['pet_id'] as String,
        type: normalizeMedicalRecordType(json['type'] as String),
        title: json['title'] as String,
        recordDate: DateTime.parse(json['record_date'] as String),
        nextDueDate: json['next_due_date'] != null
            ? DateTime.parse(json['next_due_date'] as String)
            : null,
        notes: json['notes'] as String?,
        brand: json['brand'] as String?,
        dewormType: json['deworm_type'] as String?,
        clinic: json['clinic'] as String?,
        cost: (json['cost'] as num?)?.toDouble(),
        photoUrls: List<String>.from(json['photo_urls'] as List? ?? []),
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
        if (brand != null) 'brand': brand,
        if (dewormType != null) 'deworm_type': dewormType,
        if (clinic != null) 'clinic': clinic,
        if (cost != null) 'cost': cost,
        'photo_urls': photoUrls,
      };
}

String normalizeMedicalRecordType(String type) {
  switch (type) {
    case 'disease':
      return 'surgery';
    case 'allergy':
      return 'other';
    default:
      return type;
  }
}

String encodeMedicalRecordType(String type) {
  switch (type) {
    case 'surgery':
      return 'disease';
    case 'other':
      return 'allergy';
    default:
      return type;
  }
}
