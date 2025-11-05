import 'package:json_annotation/json_annotation.dart';

part 'topic.g.dart';

@JsonSerializable()
class Topic {
  final int? id;
  @JsonKey(name: 'experiment_id')
  final int experimentId;
  final String
  name; // Tree-like name (e.g., "gps/location", "imu/acceleration")
  final bool enabled;
  @JsonKey(name: 'sampling_rate')
  final double samplingRate; // Hz

  Topic({
    this.id,
    required this.experimentId,
    required this.name,
    required this.enabled,
    required this.samplingRate,
  });

  Topic copyWith({
    int? id,
    int? experimentId,
    String? name,
    bool? enabled,
    double? samplingRate,
  }) {
    return Topic(
      id: id ?? this.id,
      experimentId: experimentId ?? this.experimentId,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      samplingRate: samplingRate ?? this.samplingRate,
    );
  }

  Map<String, dynamic> toJson() => _$TopicToJson(this);
  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);

  // Convert to/from database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'experiment_id': experimentId,
      'name': name,
      'enabled': enabled ? 1 : 0,
      'sampling_rate': samplingRate,
    };
  }

  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as int?,
      experimentId: map['experiment_id'] as int,
      name: map['name'] as String,
      enabled: (map['enabled'] as int) == 1,
      samplingRate: (map['sampling_rate'] as num).toDouble(),
    );
  }
}
