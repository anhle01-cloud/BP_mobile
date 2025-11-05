import 'dart:async';
import '../websocket_server.dart';
import 'publisher.dart';

/// External Publisher for ESP32 clients via WebSocket
/// Routes data from WebSocket server to topics
class ExternalPublisher implements Publisher {
  final String name = 'external';
  final WebSocketServer server;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  final StreamController<Map<String, dynamic>> _dataController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _activeController =
      StreamController<bool>.broadcast();

  bool _isActive = false;

  ExternalPublisher({required this.server});

  @override
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  @override
  Stream<bool> get isActive => _activeController.stream;

  @override
  bool get isCurrentlyActive => _isActive;

  @override
  Future<void> start() async {
    if (_isActive) return;

    // Start WebSocket server if not already running
    if (!server.isRunning) {
      await server.start();
    }

    _isActive = true;
    _activeController.add(true);

    // Subscribe to server data stream
    _subscription = server.dataStream.listen(
      (data) {
        _dataController.add(data);
      },
      onError: (error) {
        _dataController.addError(error);
      },
      onDone: () {
        _isActive = false;
        _activeController.add(false);
      },
    );
  }

  @override
  Future<void> stop() async {
    if (!_isActive) return;

    await _subscription?.cancel();
    _subscription = null;
    _isActive = false;
    _activeController.add(false);

    // Note: Don't stop the server here as other publishers might use it
  }

  void dispose() {
    stop();
    _dataController.close();
    _activeController.close();
  }
}
