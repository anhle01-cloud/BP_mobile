import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../providers/publisher_provider.dart';
import '../../services/publisher_manager.dart';
import '../../models/network_client.dart';
import '../../models/topic_history.dart';

class PublishersViewScreen extends ConsumerStatefulWidget {
  const PublishersViewScreen({super.key});

  @override
  ConsumerState<PublishersViewScreen> createState() => _PublishersViewScreenState();
}

class _PublishersViewScreenState extends ConsumerState<PublishersViewScreen> {
  // Controllers for sampling rate text fields to avoid rebuild issues
  final Map<String, TextEditingController> _rateControllers = {};
  
  @override
  void dispose() {
    for (var controller in _rateControllers.values) {
      controller.dispose();
    }
    _rateControllers.clear();
    super.dispose();
  }
  
  /// Get user-friendly error message for sensor PlatformException
  String _getSensorErrorMessage(String publisherName, PlatformException e) {
    final publisherDisplayNames = {
      'gps': 'GPS',
      'imu': 'IMU',
      'external': 'External (ESP32)',
    };
    
    final displayName = publisherDisplayNames[publisherName] ?? publisherName;
    
    // Check error code for common sensor availability issues
    if (e.code == 'sensor_not_available' || 
        e.code == 'NO_SENSOR' || 
        e.message?.toLowerCase().contains('sensor') == true ||
        e.message?.toLowerCase().contains('not available') == true ||
        e.message?.toLowerCase().contains('not found') == true) {
      return 'This device does not have a $displayName sensor. The sensor is not available on this hardware.';
    }
    
    // Generic PlatformException message
    if (e.message != null && e.message!.isNotEmpty) {
      return '${displayName}: ${e.message}';
    }
    
    return 'Failed to enable $displayName. The sensor may not be available on this device.';
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

        // INTERNAL PUBLISHERS SECTION
        _buildSectionHeader('Internal Publishers'),
        const SizedBox(height: 8),
        ..._buildInternalPublishers(manager, status),
        const SizedBox(height: 16),

        // NETWORK PUBLISHERS SECTION
        _buildSectionHeader('Network Publishers'),
        const SizedBox(height: 8),
        _buildNetworkPublishersSection(manager, isExternalEnabled, isExternalActive),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  List<Widget> _buildInternalPublishers(
    PublisherManager manager,
    Map<String, bool> status,
  ) {
    final internalPublishers = [
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
    ];

    return internalPublishers.map((publisher) {
      final publisherName = publisher['name'] as String;
      final isActive = status[publisherName] ?? false;
      final isEnabled = manager.isPublisherEnabled(publisherName);

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
              if (isEnabled) ...[
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
                if (value && mounted) {
                  setState(() {});
                }
                
                if (mounted) {
                  String errorMessage;
                  String errorTitle = 'Error';
                  
                  if (e is PlatformException) {
                    errorTitle = 'Sensor Not Available';
                    errorMessage = _getSensorErrorMessage(publisherName, e);
                  } else {
                    errorMessage = 'Failed to ${value ? 'enable' : 'disable'} ${publisher['displayName']}: $e';
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            errorTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.main,
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(
                        label: 'OK',
                        textColor: Colors.white,
                        onPressed: () {},
                      ),
                    ),
                  );
                }
              }
            },
            activeThumbColor: AppColors.accent,
          ),
          children: [
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
          ],
        ),
      );
    }).toList();
  }

  Widget _buildNetworkPublishersSection(
    PublisherManager manager,
    bool isExternalEnabled,
    bool isExternalActive,
  ) {
    // External publisher toggle
    final externalPublisherCard = Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isExternalActive 
              ? AppColors.accent 
              : (isExternalEnabled ? AppColors.textSecondary : AppColors.textTertiary),
          child: const Icon(
            Icons.wifi,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: const Text(
          'Network (ESP32)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
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
              isExternalActive 
                  ? 'Active - Waiting for clients' 
                  : (isExternalEnabled ? 'Enabled - Starting...' : 'Disabled'),
              style: TextStyle(
                fontSize: 12,
                color: isExternalActive 
                    ? AppColors.accent 
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: Switch(
          value: isExternalEnabled,
          onChanged: (value) async {
            try {
              if (value) {
                await manager.enablePublisher('external');
              } else {
                await manager.disablePublisher('external');
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to ${value ? 'enable' : 'disable'} Network publisher: $e'),
                    backgroundColor: AppColors.main,
                  ),
                );
              }
            }
          },
          activeThumbColor: AppColors.accent,
        ),
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Data from ESP32 clients via WebSocket. Configured on ESP32 side.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    // Connected clients list
    final clientsAsync = ref.watch(connectedClientsProvider);
    final topicsAsync = ref.watch(networkTopicsProvider);
    final historyAsync = ref.watch(topicHistoryProvider);

    return Column(
      children: [
        externalPublisherCard,
        if (isExternalEnabled)
          clientsAsync.when(
            data: (clients) {
              if (clients.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.devices_other,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No ESP32 clients connected',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connect ESP32 devices to see them here',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: clients.map((client) {
                  return _buildClientCard(
                    client,
                    topicsAsync,
                    historyAsync,
                  );
                }).toList(),
              );
            },
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, stack) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading clients: $error',
                  style: TextStyle(color: AppColors.main),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildClientCard(
    NetworkClient client,
    AsyncValue<Map<String, Map<String, dynamic>>> topicsAsync,
    AsyncValue<Map<String, List<TopicHistoryEntry>>> historyAsync,
  ) {
    final quality = client.connectionQuality;
    final qualityText = client.connectionQualityText;
    Color qualityColor;
    
    if (quality == 0.0) {
      qualityColor = AppColors.textTertiary;
    } else if (quality < 0.4) {
      qualityColor = Colors.red;
    } else if (quality < 0.7) {
      qualityColor = Colors.orange;
    } else if (quality < 0.9) {
      qualityColor = Colors.blue;
    } else {
      qualityColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: client.isConnected ? qualityColor : AppColors.textTertiary,
          child: const Icon(
            Icons.devices_other,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          client.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: client.isConnected ? qualityColor : AppColors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              client.isConnected ? qualityText : 'Disconnected',
              style: TextStyle(
                fontSize: 12,
                color: client.isConnected ? qualityColor : AppColors.textTertiary,
              ),
            ),
            if (client.latencyMs != null) ...[
              const SizedBox(width: 8),
              Text(
                '${client.latencyMs}ms',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection info
                _buildInfoRow('Connected', client.connectedAt.toString().substring(0, 19)),
                if (client.latencyMs != null)
                  _buildInfoRow('Latency', '${client.latencyMs}ms'),
                if (client.missedPings > 0)
                  _buildInfoRow('Missed Pings', '${client.missedPings}'),
                const SizedBox(height: 16),
                
                // Topics list
                Text(
                  'Topics (${client.topics.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                
                topicsAsync.when(
                  data: (topicsMap) {
                    return historyAsync.when(
                      data: (history) {
                        return Column(
                          children: client.topics.map((topic) {
                            final fullTopicName = '${client.name}/$topic';
                            final topicInfo = topicsMap[fullTopicName];
                            final metadata = client.topicMetadata[topic];
                            final historyEntries = history[fullTopicName] ?? [];
                            
                            return _buildTopicCard(
                              client.name,
                              topic,
                              fullTopicName,
                              metadata,
                              topicInfo,
                              historyEntries,
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => Text('Error: $e', style: TextStyle(color: AppColors.main)),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, s) => Text('Error: $e', style: TextStyle(color: AppColors.main)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(
    String clientName,
    String topic,
    String fullTopicName,
    TopicMetadata? metadata,
    Map<String, dynamic>? topicInfo,
    List<TopicHistoryEntry> historyEntries,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.textPrimary.withValues(alpha: 0.03),
      child: ExpansionTile(
        title: Text(
          topic,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (metadata != null) ...[
              Text(
                metadata.description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (metadata.unit != null || metadata.samplingRate != null)
                  Text(
                    [
                      if (metadata.samplingRate != null) '${metadata.samplingRate!.toStringAsFixed(1)} Hz',
                      if (metadata.unit != null) metadata.unit!,
                    ].join(' • '),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
            Text(
              '${historyEntries.length} recent entries',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (historyEntries.isEmpty)
                  Text(
                    'No recent entries',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  ...historyEntries.reversed.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('HH:mm:ss.SSS').format(entry.dateTime),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.data.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
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
