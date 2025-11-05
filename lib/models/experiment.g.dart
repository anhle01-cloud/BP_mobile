// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'experiment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Experiment _$ExperimentFromJson(Map<String, dynamic> json) => Experiment(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String,
  createdAt: (json['created_at'] as num).toInt(),
  isActive: json['is_active'] as bool,
);

Map<String, dynamic> _$ExperimentToJson(Experiment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'created_at': instance.createdAt,
      'is_active': instance.isActive,
    };
