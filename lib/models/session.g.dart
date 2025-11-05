// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Session _$SessionFromJson(Map<String, dynamic> json) => Session(
  id: (json['id'] as num?)?.toInt(),
  experimentId: (json['experimentId'] as num).toInt(),
  sessionNumber: (json['sessionNumber'] as num).toInt(),
  startTimestamp: (json['startTimestamp'] as num).toInt(),
  endTimestamp: (json['endTimestamp'] as num?)?.toInt(),
  entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
  startEntryId: (json['startEntryId'] as num?)?.toInt(),
  endEntryId: (json['endEntryId'] as num?)?.toInt(),
);

Map<String, dynamic> _$SessionToJson(Session instance) => <String, dynamic>{
  'id': instance.id,
  'experimentId': instance.experimentId,
  'sessionNumber': instance.sessionNumber,
  'startTimestamp': instance.startTimestamp,
  'endTimestamp': instance.endTimestamp,
  'entryCount': instance.entryCount,
  'startEntryId': instance.startEntryId,
  'endEntryId': instance.endEntryId,
};
