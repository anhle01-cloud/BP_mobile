import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../providers/publisher_provider.dart';
import '../../services/publisher_manager.dart';
import '../../services/topic_subscription_service.dart';
import '../../models/network_client.dart';
import '../../models/topic_history.dart';

class ClientManagementScreen extends ConsumerStatefulWidget {
  const ClientManagementScreen({super.key});

  @override
  ConsumerState<ClientManagementScreen> createState() => _ClientManagementScreenState();
}

class _ClientManagementScreenState extends ConsumerState<ClientManagementScreen> {
  final TopicSubscriptionService _subscriptionService = TopicSubscriptionService();

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(publisherManagerProvider);
    final clientsAsync = ref.watch(connectedClientsProvider);
    final topicsAsync = ref.watch(networkTopicsProvider);
    final historyAsync = ref.watch(topicHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Management'),
        backgroundColor: AppColors.main,
        foregroundColor: Colors.white,
      ),
      body: clientsAsync.when(
        data: (clients) {
          if (clients.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices_other,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No ESP32 clients connected',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect ESP32 devices to see them here',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }

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
                        'Connected Clients',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage topic subscriptions for recording sessions and dashboard widgets. Only subscribed topics will be filtered from the WebSocket message pool.',
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

              // Client cards
              ...clients.map((client) {
                return _buildClientCard(
                  client,
                  topicsAsync,
                  historyAsync,
                  manager,
                );
              }).toList(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.main),
              const SizedBox(height: 16),
              Text(
                'Error loading clients',
                style: TextStyle(color: AppColors.main),
              ),
              Text(
                '$error',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientCard(
    NetworkClient client,
    AsyncValue<Map<String, Map<String, dynamic>>> topicsAsync,
    AsyncValue<Map<String, List<TopicHistoryEntry>>> historyAsync,
    PublisherManager manager,
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
      margin: const EdgeInsets.only(bottom: 16),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            Text(
              'Connected: ${DateFormat('HH:mm:ss').format(client.connectedAt)}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
            Text(
              'Topics: ${client.topics.length}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
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
                // Connection info
                Text(
                  'Connection Info',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Status', client.isConnected ? 'Connected' : 'Disconnected'),
                if (client.latencyMs != null)
                  _buildInfoRow('Latency', '${client.latencyMs}ms'),
                if (client.missedPings > 0)
                  _buildInfoRow('Missed Pings', '${client.missedPings}'),
                const SizedBox(height: 16),
                
                // Topics section
                Text(
                  'Available Topics (${client.topics.length})',
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
                            
                            return _buildTopicSubscriptionCard(
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

  Widget _buildTopicSubscriptionCard(
    String clientName,
    String topic,
    String fullTopicName,
    TopicMetadata? metadata,
    Map<String, dynamic>? topicInfo,
    List<TopicHistoryEntry> historyEntries,
  ) {
    return FutureBuilder<bool>(
      future: _subscriptionService.isSubscribed(fullTopicName),
      builder: (context, snapshot) {
        final isSubscribed = snapshot.data ?? false;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isSubscribed
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.textPrimary.withValues(alpha: 0.03),
          child: ExpansionTile(
            leading: Checkbox(
              value: isSubscribed,
              onChanged: (value) async {
                if (value == true) {
                  await _subscriptionService.subscribeTopic(fullTopicName);
                  // Update WebSocket server subscriptions
                  final manager = ref.read(publisherManagerProvider);
                  final server = manager.webSocketServer;
                  if (server != null) {
                    server.subscribeTopic(fullTopicName);
                  }
                } else {
                  await _subscriptionService.unsubscribeTopic(fullTopicName);
                  // Update WebSocket server subscriptions
                  final manager = ref.read(publisherManagerProvider);
                  final server = manager.webSocketServer;
                  if (server != null) {
                    server.unsubscribeTopic(fullTopicName);
                  }
                }
                setState(() {});
              },
            ),
            title: Text(
              topic,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSubscribed ? AppColors.accent : AppColors.textPrimary,
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
                  isSubscribed
                      ? '✓ Subscribed - Messages will be filtered'
                      : 'Not subscribed - Messages ignored',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSubscribed ? AppColors.accent : AppColors.textTertiary,
                    fontWeight: isSubscribed ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
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
      },
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
}

