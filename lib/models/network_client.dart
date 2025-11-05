import 'package:json_annotation/json_annotation.dart';

part 'network_client.g.dart';

/// Network client model for ESP32 clients
@JsonSerializable()
class NetworkClient {
  final String name;
  final DateTime connectedAt;
  final List<String> topics;
  final Map<String, TopicMetadata> topicMetadata;
  
  // Connection quality tracking
  DateTime? lastPingReceived;
  DateTime? lastPongSent;
  int? latencyMs; // Round-trip latency
  int missedPings; // Count of missed ping responses
  bool isConnected;
  
  // Connection quality indicator (0.0 to 1.0)
  // 1.0 = excellent, 0.5 = good, 0.0 = poor/disconnected
  double get connectionQuality {
    if (!isConnected) return 0.0;
    if (missedPings > 3) return 0.3;
    if (missedPings > 1) return 0.6;
    if (latencyMs != null && latencyMs! > 500) return 0.7;
    if (latencyMs != null && latencyMs! > 200) return 0.85;
    return 1.0;
  }
  
  String get connectionQualityText {
    final quality = connectionQuality;
    if (quality == 0.0) return 'Disconnected';
    if (quality < 0.4) return 'Poor';
    if (quality < 0.7) return 'Fair';
    if (quality < 0.9) return 'Good';
    return 'Excellent';
  }

  NetworkClient({
    required this.name,
    required this.connectedAt,
    required this.topics,
    required this.topicMetadata,
    this.lastPingReceived,
    this.lastPongSent,
    this.latencyMs,
    this.missedPings = 0,
    this.isConnected = true,
  });

  NetworkClient copyWith({
    String? name,
    DateTime? connectedAt,
    List<String>? topics,
    Map<String, TopicMetadata>? topicMetadata,
    DateTime? lastPingReceived,
    DateTime? lastPongSent,
    int? latencyMs,
    int? missedPings,
    bool? isConnected,
  }) {
    return NetworkClient(
      name: name ?? this.name,
      connectedAt: connectedAt ?? this.connectedAt,
      topics: topics ?? this.topics,
      topicMetadata: topicMetadata ?? this.topicMetadata,
      lastPingReceived: lastPingReceived ?? this.lastPingReceived,
      lastPongSent: lastPongSent ?? this.lastPongSent,
      latencyMs: latencyMs ?? this.latencyMs,
      missedPings: missedPings ?? this.missedPings,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  factory NetworkClient.fromJson(Map<String, dynamic> json) =>
      _$NetworkClientFromJson(json);

  Map<String, dynamic> toJson() => _$NetworkClientToJson(this);
}

/// Topic metadata for network topics
@JsonSerializable()
class TopicMetadata {
  final String description;
  final String? unit;
  final double? samplingRate; // Hz
  
  TopicMetadata({
    required this.description,
    this.unit,
    this.samplingRate,
  });

  factory TopicMetadata.fromJson(Map<String, dynamic> json) =>
      _$TopicMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$TopicMetadataToJson(this);
}

