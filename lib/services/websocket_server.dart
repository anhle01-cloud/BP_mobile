import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/network_client.dart';
import '../models/topic_history.dart';
import 'network_manager.dart';

/// WebSocket server for ESP32 clients with enhanced features:
/// - Client registration with name management
/// - Ping/pong heartbeat for connection quality
/// - Automatic topic discovery
/// - Topic history tracking
class WebSocketServer {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _clientChannels = {}; // client_name -> channel
  final Map<String, NetworkClient> _clients = {}; // client_name -> client info
  final StreamController<Map<String, dynamic>> _dataController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<NetworkClient> _clientConnectedController =
      StreamController<NetworkClient>.broadcast();
  final StreamController<String> _clientDisconnectedController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _topicDiscoveredController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Topic history cache
  final TopicHistoryCache _topicHistory = TopicHistoryCache();

  // Ping/pong tracking
  final Map<String, DateTime> _pendingPings = {}; // client_name -> ping timestamp
  Timer? _pingTimer;
  Timer? _connectionQualityTimer;

  int _port;
  bool _isRunning = false;
  String? _serverIp;
  final Set<String> _subscribedTopics = {}; // Topics to filter from message pool
  static const int _pingIntervalSeconds = 10; // Send ping every 10 seconds
  static const int _maxMissedPings = 3; // Consider disconnected after 3 missed pings

  WebSocketServer({int port = 3000}) : _port = port;

  /// Set port (requires restart if server is running)
  void setPort(int port) {
    if (port < 1 || port > 65535) {
      throw ArgumentError('Port must be between 1 and 65535');
    }
    if (_isRunning) {
      throw StateError('Cannot change port while server is running. Stop server first.');
    }
    _port = port;
  }

  /// Get current port
  int get port => _port;

  /// Subscribe to a topic (filter messages)
  void subscribeTopic(String topicName) {
    _subscribedTopics.add(topicName);
  }

  /// Unsubscribe from a topic
  void unsubscribeTopic(String topicName) {
    _subscribedTopics.remove(topicName);
  }

  /// Check if a topic is subscribed
  /// Returns true if topic is subscribed, or if no subscriptions exist (backward compatible)
  bool isTopicSubscribed(String topicName) {
    // If no subscriptions, allow all (backward compatible)
    if (_subscribedTopics.isEmpty) return true;
    return _subscribedTopics.contains(topicName);
  }

  /// Get all subscribed topics
  Set<String> get subscribedTopics => Set<String>.from(_subscribedTopics);

  /// Clear all subscriptions
  void clearSubscriptions() {
    _subscribedTopics.clear();
  }

  /// Bulk subscribe to topics
  void subscribeTopics(List<String> topicNames) {
    _subscribedTopics.addAll(topicNames);
  }

  /// Bulk unsubscribe from topics
  void unsubscribeTopics(List<String> topicNames) {
    _subscribedTopics.removeAll(topicNames);
  }

  /// Stream of data from connected clients
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  /// Stream of client connections
  Stream<NetworkClient> get clientConnectedStream => _clientConnectedController.stream;

  /// Stream of client disconnections
  Stream<String> get clientDisconnectedStream => _clientDisconnectedController.stream;

  /// Stream of topic discoveries
  Stream<Map<String, dynamic>> get topicDiscoveredStream => _topicDiscoveredController.stream;

  /// Get topic history cache
  TopicHistoryCache get topicHistory => _topicHistory;

  /// Get all connected clients
  List<NetworkClient> get connectedClients => _clients.values.where((c) => c.isConnected).toList();

  /// Get client by name
  NetworkClient? getClient(String clientName) => _clients[clientName];

  /// Check if server is running
  bool get isRunning => _isRunning;

  /// Get server IP address
  String? get serverIp => _serverIp;


  /// Start the WebSocket server
  /// Uses the best IP address (hotspot if active, otherwise LAN/WiFi)
  Future<void> start({String? bindIp}) async {
    if (_isRunning) return;

    try {
      final handler = webSocketHandler((
        WebSocketChannel channel,
        String? subprotocol,
      ) {
        // Client connecting - will register with name
        _handleNewConnection(channel);
      });

      final pipeline = shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler(handler);

      // Start server - bind to any IPv4 to accept connections from any interface
      final server = await shelf_io.serve(
        pipeline,
        bindIp ?? InternetAddress.anyIPv4,
        _port,
      );

      _server = server;
      _isRunning = true;

      // Get the best IP address (hotspot if active, otherwise LAN/WiFi)
      _serverIp = bindIp ?? await _getBestIpAddress();

      // Start ping/pong timer
      _startPingTimer();
      _startConnectionQualityTimer();

      print('WebSocket server started on ${_serverIp ?? 'unknown'}:$_port');
    } catch (e) {
      print('Error starting WebSocket server: $e');
      rethrow;
    }
  }

