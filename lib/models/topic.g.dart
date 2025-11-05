// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topic.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Topic _$TopicFromJson(Map<String, dynamic> json) => Topic(
  id: (json['id'] as num?)?.toInt(),
  experimentId: (json['experiment_id'] as num).toInt(),
  name: json['name'] as String,
  enabled: json['enabled'] as bool,
  samplingRate: (json['sampling_rate'] as num).toDouble(),
);

Map<String, dynamic> _$TopicToJson(Topic instance) => <String, dynamic>{
  'id': instance.id,
  'experiment_id': instance.experimentId,
  'name': instance.name,
  'enabled': instance.enabled,
  'sampling_rate': instance.samplingRate,
};
