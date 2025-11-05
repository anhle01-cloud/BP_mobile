import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'publisher.dart';

/// IMU Publisher using sensors_plus
/// Samples at 60Hz if available
class ImuPublisher implements Publisher {
  final String name = 'imu';
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<UserAccelerometerEvent>? _userAccelSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;

  final StreamController<Map<String, dynamic>> _dataController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _activeController =
      StreamController<bool>.broadcast();

  bool _isActive = false;

  @override
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  @override
  Stream<bool> get isActive => _activeController.stream;

  @override
  bool get isCurrentlyActive => _isActive;

  @override
  Future<void> start() async {
    if (_isActive) return;

    _isActive = true;
    _activeController.add(true);

    // Subscribe to accelerometer
    _accelSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        _emitImuData('acceleration', {
          'x': event.x,
          'y': event.y,
          'z': event.z,
        });
      },
      onError: (error) {
        _dataController.addError(error);
      },
    );

    // Subscribe to gyroscope
    _gyroSubscription = gyroscopeEventStream().listen(
      (GyroscopeEvent event) {
        _emitImuData('gyroscope', {'x': event.x, 'y': event.y, 'z': event.z});
      },
      onError: (error) {
        _dataController.addError(error);
      },
    );

    // Subscribe to user accelerometer (gravity removed)
    _userAccelSubscription = userAccelerometerEventStream().listen(
      (UserAccelerometerEvent event) {
        _emitImuData('user_acceleration', {
          'x': event.x,
          'y': event.y,
          'z': event.z,
        });
      },
      onError: (error) {
        _dataController.addError(error);
      },
    );

    // Subscribe to magnetometer
    _magSubscription = magnetometerEventStream().listen(
      (MagnetometerEvent event) {
        _emitImuData('magnetometer', {
          'x': event.x,
          'y': event.y,
          'z': event.z,
        });
      },
      onError: (error) {
        _dataController.addError(error);
      },
    );
  }

  @override
  Future<void> stop() async {
    if (!_isActive) return;

    await _accelSubscription?.cancel();
    await _gyroSubscription?.cancel();
    await _userAccelSubscription?.cancel();
    await _magSubscription?.cancel();

    _accelSubscription = null;
    _gyroSubscription = null;
    _userAccelSubscription = null;
    _magSubscription = null;

    _isActive = false;
    _activeController.add(false);
  }

  void _emitImuData(String sensorType, Map<String, double> values) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'id': 'imu_${sensorType}_$timestamp',
      'timestamp': timestamp,
      'sensor_type': sensorType,
      'values': values,
    };

    _dataController.add(data);
  }

  void dispose() {
    stop();
    _dataController.close();
    _activeController.close();
  }
}
