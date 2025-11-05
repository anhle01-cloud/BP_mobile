import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/publisher_manager.dart';
import '../models/network_client.dart';
import '../models/topic_history.dart';

/// Publisher manager provider (kept alive to maintain state across screens)
final publisherManagerProvider = Provider<PublisherManager>((ref) {
  final manager = PublisherManager();
  ref.onDispose(() => manager.dispose());
  ref.keepAlive(); // Keep alive to maintain state across screens
  return manager;
});

/// Publisher status provider (watches enabled/active state)
/// Only emits when status actually changes, not on every poll
final publisherStatusProvider = StreamProvider<Map<String, bool>>((ref) {
  final manager = ref.watch(publisherManagerProvider);
  
  // Create a stream that emits status updates only when status changes
  final controller = StreamController<Map<String, bool>>();
  Timer? timer;
  Map<String, bool>? lastStatus;
  
  // Listen to all publisher enabled states
  final subscriptions = <String, StreamSubscription<bool>>{};
  
  bool _mapsEqual(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (var key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
  
  void emitStatus() {
    final currentStatus = manager.getPublisherStatus();
    // Only emit if status actually changed
    if (lastStatus == null || !_mapsEqual(lastStatus!, currentStatus)) {
      lastStatus = Map<String, bool>.from(currentStatus);
      controller.add(currentStatus);
    }
  }
  
  for (var publisherName in ['gps', 'imu', 'external']) {
    subscriptions[publisherName] = manager.getEnabledStream(publisherName).listen(
      (_) => emitStatus(),
    );
  }
  
  // Poll status every 2 seconds (reduced from 1 second) to catch active state changes
  timer = Timer.periodic(const Duration(seconds: 2), (_) => emitStatus());
  
  // Initial status
  emitStatus();
  
  ref.onDispose(() {
    timer?.cancel();
    for (var sub in subscriptions.values) {
      sub.cancel();
    }
    controller.close();
  });
  
  return controller.stream;
});

/// Available topics provider (based on enabled publishers)
/// This provider watches for publisher enabled state changes and updates accordingly
final availableTopicsProvider = StreamProvider<List<String>>((ref) {
  // Watch the manager to ensure it stays alive while the stream is active
  final manager = ref.watch(publisherManagerProvider);
  
  // Create a stream that emits available topics whenever publisher state changes
  final controller = StreamController<List<String>>();
  
  // Listen to all publisher enabled states
  final subscriptions = <String, StreamSubscription<bool>>{};
  
  void emitTopics() {
    try {
      final topics = manager.getAvailableTopics();
      controller.add(topics);
    } catch (e) {
      print('Error getting available topics: $e');
      // Emit empty list on error to prevent crashes
      controller.add([]);
    }
  }
  
  // Listen to enabled state changes for each publisher
  for (var publisherName in ['gps', 'imu', 'external']) {
    try {
      subscriptions[publisherName] = manager.getEnabledStream(publisherName).listen(
        (_) {
          // Emit topics when enabled state changes
          emitTopics();
        },
        onError: (error) {
          print('Error in enabled stream for $publisherName: $error');
          // Try to emit current topics anyway
          try {
            emitTopics();
          } catch (e) {
            print('Error emitting topics after stream error: $e');
          }
        },
        cancelOnError: false, // Don't cancel on error - keep listening
      );
    } catch (e) {
      print('Error subscribing to enabled stream for $publisherName: $e');
      // Continue with other publishers
    }
  }
  
  // Initial topics
  emitTopics();
  
  ref.onDispose(() {
    for (var sub in subscriptions.values) {
      try {
        sub.cancel();
      } catch (e) {
        print('Error canceling subscription: $e');
      }
    }
    subscriptions.clear();
    try {
      controller.close();
    } catch (e) {
      print('Error closing controller: $e');
    }
  });
  
  return controller.stream;
});

/// Connected network clients provider
/// Streams connected ESP32 clients with their connection quality
final connectedClientsProvider = StreamProvider<List<NetworkClient>>((ref) {
  final manager = ref.watch(publisherManagerProvider);
  
  final controller = StreamController<List<NetworkClient>>();
  Timer? timer;
  StreamSubscription<NetworkClient>? connectedSub;
  StreamSubscription<String>? disconnectedSub;
  
  void emitClients() {
    try {
      final webSocketServer = manager.webSocketServer;
      if (webSocketServer != null && webSocketServer.isRunning) {
        final clients = webSocketServer.connectedClients;
        controller.add(clients);
      } else {
        controller.add([]);
      }
    } catch (e) {
      print('Error getting connected clients: $e');
      controller.add([]);
    }
  }
  
  // Listen to client connection/disconnection streams
  Future<void> setupStreams() async {
    final webSocketServer = await manager.getWebSocketServer();
    if (webSocketServer != null) {
      connectedSub = webSocketServer.clientConnectedStream.listen(
        (_) => emitClients(),
      );
      disconnectedSub = webSocketServer.clientDisconnectedStream.listen(
        (_) => emitClients(),
      );
    }
  }
  
  // Initial setup
  setupStreams();
  
  // Poll every 2 seconds to catch connection quality updates
  timer = Timer.periodic(const Duration(seconds: 2), (_) => emitClients());
  
  // Initial emit
  emitClients();
  
  ref.onDispose(() {
    timer?.cancel();
    connectedSub?.cancel();
    disconnectedSub?.cancel();
    controller.close();
  });
  
  return controller.stream;
});

/// Network topics with metadata provider
final networkTopicsProvider = StreamProvider<Map<String, Map<String, dynamic>>>((ref) {
  final manager = ref.watch(publisherManagerProvider);
  final clientsAsync = ref.watch(connectedClientsProvider);
  
  final controller = StreamController<Map<String, Map<String, dynamic>>>();
  Timer? timer;
  
  void emitTopics() {
    try {
      final topics = manager.getNetworkTopics();
      controller.add(topics);
    } catch (e) {
      print('Error getting network topics: $e');
      controller.add({});
    }
  }
  
  // Listen to client changes
  clientsAsync.whenData((_) => emitTopics());
  
  // Initial emit
  emitTopics();
  
  // Poll every 2 seconds
  timer = Timer.periodic(const Duration(seconds: 2), (_) => emitTopics());
  
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  
  return controller.stream;
});

/// Topic history provider (from WebSocket server)
final topicHistoryProvider = StreamProvider<Map<String, List<TopicHistoryEntry>>>((ref) {
  final manager = ref.watch(publisherManagerProvider);
  
  final controller = StreamController<Map<String, List<TopicHistoryEntry>>>();
  Timer? timer;
  
  void emitHistory() {
    try {
      final webSocketServer = manager.webSocketServer;
      if (webSocketServer != null && webSocketServer.isRunning) {
        final historyCache = webSocketServer.topicHistory;
        final topics = historyCache.getTopics();
        final history = <String, List<TopicHistoryEntry>>{};
        
        for (var topic in topics) {
          history[topic] = historyCache.getEntries(topic);
        }
        
        controller.add(history);
      } else {
        controller.add({});
      }
    } catch (e) {
      print('Error getting topic history: $e');
      controller.add({});
    }
  }
  
  // Poll every 1 second for topic history updates
  timer = Timer.periodic(const Duration(seconds: 1), (_) => emitHistory());
  
  // Initial emit
  emitHistory();
  
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  
  return controller.stream;
});

