class ConsultSession {
  final String id;
  final String petId;
  final String symptoms;
  final List<String> photoUrls;
  final Map<String, dynamic>? aiResponse;
  final String? riskLevel;
  final DateTime createdAt;

  const ConsultSession({
    required this.id,
    required this.petId,
    required this.symptoms,
    required this.photoUrls,
    this.aiResponse,
    this.riskLevel,
    required this.createdAt,
  });

  factory ConsultSession.fromJson(Map<String, dynamic> json) => ConsultSession(
    id: json['id'] as String,
    petId: json['pet_id'] as String,
    symptoms: json['symptoms'] as String,
    photoUrls: List<String>.from(json['photo_urls'] as List? ?? []),
    aiResponse: json['ai_response'] as Map<String, dynamic>?,
    riskLevel: json['risk_level'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
