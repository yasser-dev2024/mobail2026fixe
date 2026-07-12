class WhatsappTemplateModel {
  final String id;
  final String key;
  final String name;
  final String template;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  const WhatsappTemplateModel({
    required this.id,
    required this.key,
    required this.name,
    required this.template,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WhatsappTemplateModel.fromMap(Map<String, dynamic> map) {
    return WhatsappTemplateModel(
      id: map['id'] as String,
      key: map['key'] as String,
      name: map['name'] as String,
      template: map['template'] as String,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'key': key,
        'name': name,
        'template': template,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  String buildMessage(Map<String, String> variables) {
    String result = template;
    for (final entry in variables.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  WhatsappTemplateModel copyWith({
    String? id,
    String? key,
    String? name,
    String? template,
    bool? isActive,
    int? createdAt,
    int? updatedAt,
  }) {
    return WhatsappTemplateModel(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      template: template ?? this.template,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
