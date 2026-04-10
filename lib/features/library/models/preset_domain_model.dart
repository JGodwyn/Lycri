class PresetDomainModel {
  final String id;
  final String name;
  final String data;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PresetDomainModel({
    required this.id,
    required this.name,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PresetDomainModel.fromJson(Map<String, dynamic> json) {
    return PresetDomainModel(
      id: json['id'] as String,
      name: json['name'] as String,
      data: json['data'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
