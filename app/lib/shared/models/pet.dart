class Pet {
  final String id;
  final String userId;
  final String name;
  final String species;
  final String? breed;
  final DateTime? birthDate;
  final double? weightKg;
  final String? gender;
  final bool neutered;
  final String? avatarUrl;
  final DateTime createdAt;

  const Pet({
    required this.id,
    required this.userId,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
    this.weightKg,
    this.gender,
    required this.neutered,
    this.avatarUrl,
    required this.createdAt,
  });

  int? get ageYears {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int years = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      years--;
    }
    return years;
  }

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    name: json['name'] as String,
    species: json['species'] as String,
    breed: json['breed'] as String?,
    birthDate: json['birth_date'] != null
        ? DateTime.parse(json['birth_date'] as String)
        : null,
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    gender: json['gender'] as String?,
    neutered: json['neutered'] as bool? ?? false,
    avatarUrl: json['avatar_url'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'species': species,
    if (breed != null) 'breed': breed,
    if (birthDate != null) 'birth_date': birthDate!.toIso8601String().substring(0, 10),
    if (weightKg != null) 'weight_kg': weightKg,
    if (gender != null) 'gender': gender,
    'neutered': neutered,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
  };
}
