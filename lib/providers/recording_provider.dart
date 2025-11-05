import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/experiment.dart';
import '../models/topic.dart';
import '../models/data_entry.dart';
import '../services/recording_service.dart';
import 'publisher_provider.dart';

/// Recording service provider
final recordingServiceProvider = Provider<RecordingService>((ref) {
  // Use watch instead of read to ensure provider is initialized
  final publisherManager = ref.watch(publisherManagerProvider);
  final service = RecordingService(publisherManager);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Recording state
class RecordingState {
  final bool isRecording;
  final Experiment? activeExperiment;
  final int sessionNumber;
  final int? sessionId; // Current session ID
  final Map<String, List<DataEntry>> latestEntries;
  final Map<String, bool> publisherStatus;
  final int totalEntries; // Global total
  final int storageSizeBytes; // Global storage
  final int sessionEntries; // Session-specific entry count
  final int sessionStorageBytes; // Session-specific storage

  RecordingState({
    this.isRecording = false,
    this.activeExperiment,
    this.sessionNumber = 0,
    this.sessionId,
    Map<String, List<DataEntry>>? latestEntries,
    Map<String, bool>? publisherStatus,
    this.totalEntries = 0,
    this.storageSizeBytes = 0,
    this.sessionEntries = 0,
    this.sessionStorageBytes = 0,
  })  : latestEntries = latestEntries ?? {},
        publisherStatus = publisherStatus ?? {};

  RecordingState copyWith({
    bool? isRecording,
    Experiment? activeExperiment,
    int? sessionNumber,
    int? sessionId,
    Map<String, List<DataEntry>>? latestEntries,
    Map<String, bool>? publisherStatus,
    int? totalEntries,
    int? storageSizeBytes,
    int? sessionEntries,
    int? sessionStorageBytes,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      activeExperiment: activeExperiment ?? this.activeExperiment,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      sessionId: sessionId ?? this.sessionId,
      latestEntries: latestEntries ?? this.latestEntries,
      publisherStatus: publisherStatus ?? this.publisherStatus,
      totalEntries: totalEntries ?? this.totalEntries,
      storageSizeBytes: storageSizeBytes ?? this.storageSizeBytes,
      sessionEntries: sessionEntries ?? this.sessionEntries,
      sessionStorageBytes: sessionStorageBytes ?? this.sessionStorageBytes,
    );
  }
}

/// Recording state notifier (Riverpod 3.x compatible)
class RecordingStateNotifier extends Notifier<RecordingState> {
  RecordingService? _service;
  StreamSubscription<Map<String, List<DataEntry>>>? _latestEntriesSubscription;
  StreamSubscription<int>? _totalEntriesSubscription;
  StreamSubscription<int>? _storageSizeSubscription;
  StreamSubscription<int>? _sessionEntriesSubscription;
  StreamSubscription<int>? _sessionStorageSubscription;

  RecordingService get service {
    _service ??= ref.read(recordingServiceProvider);
    return _service!;
  }

  @override
  RecordingState build() {
    // Initialize service if not already initialized
    _service ??= ref.read(recordingServiceProvider);

    // Listen to latest entries stream
    _latestEntriesSubscription = service.latestEntriesStream.listen(
      (latestEntries) {
        state = state.copyWith(
          latestEntries: latestEntries,
          publisherStatus: service.getPublisherStatus(),
        );
      },
    );
    
    // Listen to total entries stream
    _totalEntriesSubscription = service.totalEntriesStream.listen(
      (totalEntries) {
        state = state.copyWith(totalEntries: totalEntries);
      },
    );
    
    // Listen to storage size stream
    _storageSizeSubscription = service.storageSizeStream.listen(
      (storageSize) {
        state = state.copyWith(storageSizeBytes: storageSize);
      },
    );
    
    // Listen to session-specific entry count
    _sessionEntriesSubscription = service.sessionEntriesStream.listen(
      (sessionEntries) {
        state = state.copyWith(sessionEntries: sessionEntries);
      },
    );
    
    // Listen to session-specific storage
    _sessionStorageSubscription = service.sessionStorageStream.listen(
      (sessionStorage) {
        state = state.copyWith(sessionStorageBytes: sessionStorage);
      },
    );

    ref.onDispose(() {
      _latestEntriesSubscription?.cancel();
      _totalEntriesSubscription?.cancel();
      _storageSizeSubscription?.cancel();
      _sessionEntriesSubscription?.cancel();
      _sessionStorageSubscription?.cancel();
    });

    // Initialize with current values
    _initializeState();

    return RecordingState();
  }
  
  Future<void> _initializeState() async {
    final totalEntries = await service.getCurrentTotalEntries();
    final storageSize = await service.getCurrentStorageSize();
    state = state.copyWith(
      totalEntries: totalEntries,
      storageSizeBytes: storageSize,
      sessionEntries: 0,
      sessionStorageBytes: 0,
    );
  }

  /// Start recording
  Future<void> startRecording(Experiment experiment, List<Topic> topics) async {
    await service.startRecording(experiment, topics);
    final totalEntries = await service.getCurrentTotalEntries();
    final storageSize = await service.getCurrentStorageSize();
    // Get current session ID from service (we'll need to add a getter)
    state = state.copyWith(
      isRecording: true,
      activeExperiment: experiment,
      sessionNumber: service.sessionNumber,
      sessionId: service.getCurrentSessionId(),
      publisherStatus: service.getPublisherStatus(),
      totalEntries: totalEntries,
      storageSizeBytes: storageSize,
      sessionEntries: 0,
      sessionStorageBytes: 0,
    );
  }

  /// Stop recording
  Future<void> stopRecording() async {
    // Stop service first
    await service.stopRecording();
    
    // Reset state immediately for responsive UI
    state = RecordingState();
  }

  /// Get latest entries for a topic
  List<DataEntry> getLatestEntries(String topicName) {
    return service.getLatestEntries(topicName);
  }

  /// Get all latest entries
  Map<String, List<DataEntry>> getAllLatestEntries() {
    return service.getAllLatestEntries();
  }

  /// Get publisher status
  Map<String, bool> getPublisherStatus() {
    return service.getPublisherStatus();
  }
}

/// Recording state provider (Riverpod 3.x)
final recordingStateProvider =
    NotifierProvider<RecordingStateNotifier, RecordingState>(
        RecordingStateNotifier.new);
