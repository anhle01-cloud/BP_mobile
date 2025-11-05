import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../models/experiment.dart';
import '../../models/topic.dart';
import '../../providers/experiment_provider.dart';
import '../../providers/recording_provider.dart';
import '../../providers/publisher_provider.dart';
import '../recording/recording_console_screen.dart';
import 'sessions_history_screen.dart';

class ExperimentDetailScreen extends ConsumerStatefulWidget {
  final int experimentId;

  const ExperimentDetailScreen({super.key, required this.experimentId});

  @override
  ConsumerState<ExperimentDetailScreen> createState() =>
      _ExperimentDetailScreenState();
}

class _ExperimentDetailScreenState
    extends ConsumerState<ExperimentDetailScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isEditing = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Refresh sessions when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(experimentSessionsProvider(widget.experimentId));
    });
    
    final experimentAsync = ref.watch(experimentProvider(widget.experimentId));
    final topicsAsync =
        ref.watch(experimentTopicsProvider(widget.experimentId));
    final recordingState = ref.watch(recordingStateProvider);
    
    // Check if this experiment is currently being recorded
    final isRecording = recordingState.isRecording &&
        recordingState.activeExperiment?.id == widget.experimentId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Experiment Details'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveExperimentName(ref),
            ),
          if (!_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SessionsHistoryScreen(
                      experimentId: widget.experimentId,
                    ),
                  ),
                );
              },
              tooltip: 'View Sessions',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _startEditing(ref),
            ),
          ],
        ],
      ),
      body: experimentAsync.when(
        data: (experiment) {
          if (experiment == null) {
            return const Center(child: Text('Experiment not found'));
          }

          if (_nameController.text.isEmpty) {
            _nameController.text = experiment.name;
          }

          final isRecording = recordingState.isRecording &&
              recordingState.activeExperiment?.id == experiment.id;
          
          // Get available topics from enabled publishers
          final publisherManager = ref.watch(publisherManagerProvider);
          final availableTopicsAsync = ref.watch(availableTopicsProvider);

          return topicsAsync.when(
            data: (topics) {
              // Map of topic names to enabled state (from experiment topics)
              final Map<String, bool> topicEnabledMap = {};
              for (var topic in topics) {
                topicEnabledMap[topic.name] = topic.enabled;
              }

              return availableTopicsAsync.when(
                data: (availableTopics) => Column(
                  children: [
                    // Experiment name
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _isEditing
                          ? TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Experiment Name',
                                border: OutlineInputBorder(),
                              ),
                            )
                          : Text(
                              experiment.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                    ),
                    const Divider(),

                    // Available Topics section (from enabled publishers)
                    Expanded(
                      child: availableTopics.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.sensors_off,
                                  size: 64,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No publishers enabled',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Enable publishers in the Publishers view to see available topics',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textTertiary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: availableTopics.length,
                            itemBuilder: (context, index) {
                              final topicName = availableTopics[index];
                              final isTopicEnabled = topicEnabledMap[topicName] ?? false;
                              final isTopicActive = isRecording && 
                                  (recordingState.publisherStatus[topicName] == true);
                              final isTopicUnavailable = isRecording && 
                                  recordingState.unavailableTopics.containsKey(topicName);
                              final unavailableReason = recordingState.unavailableTopics[topicName];
                          
                          // Get sampling rate from publisher manager for internal topics
                          String samplingRateText;
                          if (topicName.startsWith('gps/')) {
                            samplingRateText = '${publisherManager.getSamplingRate('gps').toStringAsFixed(1)} Hz';
                          } else if (topicName.startsWith('imu/')) {
                            samplingRateText = '${publisherManager.getSamplingRate('imu').toStringAsFixed(1)} Hz';
                          } else {
                            samplingRateText = 'Configured in ESP32';
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: Checkbox(
                                value: isTopicEnabled,
                                onChanged: isRecording
                                    ? null
                                    : (value) async {
                                        // Toggle topic in database
                                        await topicsAsync.when(
                                          data: (topics) async {
                                            final topic = topics.firstWhere(
                                              (t) => t.name == topicName,
                                              orElse: () => Topic(
                                                experimentId: experiment.id!,
                                                name: topicName,
                                                enabled: value ?? false,
                                                samplingRate: topicName.startsWith('gps/')
                                                    ? publisherManager.getSamplingRate('gps')
                                                    : (topicName.startsWith('imu/')
                                                        ? publisherManager.getSamplingRate('imu')
                                                        : 1.0),
                                              ),
                                            );
                                            if (topic.id != null) {
                                              await ref.read(
                                                  toggleTopicProvider(topic).future);
                                            } else {
                                              // Create new topic
                                              await ref.read(
                                                  createTopicProvider(topic).future);
                                            }
                                          },
                                          loading: () {},
                                          error: (_, __) {},
                                        );
                                      },
                              ),
                              title: Text(topicName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Sampling Rate: $samplingRateText'),
                                  if (isRecording) ...[
                                    if (isTopicActive)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: AppColors.accent,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Active',
                                            style: TextStyle(
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                    else if (isTopicUnavailable)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.warning,
                                            size: 16,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              unavailableReason ?? 'Unavailable',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.cancel,
                                            size: 16,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Inactive',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          );
                            },
                          ),
                    ),

                    // Record button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: isRecording
                              ? null
                              : () => _startRecording(
                                  context, ref, experiment, AsyncValue.data(topics)),
                          icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
                          label: Text(isRecording ? 'Recording...' : 'Start Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isRecording ? AppColors.main : AppColors.accent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error loading topics: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: isRecording
          ? FloatingActionButton.extended(
              onPressed: () => _stopRecording(context, ref),
              backgroundColor: AppColors.main,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Recording'),
            )
          : null,
    );
  }

  void _startEditing(WidgetRef ref) {
    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _saveExperimentName(WidgetRef ref) async {
    final experimentAsync =
        ref.read(experimentProvider(widget.experimentId));
    final experiment = await experimentAsync.when(
      data: (data) => Future.value(data),
      loading: () => Future.value(null),
      error: (_, __) => Future.value(null),
    );
    if (experiment != null && _nameController.text.isNotEmpty) {
      await ref
          .read(updateExperimentProvider(
                  experiment.copyWith(name: _nameController.text.trim()))
              .future);
      setState(() {
        _isEditing = false;
      });
    }
  }

  
  Future<void> _stopRecording(BuildContext context, WidgetRef ref) async {
    // Stop immediately without confirmation for faster response
    await ref.read(recordingStateProvider.notifier).stopRecording();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording stopped'),
          backgroundColor: AppColors.accent,
          duration: Duration(seconds: 2),
        ),
      );
      // Navigate back to experiment list or refresh
      Navigator.pop(context);
    }
  }

  Future<void> _startRecording(BuildContext context, WidgetRef ref,
      Experiment experiment, AsyncValue<List<Topic>> topicsAsync) async {
    // Check if already recording
    final recordingState = ref.read(recordingStateProvider);
    if (recordingState.isRecording) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Already recording: ${recordingState.activeExperiment?.name ?? "Unknown"}. Please stop the current recording first.',
            ),
            backgroundColor: AppColors.main,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final topics = await topicsAsync.when(
      data: (data) => Future.value(data),
      loading: () => Future.value(<Topic>[]),
      error: (_, __) => Future.value(<Topic>[]),
    );
    final enabledTopics = topics.where((t) => t.enabled).toList();

    if (enabledTopics.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable at least one topic')),
        );
      }
      return;
    }

    try {
      await ref
          .read(recordingStateProvider.notifier)
          .startRecording(experiment, enabledTopics);

      if (context.mounted) {
        // Use pushReplacement to prevent going back to a stale screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RecordingConsoleScreen(experimentId: experiment.id!),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting recording: $e'),
            backgroundColor: AppColors.main,
          ),
        );
      }
    }
  }
}
