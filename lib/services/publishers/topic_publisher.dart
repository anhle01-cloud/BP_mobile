import 'dart:async';
import 'publisher.dart';

/// Wraps a Publisher with topic name and sampling rate control
class TopicPublisher {
  final Publisher publisher;
  final String topicName;
  double samplingRate; // Hz
  StreamSubscription<Map<String, dynamic>>? _subscription;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();
  bool _isActive = false;
  DateTime? _lastEmitTime;

  TopicPublisher({
    required this.publisher,
    required this.topicName,
    required this.samplingRate,
  });

  /// Start the publisher with sampling rate control
  /// Note: This subscribes to the underlying publisher but doesn't start it
  /// The underlying publisher should be started via PublisherManager
  Future<void> start() async {
    if (_isActive) return;

    // Don't start the underlying publisher - it's managed by PublisherManager
    // Just subscribe to its stream if it's already running
    _isActive = true;

    // Subscribe to publisher stream and apply sampling rate
    // For network topics, filter by topic_name to ensure correct routing
    _subscription = publisher.dataStream.listen(
      (data) {
        // For network topics, only emit data that matches this topic
        if (topicName.contains('/') && !topicName.startsWith('gps/') && !topicName.startsWith('imu/')) {
          // Network topic - check if data matches this topic
          final dataTopicName = data['topic_name'] as String?;
          if (dataTopicName != null && dataTopicName != topicName) {
            // Data doesn't match this topic - skip it
            return;
          }
        }
        // Emit data (either matches topic or is internal topic)
        _emitWithRateLimit(data);
      },
      onError: (error) {
        _controller.addError(error);
      },
      onDone: () {
        _isActive = false;
        _controller.close();
      },
    );
  }

  /// Stop the publisher
  /// Note: This stops the subscription but doesn't stop the underlying publisher
  /// The underlying publisher is managed by PublisherManager
  Future<void> stop() async {
    if (!_isActive) return;

    await _subscription?.cancel();
    _subscription = null;
    // Don't stop the underlying publisher - it's managed by PublisherManager
    _isActive = false;
    _lastEmitTime = null;
  }

  /// Stream of data with sampling rate applied
  Stream<Map<String, dynamic>> get dataStream => _controller.stream;

  /// Check if currently active
  bool get isActive => _isActive;

  /// Update sampling rate
  void updateSamplingRate(double newRate) {
    samplingRate = newRate;
  }

  /// Emit data with rate limiting
  void _emitWithRateLimit(Map<String, dynamic> data) {
    final now = DateTime.now();

    if (_lastEmitTime == null) {
      // First emission
      _lastEmitTime = now;
      _controller.add(_addTopicMetadata(data));
      return;
    }

    // Calculate time since last emission
    final duration = now.difference(_lastEmitTime!);
    final minInterval = Duration(milliseconds: (1000 / samplingRate).round());

    if (duration >= minInterval) {
      _lastEmitTime = now;
      _controller.add(_addTopicMetadata(data));
    }
    // Otherwise, skip this emission (rate limiting)
  }

  /// Add topic metadata to data
  /// For network topics, preserve the existing topic_name from the enriched data
  /// For internal topics, add topic_name if not present
  Map<String, dynamic> _addTopicMetadata(Map<String, dynamic> data) {
    // For network topics (from WebSocket), the topic_name is already set correctly
    // in the enriched data by the WebSocket server. Don't overwrite it.
    if (data.containsKey('topic_name') && data['topic_name'].toString().contains('/')) {
      // Network topic - preserve the existing topic_name
      return data;
    }
    
    // For internal topics (GPS/IMU), add topic_name if not present
    return {
      ...data,
      'topic_name': topicName,
    };
  }

  /// Dispose resources
  void dispose() {
    stop();
    _controller.close();
  }
}
