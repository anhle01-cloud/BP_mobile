import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../providers/publisher_provider.dart';
import '../../services/publisher_manager.dart';

class PublishersViewScreen extends ConsumerStatefulWidget {
  const PublishersViewScreen({super.key});

  @override
  ConsumerState<PublishersViewScreen> createState() => _PublishersViewScreenState();
}

class _PublishersViewScreenState extends ConsumerState<PublishersViewScreen> {
  // Controllers for sampling rate text fields to avoid rebuild issues
  final Map<String, TextEditingController> _rateControllers = {};
  
  // Cache for WebSocket server info to prevent constant refreshes
  Future<Map<String, String?>>? _cachedWebSocketInfo;
  DateTime? _lastWebSocketInfoFetch;
  static const _cacheDuration = Duration(seconds: 5);
  
  @override
  void dispose() {
    for (var controller in _rateControllers.values) {
      controller.dispose();
    }
    _rateControllers.clear();
    super.dispose();
  }
  
  Future<Map<String, String?>> _getWebSocketServerInfo(PublisherManager manager) async {
    final now = DateTime.now();
    
    // Return cached result if still valid
    if (_cachedWebSocketInfo != null && 
        _lastWebSocketInfoFetch != null &&
        now.difference(_lastWebSocketInfoFetch!) < _cacheDuration) {
      try {
        return await _cachedWebSocketInfo!;
      } catch (e) {
        // If cached future failed, fetch new one
        _cachedWebSocketInfo = null;
      }
    }
    
    // Fetch new info
    _cachedWebSocketInfo = manager.getWebSocketServerInfo();
    _lastWebSocketInfoFetch = now;
    return _cachedWebSocketInfo!;
  }
  
  
  @override
  Widget build(BuildContext context) {
    final publisherManager = ref.watch(publisherManagerProvider);
    final statusAsync = ref.watch(publisherStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Publishers'),
        backgroundColor: AppColors.main,
        foregroundColor: Colors.white,
      ),
      body: statusAsync.when(
        data: (status) => _buildPublishersView(context, publisherManager, status),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildPublishersView(
    BuildContext context,
    PublisherManager manager,
    Map<String, bool> status,
  ) {
    final publishers = [
      {
        'name': 'gps',
        'displayName': 'GPS',
        'description': 'Location data from device GPS',
        'icon': Icons.location_on,
      },
      {
        'name': 'imu',
        'displayName': 'IMU',
        'description': 'Accelerometer, gyroscope, and magnetometer data',
        'icon': Icons.sensors,
      },
      {
        'name': 'external',
        'displayName': 'External (ESP32)',
        'description': 'Data from ESP32 clients via WebSocket',
        'icon': Icons.wifi,
      },
    ];

    final isExternalEnabled = manager.isPublisherEnabled('external');
    final isExternalActive = status['external'] ?? false;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Publisher Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enable publishers to start emitting data. Publishers run independently of recording sessions.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // WebSocket connection info card (only show when external publisher is enabled)
        if (isExternalEnabled)
          FutureBuilder<Map<String, String?>>(
            key: const ValueKey('websocket_info_card'),
            future: _getWebSocketServerInfo(manager),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Card(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              
              final serverInfo = snapshot.data ?? {};
              final ip = serverInfo['ip'] ?? 'Waiting...';
              final port = serverInfo['port'] ?? '8080';
              final url = serverInfo['url'] ?? 'ws://$ip:$port';

              return Card(
                color: AppColors.accent.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.wifi,
                            color: AppColors.accent,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'WebSocket Server',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isExternalActive
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExternalActive ? 'Active' : 'Starting...',
                            style: TextStyle(
                              fontSize: 12,
                              color: isExternalActive
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildConnectionInfoRow(
                        'IP Address',
                        ip,
                        Icons.my_location,
                      ),
                      const SizedBox(height: 8),
                      _buildConnectionInfoRow(
                        'Port',
                        port,
                        Icons.numbers,
                      ),
                      const SizedBox(height: 8),
                      _buildConnectionInfoRow(
                        'WebSocket URL',
                        url,
                        Icons.link,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ESP32 Connection:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              url,
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'monospace',
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Connect your ESP32 to this device\'s hotspot and use the URL above.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        if (isExternalEnabled) const SizedBox(height: 16),

        // Publishers list
        ...publishers.map((publisher) {
          final publisherName = publisher['name'] as String;
          final isActive = status[publisherName] ?? false;
          final isEnabled = manager.isPublisherEnabled(publisherName);
          final hasSamplingRate = publisherName == 'gps' || publisherName == 'imu';

          return Card(
            key: ValueKey('publisher_$publisherName'),
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: isActive 
                    ? AppColors.accent 
                    : (isEnabled ? AppColors.textSecondary : AppColors.textTertiary),
                child: Icon(
                  publisher['icon'] as IconData,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      publisher['displayName'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasSamplingRate && isEnabled) ...[
                    const SizedBox(width: 4),
                    Consumer(
                      builder: (context, ref, child) {
                        final rate = manager.getSamplingRate(publisherName);
                        return Text(
                          '${rate.toStringAsFixed(1)} Hz',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              subtitle: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive 
                          ? AppColors.accent 
                          : AppColors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isActive 
                        ? 'Active - Emitting data' 
                        : (isEnabled ? 'Enabled - Starting...' : 'Disabled'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive 
                          ? AppColors.accent 
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              trailing: Switch(
                value: isEnabled,
                onChanged: (value) async {
                  try {
                    if (value) {
                      await manager.enablePublisher(publisherName);
                    } else {
                      await manager.disablePublisher(publisherName);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppColors.main,
                        ),
                      );
                    }
                  }
                },
                activeThumbColor: AppColors.accent,
              ),
              children: hasSamplingRate ? [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        publisher['description'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sampling Rate',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSamplingRateInput(
                        context,
                        manager,
                        publisherName,
                      ),
                    ],
                  ),
                ),
              ] : [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    publisher['description'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConnectionInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSamplingRateInput(
    BuildContext context,
    PublisherManager manager,
    String publisherName,
  ) {
    final maxRate = publisherName == 'gps' ? 10.0 : 100.0;
    final currentRate = manager.getSamplingRate(publisherName);
    
    // Initialize controller if not exists
    if (!_rateControllers.containsKey(publisherName)) {
      _rateControllers[publisherName] = TextEditingController(
        text: currentRate.toStringAsFixed(1),
      );
    }
    
    return _SamplingRateTextField(
      key: ValueKey('rate_field_$publisherName'),
      controller: _rateControllers[publisherName]!,
      initialValue: currentRate,
      maxRate: maxRate,
      onChanged: (newRate) {
        manager.setSamplingRate(publisherName, newRate);
        // Update controller text
        _rateControllers[publisherName]!.text = newRate.toStringAsFixed(1);
      },
    );
  }
}

class _SamplingRateTextField extends StatefulWidget {
  final TextEditingController controller;
  final double initialValue;
  final double maxRate;
  final Function(double) onChanged;

  const _SamplingRateTextField({
    super.key,
    required this.controller,
    required this.initialValue,
    required this.maxRate,
    required this.onChanged,
  });

  @override
  State<_SamplingRateTextField> createState() => _SamplingRateTextFieldState();
}

class _SamplingRateTextFieldState extends State<_SamplingRateTextField> {
  double? _lastValidValue;

  @override
  void initState() {
    super.initState();
    _lastValidValue = widget.initialValue;
    if (widget.controller.text.isEmpty) {
      widget.controller.text = widget.initialValue.toStringAsFixed(1);
    }
  }

  @override
  void didUpdateWidget(_SamplingRateTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _lastValidValue) {
      _lastValidValue = widget.initialValue;
      widget.controller.text = widget.initialValue.toStringAsFixed(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: 'Sampling Rate (Hz)',
        hintText: '0.1 - ${widget.maxRate.toStringAsFixed(1)}',
        border: const OutlineInputBorder(),
        suffixText: 'Hz',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      onChanged: (value) {
        final newRate = double.tryParse(value);
        if (newRate != null && newRate >= 0.1 && newRate <= widget.maxRate) {
          _lastValidValue = newRate;
          widget.onChanged(newRate);
        }
      },
      onSubmitted: (value) {
        final newRate = double.tryParse(value);
        if (newRate != null && newRate >= 0.1 && newRate <= widget.maxRate) {
          _lastValidValue = newRate;
          widget.onChanged(newRate);
        } else {
          // Reset to last valid value if invalid
          widget.controller.text = (_lastValidValue ?? widget.initialValue).toStringAsFixed(1);
        }
      },
    );
  }
}