  /// Handle new WebSocket connection
  void _handleNewConnection(WebSocketChannel channel) {
    String? clientName;
    
    // Listen to messages from client
    channel.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message.toString()) as Map<String, dynamic>;
          final type = data['type'] as String?;

          switch (type) {
            case 'register':
              final registeredName = _handleRegistration(channel, data);
              if (registeredName != null) {
                clientName = registeredName;
              }
              break;
            case 'data':
              if (clientName != null && clientName!.isNotEmpty) {
                _handleDataMessage(clientName!, data);
              } else {
                print('Received data message before registration');
              }
              break;
            case 'pong':
              if (clientName != null && clientName!.isNotEmpty) {
                _handlePong(clientName!, data);
              } else {
                print('Received pong before registration');
              }
              break;
            case 'topics_update':
              if (clientName != null && clientName!.isNotEmpty) {
                _handleTopicsUpdate(clientName!, data);
              } else {
                print('Received topics_update before registration');
              }
              break;
            default:
              print('Unknown message type: $type');
          }
        } catch (e) {
          print('Error parsing message: $e');
        }
      },
      onError: (error) {
        print('WebSocket error from $clientName: $error');
        if (clientName != null && clientName!.isNotEmpty) {
          _handleClientDisconnect(clientName!);
        }
      },
      onDone: () {
        print('Client disconnected: $clientName');
        if (clientName != null && clientName!.isNotEmpty) {
          _handleClientDisconnect(clientName!);
        }
      },
    );
  }

  /// Handle client registration
  /// Returns the registered client name if successful, null otherwise
  String? _handleRegistration(
    WebSocketChannel channel,
    Map<String, dynamic> data,
  ) {
    final clientName = data['client_name'] as String?;
    final topics = (data['topics'] as List<dynamic>?)?.cast<String>() ?? [];
    final topicMetadataJson = data['topic_metadata'] as Map<String, dynamic>? ?? {};

    if (clientName == null || clientName.isEmpty) {
      channel.sink.add(jsonEncode({
        'type': 'registration_response',
        'status': 'rejected',
        'message': 'Client name is required',
      }));
      return null;
    }

    // Check for duplicate name - only reject if there's an ACTIVE connection
    // If old client is disconnected, allow re-registration (for fast reboots)
    final existingClient = _clients[clientName];
    if (existingClient != null && existingClient.isConnected) {
      // Check if the existing client's channel is still valid
      final existingChannel = _clientChannels[clientName];
      if (existingChannel != null) {
        channel.sink.add(jsonEncode({
          'type': 'registration_response',
          'status': 'rejected',
          'client_name': clientName,
          'message': 'Client name already exists. Please choose a different name.',
        }));
        return null;
      } else {
        // Channel is gone but client entry exists - clean it up
        print('Cleaning up stale client entry: $clientName');
        _clients.remove(clientName);
        _pendingPings.remove(clientName);
      }
    }
    
    // If client exists but is disconnected, remove it to allow re-registration
    if (existingClient != null && !existingClient.isConnected) {
      print('Removing disconnected client to allow re-registration: $clientName');
      _clients.remove(clientName);
      _clientChannels.remove(clientName);
      _pendingPings.remove(clientName);
    }

    // Register client
    final topicMetadata = <String, TopicMetadata>{};
    for (var entry in topicMetadataJson.entries) {
      try {
        topicMetadata[entry.key] = TopicMetadata.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
      } catch (e) {
        print('Error parsing metadata for topic ${entry.key}: $e');
      }
    }

    final client = NetworkClient(
      name: clientName,
      connectedAt: DateTime.now(),
      topics: topics,
      topicMetadata: topicMetadata,
      isConnected: true,
    );

    _clients[clientName] = client;
    _clientChannels[clientName] = channel;

    // Send registration response with system time for timestamp synchronization
    final now = DateTime.now();
    final systemTimeMs = now.millisecondsSinceEpoch;
    channel.sink.add(jsonEncode({
      'type': 'registration_response',
      'status': 'accepted',
      'client_name': clientName,
      'message': 'Registration successful',
      'server_info': {
        'ip': _serverIp,
        'port': _port,
      },
      'system_time': {
        'timestamp_ms': systemTimeMs,
        'iso8601': now.toIso8601String(),
        'timezone_offset_hours': now.timeZoneOffset.inHours,
      },
    }));

    // Emit client connected event
    _clientConnectedController.add(client);

    // Emit topic discoveries
    for (var topic in topics) {
      final fullTopicName = '$clientName/$topic';
      _topicDiscoveredController.add({
        'topic': fullTopicName,
        'client_name': clientName,
        'metadata': topicMetadata[topic],
      });
    }

    print('Client registered: $clientName with ${topics.length} topics');
    return clientName;
  }

  /// Handle data message from client
  void _handleDataMessage(String clientName, Map<String, dynamic> data) {
    final topic = data['topic'] as String?;
    final payload = data['data'] as Map<String, dynamic>?;
    final timestamp = data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

    if (topic == null || payload == null) {
      print('Invalid data message format from $clientName: $data');
      return;
    }

    // Format: client_name/topic_tree
    final fullTopicName = '$clientName/$topic';
    
    // Filter based on subscriptions
    if (!isTopicSubscribed(fullTopicName)) {
      // Topic is not subscribed, skip this message
      return;
    }
    
    final entryId = '${clientName}_${topic}_$timestamp';

    // Add to topic history (last 5 entries per topic)
    _topicHistory.addEntry(fullTopicName, payload, timestamp, entryId);

    // Add metadata and emit
    final enrichedData = {
      'id': entryId,
      'timestamp': timestamp,
      'client_name': clientName,
      'topic_name': fullTopicName,
      'data': payload,
    };

    _dataController.add(enrichedData);
  }

  /// Handle pong response from client
  void _handlePong(String clientName, Map<String, dynamic> data) {
    final pingId = data['ping_id'] as String?;
    if (pingId == null || !_pendingPings.containsKey(clientName)) return;

    final pingTime = _pendingPings.remove(clientName);
    if (pingTime != null) {
      final latency = DateTime.now().difference(pingTime).inMilliseconds;
      final client = _clients[clientName];
      if (client != null) {
        _clients[clientName] = client.copyWith(
          lastPongSent: DateTime.now(),
          latencyMs: latency,
          missedPings: 0, // Reset missed pings on successful pong
        );
      }
    }
  }

  /// Handle topics update from client
  void _handleTopicsUpdate(String clientName, Map<String, dynamic> data) {
    final topics = (data['topics'] as List<dynamic>?)?.cast<String>() ?? [];
    final topicMetadataJson = data['topic_metadata'] as Map<String, dynamic>? ?? {};

    final client = _clients[clientName];
    if (client == null) return;

    final topicMetadata = <String, TopicMetadata>{};
    for (var entry in topicMetadataJson.entries) {
      topicMetadata[entry.key] = TopicMetadata.fromJson(
        Map<String, dynamic>.from(entry.value),
      );
    }

    // Update client with new topics
    _clients[clientName] = client.copyWith(
      topics: topics,
      topicMetadata: topicMetadata,
    );

    // Emit topic discoveries
    for (var topic in topics) {
      final fullTopicName = '$clientName/$topic';
      _topicDiscoveredController.add({
        'topic': fullTopicName,
        'client_name': clientName,
        'metadata': topicMetadata[topic],
      });
    }

    print('Topics updated for client $clientName: ${topics.length} topics');
  }

  /// Handle client disconnect
  /// Immediately removes client registration to allow fast reconnection
  void _handleClientDisconnect(String clientName) {
    print('Client disconnected: $clientName - cleaning up immediately');
    
    // Immediately remove from channels and clients to allow fast reconnection
    _clientChannels.remove(clientName);
    _clients.remove(clientName);
    _pendingPings.remove(clientName);
    
    // Emit disconnect event
    _clientDisconnectedController.add(clientName);
    
    print('Client $clientName cleaned up - ready for re-registration');
  }

  /// Manually disconnect a client by name
  /// Closes the WebSocket connection and cleans up
  Future<void> disconnectClient(String clientName) async {
    print('Manually disconnecting client: $clientName');
    
    // Close the WebSocket channel
    final channel = _clientChannels[clientName];
    if (channel != null) {
      try {
        await channel.sink.close();
        print('WebSocket channel closed for $clientName');
      } catch (e) {
        print('Error closing channel for $clientName: $e');
      }
    }
    
    // Clean up (this will also trigger _handleClientDisconnect via onDone)
    // But we'll also call it directly to ensure cleanup
    _handleClientDisconnect(clientName);
  }

  /// Start ping timer to send periodic pings
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      Duration(seconds: _pingIntervalSeconds),
      (_) {
        if (!_isRunning) return;

        for (var entry in _clientChannels.entries) {
          final clientName = entry.key;
          final channel = entry.value;
          final client = _clients[clientName];

          if (client == null || !client.isConnected) continue;

          try {
            final pingId = DateTime.now().millisecondsSinceEpoch.toString();
            _pendingPings[clientName] = DateTime.now();

            channel.sink.add(jsonEncode({
              'type': 'ping',
              'ping_id': pingId,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }));

            // Update last ping sent time
            _clients[clientName] = client.copyWith(
              lastPingReceived: DateTime.now(),
            );
          } catch (e) {
            print('Error sending ping to $clientName: $e');
            _handleClientDisconnect(clientName);
          }
        }
      },
    );
  }

  /// Start connection quality timer to check for missed pings
  void _startConnectionQualityTimer() {
    _connectionQualityTimer?.cancel();
    _connectionQualityTimer = Timer.periodic(
      Duration(seconds: _pingIntervalSeconds * 2),
      (_) {
        if (!_isRunning) return;

        for (var clientName in _clients.keys.toList()) {
          final client = _clients[clientName];
          if (client == null || !client.isConnected) continue;

          // Check if pong was received recently
          if (client.lastPongSent == null ||
              DateTime.now().difference(client.lastPongSent!).inSeconds >
                  _pingIntervalSeconds * 2) {
            // Missed ping
            final missedPings = client.missedPings + 1;
            _clients[clientName] = client.copyWith(missedPings: missedPings);

            if (missedPings >= _maxMissedPings) {
              print('Client $clientName missed $missedPings pings, marking as disconnected');
              _handleClientDisconnect(clientName);
            }
          }
        }
      },
    );
  }

  /// Get best IP address (hotspot IP if active, otherwise LAN IP)
  Future<String?> _getBestIpAddress() async {
    try {
      final networkManager = NetworkManager();

      // Check if hotspot is active
      final isHotspot = await networkManager.isHotspotActive();

      if (isHotspot) {
        // Use hotspot IP
        final hotspotIp = await networkManager.getHotspotIpAddress();
        if (hotspotIp != null) {
          return hotspotIp;
        }
      }

      // Otherwise, use LAN IP (WiFi connection)
      final lanIp = await networkManager.getLanIpAddress();
      if (lanIp != null) {
        return lanIp;
      }

      // Fallback: try to get any IP
      final anyIp = await networkManager.getIpAddress();
      return anyIp;
    } catch (e) {
      print('Error getting best IP address: $e');
      // Fallback to local IP detection
      return await _getLocalIpAddress();
    }
  }

  /// Stop the WebSocket server
  Future<void> stop() async {
    if (!_isRunning) return;

    // Cancel timers
    _pingTimer?.cancel();
    _connectionQualityTimer?.cancel();

    // Close all client connections
    for (var client in _clientChannels.values) {
      try {
        await client.sink.close();
      } catch (e) {
        print('Error closing client connection: $e');
      }
    }
    _clientChannels.clear();
    _clients.clear();
    _pendingPings.clear();

    // Close server
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    _serverIp = null;

    print('WebSocket server stopped');
  }

  /// Send message to specific client
  void sendToClient(String clientName, Map<String, dynamic> message) {
    final client = _clientChannels[clientName];
    if (client != null) {
      try {
        client.sink.add(jsonEncode(message));
      } catch (e) {
        print('Error sending to client $clientName: $e');
      }
    }
  }

  /// Broadcast message to all connected clients
  void broadcast(Map<String, dynamic> message) {
    final jsonMessage = jsonEncode(message);
    for (var entry in _clientChannels.entries) {
      try {
        entry.value.sink.add(jsonMessage);
      } catch (e) {
        print('Error broadcasting to client ${entry.key}: $e');
      }
    }
  }

  /// Get number of connected clients
  int get clientCount => _clients.values.where((c) => c.isConnected).length;

  /// Get local IP address
  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    return null;
  }

  void dispose() {
    stop();
    _dataController.close();
    _clientConnectedController.close();
    _clientDisconnectedController.close();
    _topicDiscoveredController.close();
    _topicHistory.clear();
  }
}
