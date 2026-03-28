class HealthLog {
  final String id;
  final String petId;
  final DateTime logDate;
  final String? foodType;
  final int? foodAmountG;
  final int? waterMl;
  final double? weightKg;
  final int? stoolStatus;
  final int? appetiteLevel;
  final String? notes;
  final DateTime createdAt;

  const HealthLog({
    required this.id,
    required this.petId,
    required this.logDate,
    this.foodType,
    this.foodAmountG,
    this.waterMl,
    this.weightKg,
    this.stoolStatus,
    this.appetiteLevel,
    this.notes,
    required this.createdAt,
  });

  factory HealthLog.fromJson(Map<String, dynamic> json) => HealthLog(
    id: json['id'] as String,
    petId: json['pet_id'] as String,
    logDate: DateTime.parse(json['log_date'] as String),
    foodType: json['food_type'] as String?,
    foodAmountG: json['food_amount_g'] as int?,
    waterMl: json['water_ml'] as int?,
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    stoolStatus: json['stool_status'] as int?,
    appetiteLevel: json['appetite_level'] as int?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'pet_id': petId,
    'log_date': logDate.toIso8601String().substring(0, 10),
    if (foodType != null) 'food_type': foodType,
    if (foodAmountG != null) 'food_amount_g': foodAmountG,
    if (waterMl != null) 'water_ml': waterMl,
    if (weightKg != null) 'weight_kg': weightKg,
    if (stoolStatus != null) 'stool_status': stoolStatus,
    if (appetiteLevel != null) 'appetite_level': appetiteLevel,
    if (notes != null) 'notes': notes,
  };
}
