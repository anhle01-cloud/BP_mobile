import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../models/experiment.dart';
import '../../models/topic.dart';
import '../../providers/experiment_provider.dart';
import 'experiment_detail_screen.dart';

class ExperimentListScreen extends ConsumerWidget {
  const ExperimentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experimentsAsync = ref.watch(experimentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Experiments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateExperimentDialog(context, ref),
          ),
        ],
      ),
      body: experimentsAsync.when(
        data: (experiments) {
          if (experiments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.science_outlined,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No experiments yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _showCreateExperimentDialog(context, ref),
                    child: const Text('Create your first experiment'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: experiments.length,
            itemBuilder: (context, index) {
              final experiment = experiments[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    experiment.isActive
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: experiment.isActive
                        ? AppColors.accent
                        : AppColors.textTertiary,
                  ),
                  title: Text(experiment.name),
                  subtitle: FutureBuilder<int>(
                    future: _getExperimentStorageSize(ref, experiment.id!),
                    builder: (context, snapshot) {
                      final storageSize = snapshot.data ?? 0;
                      String formatBytes(int bytes) {
                        if (bytes < 1024) return '$bytes B';
                        if (bytes < 1024 * 1024)
                          return '${(bytes / 1024).toStringAsFixed(1)} KB';
                        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
                      }

                      return Text(
                        'Created: ${_formatDate(experiment.createdAt)}\nStorage: ${formatBytes(storageSize)}',
                      );
                    },
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'view':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExperimentDetailScreen(
                                experimentId: experiment.id!,
                              ),
                            ),
                          );
                          break;
                        case 'export':
                          await _exportExperiment(context, ref, experiment);
                          break;
                        case 'delete':
                          _showDeleteDialog(context, ref, experiment);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility),
                            SizedBox(width: 8),
                            Text('View/Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Text('Export'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppColors.main),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: AppColors.main),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExperimentDetailScreen(
                          experimentId: experiment.id!,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.main),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(experimentsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateExperimentDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Experiment'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Experiment Name',
            hintText: 'Enter experiment name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final name = nameController.text.trim();
                final repository = ref.read(experimentRepositoryProvider);
                final now = DateTime.now().millisecondsSinceEpoch;
                final experiment = Experiment(
                  name: name,
                  createdAt: now,
                  isActive: false,
                );
                final id = await repository.createExperiment(experiment);

                // Create default topics for this experiment
                await _createDefaultTopics(repository, id);

                ref.invalidate(experimentsProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ExperimentDetailScreen(experimentId: id),
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportExperiment(
    BuildContext context,
    WidgetRef ref,
    Experiment experiment,
  ) async {
    try {
      final repository = ref.read(experimentRepositoryProvider);

      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      // Get export directory
      final exportDir = await repository.getExportDirectory();
      if (exportDir.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access export directory'),
              backgroundColor: AppColors.main,
            ),
          );
        }
        return;
      }

      // Create filename with timestamp (ZIP format)
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = '${experiment.name.replaceAll(' ', '_')}_$timestamp.zip';
      final filePath = '$exportDir/$filename';

      // Write to file (ZIP with per-session JSONs)
      await repository.exportExperimentToFile(experiment.id!, filePath);

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exported to: $filename',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  filePath,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.main,
          ),
        );
      }
    }
  }

  Future<void> _createDefaultTopics(
    experimentRepository,
    int experimentId,
  ) async {
    final defaultTopics = [
      Topic(
        experimentId: experimentId,
        name: 'gps/location',
        enabled: false,
        samplingRate: 2.0, // 2 Hz default
      ),
      Topic(
        experimentId: experimentId,
        name: 'imu/acceleration',
        enabled: false,
        samplingRate: 60.0, // 60 Hz default
      ),
      Topic(
        experimentId: experimentId,
        name: 'imu/gyroscope',
        enabled: false,
        samplingRate: 60.0,
      ),
      Topic(
        experimentId: experimentId,
        name: 'imu/magnetometer',
        enabled: false,
        samplingRate: 60.0,
      ),
    ];

    for (var topic in defaultTopics) {
      await experimentRepository.createTopic(topic);
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    Experiment experiment,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Experiment'),
        content: Text(
          'Are you sure you want to delete "${experiment.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(deleteExperimentProvider(experiment.id!).future);
              if (context.mounted) {
                Navigator.pop(context);
                ref.invalidate(experimentsProvider);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.main),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  Future<int> _getExperimentStorageSize(WidgetRef ref, int experimentId) async {
    final repository = ref.read(experimentRepositoryProvider);
    return await repository.getExperimentStorageSize(experimentId);
  }
}
