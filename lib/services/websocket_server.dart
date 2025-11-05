import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'network_manager.dart';

/// WebSocket server for ESP32 clients
/// Routes messages to topics
class WebSocketServer {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _clients = {};
  final StreamController<Map<String, dynamic>> _dataController =
      StreamController<Map<String, dynamic>>.broadcast();

  int _port;
  bool _isRunning = false;
  String? _serverIp;

  WebSocketServer({int port = 8080}) : _port = port;

  /// Stream of data from connected clients
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  /// Check if server is running
  bool get isRunning => _isRunning;

  /// Get server IP address
  String? get serverIp => _serverIp;

  /// Get server port
  int get port => _port;

  /// Start the WebSocket server
  /// Uses the best IP address (hotspot if active, otherwise LAN/WiFi)
  Future<void> start({String? bindIp}) async {
    if (_isRunning) return;

    try {
      final handler = webSocketHandler((
        WebSocketChannel channel,
        String? subprotocol,
      ) {
        final clientId = DateTime.now().millisecondsSinceEpoch.toString();
        _clients[clientId] = channel;

        print('Client connected: $clientId');

        // Listen to messages from client
        channel.stream.listen(
          (message) {
            _handleMessage(clientId, message);
          },
          onError: (error) {
            print('WebSocket error from $clientId: $error');
            _clients.remove(clientId);
          },
          onDone: () {
            print('Client disconnected: $clientId');
            _clients.remove(clientId);
          },
        );

        // Send welcome message
        channel.sink.add(
          jsonEncode({
            'type': 'welcome',
            'client_id': clientId,
            'message': 'Connected to BlackPearl Mobile server',
          }),
        );
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

      print('WebSocket server started on ${_serverIp ?? 'unknown'}:$_port');
    } catch (e) {
      print('Error starting WebSocket server: $e');
      rethrow;
    }
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

    // Close all client connections
    for (var client in _clients.values) {
      try {
        await client.sink.close();
      } catch (e) {
        print('Error closing client connection: $e');
      }
    }
    _clients.clear();

    // Close server
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    _serverIp = null;

    print('WebSocket server stopped');
  }

  /// Handle incoming message from client
  void _handleMessage(String clientId, dynamic message) {
    try {
      final data = jsonDecode(message.toString()) as Map<String, dynamic>;

      // Expected format: { "topic": "topic/name", "data": {...} }
      final topicName = data['topic'] as String?;
      final payload = data['data'] as Map<String, dynamic>?;

      if (topicName == null || payload == null) {
        print('Invalid message format from $clientId: $message');
        return;
      }

      // Add metadata
      final enrichedData = {
        'id': 'external_${clientId}_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'client_id': clientId,
        'topic_name': topicName,
        'data': payload,
      };

      _dataController.add(enrichedData);
    } catch (e) {
      print('Error handling message from $clientId: $e');
    }
  }

  /// Send message to all connected clients
  void broadcast(Map<String, dynamic> message) {
    final jsonMessage = jsonEncode(message);
    for (var client in _clients.values) {
      try {
        client.sink.add(jsonMessage);
      } catch (e) {
        print('Error broadcasting to client: $e');
      }
    }
  }

  /// Send message to specific client
  void sendToClient(String clientId, Map<String, dynamic> message) {
    final client = _clients[clientId];
    if (client != null) {
      try {
        client.sink.add(jsonEncode(message));
      } catch (e) {
        print('Error sending to client $clientId: $e');
      }
    }
  }

  /// Get number of connected clients
  int get clientCount => _clients.length;

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
  }
}
