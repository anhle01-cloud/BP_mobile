// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_client.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NetworkClient _$NetworkClientFromJson(Map<String, dynamic> json) =>
    NetworkClient(
      name: json['name'] as String,
      connectedAt: DateTime.parse(json['connectedAt'] as String),
      topics: (json['topics'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      topicMetadata: (json['topicMetadata'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, TopicMetadata.fromJson(e as Map<String, dynamic>)),
      ),
      lastPingReceived: json['lastPingReceived'] == null
          ? null
          : DateTime.parse(json['lastPingReceived'] as String),
      lastPongSent: json['lastPongSent'] == null
          ? null
          : DateTime.parse(json['lastPongSent'] as String),
      latencyMs: (json['latencyMs'] as num?)?.toInt(),
      missedPings: (json['missedPings'] as num?)?.toInt() ?? 0,
      isConnected: json['isConnected'] as bool? ?? true,
    );

Map<String, dynamic> _$NetworkClientToJson(NetworkClient instance) =>
    <String, dynamic>{
      'name': instance.name,
      'connectedAt': instance.connectedAt.toIso8601String(),
      'topics': instance.topics,
      'topicMetadata': instance.topicMetadata,
      'lastPingReceived': instance.lastPingReceived?.toIso8601String(),
      'lastPongSent': instance.lastPongSent?.toIso8601String(),
      'latencyMs': instance.latencyMs,
      'missedPings': instance.missedPings,
      'isConnected': instance.isConnected,
    };

TopicMetadata _$TopicMetadataFromJson(Map<String, dynamic> json) =>
    TopicMetadata(
      description: json['description'] as String,
      unit: json['unit'] as String?,
      samplingRate: (json['samplingRate'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$TopicMetadataToJson(TopicMetadata instance) =>
    <String, dynamic>{
      'description': instance.description,
      'unit': instance.unit,
      'samplingRate': instance.samplingRate,
    };
