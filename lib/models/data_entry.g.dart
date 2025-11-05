// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DataEntry _$DataEntryFromJson(Map<String, dynamic> json) => DataEntry(
  id: (json['id'] as num?)?.toInt(),
  timestamp: (json['timestamp'] as num).toInt(),
  topicName: json['topic_name'] as String,
  experimentId: (json['experiment_id'] as num).toInt(),
  sessionId: (json['session_id'] as num?)?.toInt(),
  data: json['data'] as Map<String, dynamic>,
);

Map<String, dynamic> _$DataEntryToJson(DataEntry instance) => <String, dynamic>{
  'id': instance.id,
  'timestamp': instance.timestamp,
  'topic_name': instance.topicName,
  'experiment_id': instance.experimentId,
  'session_id': instance.sessionId,
  'data': instance.data,
};
