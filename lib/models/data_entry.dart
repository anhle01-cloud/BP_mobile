import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'data_entry.g.dart';

@JsonSerializable()
class DataEntry {
  final int? id; // Auto-increment
  final int timestamp; // UNIX timestamp in milliseconds
  @JsonKey(name: 'topic_name')
  final String topicName;
  @JsonKey(name: 'experiment_id')
  final int experimentId; // Associate with experiment
  @JsonKey(name: 'session_id')
  final int? sessionId; // Associate with session (nullable for backward compatibility)
  final Map<String, dynamic> data; // JSON data

  DataEntry({
    this.id,
    required this.timestamp,
    required this.topicName,
    required this.experimentId,
    this.sessionId,
    required this.data,
  });

  DataEntry copyWith({
    int? id,
    int? timestamp,
    String? topicName,
    int? experimentId,
    int? sessionId,
    Map<String, dynamic>? data,
  }) {
    return DataEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      topicName: topicName ?? this.topicName,
      experimentId: experimentId ?? this.experimentId,
      sessionId: sessionId ?? this.sessionId,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() => _$DataEntryToJson(this);
  factory DataEntry.fromJson(Map<String, dynamic> json) =>
      _$DataEntryFromJson(json);

  // Convert to/from database map
  // Data is stored as JSON string in database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp,
      'topic_name': topicName,
      'experiment_id': experimentId,
      'session_id': sessionId,
      'data': jsonEncode(data),
    };
  }

  factory DataEntry.fromMap(Map<String, dynamic> map) {
    // Handle migration - experiment_id might be null for old data
    // For old data without experiment_id, we'll need to infer it from topics
    final experimentIdValue = map['experiment_id'];
    final experimentId = experimentIdValue is int
        ? experimentIdValue
        : (experimentIdValue != null
              ? int.tryParse(experimentIdValue.toString())
              : null);

    return DataEntry(
      id: map['id'] as int?,
      timestamp: map['timestamp'] as int,
      topicName: map['topic_name'] as String,
      experimentId:
          experimentId ?? 0, // Default to 0 if missing (will be filtered out)
      sessionId: map['session_id'] as int?,
      data: jsonDecode(map['data'] as String) as Map<String, dynamic>,
    );
  }
}
