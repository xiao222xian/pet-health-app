class TimelineEvent {
  final String id;
  final String petId;
  final String type;
  final String title;
  final String? content;
  final List<String> photoUrls;
  final DateTime eventDate;
  final DateTime createdAt;

  const TimelineEvent({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    this.content,
    required this.photoUrls,
    required this.eventDate,
    required this.createdAt,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
    id: json['id'] as String,
    petId: json['pet_id'] as String,
    type: json['type'] as String,
    title: json['title'] as String,
    content: json['content'] as String?,
    photoUrls: List<String>.from(json['photo_urls'] as List? ?? []),
    eventDate: DateTime.parse(json['event_date'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'pet_id': petId,
    'type': type,
    'title': title,
    if (content != null) 'content': content,
    'photo_urls': photoUrls,
    'event_date': eventDate.toIso8601String().substring(0, 10),
  };
}
