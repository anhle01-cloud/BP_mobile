import 'dart:async';
import 'publishers/publisher.dart';
import 'publishers/gps_publisher.dart';
import 'publishers/imu_publisher.dart';
import 'publishers/external_publisher.dart';
import 'websocket_server.dart';
import 'network_manager.dart';

/// Publisher Manager manages all publishers independently of recording state
/// Publishers emit data continuously when enabled, allowing multiple consumers
/// (recording sessions, dashboard widgets, etc.) to subscribe to the same streams
class PublisherManager {
  // Publisher instances
  final GpsPublisher _gpsPublisher = GpsPublisher();
  final ImuPublisher _imuPublisher = ImuPublisher();
  ExternalPublisher? _externalPublisher;
  WebSocketServer? _webSocketServer;

  // Enable/disable state for each publisher
  final Map<String, bool> _enabledState = {
    'gps': false,
    'imu': false,
    'external': false,
  };

  // Sampling rates for internal publishers (stored per publisher, not per topic)
  final Map<String, double> _samplingRates = {
    'gps': 1.0, // Default 1 Hz for GPS
    'imu': 60.0, // Default 60 Hz for IMU
  };

  // Stream controllers for enable/disable state changes
  final Map<String, StreamController<bool>> _enabledControllers = {};
  
  // Stream controllers for sampling rate changes
  final Map<String, StreamController<double>> _samplingRateControllers = {};

  PublisherManager() {
    // Initialize stream controllers
    for (var key in _enabledState.keys) {
      _enabledControllers[key] = StreamController<bool>.broadcast();
    }
    
    // Initialize sampling rate controllers for internal publishers
    for (var key in _samplingRates.keys) {
      _samplingRateControllers[key] = StreamController<double>.broadcast();
    }

    // Listen to publisher active states
    _gpsPublisher.isActive.listen((isActive) {
      _enabledControllers['gps']?.add(_enabledState['gps']! && isActive);
    });
    _imuPublisher.isActive.listen((isActive) {
      _enabledControllers['imu']?.add(_enabledState['imu']! && isActive);
    });
  }

  /// Get GPS publisher
  GpsPublisher get gpsPublisher => _gpsPublisher;

  /// Get IMU publisher
  ImuPublisher get imuPublisher => _imuPublisher;

  /// Get External publisher (creates if needed)
  ExternalPublisher? get externalPublisher => _externalPublisher;

  /// Get WebSocket server (creates if needed)
  Future<WebSocketServer?> getWebSocketServer() async {
    if (_webSocketServer == null) {
      _webSocketServer = WebSocketServer();
      _externalPublisher = ExternalPublisher(server: _webSocketServer!);
      await _webSocketServer!.start();
      
      // Listen to external publisher active state
      _externalPublisher?.isActive.listen((isActive) {
        _enabledControllers['external']?.add(_enabledState['external']! && isActive);
      });
    }
    return _webSocketServer;
  }

  /// Get sampling rate for a publisher
  double getSamplingRate(String publisherName) {
    return _samplingRates[publisherName] ?? 1.0;
  }

  /// Set sampling rate for a publisher (GPS or IMU only)
  void setSamplingRate(String publisherName, double rate) {
    if (publisherName == 'gps' || publisherName == 'imu') {
      _samplingRates[publisherName] = rate;
      _samplingRateControllers[publisherName]?.add(rate);
    }
  }

  /// Get stream of sampling rate changes for a publisher
  Stream<double> getSamplingRateStream(String publisherName) {
    return _samplingRateControllers[publisherName]?.stream ?? 
           Stream.value(_samplingRates[publisherName] ?? 1.0);
  }

  /// Get available topics based on enabled publishers
  /// Returns list of topic names that can be recorded
  List<String> getAvailableTopics() {
    final topics = <String>[];
    
    if (_enabledState['gps'] == true) {
      topics.add('gps/location');
    }
    
    if (_enabledState['imu'] == true) {
      topics.add('imu/acceleration');
      topics.add('imu/gyroscope');
      topics.add('imu/magnetometer');
      topics.add('imu/user_acceleration');
    }
    
    if (_enabledState['external'] == true) {
      // External topics are dynamic - they come from ESP32
      // We'll add them as they're discovered, but for now just show the base topic
      topics.add('external/data');
    }
    
    return topics;
  }

