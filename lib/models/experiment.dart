import 'package:json_annotation/json_annotation.dart';

part 'experiment.g.dart';

@JsonSerializable()
class Experiment {
  final int? id;
  final String name;
  @JsonKey(name: 'created_at')
  final int createdAt;
  @JsonKey(name: 'is_active')
  final bool isActive;

  Experiment({
    this.id,
    required this.name,
    required this.createdAt,
    required this.isActive,
  });

  Experiment copyWith({int? id, String? name, int? createdAt, bool? isActive}) {
    return Experiment(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => _$ExperimentToJson(this);
  factory Experiment.fromJson(Map<String, dynamic> json) =>
      _$ExperimentFromJson(json);

  // Convert to/from database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Experiment.fromMap(Map<String, dynamic> map) {
    return Experiment(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: map['created_at'] as int,
      isActive: (map['is_active'] as int) == 1,
    );
  }
}
