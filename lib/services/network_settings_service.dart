import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing network settings (port, etc.)
class NetworkSettingsService {
  static const String _portKey = 'websocket_port';
  static const int _defaultPort = 3000;

  /// Get configured WebSocket port
  Future<int> getPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_portKey) ?? _defaultPort;
  }

  /// Set WebSocket port
  Future<void> setPort(int port) async {
    if (port < 1 || port > 65535) {
      throw ArgumentError('Port must be between 1 and 65535');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_portKey, port);
  }

  /// Get default port
  static int get defaultPort => _defaultPort;
}