  /// Get WebSocket server info (IP and port)
  /// Uses hotspot IP if hotspot is active, otherwise uses LAN IP
  Future<Map<String, String?>> getWebSocketServerInfo() async {
    if (_webSocketServer == null || !_webSocketServer!.isRunning) {
      return {
        'ip': null,
        'port': null,
        'url': null,
      };
    }

    final ip = await _getBestIpAddress();
    final port = _webSocketServer!.port.toString();
    final url = ip != null ? 'ws://$ip:$port' : null;

    return {
      'ip': ip,
      'port': port,
      'url': url,
    };
  }

  /// Get best IP address (hotspot IP if active, otherwise LAN IP)
  Future<String?> _getBestIpAddress() async {
    try {
      // Import NetworkManager
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
      // Fallback to server IP if available
      return _webSocketServer?.serverIp;
    }
  }

  /// Enable a publisher (starts it if not already running)
  Future<void> enablePublisher(String publisherName) async {
    if (_enabledState[publisherName] == true) return;

    _enabledState[publisherName] = true;
    _enabledControllers[publisherName]?.add(true);

    try {
      switch (publisherName) {
        case 'gps':
          await _gpsPublisher.start();
          break;
        case 'imu':
          await _imuPublisher.start();
          break;
        case 'external':
          await getWebSocketServer();
          await _externalPublisher?.start();
          break;
      }
    } catch (e) {
      // If start fails, revert enabled state
      _enabledState[publisherName] = false;
      _enabledControllers[publisherName]?.add(false);
      rethrow;
    }
  }

  /// Disable a publisher (stops it)
  Future<void> disablePublisher(String publisherName) async {
    if (_enabledState[publisherName] == false) return;

    _enabledState[publisherName] = false;
    _enabledControllers[publisherName]?.add(false);

    try {
      switch (publisherName) {
        case 'gps':
          await _gpsPublisher.stop();
          break;
        case 'imu':
          await _imuPublisher.stop();
          break;
        case 'external':
          await _externalPublisher?.stop();
          // Don't stop WebSocket server - it may be needed for other purposes
          break;
      }
    } catch (e) {
      print('Error disabling publisher $publisherName: $e');
    }
  }

  /// Check if a publisher is enabled
  bool isPublisherEnabled(String publisherName) {
    return _enabledState[publisherName] ?? false;
  }

  /// Check if a publisher is active (running and emitting data)
  bool isPublisherActive(String publisherName) {
    switch (publisherName) {
      case 'gps':
        return _enabledState['gps']! && _gpsPublisher.isCurrentlyActive;
      case 'imu':
        return _enabledState['imu']! && _imuPublisher.isCurrentlyActive;
      case 'external':
        return _enabledState['external']! && 
               (_externalPublisher?.isCurrentlyActive ?? false);
      default:
        return false;
    }
  }

  /// Get publisher status (enabled, active, etc.)
  Map<String, bool> getPublisherStatus() {
    return {
      'gps': isPublisherActive('gps'),
      'imu': isPublisherActive('imu'),
      'external': isPublisherActive('external'),
    };
  }

  /// Get stream of enabled state for a publisher
  Stream<bool> getEnabledStream(String publisherName) {
    return _enabledControllers[publisherName]?.stream ?? 
           Stream.value(false);
  }

  /// Get publisher instance by name
  Publisher? getPublisher(String publisherName) {
    switch (publisherName) {
      case 'gps':
        return _gpsPublisher;
      case 'imu':
        return _imuPublisher;
      case 'external':
        return _externalPublisher;
      default:
        return null;
    }
  }

  /// Get publisher data stream (for subscribing to data)
  Stream<Map<String, dynamic>>? getPublisherDataStream(String publisherName) {
    return getPublisher(publisherName)?.dataStream;
  }

  /// Stop WebSocket server (call when truly shutting down)
  Future<void> stopWebSocketServer() async {
    await _externalPublisher?.stop();
    await _webSocketServer?.stop();
    _webSocketServer = null;
    _externalPublisher = null;
  }

  /// Dispose all resources
  void dispose() {
    // Stop all publishers
    _gpsPublisher.dispose();
    _imuPublisher.dispose();
    _externalPublisher?.dispose();
    
    // Close stream controllers
    for (var controller in _enabledControllers.values) {
      controller.close();
    }
    _enabledControllers.clear();
    
    for (var controller in _samplingRateControllers.values) {
      controller.close();
    }
    _samplingRateControllers.clear();

    // Stop WebSocket server
    stopWebSocketServer();
  }
}
