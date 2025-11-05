import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'publisher.dart';

/// GPS Publisher using geolocator
/// Stabilizes before emitting data (>1Hz if available)
class GpsPublisher implements Publisher {
  final String name = 'gps';
  StreamSubscription<Position>? _subscription;
  final StreamController<Map<String, dynamic>> _dataController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _activeController =
      StreamController<bool>.broadcast();

  bool _isActive = false;
  bool _isStabilized = false;
  static const double _minAccuracyMeters = 20.0; // Minimum accuracy threshold
  static const int _stabilizationTimeMs =
      3000; // Wait 3 seconds for stabilization
  DateTime? _startTime;

  @override
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  @override
  Stream<bool> get isActive => _activeController.stream;

  @override
  bool get isCurrentlyActive => _isActive;

  @override
  Future<void> start() async {
    if (_isActive) return;

    // Check permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    _isActive = true;
    _isStabilized = false;
    _startTime = DateTime.now();
    _activeController.add(true);

    // Start listening to position updates
    // Use high accuracy location settings
    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // No distance filter
      timeLimit: null,
    );

    _subscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _handlePosition(position);
          },
          onError: (error) {
            _dataController.addError(error);
          },
        );
  }

  @override
  Future<void> stop() async {
    if (!_isActive) return;

    await _subscription?.cancel();
    _subscription = null;
    _isActive = false;
    _isStabilized = false;
    _startTime = null;
    _activeController.add(false);
  }

  void _handlePosition(Position position) {
    // Check if stabilized
    if (!_isStabilized) {
      final elapsed = DateTime.now().difference(_startTime!);

      // Check if we've waited enough time and have good accuracy
      if (elapsed.inMilliseconds >= _stabilizationTimeMs &&
          position.accuracy <= _minAccuracyMeters) {
        _isStabilized = true;
      } else if (elapsed.inMilliseconds >= _stabilizationTimeMs * 2) {
        // If we've waited twice the stabilization time, proceed anyway
        _isStabilized = true;
      } else {
        // Still stabilizing, skip this position
        return;
      }
    }

    // Emit position data
    final timestamp = position.timestamp.millisecondsSinceEpoch;
    final data = {
      'id': 'gps_$timestamp',
      'timestamp': timestamp,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'altitude': position.altitude,
      'accuracy': position.accuracy,
      'heading': position.heading,
      'speed': position.speed,
      'speed_accuracy': position.speedAccuracy,
      'is_mocked': position.isMocked,
    };

    _dataController.add(data);
  }

  void dispose() {
    stop();
    _dataController.close();
    _activeController.close();
  }
}
