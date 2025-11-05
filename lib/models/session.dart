import 'package:json_annotation/json_annotation.dart';

part 'session.g.dart';

@JsonSerializable()
class Session {
  final int? id;
  final int experimentId;
  final int sessionNumber; // Per-experiment session number
  final int startTimestamp;
  final int? endTimestamp;
  final int entryCount;
  final int? startEntryId; // First entry ID for this session
  final int? endEntryId; // Last entry ID for this session

  Session({
    this.id,
    required this.experimentId,
    required this.sessionNumber,
    required this.startTimestamp,
    this.endTimestamp,
    this.entryCount = 0,
    this.startEntryId,
    this.endEntryId,
  });

  // Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'experiment_id': experimentId,
      'session_number': sessionNumber,
      'start_timestamp': startTimestamp,
      'end_timestamp': endTimestamp,
      'entry_count': entryCount,
      'start_entry_id': startEntryId,
      'end_entry_id': endEntryId,
    };
  }

  // Create from Map
  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as int?,
      experimentId: map['experiment_id'] as int,
      sessionNumber: map['session_number'] as int,
      startTimestamp: map['start_timestamp'] as int,
      endTimestamp: map['end_timestamp'] as int?,
      entryCount: map['entry_count'] as int? ?? 0,
      startEntryId: map['start_entry_id'] as int?,
      endEntryId: map['end_entry_id'] as int?,
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() => _$SessionToJson(this);
  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);

  Session copyWith({
    int? id,
    int? experimentId,
    int? sessionNumber,
    int? startTimestamp,
    int? endTimestamp,
    int? entryCount,
    int? startEntryId,
    int? endEntryId,
  }) {
    return Session(
      id: id ?? this.id,
      experimentId: experimentId ?? this.experimentId,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      startTimestamp: startTimestamp ?? this.startTimestamp,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      entryCount: entryCount ?? this.entryCount,
      startEntryId: startEntryId ?? this.startEntryId,
      endEntryId: endEntryId ?? this.endEntryId,
    );
  }
}

