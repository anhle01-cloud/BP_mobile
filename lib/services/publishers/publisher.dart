import 'dart:async';

/// Base interface for all data publishers
/// Publishers emit data as Map<String, dynamic> with timestamp and id
abstract class Publisher {
  /// Start publishing data
  Future<void> start();

  /// Stop publishing data
  Future<void> stop();

  /// Stream of published data
  /// Each data entry must contain 'timestamp' (int) and 'id' (String) fields
  Stream<Map<String, dynamic>> get dataStream;

  /// Stream indicating if the publisher is active
  Stream<bool> get isActive;

  /// Current active state
  bool get isCurrentlyActive;

  /// Publisher name/identifier
  String get name;
}
